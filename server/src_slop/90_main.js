/**
 * Airborne backend — web app entry points.
 *
 * Apps Script answers with HTTP 200 for anything it manages to run, so failures
 * are reported through `error.code` in the body. A non-JSON response means the
 * request never reached this code — almost always a deployment whose access
 * setting sends the caller to a login page instead.
 */

/**
 * Health check.
 *
 * Deliberately requires no token and exposes no data: it exists to verify that
 * the deployment is reachable and that the client follows the redirect Apps
 * Script issues before serving the response.
 */
function doGet() {
  return output({
    ok: true,
    v: PROTOCOL_V,
    vMin: PROTOCOL_V_MIN,
    vMax: PROTOCOL_V_MAX,
    data: { service: 'airborne', buildId: BUILD_ID },
    state: {}
  });
}

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return output(errorResponse(ERROR.BAD_REQUEST, 'Empty request body'));
    }

    var body;
    try {
      body = JSON.parse(e.postData.contents);
    } catch (err) {
      return output(errorResponse(ERROR.BAD_REQUEST, 'Request body is not valid JSON'));
    }

    return output(handleRequest(body));
  } catch (err) {
    // Never let a stack trace escape as an HTML error page: the client expects
    // JSON on every path.
    console.error('Unhandled error: ' + (err && err.stack ? err.stack : err));
    return output(errorResponse(ERROR.INTERNAL, err && err.message ? err.message : String(err)));
  }
}

/** Validates, authenticates and dispatches a request. */
function handleRequest(body) {
  var parsed = parseEnvelope(body);
  if (parsed.error) {
    return parsed.error;
  }
  var envelope = parsed.envelope;

  var metadata = readMetadata();
  var identity = authenticate(envelope.token, metadata);
  if (!identity) {
    return errorResponse(ERROR.UNAUTHORIZED, 'Unknown or revoked token');
  }

  var storeConfig = null;
  if (envelope.store) {
    storeConfig = getStoreConfig(envelope.store);
    if (!storeConfig) {
      return errorResponse(ERROR.BAD_REQUEST, 'Unknown store: ' + envelope.store);
    }
  }

  if (!isMutating(envelope.action)) {
    return dispatch(envelope, identity, metadata, storeConfig);
  }

  // Mutating actions are serialized, and the idempotency check happens inside
  // the lock so that two copies of the same retried request cannot both run.
  return withLock(function () {
    return withIdempotency(envelope.requestId, function () {
      // Metadata is re-read inside the critical section: the copy taken for
      // authentication may already be stale by the time the lock is granted.
      var fresh = readMetadata();
      return dispatch(envelope, identity, fresh, storeConfig);
    });
  });
}

function dispatch(envelope, identity, metadata, storeConfig) {
  switch (envelope.action) {
    case 'bootstrap':
      return actionBootstrap(envelope, identity, metadata);
    case 'list':
      return actionList(envelope, identity, metadata, storeConfig);
    case 'insert':
      return actionInsert(envelope, identity, metadata, storeConfig);
    case 'update':
      return actionUpdate(envelope, identity, metadata, storeConfig);
    case 'delete':
      return actionDelete(envelope, identity, metadata, storeConfig);
    default:
      return errorResponse(ERROR.BAD_REQUEST, 'Unhandled action: ' + envelope.action);
  }
}
