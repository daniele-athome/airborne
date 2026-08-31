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

/**
 * Enough of ContentService for `output`.
 *
 * The real TextOutput answers `getContent` and `getMimeType`, and its
 * `setMimeType` returns the object so calls can be chained; this one does the
 * same, so a test reads the result the way Apps Script would.
 */
globalThis.ContentService = {
    MimeType: {JSON: 'application/json'},
    createTextOutput: function (text) {
        return {
            content: text,
            mimeType: null,
            setMimeType: function (type) {
                this.mimeType = type;
                return this;
            },
            getContent: function () {
                return this.content;
            },
            getMimeType: function () {
                return this.mimeType;
            }
        };
    }
};

module.exports = {setScriptProperties: setScriptProperties};
