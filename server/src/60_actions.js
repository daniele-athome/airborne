/**
 * Airborne backend — action handlers.
 *
 * Read actions run without the lock: a single ranged read is consistent enough,
 * and the version travels with the response so the client can tell whether what
 * it read is still current. Mutating actions run inside `withLock`.
 */

/** Validates a payload value against its field definition. */
function coerceField(field, raw) {
  var missing = raw === null || raw === undefined || raw === '';

  if (missing) {
    if (field.required) {
      return { error: 'Missing required field: ' + field.name };
    }
    return { value: '' };
  }

  if (field.type === 'string') {
    if (typeof raw !== 'string') {
      return { error: 'Field ' + field.name + ' must be a string' };
    }
    if (field.values && field.values.indexOf(raw) < 0) {
      return { error: 'Field ' + field.name + ' must be one of: ' + field.values.join(', ') };
    }
    return { value: raw };
  }

  if (field.type === 'number' || field.type === 'integer') {
    var num = typeof raw === 'number' ? raw : Number(raw);
    if (typeof num !== 'number' || isNaN(num) || !isFinite(num)) {
      return { error: 'Field ' + field.name + ' must be a number' };
    }
    if (field.type === 'integer' && Math.floor(num) !== num) {
      return { error: 'Field ' + field.name + ' must be an integer' };
    }
    if (field.values && field.values.indexOf(num) < 0) {
      return { error: 'Field ' + field.name + ' must be one of: ' + field.values.join(', ') };
    }
    return { value: num };
  }

  if (field.type === 'date') {
    return coerceDate(field, raw);
  }

  return { error: 'Unsupported field type for ' + field.name };
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
    return { value: raw };
  }
  if (typeof raw !== 'string') {
    return { error: 'Field ' + field.name + ' must be a date string' };
  }

  var dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
  if (dateOnly) {
    return {
      value: new Date(Number(dateOnly[1]), Number(dateOnly[2]) - 1, Number(dateOnly[3]))
    };
  }

  var parsed = new Date(raw);
  if (isNaN(parsed.getTime())) {
    return { error: 'Field ' + field.name + ' is not a valid date: ' + raw };
  }
  return { value: parsed };
}

/**
 * Builds the row to write.
 *
 * `existing` is null on insert. On update it is the current row, and every
 * column that the payload does not carry — including columns this build does
 * not map at all — is preserved from it.
 */
function buildRowValues(storeConfig, payload, identity, existing, force) {
  var values = [];
  for (var i = 0; i < storeConfig.columnCount; i++) {
    values.push(existing ? existing[i] : '');
  }

  var now = new Date();

  for (var f = 0; f < storeConfig.fields.length; f++) {
    var field = storeConfig.fields[f];

    if (field.immutable && existing) {
      continue;
    }

    if (field.managed === 'createdAt') {
      values[field.index] = existing ? existing[field.index] : now;
      continue;
    }

    if (field.managed === 'statusTimestamp') {
      // Only stamped when the status actually changes.
      var statusField = getFieldConfig(storeConfig, 'status');
      if (statusField && Object.prototype.hasOwnProperty.call(payload, 'status')) {
        var previousStatus = existing ? existing[statusField.index] : '';
        if (String(payload.status || '') !== String(previousStatus || '')) {
          values[field.index] = now;
        }
      } else if (!existing) {
        values[field.index] = '';
      }
      continue;
    }

    if (field.identity) {
      // The pilot comes from the token, not from the request: otherwise anyone
      // could file a flight under someone else's name. A claim that survived
      // checkIdentityClaim is authorized, so it is honoured here without
      // needing `force`, which is about preconditions and not about identity.
      var claimed = payload[field.name];
      if (claimed) {
        values[field.index] = String(claimed);
      } else if (!existing) {
        values[field.index] = identity.pilotName;
      }
      continue;
    }

    if (!existing || Object.prototype.hasOwnProperty.call(payload, field.name)) {
      var coerced = coerceField(field, payload[field.name]);
      if (coerced.error) {
        return { error: coerced.error };
      }
      values[field.index] = coerced.value;
    }
  }

  return { values: values };
}

/**
 * Checks that identity fields the caller tried to set are allowed.
 *
 * Non-admin tokens may only write their own name, and only the configured
 * maintenance pilot is accepted as an exception.
 */
function checkIdentityClaim(storeConfig, payload, identity) {
  var noPilotName = getProperty('NO_PILOT_NAME', false);

  for (var i = 0; i < storeConfig.fields.length; i++) {
    var field = storeConfig.fields[i];
    if (!field.identity) {
      continue;
    }
    var claimed = payload[field.name];
    if (!claimed || claimed === identity.pilotName) {
      continue;
    }
    if (isAdmin(identity)) {
      continue;
    }
    if (noPilotName && claimed === noPilotName) {
      continue;
    }
    return 'Not allowed to write ' + field.name + ' as "' + claimed + '"';
  }
  return null;
}

/** Verifies the `expect` precondition against the current row. */
function checkPrecondition(expect, currentFingerprint, currentHash, identity, force) {
  if (force) {
    if (!isAdmin(identity)) {
      return errorResponse(ERROR.FORBIDDEN, 'Only an admin token may force a write');
    }
    return null;
  }

  if (!expect) {
    return errorResponse(ERROR.BAD_REQUEST, 'Missing "expect" precondition');
  }

  if (typeof expect.fingerprint === 'string') {
    if (expect.fingerprint !== currentFingerprint) {
      return errorResponse(ERROR.CONFLICT, 'The entry was modified by someone else');
    }
    return null;
  }

  if (typeof expect.hash === 'string') {
    if (expect.hash !== currentHash) {
      return errorResponse(ERROR.CONFLICT, 'The store was modified by someone else');
    }
    return null;
  }

  return errorResponse(ERROR.BAD_REQUEST, '"expect" must carry a fingerprint or a hash');
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/**
 * Validates the token and reports the state of every store.
 *
 * Called at startup so that an app which is out of protocol range finds out
 * immediately, rather than when the pilot is trying to save a flight.
 */
function actionBootstrap(envelope, identity, metadata) {
  var stores = {};
  var names = Object.keys(STORES);

  for (var i = 0; i < names.length; i++) {
    var storeConfig = STORES[names[i]];
    try {
      var sheet = openStoreSheet(storeConfig);
      stores[names[i]] = {
        hash: metadata[versionKey(storeConfig)] || null,
        count: getRowCount(sheet, storeConfig)
      };
    } catch (err) {
      // A store that is not configured in this deployment is simply absent,
      // mirroring the app's own feature detection.
      console.warn('Store ' + names[i] + ' unavailable: ' + err.message);
    }
  }

  return okResponse(
    {
      pilotName: identity.pilotName,
      role: identity.role,
      buildId: BUILD_ID
    },
    stores
  );
}

/** Returns one page of items, newest block first. */
function actionList(envelope, identity, metadata, storeConfig) {
  var sheet = openStoreSheet(storeConfig);
  var count = getRowCount(sheet, storeConfig);
  var hash = metadata[versionKey(storeConfig)] || null;

  var pageSize = Math.min(
    Math.max(parseInt(envelope.payload.pageSize, 10) || DEFAULT_PAGE_SIZE, 1),
    MAX_PAGE_SIZE
  );

  var cursor = decodeCursor(envelope.payload.cursor);
  var lastOrdinal = cursor ? Math.min(cursor.lastOrdinal, count) : count;
  var firstOrdinal = Math.max(lastOrdinal - pageSize + 1, 1);

  var items = [];
  if (lastOrdinal >= 1) {
    var rows = readRows(sheet, storeConfig, firstOrdinal, lastOrdinal);
    for (var i = 0; i < rows.length; i++) {
      items.push(rowToItem(storeConfig, firstOrdinal + i, rows[i]));
    }
  }

  var hasMore = firstOrdinal > 1;

  return okResponse(
    {
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore ? encodeCursor({ lastOrdinal: firstOrdinal - 1, hash: hash }) : null,
      // The page is served even when the store moved under the cursor: an
      // exception in the middle of a scroll is worse than a stale flag.
      stale: !!(cursor && cursor.hash && cursor.hash !== hash)
    },
    stateFor(storeConfig, sheet, metadata)
  );
}

/**
 * Appends an item.
 *
 * No precondition is required: an append cannot conflict with another append,
 * and demanding one would produce spurious conflicts every time somebody else
 * touches the store while a form is open.
 */
function actionInsert(envelope, identity, metadata, storeConfig) {
  var claimError = checkIdentityClaim(storeConfig, envelope.payload, identity);
  if (claimError) {
    return errorResponse(ERROR.FORBIDDEN, claimError);
  }

  var sheet = openStoreSheet(storeConfig);
  var built = buildRowValues(storeConfig, envelope.payload, identity, null, envelope.force);
  if (built.error) {
    return errorResponse(ERROR.BAD_REQUEST, built.error);
  }

  if (storeConfig.idStrategy === 'column') {
    built.values[storeConfig.idColumnIndex] = allocateId(storeConfig, metadata);
  }

  // The appended ordinal is the new row count, and is trustworthy without
  // waiting for the write to be flushed back.
  var ordinal = appendRow(sheet, storeConfig, built.values);
  metadata[versionKey(storeConfig)] = bumpVersion(storeConfig, metadata);
  writeMetadata(countKey(storeConfig), String(ordinal));

  return okResponse(
    rowToItem(storeConfig, ordinal, built.values),
    stateFor(storeConfig, sheet, metadata, ordinal)
  );
}

/** Updates an item, preserving every column the payload does not carry. */
function actionUpdate(envelope, identity, metadata, storeConfig) {
  if (typeof envelope.payload.id !== 'string' || envelope.payload.id === '') {
    return errorResponse(ERROR.BAD_REQUEST, 'Missing "id"');
  }

  var claimError = checkIdentityClaim(storeConfig, envelope.payload, identity);
  if (claimError) {
    return errorResponse(ERROR.FORBIDDEN, claimError);
  }

  var sheet = openStoreSheet(storeConfig);
  var ordinal = resolveOrdinal(sheet, storeConfig, envelope.payload.id);
  if (ordinal < 0) {
    return errorResponse(
      ERROR.NOT_FOUND,
      'Entry ' + envelope.payload.id + ' no longer exists',
      null,
      stateFor(storeConfig, sheet, metadata)
    );
  }

  var existing = readRow(sheet, storeConfig, ordinal);
  var currentFingerprint = fingerprintRow(existing, storeConfig.columnCount);
  var hash = metadata[versionKey(storeConfig)] || null;

  var failed = checkPrecondition(envelope.expect, currentFingerprint, hash, identity, envelope.force);
  if (failed) {
    // A conflict carries the current row, so the app can show what is there now
    // instead of asking the pilot to start over.
    if (failed.error.code === ERROR.CONFLICT) {
      failed.error.details = { current: rowToItem(storeConfig, ordinal, existing) };
      failed.state = stateFor(storeConfig, sheet, metadata);
    }
    return failed;
  }

  var built = buildRowValues(storeConfig, envelope.payload, identity, existing, envelope.force);
  if (built.error) {
    return errorResponse(ERROR.BAD_REQUEST, built.error);
  }

  writeRow(sheet, storeConfig, ordinal, built.values);
  metadata[versionKey(storeConfig)] = bumpVersion(storeConfig, metadata);

  return okResponse(
    rowToItem(storeConfig, ordinal, built.values),
    stateFor(storeConfig, sheet, metadata)
  );
}

/** Deletes an item. */
function actionDelete(envelope, identity, metadata, storeConfig) {
  if (typeof envelope.payload.id !== 'string' || envelope.payload.id === '') {
    return errorResponse(ERROR.BAD_REQUEST, 'Missing "id"');
  }

  var sheet = openStoreSheet(storeConfig);
  var ordinal = resolveOrdinal(sheet, storeConfig, envelope.payload.id);
  if (ordinal < 0) {
    return errorResponse(
      ERROR.NOT_FOUND,
      'Entry ' + envelope.payload.id + ' no longer exists',
      null,
      stateFor(storeConfig, sheet, metadata)
    );
  }

  var existing = readRow(sheet, storeConfig, ordinal);
  var currentFingerprint = fingerprintRow(existing, storeConfig.columnCount);
  var hash = metadata[versionKey(storeConfig)] || null;

  var failed = checkPrecondition(envelope.expect, currentFingerprint, hash, identity, envelope.force);
  if (failed) {
    if (failed.error.code === ERROR.CONFLICT) {
      failed.error.details = { current: rowToItem(storeConfig, ordinal, existing) };
      failed.state = stateFor(storeConfig, sheet, metadata);
    }
    return failed;
  }

  var remaining = getRowCount(sheet, storeConfig) - 1;
  deleteRow(sheet, storeConfig, ordinal);
  metadata[versionKey(storeConfig)] = bumpVersion(storeConfig, metadata);
  writeMetadata(countKey(storeConfig), String(remaining));

  return okResponse(
    { id: envelope.payload.id, deleted: true },
    stateFor(storeConfig, sheet, metadata, remaining)
  );
}
