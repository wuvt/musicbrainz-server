use MusicBrainz::Server::Constants qw( %ENTITIES @RELATABLE_ENTITIES );

for my $type (@RELATABLE_ENTITIES) {
    my $model = $ENTITIES{$type}{model};
    my $has_subs = $ENTITIES{$type}{subscriptions};
    my $subs_section = '';

    if ($has_subs) {
        $subs_section = <<EOF;
use MusicBrainz::Server::EditSearch::Predicate::Role::Subscribed;
with 'MusicBrainz::Server::EditSearch::Predicate::Role::Subscribed' => {
    type => '$type',
    template_clause => 'EXISTS (
        SELECT TRUE FROM edit_$type
         WHERE ROLE_CLAUSE(edit_$type.$type)
           AND edit_$type.edit = edit.id
    )',
    subscribed_column => '$type'
};
EOF
    }

    # This eval is what actually creates the package. We have to do it because
    # the 'package' function thinks it's a version number if you pass it a
    # string, and we can't interpolate $model any other way than this (the rest
    # could presumably just be done with a normal block).
    eval <<EOF;
package MusicBrainz::Server::EditSearch::Predicate::$model;
use Moose;
use MusicBrainz::Server::EditSearch::Predicate::Role::LinkedEntity;
with 'MusicBrainz::Server::EditSearch::Predicate::Role::LinkedEntity' => { type => '$type' };
$subs_section
with 'MusicBrainz::Server::EditSearch::Predicate';
EOF
};

1;

=head1 COPYRIGHT

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
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
