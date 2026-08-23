/**
 * Airborne backend — protocol envelope.
 *
 * The envelope is frozen: `v`, `token`, `action`, `store`, `requestId`,
 * `expect`, `payload` and `client` keep their names and meaning forever, so
 * that this file can always read `v` before knowing which contract version it
 * is speaking. Only payload shapes and action semantics evolve with `v`.
 */

/** Machine-readable error codes. Clients switch on these, so they never change meaning. */
var ERROR = {
  BAD_REQUEST: 'BAD_REQUEST',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  BUSY: 'BUSY',
  PROTOCOL_TOO_OLD: 'PROTOCOL_TOO_OLD',
  PROTOCOL_TOO_NEW: 'PROTOCOL_TOO_NEW',
  INTERNAL: 'INTERNAL'
};

var KNOWN_ACTIONS = ['bootstrap', 'list', 'insert', 'update', 'delete'];

/** Actions that change data, and therefore need the lock and an idempotency key. */
var MUTATING_ACTIONS = ['insert', 'update', 'delete'];

function isMutating(action) {
  return MUTATING_ACTIONS.indexOf(action) >= 0;
}

/** Builds a successful response. `state` is always a map keyed by store name. */
function okResponse(data, state) {
  return {
    ok: true,
    v: PROTOCOL_V,
    vMin: PROTOCOL_V_MIN,
    vMax: PROTOCOL_V_MAX,
    data: data === undefined ? null : data,
    state: state || {}
  };
}

/**
 * Builds an error response.
 *
 * `message` is diagnostic only — clients localize from `code` and show the
 * message just as a fallback for codes they do not know.
 */
function errorResponse(code, message, details, state) {
  var error = { code: code, message: message || code };
  if (details) {
    error.details = details;
  }
  return {
    ok: false,
    v: PROTOCOL_V,
    vMin: PROTOCOL_V_MIN,
    vMax: PROTOCOL_V_MAX,
    error: error,
    state: state || {}
  };
}

function isErrorResponse(response) {
  return !!response && response.ok === false;
}

/** Serializes a response for the Apps Script runtime. */
function output(response) {
  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Validates the envelope and normalizes its fields.
 *
 * Returns either `{ error: <response> }` or `{ envelope: {...} }`.
 */
function parseEnvelope(body) {
  if (!body || typeof body !== 'object') {
    return { error: errorResponse(ERROR.BAD_REQUEST, 'Request body must be a JSON object') };
  }

  // The version is checked first: without agreement on the contract there is no
  // point in interpreting anything else.
  if (typeof body.v !== 'number' || Math.floor(body.v) !== body.v) {
    return { error: errorResponse(ERROR.BAD_REQUEST, 'Missing or non-integer "v"') };
  }
  if (body.v < PROTOCOL_V_MIN) {
    return {
      error: errorResponse(
        ERROR.PROTOCOL_TOO_OLD,
        'This app speaks protocol v' + body.v + ', the server requires at least v' + PROTOCOL_V_MIN
      )
    };
  }
  if (body.v > PROTOCOL_V_MAX) {
    return {
      error: errorResponse(
        ERROR.PROTOCOL_TOO_NEW,
        'This app speaks protocol v' + body.v + ', the server supports up to v' + PROTOCOL_V_MAX
      )
    };
  }

  if (typeof body.token !== 'string' || body.token === '') {
    return { error: errorResponse(ERROR.UNAUTHORIZED, 'Missing token') };
  }
  if (typeof body.action !== 'string' || KNOWN_ACTIONS.indexOf(body.action) < 0) {
    return { error: errorResponse(ERROR.BAD_REQUEST, 'Unknown action: ' + body.action) };
  }

  var envelope = {
    v: body.v,
    token: body.token,
    action: body.action,
    store: typeof body.store === 'string' ? body.store : null,
    requestId: typeof body.requestId === 'string' && body.requestId !== '' ? body.requestId : null,
    expect: body.expect && typeof body.expect === 'object' ? body.expect : null,
    payload: body.payload && typeof body.payload === 'object' ? body.payload : {},
    client: typeof body.client === 'string' ? body.client : null,
    force: body.force === true
  };

  if (envelope.action !== 'bootstrap' && !envelope.store) {
    return { error: errorResponse(ERROR.BAD_REQUEST, 'Missing "store"') };
  }
  if (isMutating(envelope.action) && !envelope.requestId) {
    // Without it a lost response cannot be retried safely, so it is mandatory
    // rather than merely recommended.
    return { error: errorResponse(ERROR.BAD_REQUEST, 'Missing "requestId" on a mutating action') };
  }

  return { envelope: envelope };
}

/** Encodes a `list` cursor. Opaque to the client. */
function encodeCursor(cursor) {
  return Utilities.base64EncodeWebSafe(JSON.stringify(cursor));
}

/** Decodes a `list` cursor, returning null when it is unusable. */
function decodeCursor(encoded) {
  if (typeof encoded !== 'string' || encoded === '') {
    return null;
  }
  try {
    var json = Utilities.newBlob(Utilities.base64DecodeWebSafe(encoded)).getDataAsString();
    var cursor = JSON.parse(json);
    return cursor && typeof cursor.lastOrdinal === 'number' ? cursor : null;
  } catch (err) {
    return null;
  }
}
