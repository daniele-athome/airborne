'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { loadContext } = require('./helpers');

const ctx = loadContext(['00_config.js', '20_auth.js', '30_canonical.js']);

test('trailing empty cells do not change the fingerprint', () => {
  // Sheets truncates trailing empties, so the same row arrives with different
  // lengths depending on how it is read.
  const short = ['a', 1];
  const padded = ['a', 1, '', '', ''];
  assert.strictEqual(ctx.fingerprintRow(short, 5), ctx.fingerprintRow(padded, 5));
});

test('equivalent number representations collapse', () => {
  assert.strictEqual(ctx.fingerprintRow([1247.3], 1), ctx.fingerprintRow([1247.30], 1));
});

test('a number and its string form are distinguishable', () => {
  assert.notStrictEqual(ctx.fingerprintRow([42], 1), ctx.fingerprintRow(['42'], 1));
});

test('null, undefined and empty string are the same empty cell', () => {
  const a = ctx.fingerprintRow([null, 'x'], 2);
  const b = ctx.fingerprintRow([undefined, 'x'], 2);
  const c = ctx.fingerprintRow(['', 'x'], 2);
  assert.strictEqual(a, b);
  assert.strictEqual(b, c);
});

test('a change in any column changes the fingerprint', () => {
  const base = ['2026-08-14', 'Marco', 1247.3, '', 'note'];
  for (let i = 0; i < base.length; i++) {
    const changed = base.slice();
    changed[i] = 'CHANGED';
    assert.notStrictEqual(
      ctx.fingerprintRow(base, base.length),
      ctx.fingerprintRow(changed, base.length),
      `column ${i} did not affect the fingerprint`
    );
  }
});

test('columns beyond the declared width are ignored', () => {
  // Only the declared range participates: an extra column the deployment does
  // not know about must not make every fingerprint unstable.
  assert.strictEqual(
    ctx.fingerprintRow(['a', 'b'], 2),
    ctx.fingerprintRow(['a', 'b', 'surprise'], 2)
  );
});

test('field boundaries cannot be forged by content', () => {
  // Without a separator that cannot occur in content, these two rows would
  // canonicalize to the same string.
  assert.notStrictEqual(
    ctx.fingerprintRow(['ab', 'c'], 2),
    ctx.fingerprintRow(['a', 'bc'], 2)
  );
});

test('dates compare by instant, not by formatting', () => {
  const a = new Date(2026, 7, 14);
  const b = new Date(2026, 7, 14);
  assert.strictEqual(ctx.fingerprintRow([a], 1), ctx.fingerprintRow([b], 1));
  assert.notStrictEqual(ctx.fingerprintRow([a], 1), ctx.fingerprintRow([new Date(2026, 7, 15)], 1));
});

test('fingerprint is hex of the configured length', () => {
  const fp = ctx.fingerprintRow(['a'], 1);
  assert.strictEqual(fp.length, ctx.FINGERPRINT_LENGTH);
  assert.match(fp, /^[0-9a-f]+$/);
});
