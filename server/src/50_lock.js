/**
 * Runs `fn` while holding the script lock.
 *
 * Returns a BUSY response instead of throwing when the lock cannot be taken, so
 * the client can back off and retry with the same requestId.
 */
function withLock(fn) {
    const lock = LockService.getScriptLock();
    if (!lock.tryLock(LOCK_TIMEOUT_MS)) {
        return errorResponse(
            ERROR.BUSY,
            'Another operation is in progress, retry shortly'
        );
    }
    try {
        return fn();
    } finally {
        // Pending writes must reach the spreadsheet before the next holder of the lock reads it.
        commitChanges();
        lock.releaseLock();
    }
}

/**
 * Replays the stored result of a previous identical request, or runs `fn` and
 * remembers its result.
 *
 * This must be called *inside* the lock: checking the cache outside it would
 * let two concurrent copies of the same request both miss the cache and both
 * execute, which is the duplicate this is meant to prevent.
 *
 * Only successful responses are memoized — BUSY and CONFLICT are meant to be
 * retried with the same requestId.
 */
function withIdempotency(requestId, fn) {
    if (!requestId) {
        return fn();
    }

    const cache = CacheService.getScriptCache();
    const key = 'req:' + requestId;

    const cached = cache.get(key);
    if (cached) {
        try {
            const previous = JSON.parse(cached);
            previous.replayed = true;
            return previous;
        } catch (err) {
            // A corrupted entry is not worth failing over: fall through and re-run.
            console.warn('Discarding unreadable idempotency record for ' + requestId);
        }
    }

    const result = fn();
    if (result && result.ok) {
        cache.put(key, JSON.stringify(result), IDEMPOTENCY_TTL_SECONDS);
    }
    return result;
}

/* Test-only: see test/load.js. Apps Script has no `module`, so this never runs there. */
if (typeof module === 'object') {
    module.exports = {withLock, withIdempotency};
}
