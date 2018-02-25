package MusicBrainz::Server::Form::Field::ArtistCredit;
use HTML::FormHandler::Moose;
use Scalar::Util qw( looks_like_number );
use Storable qw( dclone );
use Text::Trim qw( );
use JSON qw( to_json );
extends 'HTML::FormHandler::Field::Compound';

use MusicBrainz::Server::Edit::Utils qw( clean_submitted_artist_credits );
use MusicBrainz::Server::Entity::ArtistCredit;
use MusicBrainz::Server::Entity::ArtistCreditName;
use MusicBrainz::Server::Translation qw( l ln );

has_field 'names'             => ( type => 'Repeatable', num_when_empty => 1 );
has_field 'names.name'        => ( type => '+MusicBrainz::Server::Form::Field::Text');
has_field 'names.artist'      => ( type => '+MusicBrainz::Server::Form::Field::Artist' );
has_field 'names.join_phrase' => (
    # Can't use MusicBrainz::Server::Form::Field::Text as we need whitespace on the left
    # and right.
    type => 'Text',
    trim => { transform => sub { MusicBrainz::Server::Data::Utils::sanitize(shift) } }
);

around 'validate_field' => sub {
    my $orig = shift;
    my $self = shift;

    my $ret = $self->$orig(@_);

    my $input = $self->result->input;

    my $artists = 0;
    for (@{ $input->{'names'} })
    {
        next unless $_;

        my $artist_id = Text::Trim::trim $_->{'artist'}->{'id'};
        my $artist_name = Text::Trim::trim $_->{'artist'}->{'name'};
        my $name = Text::Trim::trim $_->{'name'} || Text::Trim::trim $_->{'artist'}->{'name'};

        if ($artist_id && $name)
        {
            $artists++;
        }
        elsif (! $artist_id && ! $artist_name && $name)
        {
            $self->add_error(
                l('Please add an artist name for {credit}',
                  { credit => $name }));
        }
        elsif (! $artist_id && ( $name || $artist_name ))
        {
            # FIXME: better error message.
            $self->add_error(
                l('Artist "{artist}" is unlinked, please select an existing artist.
                   You may need to add a new artist to MusicBrainz first.',
                  { artist => ($name || $artist_name) }));
        }
        elsif (!$artist_id)
        {
            $self->add_error(l('Please add an artist name for each credit.'));
        }
    }

    # Do not nag about the field being required if there are other
    # errors which already invalidate the field.
    return 0 if $self->has_errors;

    # If the form is editing an existing entity and the AC field is entirely
    # missing (as opposed to existing but being empty, which is handled above),
    # the field will *not* be required. The form will see this is as no changes
    # being made. This behavior allows bots and browser scripts to function
    # properly (i.e. environments where AC fields aren't generated).
    unless ($artists || $self->form->init_object)
    {
        $self->add_error(l("Artist credit field is required"));
    }

    return !$self->has_errors;
};

around 'value' => sub {
    my $orig = shift;
    my $self = shift;

    my $ret = $self->$orig(@_);

    return $ret unless $ret && $ret->{names};

    my @names = @{ $ret->{names} };
    for my $i (0 .. $#names) {
        if ($self->result->input) {
            # HTML::FormHandler incorrectly trims the join phrase if
            # it is a single space, work around this by taking the
            # join phrase directly from the input here.
            $ret->{names}->[$i]->{join_phrase} = $self->result->input->{names}->[$i]->{join_phrase};
        }
    }

    return clean_submitted_artist_credits($ret);
};

sub json {
    my $self = shift;
    my $result = $self->result;
    my $names = [];

    if (defined $result) {
        if ($result->input) {
            $names = dclone($result->input->{names});

        } elsif ($result->value) {
            $names = dclone($result->value->{names});
        }
    }

    if (!$names || scalar @$names == 0) {
        $names = [{}];
    }

    my $c = $self->form->ctx;

    my $artists = $c->model('Artist')->get_by_ids(map { $_->{artist}->{id} } @$names);
    for my $name (@$names) {
        my $artist = $artists->{$name->{artist}->{id}};
        $name->{artist} = $artist->TO_JSON if $artist;
        $name->{joinPhrase} = delete $name->{join_phrase};
    }

    return to_json($names);
}

=head1 LICENSE

Copyright (C) 2011 MetaBrainz Foundation

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=cut

1;
