/*
 * @flow
 * Copyright (C) 2018 Shamroy Pellew
 *
 * This file is part of MusicBrainz, the open internet music database,
 * and is licensed under the GPL version 2, or (at your option) any
 * later version: http://www.gnu.org/licenses/gpl-2.0.txt
 */

const React = require('react');
const NotFound = require('../components/NotFound');
const {l} = require('../static/scripts/common/i18n');

const ElectionNotFound = () => (
  <NotFound title={l('Election Not Found')}>
    <p>{l('Sorry, we could not find this election.')}</p>
    <p><a href="/elections">{l('Back to all elections.')}</a></p>
  </NotFound>
);

module.exports = ElectionNotFound;
