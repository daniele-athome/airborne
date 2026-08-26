'use strict';

/**
 * Loads Apps Script source files into a sandbox.
 *
 * The project has a flat global namespace and no module system, so the files
 * cannot be `require`d. Evaluating them in a vm context reproduces the same
 * flat scope and lets the pure logic be tested without the Google runtime.
 */

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const SRC = path.join(__dirname, '..', 'src');

/** Minimal stand-ins for the Apps Script services used by the pure modules. */
function makeStubs() {
  return {
    Utilities: {
      DigestAlgorithm: { SHA_256: 'SHA_256' },
      computeDigest(_algorithm, value) {
        const digest = crypto.createHash('sha256').update(value, 'utf8').digest();
        // Apps Script returns signed bytes.
        return Array.from(digest).map((b) => (b > 127 ? b - 256 : b));
      },
      base64EncodeWebSafe(value) {
        return Buffer.from(value, 'utf8').toString('base64url');
      },
      base64DecodeWebSafe(value) {
        return Buffer.from(value, 'base64url');
      },
      newBlob(bytes) {
        return { getDataAsString: () => Buffer.from(bytes).toString('utf8') };
      }
    },
    console
  };
}

/** Evaluates the given source files in a fresh sandbox and returns its globals. */
function loadContext(files) {
  const context = vm.createContext(makeStubs());
  for (const file of files) {
    const code = fs.readFileSync(path.join(SRC, file), 'utf8');
    vm.runInContext(code, context, { filename: file });
  }
  return context;
}

module.exports = { loadContext };
