/*
 * @flow
 * Copyright (C) 2018 MetaBrainz Foundation
 *
 * This file is part of MusicBrainz, the open internet music database,
 * and is licensed under the GPL version 2, or (at your option) any
 * later version: http://www.gnu.org/licenses/gpl-2.0.txt
 */

const React = require('react');

type Props = {|
  +children: React.Node;
|};

const Tabs = ({children}: Props) => (
  <div className="tabs">
    <ul className="tabs">
      {children}
    </ul>
  </div>
);

module.exports = Tabs;
