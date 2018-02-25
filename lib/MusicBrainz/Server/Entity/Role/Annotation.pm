package MusicBrainz::Server::Entity::Role::Annotation;
use Moose::Role;

use MusicBrainz::Server::Entity::Types;

has 'latest_annotation' => (
    isa => 'Annotation',
    is  => 'rw',
);

around TO_JSON => sub {
    my ($orig, $self) = @_;

    my $json = $self->$orig;
    my $annotation = $self->latest_annotation;

    if (defined $annotation) {
        $json->{annotation} = $annotation->text;
    }

    return $json;
};

no Moose::Role;
1;

=head1 COPYRIGHT

Copyright (C) 2009 Oliver Charles

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

