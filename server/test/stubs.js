/**
 * Stand-ins for the Apps Script services the sources reach for.
 *
 * Only what the pure layer touches lives here; sheets, locks, and the cache come
 * later, when there is something to test that needs them.
 */

let scriptProperties = {};

/** Installs the script properties a test wants `getProperty` to see. */
function setScriptProperties(properties) {
    scriptProperties = properties || {};
}

globalThis.PropertiesService = {
    getScriptProperties: function () {
        return {
            getProperty: function (key) {
                return Object.prototype.hasOwnProperty.call(scriptProperties, key)
                    ? scriptProperties[key]
                    : null;
            }
        };
    }
};

module.exports = {setScriptProperties: setScriptProperties};
