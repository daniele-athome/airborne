// noinspection JSUnusedGlobalSymbols
function doGet() {
    return output({
        ok: true,
        v: PROTOCOL_V,
        vMin: PROTOCOL_V_MIN,
        vMax: PROTOCOL_V_MAX,
        data: {service: 'airborne', buildId: BUILD_ID}
    });
}

// noinspection JSUnusedGlobalSymbols
function doPost(e) {
    try {
        if (!e || !e.postData || !e.postData.contents) {
            return output(errorResponse(ERROR.BAD_REQUEST, 'Empty request body'));
        }

        let body;
        try {
            body = JSON.parse(e.postData.contents);
        } catch (err) {
            return output(errorResponse(ERROR.BAD_REQUEST, 'Request body is not valid JSON'));
        }

        return output(handleRequest(body));
    } catch (err) {
        // Never let a stack trace escape as an HTML error page: the client expects JSON on every path.
        console.error('Unhandled error: ' + (err && err.stack ? err.stack : err));
        return output(errorResponse(ERROR.INTERNAL, err && err.message ? err.message : String(err)));
    }
}

function handleRequest(body) {
    const parsed = parseEnvelope(body);
    if (parsed.error) {
        return parsed.error;
    }
    const envelope = parsed.envelope;

    const identity = authenticate(envelope.token);
    if (!identity) {
        return errorResponse(ERROR.UNAUTHORIZED, 'Unknown or revoked token');
    }

    if (!isMutating(envelope.action)) {
        return dispatch(envelope, identity);
    }

    return withLock(function () {
        return withIdempotency(envelope.requestId, function () {
            return dispatch(envelope, identity);
        });
    });
}

function dispatch(envelope, identity) {
    switch (envelope.action) {
        case 'flight-log/insert':
            return actionFlightLogInsert(envelope.payload, identity);
        default:
            return errorResponse(ERROR.BAD_REQUEST, 'Unhandled action: ' + envelope.action);
    }
}
