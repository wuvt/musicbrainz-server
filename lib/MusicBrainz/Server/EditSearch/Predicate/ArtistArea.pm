package MusicBrainz::Server::EditSearch::Predicate::ArtistArea;
use Moose;
use namespace::autoclean;

extends 'MusicBrainz::Server::EditSearch::Predicate::Set';
with 'MusicBrainz::Server::EditSearch::Predicate::Role::EntityArea' => { type => 'artist' };

has name => (
    is => 'rw',
);

1;
