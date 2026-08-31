/** Schema for the flight log sheet. */
const flight_log_config = {
    schema: [
        {name: 'createdAt', index: 0, type: 'date', managed: 'createdAt', immutable: true},
        {name: 'date', index: 1, type: 'date', required: true},
        {name: 'pilotName', index: 2, type: 'string', required: true, identity: true},
        {name: 'startHour', index: 3, type: 'number', required: true},
        {name: 'endHour', index: 4, type: 'number', required: true},
        {name: 'origin', index: 5, type: 'string', required: true},
        {name: 'destination', index: 6, type: 'string', required: true},
        {name: 'fuel', index: 7, type: 'number', nullable: true},
        {name: 'fuelPrice', index: 8, type: 'number', nullable: true},
        {name: 'notes', index: 9, type: 'string', nullable: true},
        {name: 'stableId', index: 10, type: 'string', managed: 'stableId', immutable: true}
    ],
    headerRows: 1,
    /** 1-based column of the stableId field. Must agree with its index. */
    stableIdColumn: 11,
    /** Sort keys, by field name, applied after every change. */
    sort: ['startHour', 'endHour'],
}

/** Metadata key holding the version counter of the flight log. */
const FLIGHT_LOG_VERSION_KEY = 'flight_log.hash';

// for the stable ID generator
const ID_LETTERS = 'abcdefghijklmnopqrstuvwxyz';
const ID_ALPHABET = ID_LETTERS + '0123456789';

/**
 * Parses a date field.
 *
 * A plain `yyyy-MM-dd` becomes midnight in the script timezone, which is what
 * typing the date into the sheet would produce; a full ISO timestamp keeps its
 * time component.
 */
function coerceDate(field, raw) {
    if (raw instanceof Date) {
        return {value: raw};
    }
    if (typeof raw !== 'string') {
        return {error: 'Field ' + field.name + ' must be a date string'};
    }

    const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
    if (dateOnly) {
        return {
            value: new Date(Number(dateOnly[1]), Number(dateOnly[2]) - 1, Number(dateOnly[3]))
        };
    }

    const parsed = new Date(raw);
    if (isNaN(parsed.getTime())) {
        return {error: 'Field ' + field.name + ' is not a valid date: ' + raw};
    }
    return {value: parsed};
}

/** Validates a payload value against its field definition. */
function coerceField(field, raw) {
    const missing = raw === null || raw === undefined || raw === '';

    if (missing) {
        if (field.required) {
            return {error: 'Missing required field: ' + field.name};
        }
        return {value: ''};
    }

    if (field.type === 'string') {
        if (typeof raw !== 'string') {
            return {error: 'Field ' + field.name + ' must be a string'};
        }
        if (field.values && field.values.indexOf(raw) < 0) {
            return {error: 'Field ' + field.name + ' must be one of: ' + field.values.join(', ')};
        }
        return {value: raw};
    }

    if (field.type === 'number' || field.type === 'integer') {
        const num = typeof raw === 'number' ? raw : Number(raw);
        if (typeof num !== 'number' || isNaN(num) || !isFinite(num)) {
            return {error: 'Field ' + field.name + ' must be a number'};
        }
        if (field.type === 'integer' && Math.floor(num) !== num) {
            return {error: 'Field ' + field.name + ' must be an integer'};
        }
        if (field.values && field.values.indexOf(num) < 0) {
            return {error: 'Field ' + field.name + ' must be one of: ' + field.values.join(', ')};
        }
        return {value: num};
    }

    if (field.type === 'date') {
        return coerceDate(field, raw);
    }

    return {error: 'Unsupported field type for ' + field.name};
}

function generateStableId() {
    const len = 10;
    let out = ID_LETTERS.charAt(Math.floor(Math.random() * ID_LETTERS.length));
    for (let i = 1; i < len; i++) {
        out += ID_ALPHABET.charAt(Math.floor(Math.random() * ID_ALPHABET.length));
    }
    return out;
}

function buildRowValues(schema, payload, existing, identityValues) {
    const values = [];
    for (let i = 0; i < schema.length; i++) {
        values.push(existing ? existing[i] : '');
    }

    let stableId = null;
    const now = new Date();

    for (let f = 0; f < schema.length; f++) {
        const field = schema[f];

        if (field.managed === 'stableId' && existing) {
            stableId = existing[field.index];
        }

        if (field.immutable && existing) {
            // cannot change immutable fields on update
            continue;
        }

        if (field.managed === 'createdAt') {
            values[field.index] = existing ? existing[field.index] : now;
            continue;
        } else if (field.managed === 'stableId') {
            // TODO test this
            if (existing) {
                stableId = existing[field.index];
            } else if (!stableId) {
                stableId = generateStableId();
            }

            values[field.index] = stableId;
            continue;
        } else if (field.managed === 'empty') {
            values[field.index] = null;
            continue;
        }

        // At this point, any identity claims have been validated: just write down the
        // value resolved by the identity check.
        if (field.identity) {
            values[field.index] = identityValues[field.name];
            continue;
        }

        if (!existing || Object.prototype.hasOwnProperty.call(payload, field.name)) {
            const coerced = coerceField(field, payload[field.name]);
            if (coerced.error) {
                return {error: coerced.error};
            }
            values[field.index] = coerced.value;
        }
    }

    return {values: values, rowId: stableId};
}

/*
 * Identity rules.
 *
 * An admin does anything. A pilot files, edits and removes entries under their
 * own name; may file, edit and remove entries under the maintenance name; and
 * may hand one of their own entries over to the maintenance name. That
 * hand-over is one-way: an entry already filed under the maintenance name is
 * reassignable by nobody.
 */

/** The maintenance pilot name, or null when the deployment defines none. */
function getNoPilotName() {
    const value = getProperty('NO_PILOT_NAME', false);
    const name = value === null || value === undefined ? '' : String(value).trim();
    return name === '' ? null : name;
}

/** The schema fields that carry the identity of a row. */
function identityFields(sheetConfig) {
    const fields = [];
    for (let i = 0; i < sheetConfig.schema.length; i++) {
        if (sheetConfig.schema[i].identity) {
            fields.push(sheetConfig.schema[i]);
        }
    }
    return fields;
}

/** The name a row is currently filed under, empty when there is none. */
function identityOwner(field, existing) {
    return existing ? normalizeName(existing[field.index]) : '';
}

/**
 * Reads the name a request asks for.
 *
 * An absent, null, or empty claim is reported as the empty string, meaning "no
 * claim": callers resolve that to the default for their operation. Identity
 * fields skip `coerceField`, so the type check lives here instead.
 */
function claimedName(field, payload) {
    if (!Object.prototype.hasOwnProperty.call(payload, field.name)) {
        return {claimed: ''};
    }
    const raw = payload[field.name];
    if (raw === null || raw === undefined) {
        return {claimed: ''};
    }
    if (typeof raw !== 'string') {
        return {error: 'Field ' + field.name + ' must be a string'};
    }
    return {claimed: raw.trim()};
}

/**
 * Decides the identity values an insert may write.
 *
 * Returns `{values: {<field>: <name>}}`, or `{error, code}`.
 */
function resolveIdentityForInsert(sheetConfig, payload, identity) {
    const noPilotName = getNoPilotName();
    const fields = identityFields(sheetConfig);
    const values = {};

    for (let i = 0; i < fields.length; i++) {
        const field = fields[i];
        const claim = claimedName(field, payload);
        if (claim.error) {
            return {error: claim.error, code: ERROR.BAD_REQUEST};
        }
        const claimed = claim.claimed;

        // Pilot name defaults to authenticated user
        if (claimed === '' || sameName(claimed, identity.pilotName)) {
            values[field.name] = identity.pilotName;
            continue;
        }
        if (noPilotName && sameName(claimed, noPilotName)) {
            values[field.name] = noPilotName;
            continue;
        }
        if (isAdmin(identity)) {
            values[field.name] = claimed;
            continue;
        }
        return {
            error: 'Not allowed to add entry as "' + claimed + '"',
            code: ERROR.FORBIDDEN
        };
    }

    return {values: values};
}

function resolveIdentityForUpdate(sheetConfig, payload, identity, existing) {
    const noPilotName = getNoPilotName();
    const fields = identityFields(sheetConfig);
    const values = {};

    for (let i = 0; i < fields.length; i++) {
        const field = fields[i];
        const claim = claimedName(field, payload);
        if (claim.error) {
            return {error: claim.error, code: ERROR.BAD_REQUEST};
        }

        const owner = identityOwner(field, existing);
        // No claim leaves the entry where it is
        const claimed = claim.claimed === '' ? owner : claim.claimed;

        if (isAdmin(identity)) {
            values[field.name] = claimed;
            continue;
        }

        const ownedBySelf = sameName(owner, identity.pilotName);
        const ownedByNoPilot = !!noPilotName && sameName(owner, noPilotName);

        if (!ownedBySelf && !ownedByNoPilot) {
            return {
                error: 'Not allowed to modify an entry filed under another name',
                code: ERROR.FORBIDDEN
            };
        }
        if (ownedBySelf && sameName(claimed, identity.pilotName)) {
            values[field.name] = identity.pilotName;
            continue;
        }
        if (noPilotName && sameName(claimed, noPilotName)) {
            values[field.name] = noPilotName;
            continue;
        }
        if (ownedByNoPilot) {
            return {
                error: 'Not allowed to take over an entry filed under "' + noPilotName + '"',
                code: ERROR.FORBIDDEN
            };
        }
        return {
            error: 'Not allowed to refile an entry as "' + claimed + '"',
            code: ERROR.FORBIDDEN
        };
    }

    return {values: values};
}

function checkIdentityForDelete(sheetConfig, identity, existing) {
    if (isAdmin(identity)) {
        return null;
    }

    const noPilotName = getNoPilotName();
    const fields = identityFields(sheetConfig);
    for (let i = 0; i < fields.length; i++) {
        const owner = identityOwner(fields[i], existing);
        const ownedBySelf = sameName(owner, identity.pilotName);
        const ownedByNoPilot = !!noPilotName && sameName(owner, noPilotName);

        // Same gate `resolveIdentityForUpdate` opens with, and deliberately the
        // same shape: the two drift apart the moment one of them is edited alone.
        if (!ownedBySelf && !ownedByNoPilot) {
            return 'Not allowed to delete an entry filed under another name';
        }
    }
    return null;
}

/** Bumps the version counter the app watches to know the data moved. */
function updateFlightLogMetadata() {
    updateVersionMetadata(FLIGHT_LOG_VERSION_KEY);
}

function actionFlightLogInsert(payload, identity) {
    const claim = resolveIdentityForInsert(flight_log_config, payload, identity);
    if (claim.error) {
        return errorResponse(claim.code, claim.error);
    }

    const sheet = openFlightLogSheet();

    const built = buildRowValues(flight_log_config.schema, payload, null, claim.values);
    if (built.error) {
        return errorResponse(ERROR.BAD_REQUEST, built.error);
    }

    appendRow(sheet, built.values);

    // apply proper sort
    sortSheet(flight_log_config, sheet);

    // update hash in metadata
    updateFlightLogMetadata();

    return okResponse({'id': built.rowId});
}

function actionFlightLogUpdate(payload, identity) {
    if (typeof payload.id !== 'string' || payload.id === '') {
        return errorResponse(ERROR.BAD_REQUEST, 'Missing "id"');
    }

    const sheet = openFlightLogSheet();

    const rowIndex = findRow(flight_log_config, sheet, payload.id);
    if (rowIndex < 0) {
        return entryNotFoundErrorResponse(payload.id);
    }

    const existing = readRow(flight_log_config, sheet, rowIndex);
    if (!existing) {
        return entryNotFoundErrorResponse(payload.id);
    }

    const claim = resolveIdentityForUpdate(flight_log_config, payload, identity, existing);
    if (claim.error) {
        return errorResponse(claim.code, claim.error);
    }

    const built = buildRowValues(flight_log_config.schema, payload, existing, claim.values);
    if (built.error) {
        return errorResponse(ERROR.BAD_REQUEST, built.error);
    }

    writeRow(flight_log_config, sheet, rowIndex, built.values);

    // apply proper sort
    sortSheet(flight_log_config, sheet);

    // update hash in metadata
    updateFlightLogMetadata();

    return okResponse({'id': built.rowId});
}

function actionFlightLogDelete(payload, identity) {
    if (typeof payload.id !== 'string' || payload.id === '') {
        return errorResponse(ERROR.BAD_REQUEST, 'Missing "id"');
    }

    const sheet = openFlightLogSheet();

    const rowIndex = findRow(flight_log_config, sheet, payload.id);
    if (rowIndex < 0) {
        return entryNotFoundErrorResponse(payload.id);
    }

    const existing = readRow(flight_log_config, sheet, rowIndex);
    if (!existing) {
        return entryNotFoundErrorResponse(payload.id);
    }

    const claimError = checkIdentityForDelete(flight_log_config, identity, existing);
    if (claimError) {
        return errorResponse(ERROR.FORBIDDEN, claimError);
    }

    deleteRow(sheet, rowIndex);

    // apply proper sort
    // technically we wouldn't need a sort after a delete, but it might fix bad situations
    sortSheet(flight_log_config, sheet);

    // update hash in metadata
    updateFlightLogMetadata();

    return okResponse({'id': payload.id});
}

/* Test-only: see test/load.js. Apps Script has no `module`, so this never runs there. */
if (typeof module === 'object') {
    module.exports = {
        flight_log_config, FLIGHT_LOG_VERSION_KEY, ID_LETTERS, ID_ALPHABET,
        coerceDate, coerceField, generateStableId, buildRowValues,
        getNoPilotName, identityFields, identityOwner, claimedName,
        resolveIdentityForInsert, resolveIdentityForUpdate, checkIdentityForDelete,
        updateFlightLogMetadata,
        actionFlightLogInsert, actionFlightLogUpdate, actionFlightLogDelete
    };
}
