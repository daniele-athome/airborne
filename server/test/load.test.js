/**
 * Guards the loader itself.
 *
 * Every source publishes its declarations by hand, so a name added later can be
 * left out of the list. That failure is quiet in the wrong way: the source keeps
 * working in production, and only the tests that happen to touch the new name
 * break, with a ReferenceError that says nothing about the real cause. So rather
 * than duplicating the export lists here, this reads the sources and checks that
 * every top-level declaration actually made it onto the namespace.
 */

const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {sourceFiles} = require('./load.js');
const {setScriptProperties} = require('./stubs.js');

/** Names declared at the top level of a source, found by their zero indentation. */
function declaredNames(source) {
    const names = [];
    const lines = source.split('\n');
    for (const line of lines) {
        const match = /^(?:const|let|var|function)\s+([A-Za-z_$][\w$]*)/.exec(line);
        if (match) {
            names.push(match[1]);
        }
    }
    return names;
}

test('the scan finds the declarations it is meant to find', () => {
    // Without this the check below would pass vacuously the day the regex stops
    // matching — an empty list of names satisfies "all names are reachable".
    const files = sourceFiles();
    assert.ok(files.length >= 7, 'expected the tracked sources, got ' + files.length);

    let total = 0;
    for (const file of files) {
        total += declaredNames(fs.readFileSync(file, 'utf8')).length;
    }
    assert.ok(total > 50, 'the top-level scan found only ' + total + ' declarations');
});

test('every top-level declaration reaches the shared namespace', () => {
    const missing = [];
    for (const file of sourceFiles()) {
        for (const name of declaredNames(fs.readFileSync(file, 'utf8'))) {
            if (!(name in globalThis)) {
                missing.push(path.basename(file) + ': ' + name);
            }
        }
    }
    assert.deepEqual(missing, [], 'missing from the module.exports epilogue of their source');
});

test('a name declared late in the order sees one declared early', () => {
    // The real point of the loader: this is a 60_actions.js function reaching a
    // 10_protocol.js constant, which is what plain `require` cannot do.
    setScriptProperties({NO_PILOT_NAME: 'NO PILOT'});
    assert.equal(
        resolveIdentityForUpdate(flight_log_config, {pilotName: 'Bob'}, {pilotName: 'Alice', role: ROLE_PILOT}, []).code,
        ERROR.FORBIDDEN
    );
});
