package MusicBrainz::Server::Entity::Artist;

use Moose;
use MusicBrainz::Server::Constants qw( $DARTIST_ID $VARTIST_ID $VARTIST_GID );
use MusicBrainz::Server::Entity::PartialDate;
use MusicBrainz::Server::Entity::Types;

extends 'MusicBrainz::Server::Entity::CoreEntity';
with 'MusicBrainz::Server::Entity::Role::Taggable';
with 'MusicBrainz::Server::Entity::Role::Linkable';
with 'MusicBrainz::Server::Entity::Role::Annotation';
with 'MusicBrainz::Server::Entity::Role::LastUpdate';
with 'MusicBrainz::Server::Entity::Role::Rating';
with 'MusicBrainz::Server::Entity::Role::Age';
with 'MusicBrainz::Server::Entity::Role::IPI';
with 'MusicBrainz::Server::Entity::Role::ISNI';
with 'MusicBrainz::Server::Entity::Role::Comment';
with 'MusicBrainz::Server::Entity::Role::Area';
with 'MusicBrainz::Server::Entity::Role::Type' => { model => 'ArtistType' };

sub entity_type { 'artist' }

has 'sort_name' => (
    is => 'rw',
    isa => 'Str'
);

has 'gender_id' => (
    is => 'rw',
    isa => 'Int'
);

has 'gender' => (
    is => 'rw',
    isa => 'Gender',
);

sub gender_name
{
    my ($self) = @_;
    return $self->gender ? $self->gender->name : undef;
}

sub l_gender_name
{
    my ($self) = @_;
    return $self->gender ? $self->gender->l_name : undef;
}

has 'begin_area_id' => (
    is => 'rw',
    isa => 'Int'
);

has 'begin_area' => (
    is => 'rw',
    isa => 'Area'
);

has 'end_area_id' => (
    is => 'rw',
    isa => 'Int'
);

has 'end_area' => (
    is => 'rw',
    isa => 'Area'
);

sub is_special_purpose {
    my $self = shift;
    return ($self->id && ($self->id == $DARTIST_ID ||
                          $self->id == $VARTIST_ID))
        || ($self->gid && $self->gid eq $VARTIST_GID);
}

sub _appearances_table_types { ("release", "release_group", "work", "recording") }

around TO_JSON => sub {
    my ($orig, $self) = @_;

    return {
        %{$self->$orig},
        $self->begin_area ? (begin_area => $self->begin_area->TO_JSON) : (),
        $self->end_area ? (end_area => $self->end_area->TO_JSON) : (),
        $self->gender ? (gender => $self->gender->TO_JSON) : (),
        begin_area_id => $self->begin_area_id,
        end_area_id => $self->end_area_id,
        gender_id => $self->gender_id,
        sort_name => $self->sort_name,
    };
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky

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
