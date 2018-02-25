#!/usr/bin/env node
// Copyright (C) 2017 MetaBrainz Foundation
//
// This file is part of MusicBrainz, the open internet music database,
// and is licensed under the GPL version 2, or (at your option) any
// later version: http://www.gnu.org/licenses/gpl-2.0.txt

const CDP = require('chrome-remote-interface');
const fileUrl = require('file-url');
const path = require('path');
const utf8 = require('utf8');

CDP((client) => {
  const {Page, Runtime} = client;

  function getValue(arg) {
    return utf8.encode(arg.value);
  }

  Promise.all([
    Page.enable(),
    Runtime.enable(),
  ]).then(() => {
    let timeout;

    function exit(code) {
      client.close();
      process.exit(code);
    }

    function onTimeout() {
      console.error('ERROR: Test timed out');
      exit(2);
    }

    Runtime.consoleAPICalled(function (event) {
      clearTimeout(timeout);

      let args = event.args.map(getValue);
      (console[event.type] || console.log).apply(console, args);

      if (args[0] === '# ok') {
        exit(0);
      } else {
        timeout = setTimeout(onTimeout, 1000);
      }
    });

    Runtime.exceptionThrown(function (event) {
      console.error(utf8.encode(event.exceptionDetails.exception.description) + '\n');
      exit(1);
    });

    return Page.navigate({
      url: fileUrl(
        path.resolve(__dirname, '../root/static/scripts/tests/web.html')
      ),
    });
  });
}).on('error', (err) => {
  console.error('Cannot connect to browser:', err);
});
