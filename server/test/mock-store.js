'use strict';

/**
 * A call-recording mock of 40_store.js's public functions, for tests that
 * want to exercise 60_actions.js/90_main.js without a fake Sheet at all: they
 * only care whether the right store call was made, not whether it produced a
 * spreadsheet-accurate result.
 *
 * Built on node:test's own mock.fn — no hand-rolled spy. Each mocked function
 * exposes its call history the standard way: `fn.mock.calls`, each entry with
 * an `.arguments` array (see the Node docs for `MockFunctionContext`).
 *
 * `impls` overrides the default behaviour of individual functions.
 */

const {mock} = require('node:test');

const DEFAULTS = {
    openFlightLogSheet: () => ({}),
    openMetadataSheet: () => ({}),
    findRow: () => -1,
    readRow: () => null,
    writeRow: () => undefined,
    deleteRow: () => undefined,
    appendRow: () => undefined,
    sortSheet: () => undefined,
    updateVersionMetadata: () => undefined,
    readMetadata: () => ({}),
    commitChanges: () => undefined
};

function mockStore(impls) {
    const store = {};
    for (const name of Object.keys(DEFAULTS)) {
        store[name] = mock.fn((impls && impls[name]) || DEFAULTS[name]);
    }
    return store;
}

module.exports = {mockStore};
