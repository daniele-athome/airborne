/** Schema for the flight log sheet. */
const flight_log_config = {
    schema: [
        {name: 'createdAt', index: 0, type: 'date', managed: 'createdAt', immutable: true},
        {name: 'date', index: 1, type: 'date', required: true},
        {name: 'pilotName', index: 2, type: 'string', required: true/*, identity: true*/},
        {name: 'startHour', index: 3, type: 'number', required: true},
        {name: 'endHour', index: 4, type: 'number', required: true},
        {name: 'origin', index: 5, type: 'string', required: true},
        {name: 'destination', index: 6, type: 'string', required: true},
        {name: 'fuel', index: 7, type: 'number', nullable: true},
        {name: 'fuelPrice', index: 8, type: 'number', nullable: true},
        {name: 'notes', index: 9, type: 'string', nullable: true},
        {name: 'flightTime', index: 10, type: 'string', managed: 'empty'},
        {name: 'stableId', index: 11, type: 'string', managed: 'stableId', immutable: true}
    ],
    headerRows: 1,
    stableIdColumn: 12,
}

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

function buildRowValues(schema, payload, identity, existing) {
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
        }
        else if (field.managed === 'stableId') {
            // TODO test this
            if (existing) {
                stableId = existing[field.index];
            } else if (!stableId) {
                stableId = Utilities.getUuid();
            }

            values[field.index] = stableId;
            continue;
        }
        else if (field.managed === 'empty') {
            values[field.index] = null;
            continue;
        }

        // TODO unused as of now
        /*if (field.identity) {
            const claimed = payload[field.name];
            if (claimed) {
                values[field.index] = String(claimed);
            } else if (!existing) {
                values[field.index] = identity.pilotName;
            }
            continue;
        }*/

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

function sortFlightLog(sheet) {
    // TODO change this lock mechanism
    if (sheet.getRange('L1').getValue() !== 'LOCKED') {
        const range = sheet.getRange("A:L");
        range.sort([{column: 4}, {column: 5}]);
    }
}

function updateFlightLogMetadata() {
    // calculate checksum of data
    const metadataSheet = openMetadataSheet();
    const finder = metadataSheet.createTextFinder("flight_log.hash").matchEntireCell(true);
    /** @type {SpreadsheetApp.Range} */
    const hashKeyCell = finder.findNext();
    if (hashKeyCell) {
        const hashValueCell = metadataSheet.getRange(hashKeyCell.getRow(), hashKeyCell.getColumn() + 1);
        const currentVersion = hashValueCell.getValue() || 0;
        hashValueCell.setValue(currentVersion + 1);
    }
}

function actionFlightLogInsert(payload, identity) {
    // TODO check pilot name in payload against identity
    //  (for now everything is authorized on insert)

    const sheetName = getProperty('FLIGHT_LOG_SHEET_NAME');
    const sheet = openSheetByName(sheetName);
    if (!sheet) {
        throw new Error('Flight log sheet not found in this spreadsheet: ' + sheetName);
    }

    const built = buildRowValues(flight_log_config.schema, payload, identity, null);
    if (built.error) {
        return errorResponse(ERROR.BAD_REQUEST, built.error);
    }

    sheet.appendRow(built.values);

    // apply proper sort
    sortFlightLog(sheet);

    // update hash in metadata
    updateFlightLogMetadata();

    return okResponse({'id': built.rowId});
}

function actionFlightLogUpdate(payload, identity) {
    if (typeof payload.id !== 'string' || payload.id === '') {
        return errorResponse(ERROR.BAD_REQUEST, 'Missing "id"');
    }

    // TODO check pilot name in payload against identity
    //  (for now everything is authorized on insert)

    const sheetName = getProperty('FLIGHT_LOG_SHEET_NAME');
    const sheet = openSheetByName(sheetName);
    if (!sheet) {
        throw new Error('Flight log sheet not found in this spreadsheet: ' + sheetName);
    }

    const rowIndex = findRow(flight_log_config, sheet, payload.id);
    if (rowIndex < 0) {
        return errorResponse(
            ERROR.NOT_FOUND,
            'Entry ' + payload.id + ' not found',
            null
        );
    }

    const existing = readRow(flight_log_config, sheet, rowIndex);
    const built = buildRowValues(flight_log_config.schema, payload, identity, existing);
    if (built.error) {
        return errorResponse(ERROR.BAD_REQUEST, built.error);
    }

    writeRow(flight_log_config, sheet, rowIndex, built.values);

    // apply proper sort
    sortFlightLog(sheet);

    // update hash in metadata
    updateFlightLogMetadata();

    return okResponse({'id': built.rowId});
}
