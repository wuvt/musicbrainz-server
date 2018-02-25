package t::MusicBrainz::Server::Entity::Artist;
use Test::Routine;
use Test::Moose;
use Test::More;

use Date::Calc qw(This_Year);
use Hook::LexWrap;
use MusicBrainz::Server::Entity::Artist;
use MusicBrainz::Server::Entity::ArtistType;
use MusicBrainz::Server::Entity::ArtistAlias;
use aliased 'MusicBrainz::Server::Entity::PartialDate';

use MusicBrainz::Server::Constants qw( $DARTIST_ID $VARTIST_ID $VARTIST_GID );

test all => sub {

my $artist = MusicBrainz::Server::Entity::Artist->new();
ok( defined $artist->begin_date );
ok( $artist->begin_date->is_empty );
ok( defined $artist->end_date );
ok( $artist->end_date->is_empty );

is( $artist->type_name, undef );
is( $artist->last_updated , undef );
$artist->type(MusicBrainz::Server::Entity::ArtistType->new(id => 1, name => 'Person'));
is( $artist->type_name, 'Person' );
is( $artist->type->id, 1 );
is( $artist->type->name, 'Person' );

$artist->edits_pending(2);
is( $artist->edits_pending, 2 );

ok( !$artist->has_age );

my $constant_now = wrap 'DateTime::now', post => sub {
    return DateTime->new(
        year => '2011',
        month => 8,
        day => 9
    );
};

# FIXME: Split these tests and make them independent of each other

# testing ->age with exact dates
$artist->begin_date(PartialDate->new(year => 1976, month => 7, day => 23));
$artist->end_date(PartialDate->new(year => 1976, month => 7, day => 24));
$artist->ended(1);
my @got = $artist->age;
is_deeply ( \@got, [0, 0, 1], "Artist age 1 day" );

$artist->end_date(PartialDate->new(year => 1976, month => 8, day => 1));
@got = $artist->age;
is_deeply( \@got, [0, 0, 9], "Artist age 9 days" );

$artist->end_date(PartialDate->new(year => 1976, month => 11, day => 1));
@got = $artist->age;
is_deeply( \@got, [0, 3, 9], "Artist age 3 months" );

$artist->begin_date(PartialDate->new(year => 1553, month => 7, day => 23));
@got = $artist->age;
is_deeply( \@got, [423, 3, 9], "Artist age 423 years" );

$artist->end_date(PartialDate->new(year => 2140, month => 11, day => 1));
@got = $artist->age;
is_deeply( \@got, [587, 3, 9], "Artist age 587 years" );

# testing ->age with an empty end date.
$artist = MusicBrainz::Server::Entity::Artist->new();
$artist->begin_date(PartialDate->new(year => This_Year() - 24));
is( ($artist->age)[0], 24, "Artist still alive, age 24 years" );

# testing ->age with partial dates
$artist->begin_date(PartialDate->new(year => 2010));
$artist->end_date(PartialDate->new(year => 2012));
$artist->ended(1);
@got = $artist->age;
is_deeply( \@got, [2, 0, 0], "Artist with partial dates, age 1 year" );

$artist->end_date(PartialDate->new(year => 2012, month => 12));
@got = $artist->age;
is_deeply( \@got, [2, 11, 0], "Artist with partial dates, age 1 year" );

$artist->begin_date(PartialDate->new(year => 2010, month => 12));
$artist->end_date(PartialDate->new(year => 2012, month => 1));
@got = $artist->age;
is_deeply( \@got, [1, 1, 0], "Artist with partial dates, age 1 month" );

$artist->begin_date(PartialDate->new(year => 2010, month => 12, day => 31));
@got = $artist->age;
is_deeply ( \@got, [1, 0, 1], "Artist with partial dates, age 1 day" );

$artist->end_date(PartialDate->new(year => undef, month => 1));
ok(!$artist->has_age, "No age for ended artist without end year");

# testing ->age with negative years
$artist->begin_date(PartialDate->new(year => -551, month => 9, day => 28));
$artist->end_date(PartialDate->new(year => -479, month => 4, day => 11));
$artist->ended(1);
ok( !$artist->has_age, "Do not calculate age for artists with negative years");

# testing ->age with future begin dates
$artist->begin_date(PartialDate->new(year => 9999, month => 9, day => 28));
$artist->end_date(PartialDate->new(year => 3459, month => 4, day => 11));
ok( !$artist->has_age, "Do not calculate age for artists with negative years");

# testing ->age when the begin date is more specific than the end date
$artist->begin_date(PartialDate->new(year => 1987, month => 3, day => 7));
$artist->end_date(PartialDate->new(year => 1987));
ok( !$artist->has_age,
    "Do not calculate age for artists with more specific begin than end dates");


ok(MusicBrainz::Server::Entity::Artist->new( id => $DARTIST_ID )->is_special_purpose);
ok(MusicBrainz::Server::Entity::Artist->new( id => $VARTIST_ID )->is_special_purpose);
ok(MusicBrainz::Server::Entity::Artist->new( gid => $VARTIST_GID )->is_special_purpose);
ok(!MusicBrainz::Server::Entity::Artist->new( id => 5 )->is_special_purpose);
ok(!MusicBrainz::Server::Entity::Artist->new( gid => '7527f6c2-d762-4b88-b5e2-9244f1e34c46' )->is_special_purpose);

};

1;
