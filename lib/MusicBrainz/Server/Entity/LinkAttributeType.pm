package MusicBrainz::Server::Entity::LinkAttributeType;
use Moose;

use MusicBrainz::Server::Entity::Types;
use MusicBrainz::Server::Translation::Relationships;
use MusicBrainz::Server::Translation::Instruments;
use MusicBrainz::Server::Translation::InstrumentDescriptions;

use MusicBrainz::Server::Constants qw( $INSTRUMENT_ROOT_ID );

extends 'MusicBrainz::Server::Entity';

with 'MusicBrainz::Server::Entity::Role::OptionsTree' => {
    type => 'LinkAttributeType',
};

sub entity_type { 'link_attribute_type' }

has 'root_id' => (
    is => 'rw',
    isa => 'Int',
);

has 'root' => (
    is => 'rw',
    isa => 'LinkAttributeType',
);

sub l_name {
    my $self = shift;
    my $rootid = defined $self->root ? $self->root->id : $self->root_id;
    if ($rootid == $INSTRUMENT_ROOT_ID) {
        return MusicBrainz::Server::Translation::Instruments::l($self->name);
    } else {
        return MusicBrainz::Server::Translation::Relationships::l($self->name);
    }
}

sub l_description {
    my $self = shift;
    my $rootid = defined $self->root ? $self->root->id : $self->root_id;
    if ($rootid == $INSTRUMENT_ROOT_ID) {
        return MusicBrainz::Server::Translation::InstrumentDescriptions::l($self->description);
    } else {
        return MusicBrainz::Server::Translation::Relationships::l($self->description);
    }
}

has 'free_text' => (
    is => 'rw',
    isa => 'Bool',
);

has 'creditable' => (
    is => 'rw',
    isa => 'Bool',
);

around TO_JSON => sub {
    my ($orig, $self) = @_;

    return {
        %{ $self->$orig },
        gid => $self->gid,
        $self->root ? (root => $self->root->TO_JSON) : (),
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
