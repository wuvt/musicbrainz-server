// This file is part of MusicBrainz, the open internet music database.
// Copyright (C) 2014 MetaBrainz Foundation
// Licensed under the GPL version 2, or (at your option) any later version:
// http://www.gnu.org/licenses/gpl-2.0.txt

const _ = require('lodash');
const test = require('tape');

const formatDate = require('../common/utility/formatDate');
const formatDatePeriod = require('../common/utility/formatDatePeriod');
const formatTrackLength = require('../common/utility/formatTrackLength');
const parseDate = require('../common/utility/parseDate');
const dates = require('../edit/utility/dates');

test('formatTrackLength', function (t) {
    t.plan(6);

    var seconds = 1000;
    var minutes = 60 * seconds;
    var hours = 60 * minutes;

    t.equal(formatTrackLength(23), '23 ms', 'formatTrackLength');
    t.equal(formatTrackLength(260586), '4:21', 'formatTrackLength');
    t.equal(formatTrackLength(23 * seconds), '0:23', 'formatTrackLength');
    t.equal(formatTrackLength(59 * minutes), '59:00', 'formatTrackLength');
    t.equal(formatTrackLength(60 * minutes), '1:00:00', 'formatTrackLength');
    t.equal(formatTrackLength(14 * hours + 15 * minutes + 16 * seconds), '14:15:16', 'formatTrackLength');
});

test('parseDate', function (t) {
    t.plan(16);

    var parseDateTests = [
        { date: "", expected: { year: null, month: null, day: null} },
        { date: "0000", expected: { year: 0, month: null, day: null} },
        { date: "1999-01-02", expected: { year: 1999, month: 1, day: 2 } },
        { date: "1999-01", expected: { year: 1999, month: 1, day: null } },
        { date: "1999", expected: { year: 1999, month: null, day: null } },
        { date: "????-01-02", expected: { year: null, month: 1, day: 2 } },
        { date: "????-??-02", expected: { year: null, month: null, day: 2 } },
        { date: "1999-??-02", expected: { year: 1999, month: null, day: 2 } },

        // Relationship editor seeding format (via URL query params).
        { date: '-----', expected: { year: null, month: null, day: null} },
        { date: '----02', expected: { year: null, month: null, day: 2 } },
        { date: '--01--', expected: { year: null, month: 1, day: null } },
        { date: '--01-02', expected: { year: null, month: 1, day: 2 } },
        { date: '1999--', expected: { year: 1999, month: null, day: null } },
        { date: '1999----', expected: { year: 1999, month: null, day: null } },
        { date: '1999---02', expected: { year: 1999, month: null, day: 2 } },
        { date: '1999-01--', expected: { year: 1999, month: 1, day: null } },
    ];

    _.each(parseDateTests, function (test) {
        var result = parseDate(test.date);
        t.deepEqual(result, test.expected, test.date);
    });
});

test("formatDate", function (t) {
    t.plan(13);

    t.equal(formatDate(null), "");
    t.equal(formatDate(undefined), "");
    t.equal(formatDate({}), "");
    t.equal(formatDate({ year: 0 }), "0000");
    t.equal(formatDate({ year: 1999 }), "1999");
    t.equal(formatDate({ year: 1999, month: 1 }), "1999-01");
    t.equal(formatDate({ year: 1999, month: 1, day: 1 }), "1999-01-01");
    t.equal(formatDate({ year: 1999, day: 1 }), "1999-??-01");
    t.equal(formatDate({ month: 1 }), "????-01");
    t.equal(formatDate({ month: 1, day: 1 }), "????-01-01");
    t.equal(formatDate({ day: 1 }), "????-??-01");
    t.equal(formatDate({ year: 0, month: 1, day: 1 }), "0000-01-01");
    t.equal(formatDate({ year: -1, month: 1, day: 1 }), "-001-01-01");
});

test("formatDatePeriod", function (t) {
    t.plan(8);

    var a = { year: 1999 };
    var b = { year: 2000 };

    t.equal(formatDatePeriod({ begin_date: a, end_date: a, ended: false }), "1999");
    t.equal(formatDatePeriod({ begin_date: a, end_date: a, ended: true }), "1999");

    t.equal(formatDatePeriod({ begin_date: a, end_date: b, ended: false }), "1999 \u2013 2000");
    t.equal(formatDatePeriod({ begin_date: a, end_date: b, ended: true }), "1999 \u2013 2000");

    t.equal(formatDatePeriod({ begin_date: {}, end_date: b, ended: false }), "\u2013 2000");
    t.equal(formatDatePeriod({ begin_date: {}, end_date: b, ended: true }), "\u2013 2000");

    t.equal(formatDatePeriod({ begin_date: a, end_date: {}, ended: false }), "1999 \u2013");
    t.equal(formatDatePeriod({ begin_date: a, end_date: {}, ended: true }), "1999 \u2013 ????");
});

test("validDate", function (t) {
    t.plan(12);

    t.equal(dates.isDateValid("", "", ""), true, "all empty strings are valid");
    t.equal(dates.isDateValid(undefined, undefined, undefined), true, "all undefined values are valid");
    t.equal(dates.isDateValid(null, null, null), true, "all null values are valid");
    t.equal(dates.isDateValid(2000), true, "just a year is valid");
    t.equal(dates.isDateValid("", 10), true, "just a month is valid");
    t.equal(dates.isDateValid("", "", 29), true, "just a day is valid");
    t.equal(dates.isDateValid(0), false, "the year 0 is invalid");
    t.equal(dates.isDateValid("", 13), false, "months > 12 are invalid");
    t.equal(dates.isDateValid("", "", 32), false, "days > 31 are invalid");
    t.equal(dates.isDateValid(2001, 2, 29), false, "2001-02-29 is invalid");
    t.equal(dates.isDateValid("2000f"), false, "letters are invalid");
    t.equal(dates.isDateValid(1960, 2, 29), true, "leap years are handled correctly (MBS-5663)");
});

test("validDatePeriod", function (t) {
    t.plan(8);

    var tests = [
        {
            a: {},
            b: {},
            expected: true
        },
        {
            a: { year: 2000, month: null, day: 11 },
            b: { year: 2000, month: null, day: 10 },
            expected: true
        },
        {
            a: { year: 2000, month: 11, day: 11 },
            b: { year: 2000, month: 12, day: 12 },
            expected: true
        },
        {
            a: { year: 2000, month: 11, day: 11 },
            b: { year: 1999, month: 12, day: 12 },
            expected: false
        },
        {
            a: { year: 2000, month: 11, day: 11 },
            b: { year: 2000, month: 10, day: 12 },
            expected: false
        },
        {
            a: { year: 2000, month: 11, day: 11 },
            b: { year: 2000, month: 11, day: 10 },
            expected: false
        },
        {
            a: { year: "2000", month: "3", day: "1" },
            b: { year: "2000", month: "10", day: "1" },
            expected: true
        },
        {
            a: { year: 1961, month: 2, day: 28 },
            b: { year: 1961, month: 2, day: 29 },
            expected: false
        }
    ];

    _.each(tests, function (test) {
        t.equal(dates.isDatePeriodValid(test.a, test.b), test.expected);
    });
});
