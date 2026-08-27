'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');

function makeCtx() {
    return loadContext(['20_auth.js'], {});
}

test('resolves a token to its pilot with the default pilot role', () => {
    const ctx = makeCtx();
    // identity is built inside the vm sandbox, so it is structurally but not
    // reference-equal to a same-shaped object literal from this realm.
    const identity = ctx.authenticate('secret', {'token.mario': 'secret'});
    assert.deepEqual(identity, {pilotName: 'mario', role: 'pilot'});
});

test('reads the role from the matching role.<pilot> key, lower-cased', () => {
    const ctx = makeCtx();
    const identity = ctx.authenticate('secret', {'token.mario': 'secret', 'role.mario': 'Admin'});
    assert.strictEqual(identity.role, 'admin');
    assert.strictEqual(ctx.isAdmin(identity), true);
});

test('an unmatched token resolves to null', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.authenticate('nope', {'token.mario': 'secret'}), null);
    assert.strictEqual(ctx.authenticate('secret', {}), null);
});

test('token comparison trims whitespace on both sides', () => {
    const ctx = makeCtx();
    const identity = ctx.authenticate('  secret  ', {'token.mario': 'secret'});
    assert.strictEqual(identity.pilotName, 'mario');

    const identity2 = ctx.authenticate('secret', {'token.mario': '  secret  '});
    assert.strictEqual(identity2.pilotName, 'mario');
});

test('the pilot name is trimmed from the key', () => {
    const ctx = makeCtx();
    const identity = ctx.authenticate('secret', {'token. mario ': 'secret'});
    assert.strictEqual(identity.pilotName, 'mario');
});

test('a token key with no pilot name is a configuration error and is skipped', () => {
    const ctx = makeCtx();
    const identity = ctx.authenticate('secret', {'token.': 'secret', 'token.mario': 'secret'});
    assert.strictEqual(identity.pilotName, 'mario');
});

test('a falsy stored token value never matches', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.authenticate('', {'token.mario': ''}), null);
    assert.strictEqual(ctx.authenticate('undefined', {'token.mario': null}), null);
});

test('non-token metadata keys are ignored while searching', () => {
    const ctx = makeCtx();
    const identity = ctx.authenticate('secret', {
        'role.mario': 'admin',
        'flight_log.hash': '3',
        'token.mario': 'secret'
    });
    assert.strictEqual(identity.pilotName, 'mario');
    assert.strictEqual(identity.role, 'admin');
});

test('isAdmin is true only for the admin role', () => {
    const ctx = makeCtx();
    assert.strictEqual(ctx.isAdmin({role: 'admin'}), true);
    assert.strictEqual(ctx.isAdmin({role: 'pilot'}), false);
    assert.strictEqual(ctx.isAdmin({role: 'Admin'}), false);
});
