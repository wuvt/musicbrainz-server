package MusicBrainz::Server::Controller::WS::1::Track;
use Moose;
BEGIN { extends 'MusicBrainz::Server::ControllerBase::WS::1' }

use MusicBrainz::Server::Constants qw( $EDIT_RECORDING_ADD_PUIDS );

__PACKAGE__->config(
    model => 'Recording',
);

my $ws_defs = Data::OptList::mkopt([
    track => {
        method   => 'GET',
        inc      => [ qw( artist tags isrcs puids releases _relations ratings user-ratings user-tags  ) ],
    },
    track => {
        method => 'POST',
    }
]);

with 'MusicBrainz::Server::WebService::Validator' => {
     defs    => $ws_defs,
     version => 1,
};

with 'MusicBrainz::Server::Controller::WS::1::Role::ArtistCredit';
with 'MusicBrainz::Server::Controller::WS::1::Role::Rating';
with 'MusicBrainz::Server::Controller::WS::1::Role::Tags';
with 'MusicBrainz::Server::Controller::WS::1::Role::Relationships';

sub root : Chained('/') PathPart('ws/1/track') CaptureArgs(0) { }

around 'search' => sub
{
    my $orig = shift;
    my ($self, $c) = @_;

    $c->detach('submit') if $c->req->method eq 'POST';

    if (exists $c->req->query_params->{puid}) {
        my $puid = $c->model('PUID')->get_by_puid($c->req->query_params->{puid});
        my @recording_puids = $c->model('RecordingPUID')->find_by_puid($puid->id);
        $c->model('ArtistCredit')->load(map { $_->recording} @recording_puids);
        my %recording_release_map;

        for (@recording_puids) {
            $c->model('Artist')->load($_->recording->artist_credit->names->[0])
                if @{ $_->recording->artist_credit->names } == 1;

            my ($releases) = $c->model('Release')->find_by_recording($_->recording->id);
            $recording_release_map{$_->recording->id} = $releases;
        }

        $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
        $c->res->body(
            $c->stash->{serializer}->serialize_list('track', \@recording_puids, undef, {
                recording_release_map => \%recording_release_map
            })
        );
    }
    else {
        $self->$orig($c);
    }
};

sub submit : Private
{
    my ($self, $c) = @_;

    $c->authenticate({}, 'webservice');

    my $client = $c->req->params->{client};
    my (@puids, @isrcs);

    if (my $submitted = $c->req->params->{puid}) {
        @puids = ref($submitted) ? @$submitted : ($submitted);
    }

    if (my $submitted = $c->req->params->{isrc}) {
        @isrcs = ref($submitted) ? @$submitted : ($submitted);
    }

    if (@isrcs && @puids) {
        $c->stash->{error} = 'You cannot submit PUIDs and ISRCs in one call';
        $c->detach('bad_req');
    }

    $self->submit_puid($c, $client, @puids) if @puids;
    $self->submit_isrc($c, $client, @isrcs) if @isrcs;

    $c->stash->{error} = 'You must specify a PUID or ISRC to submit';
    $c->detach('bad_req');
}

sub submit_puid : Private
{
    my ($self, $c, $client, @pairs) = @_;

    my %submit;
    for my $pair (@pairs) {
        my ($recording_id, $puid) = split(' ', $pair);
        unless (MusicBrainz::Server::Validation::IsGUID($puid) &&
              MusicBrainz::Server::Validation::IsGUID($recording_id)) {
            $c->stash->{error} = 'Invalid trackid or PUID. Both must be valid MBIDs';
            $c->detach('bad_req');
        }

        $submit{$recording_id} ||= [];
        push @{ $submit{$recording_id} }, $puid;
    }

    # We have to have a limit, I think.  It's only sensible.
    # So far I've not seen anyone submit more that about 4,500 PUIDs at once,
    # so this limit won't affect anyone in a hurry.
    if (scalar(map { @$_ } values %submit) > 5000) {
        $c->detach('declined');
    }

    # Ensure that we're not a replicated server and that we were given a client version
    if ($client eq '') {
        $c->stash->{error} = 'Client parameter must be given';
        $c->detach('bad_req');
    }

    if (DBDefs::REPLICATION_TYPE == DBDefs::RT_SLAVE) {
        $c->stash->{error} = 'Cannot submit PUIDs to a slave server.';
        $c->detach('bad_req');
    }

    # Create a mapping of GID to ID
    my %recordings = map
        { ($_->gid => $_) }
            values %{ $c->model('Recording')->get_by_gids(keys %submit) };

    my $submitted = 0;
    my @buffer;

    my $flush = sub {
        $c->model('Edit')->create(
            edit_type      => $EDIT_RECORDING_ADD_PUIDS,
            client_version => $client,
            editor_id      => $c->user->id,
            puids          => \@buffer
        );

        @buffer = ();
    };

    while(my ($recording_gid, $puids) = each %submit) {
        next unless exists $recordings{ $recording_gid };

        $flush->() if ($submitted + @$puids > 100);

        push @buffer, map +{
            recording_id => $recordings{ $recording_gid }->id,
            puid         => $_
        }, @$puids;
    }

    $flush->();

    $c->detach;
}

sub submit_isrc : Private
{
    my ($self, $c, $client, @isrcs) = @_;

    $c->detach;
}

sub lookup : Chained('load') PathPart('')
{
    my ($self, $c, $gid) = @_;
    my $track = $c->stash->{entity};

    if ($c->stash->{inc}->isrcs) {
        $c->model('ISRC')->load_for_recordings($track);
    }

    if ($c->stash->{inc}->puids) {
        $c->model('RecordingPUID')->load_for_recordings($track);
    }

    if ($c->stash->{inc}->releases) {
        my ($releases) = $c->model('Release')->find_by_recording($track->id);

        $c->model('ReleaseStatus')->load(@$releases);
        $c->model('ReleaseGroup')->load(@$releases);
        $c->model('ReleaseGroupType')->load(map { $_->release_group } @$releases);
        $c->model('Script')->load(@$releases);
        $c->model('Language')->load(@$releases);

        $c->stash->{data}{releases} = $releases;
        $c->stash->{inc}->tracklist(1);

        unless ($c->stash->{inc}->artist) {
            $c->model('ArtistCredit')->load($track);
            $c->model('Artist')->load($track->artist_credit->names->[0])
                if (@{ $track->artist_credit->names } == 1);
        }
    }

    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('track', $track, $c->stash->{inc}, $c->stash->{data}));
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
