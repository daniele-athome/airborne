'use strict';

/**
 * The identity/ownership rules from 60_actions.js: who may file, edit, hand
 * over or delete a flight log entry. See the "Identity rules" comment block
 * above resolveIdentityForInsert in the source for the intended behaviour.
 */

const test = require('node:test');
const assert = require('node:assert');
const {loadContext} = require('./helpers');
const {fakeProperties} = require('./fake-apps-script');

function makeCtx(properties) {
    return loadContext(['00_config.js', '10_protocol.js', '20_auth.js', '60_actions.js'], fakeProperties(properties));
}

function existingOwnedBy(ctx, pilotName) {
    const row = [];
    row[ctx.flight_log_config.schema.find((f) => f.name === 'pilotName').index] = pilotName;
    return row;
}

const PILOT = {pilotName: 'mario', role: 'pilot'};
const ADMIN = {pilotName: 'admin-user', role: 'admin'};

// --- resolveIdentityForInsert ------------------------------------------------

test('insert: with no claim, a pilot files under their own name', () => {
    const ctx = makeCtx({});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {}, PILOT);
    assert.deepEqual(result.values, {pilotName: 'mario'});
});

test('insert: a pilot may claim their own name, in any case/whitespace, and it is canonicalized', () => {
    const ctx = makeCtx({});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {pilotName: '  Mario  '}, PILOT);
    assert.strictEqual(result.values.pilotName, 'mario');
});

test('insert: a pilot may file under the configured maintenance name', () => {
    const ctx = makeCtx({NO_PILOT_NAME: 'manutenzione'});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {pilotName: 'Manutenzione'}, PILOT);
    assert.strictEqual(result.values.pilotName, 'manutenzione');
});

test('insert: a pilot cannot file under another pilot\'s name', () => {
    const ctx = makeCtx({});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {pilotName: 'luigi'}, PILOT);
    assert.strictEqual(result.code, ctx.ERROR.FORBIDDEN);
    assert.match(result.error, /luigi/);
});

test('insert: an admin may file under an arbitrary name', () => {
    const ctx = makeCtx({});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {pilotName: 'luigi'}, ADMIN);
    assert.strictEqual(result.values.pilotName, 'luigi');
});

test('insert: an admin with no claim files under their own name too', () => {
    const ctx = makeCtx({});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {}, ADMIN);
    assert.strictEqual(result.values.pilotName, 'admin-user');
});

test('insert: a non-string claim is a bad request', () => {
    const ctx = makeCtx({});
    const result = ctx.resolveIdentityForInsert(ctx.flight_log_config, {pilotName: 42}, PILOT);
    assert.strictEqual(result.code, ctx.ERROR.BAD_REQUEST);
});

// --- resolveIdentityForUpdate -------------------------------------------------

test('update: the owner may edit without reassigning', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'mario');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {}, PILOT, existing);
    assert.strictEqual(result.values.pilotName, 'mario');
});

test('update: the owner may hand the entry over to the maintenance name', () => {
    const ctx = makeCtx({NO_PILOT_NAME: 'manutenzione'});
    const existing = existingOwnedBy(ctx, 'mario');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {pilotName: 'manutenzione'}, PILOT, existing);
    assert.strictEqual(result.values.pilotName, 'manutenzione');
});

test('update: the owner cannot reassign the entry to another pilot', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'mario');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {pilotName: 'luigi'}, PILOT, existing);
    assert.strictEqual(result.code, ctx.ERROR.FORBIDDEN);
    assert.match(result.error, /refile/);
});

test('update: a non-owner, non-maintenance pilot cannot edit at all', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'luigi');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {}, PILOT, existing);
    assert.strictEqual(result.code, ctx.ERROR.FORBIDDEN);
    assert.match(result.error, /another name/);
});

test('update: anybody may edit an entry already filed under the maintenance name', () => {
    const ctx = makeCtx({NO_PILOT_NAME: 'manutenzione'});
    const existing = existingOwnedBy(ctx, 'manutenzione');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {}, PILOT, existing);
    assert.strictEqual(result.values.pilotName, 'manutenzione');
});

test('update: the maintenance-owned hand-over is one-way — nobody may take it back under their own name', () => {
    const ctx = makeCtx({NO_PILOT_NAME: 'manutenzione'});
    const existing = existingOwnedBy(ctx, 'manutenzione');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {pilotName: 'mario'}, PILOT, existing);
    assert.strictEqual(result.code, ctx.ERROR.FORBIDDEN);
    assert.match(result.error, /take over/);
});

test('update: an admin may reassign the entry to anybody', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'mario');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {pilotName: 'luigi'}, ADMIN, existing);
    assert.strictEqual(result.values.pilotName, 'luigi');
});

test('update: without a configured maintenance name, claiming that name is just another refile attempt', () => {
    const ctx = makeCtx({}); // NO_PILOT_NAME unset
    const existing = existingOwnedBy(ctx, 'mario');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {pilotName: 'manutenzione'}, PILOT, existing);
    assert.strictEqual(result.code, ctx.ERROR.FORBIDDEN);
    assert.match(result.error, /refile/);
});

test('update: a non-string claim is a bad request', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'mario');
    const result = ctx.resolveIdentityForUpdate(ctx.flight_log_config, {pilotName: 42}, PILOT, existing);
    assert.strictEqual(result.code, ctx.ERROR.BAD_REQUEST);
});

// --- checkIdentityForDelete ---------------------------------------------------

test('delete: an admin may delete anything', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'luigi');
    assert.strictEqual(ctx.checkIdentityForDelete(ctx.flight_log_config, ADMIN, existing), null);
});

test('delete: the owner may delete their own entry', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'mario');
    assert.strictEqual(ctx.checkIdentityForDelete(ctx.flight_log_config, PILOT, existing), null);
});

test('delete: a pilot cannot delete another pilot\'s entry', () => {
    const ctx = makeCtx({});
    const existing = existingOwnedBy(ctx, 'luigi');
    assert.match(ctx.checkIdentityForDelete(ctx.flight_log_config, PILOT, existing), /another name/);
});

test('delete: a pilot cannot delete an entry filed under the maintenance name either', () => {
    const ctx = makeCtx({NO_PILOT_NAME: 'manutenzione'});
    const existing = existingOwnedBy(ctx, 'manutenzione');
    assert.match(ctx.checkIdentityForDelete(ctx.flight_log_config, PILOT, existing), /another name/);
});
