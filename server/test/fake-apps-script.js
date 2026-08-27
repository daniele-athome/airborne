'use strict';

/**
 * Minimal in-memory stand-ins for the Apps Script services touched by src/.
 *
 * Each factory returns the subset of the global namespace it stubs (e.g.
 * `{ PropertiesService }`), so tests only pull in what the files they load
 * actually need. FakeSheet mimics just the Range/TextFinder surface that
 * 40_store.js and 60_actions.js call: getRange/getValues/setValues/sort/
 * createTextFinder/appendRow/deleteRow/getLastRow/getLastColumn.
 */

function colLetterToIndex(letters) {
    let index = 0;
    for (let i = 0; i < letters.length; i++) {
        index = index * 26 + (letters.charCodeAt(i) - 64);
    }
    return index;
}

class FakeRange {
    constructor(sheet, row, col, numRows, numCols) {
        this.sheet = sheet;
        this.row = row;
        this.col = col;
        this.numRows = numRows;
        this.numCols = numCols;
    }

    getRow() {
        return this.row;
    }

    getColumn() {
        return this.col;
    }

    getValues() {
        const out = [];
        for (let i = 0; i < this.numRows; i++) {
            const sheetRow = this.sheet.data[this.row - 1 + i];
            const line = [];
            for (let j = 0; j < this.numCols; j++) {
                const value = sheetRow ? sheetRow[this.col - 1 + j] : undefined;
                line.push(value === undefined ? '' : value);
            }
            out.push(line);
        }
        return out;
    }

    getValue() {
        return this.getValues()[0][0];
    }

    setValues(values) {
        for (let i = 0; i < this.numRows; i++) {
            const rowIndex = this.row - 1 + i;
            while (this.sheet.data.length <= rowIndex) {
                this.sheet.data.push([]);
            }
            const sheetRow = this.sheet.data[rowIndex];
            for (let j = 0; j < this.numCols; j++) {
                sheetRow[this.col - 1 + j] = values[i][j];
            }
        }
    }

    setValue(value) {
        this.setValues([[value]]);
    }

    createTextFinder(text) {
        return new FakeTextFinder(this, text);
    }

    sort(sortSpec) {
        const specs = (Array.isArray(sortSpec) ? sortSpec : [sortSpec]).map((s) =>
            typeof s === 'number' ? {column: s, ascending: true} : {column: s.column, ascending: s.ascending !== false}
        );
        const rows = this.sheet.data.slice(this.row - 1, this.row - 1 + this.numRows);
        rows.sort((a, b) => {
            for (const spec of specs) {
                const av = a[spec.column - 1];
                const bv = b[spec.column - 1];
                if (av < bv) return spec.ascending ? -1 : 1;
                if (av > bv) return spec.ascending ? 1 : -1;
            }
            return 0;
        });
        for (let i = 0; i < rows.length; i++) {
            this.sheet.data[this.row - 1 + i] = rows[i];
        }
    }
}

class FakeTextFinder {
    constructor(range, text) {
        this.range = range;
        this.text = text;
        this._entireCell = false;
        this._matchCase = false;
    }

    matchEntireCell(value) {
        this._entireCell = value;
        return this;
    }

    matchCase(value) {
        this._matchCase = value;
        return this;
    }

    findNext() {
        const {sheet, row, col, numRows, numCols} = this.range;
        const target = this._matchCase ? this.text : String(this.text).toLowerCase();
        for (let i = 0; i < numRows; i++) {
            for (let j = 0; j < numCols; j++) {
                const sheetRow = sheet.data[row - 1 + i];
                const raw = sheetRow ? sheetRow[col - 1 + j] : undefined;
                let cell = String(raw === undefined || raw === null ? '' : raw);
                if (!this._matchCase) cell = cell.toLowerCase();
                const match = this._entireCell ? cell === target : cell.indexOf(target) >= 0;
                if (match) {
                    return new FakeRange(sheet, row + i, col + j, 1, 1);
                }
            }
        }
        return null;
    }
}

class FakeSheet {
    constructor(name, initialData) {
        this.name = name;
        this.data = (initialData || []).map((row) => row.slice());
    }

    getName() {
        return this.name;
    }

    getLastRow() {
        return this.data.length;
    }

    getLastColumn() {
        return this.data.reduce((max, row) => Math.max(max, row.length), 0);
    }

    getRange(a, b, c, d) {
        if (typeof a === 'string') {
            const match = /^([A-Z]+):([A-Z]+)$/.exec(a);
            if (!match || match[1] !== match[2]) {
                throw new Error('FakeSheet.getRange: unsupported A1 notation "' + a + '"');
            }
            const col = colLetterToIndex(match[1]);
            return new FakeRange(this, 1, col, Math.max(this.data.length, 1), 1);
        }
        return new FakeRange(this, a, b, c === undefined ? 1 : c, d === undefined ? 1 : d);
    }

    appendRow(values) {
        this.data.push(values.slice());
    }

    deleteRow(rowIndex) {
        this.data.splice(rowIndex - 1, 1);
    }
}

/** Builds the SpreadsheetApp stub and exposes a flush counter via a shared state object. */
function fakeSpreadsheetApp(sheets) {
    const state = {flushCalls: 0};
    const SpreadsheetApp = {
        getActive() {
            return {
                getSheetByName(name) {
                    return Object.prototype.hasOwnProperty.call(sheets, name) ? sheets[name] : null;
                }
            };
        },
        flush() {
            state.flushCalls++;
        }
    };
    return {SpreadsheetApp, state};
}

function fakeProperties(props) {
    const values = props || {};
    return {
        PropertiesService: {
            getScriptProperties() {
                return {
                    getProperty(key) {
                        return Object.prototype.hasOwnProperty.call(values, key) ? values[key] : null;
                    }
                };
            }
        }
    };
}

function fakeContentService() {
    return {
        ContentService: {
            MimeType: {JSON: 'JSON'},
            createTextOutput(text) {
                return {
                    _text: text,
                    _mime: null,
                    setMimeType(mime) {
                        this._mime = mime;
                        return this;
                    },
                    getContent() {
                        return this._text;
                    },
                    getMimeType() {
                        return this._mime;
                    }
                };
            }
        }
    };
}

/** `opts.failToLock`: makes every `tryLock` fail, to exercise the BUSY path. */
function fakeLockService(opts) {
    const state = {tryLockCalls: 0, releaseLockCalls: 0, locked: false};
    const failToLock = !!(opts && opts.failToLock);
    const LockService = {
        getScriptLock() {
            return {
                tryLock(_timeoutMs) {
                    state.tryLockCalls++;
                    if (failToLock) return false;
                    state.locked = true;
                    return true;
                },
                releaseLock() {
                    state.releaseLockCalls++;
                    state.locked = false;
                }
            };
        }
    };
    return {LockService, state};
}

function fakeCacheService() {
    const store = new Map();
    const CacheService = {
        getScriptCache() {
            return {
                get(key) {
                    return store.has(key) ? store.get(key) : null;
                },
                put(key, value, _ttlSeconds) {
                    store.set(key, value);
                }
            };
        }
    };
    return {CacheService, store};
}

module.exports = {
    FakeSheet,
    FakeRange,
    fakeSpreadsheetApp,
    fakeProperties,
    fakeContentService,
    fakeLockService,
    fakeCacheService
};
