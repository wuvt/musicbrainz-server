package MusicBrainz::Server::Report::InstrumentReport;
use Moose::Role;

with 'MusicBrainz::Server::Report::QueryReport';

around inflate_rows => sub {
    my $orig = shift;
    my $self = shift;

    my $items = $self->$orig(@_);

    my $instruments = $self->c->model('Instrument')->get_by_ids(
        map { $_->{instrument_id} } @$items
    );
    $self->c->model('InstrumentType')->load(values %$instruments);

    return [
        map +{
            %$_,
            instrument => $instruments->{ $_->{instrument_id} }
        },
            @$items
    ];
};

1;

=head1 COPYRIGHT

This file is part of MusicBrainz, the open internet music database.
Copyright (C) 2017 MetaBrainz Foundation
Licensed under the GPL version 2, or (at your option) any later version:
http://www.gnu.org/licenses/gpl-2.0.txt

=cut
