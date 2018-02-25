// This file is part of MusicBrainz, the open internet music database.
// Copyright (C) 2015—2016 MetaBrainz Foundation
// Licensed under the GPL version 2, or (at your option) any later version:
// http://www.gnu.org/licenses/gpl-2.0.txt

const ko = require('knockout');
const React = require('react');

const {l} = require('../i18n');
const {artistCreditFromArray} = require('../immutable-entities');
const AreaWithContainmentLink = require('./AreaWithContainmentLink');
const ArtistCreditLink = require('./ArtistCreditLink');
const EntityLink = require('./EntityLink');

const DescriptiveLink = ({entity, content, showDeletedArtists = true}) => {
  let props = {content, showDisambiguation: true};

  if (entity.entityType === 'area' && entity.gid) {
    return <AreaWithContainmentLink area={entity} {...props} />;
  }

  props.key = 0;
  let link = <EntityLink entity={entity} {...props} />;

  if (entity.artistCredit) {
    let artistCredit = ko.unwrap(entity.artistCredit);
    if (Array.isArray(artistCredit)) {
      artistCredit = artistCreditFromArray(artistCredit);
    }
    return l('{entity} by {artist}', {
      __react: true,
      entity: link,
      artist: (
        <ArtistCreditLink
          artistCredit={artistCredit}
          key={1}
          showDeleted={showDeletedArtists} />
      ),
    });
  }

  if (entity.entityType === 'place' && entity.area) {
    return l('{place} in {area}', {
      __react: true,
      place: link,
      area: <AreaWithContainmentLink area={entity.area} key={1} />
    });
  }

  return link;
};

module.exports = DescriptiveLink;
