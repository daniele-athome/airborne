'use strict';

/**
 * Loads Apps Script source files into a sandbox.
 *
 * The project has a flat global namespace and no module system, so the files
 * cannot be `require`d. Evaluating them in a vm context reproduces the same
 * flat scope and lets the logic be tested without the Google runtime, using
 * the fakes in fake-apps-script.js for the handful of Apps Script services it
 * touches.
 */

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const SRC = path.join(__dirname, '..', 'src');

/**
 * Evaluates the given source files (in order) in a fresh sandbox built from `stubs`,
 * and returns a handle to read their top-level declarations.
 *
 * Top-level `function` declarations become properties of the sandbox's global
 * object, but top-level `const`/`let` (most of this codebase) do not — that is
 * how JS scoping works, in a browser or Apps Script's own global namespace too.
 * The Proxy below falls back to evaluating the property name as an expression
 * in the same context, which *does* resolve `const`/`let` bindings, so callers
 * can read `ctx.ERROR` or `ctx.PROTOCOL_V` without listing exports per file.
 */
function loadContext(files, stubs) {
    const context = vm.createContext(Object.assign({console}, stubs));
    for (const file of files) {
        const code = fs.readFileSync(path.join(SRC, file), 'utf8');
        vm.runInContext(code, context, {filename: file});
    }
    return new Proxy(context, {
        get(target, prop) {
            if (typeof prop === 'string' && !(prop in target)) {
                try {
                    return vm.runInContext(prop, context);
                } catch (err) {
                    return undefined;
                }
            }
            return target[prop];
        }
    });
}

module.exports = {loadContext};
