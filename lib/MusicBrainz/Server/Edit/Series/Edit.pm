package MusicBrainz::Server::Edit::Series::Edit;
use 5.10.0;
use Moose;

use MusicBrainz::Server::Constants qw(
    $EDIT_SERIES_CREATE
    $EDIT_SERIES_EDIT
);
use MusicBrainz::Server::Data::Series;
use MusicBrainz::Server::Edit::Utils qw( changed_display_data changed_relations );
use MusicBrainz::Server::Entity::PartialDate;
use MusicBrainz::Server::Translation qw ( N_l );

use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict Optional );

use aliased 'MusicBrainz::Server::Entity::Series';

no if $] >= 5.018, warnings => "experimental::smartmatch";

extends 'MusicBrainz::Server::Edit::Generic::Edit';
with 'MusicBrainz::Server::Edit::Series';
with 'MusicBrainz::Server::Edit::CheckForConflicts';
with 'MusicBrainz::Server::Edit::Role::AllowAmending' => {
    create_edit_type => $EDIT_SERIES_CREATE,
    entity_type => 'series',
};
with 'MusicBrainz::Server::Edit::Role::CheckDuplicates';

sub edit_type { $EDIT_SERIES_EDIT }
sub edit_name { N_l('Edit series') }
sub _edit_model { 'Series' }
sub series_id { shift->entity_id }

sub change_fields
{
    return Dict[
        name                    => Optional[Str],
        comment                 => Optional[Str],
        type_id                 => Optional[Int],
        ordering_type_id        => Optional[Int],
    ];
}

has '+data' => (
    isa => Dict[
        entity => Dict[
            id => Int,
            gid => Optional[Str],
            name => Str
        ],
        new => change_fields(),
        old => change_fields(),
    ]
);

sub foreign_keys {
    my $self = shift;
    my $relations = {};

    changed_relations($self->data, $relations,
        SeriesType          => 'type_id',
        SeriesOrderingType  => 'ordering_type_id',
    );

    $relations->{Series} = [ $self->data->{entity}{id} ];

    return $relations;
}

sub build_display_data {
    my ($self, $loaded) = @_;

    my %map = (
        name                => 'name',
        comment             => 'comment',
        type                => [ qw( type_id SeriesType ) ],
        ordering_type       => [ qw( ordering_type_id SeriesOrderingType ) ],
    );

    my $data = changed_display_data($self->data, $loaded, %map);

    $data->{series} = $loaded->{Series}{ $self->data->{entity}{id} }
        || Series->new( name => $self->data->{entity}{name} );

    return $data;
}

around allow_auto_edit => sub {
    my ($orig, $self, @args) = @_;

    return 1 if $self->can_amend($self->series_id);

    my $series = $self->c->model('Series')->get_by_id($self->series_id);
    $self->c->model('SeriesType')->load($series);
    my ($items, $hits) = $self->c->model('Series')->get_entities($series, 1, 0);

    # Allow auto-editing the series if it has no items. This is necessary
    # when an editor changes the series type and adds new part-of
    # relationships in a single submission. The series must be modified before
    # the relationships are added in order for them to display.
    return 1 unless scalar(@$items);

    # Changing the ordering type is not allowed if there are items.
    return 0 if $self->_changes_ordering_type;

    return $self->$orig(@args);
};

after insert => sub {
    my ($self) = @_;

    # prevent auto-editors from changing the ordering type as an auto-edit
    $self->auto_edit(0) if $self->_changes_ordering_type;
};

around editor_may_approve => sub {
    my ($orig, $self, @args) = @_;
    return 0 if $self->_changes_ordering_type;
    return $self->$orig(@args);
};

sub current_instance {
    my $self = shift;
    $self->c->model('Series')->get_by_id($self->entity_id),
}

sub _edit_hash {
    my ($self, $data) = @_;
    return $self->merge_changes;
}

sub _changes_ordering_type {
    my $self = shift;
    return ($self->data->{old}{ordering_type_id} // 0) != ($self->data->{new}{ordering_type_id} // 0);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;

=head1 LICENSE

Copyright (C) 2014 MetaBrainz Foundation

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
