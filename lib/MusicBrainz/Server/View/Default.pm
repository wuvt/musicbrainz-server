package MusicBrainz::Server::View::Default;

use strict;
use base 'Catalyst::View::TT';
use DBDefs;
use MRO::Compat;
use Digest::MD5 qw( md5_hex );
use MusicBrainz::Server::Translation;
use MusicBrainz::Server::View::Base;

__PACKAGE__->config(TEMPLATE_EXTENSION => '.tt');

sub process {
    my $self = shift;
    my $c = $_[0];

    MusicBrainz::Server::View::Base::process($self, @_) or return 0;
    $self->next::method(@_) or return 0;
    MusicBrainz::Server::View::Base::_post_process($self, @_);
}

sub comma_list {
    my ($self, $c, $items) = @_;

    if (ref($items) ne 'ARRAY') {
        $items = [$items];
    }

    MusicBrainz::Server::Translation::comma_list(@$items);
}

sub comma_only_list {
    my ($self, $c, $items) = @_;

    if (ref($items) ne 'ARRAY') {
        $items = [$items];
    }

    MusicBrainz::Server::Translation::comma_only_list(@$items);
}

1;
