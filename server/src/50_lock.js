/**
 * Airborne backend — mutual exclusion and idempotency.
 *
 * The script lock is what makes check-and-write atomic: reading the current
 * row, comparing the fingerprint and writing all happen inside one critical
 * section, so two clients cannot both pass the check and both write.
 *
 * It only covers executions of *this* script. Writes issued directly against
 * the Sheets API, and edits typed into the browser, bypass it — which is why
 * the app has to stop writing directly once this is in place.
 */

/**
 * Runs `fn` while holding the script lock.
 *
 * Returns a BUSY response instead of throwing when the lock cannot be taken, so
 * the client can back off and retry with the same requestId.
 */
function withLock(fn) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(LOCK_TIMEOUT_MS)) {
    return errorResponse(
      ERROR.BUSY,
      'Another operation is in progress, retry shortly',
      { retryAfterMs: LOCK_RETRY_AFTER_MS }
    );
  }
  try {
    return fn();
  } finally {
    // Pending writes must reach the spreadsheet before the next holder of the
    // lock reads it.
    SpreadsheetApp.flush();
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

  var cache = CacheService.getScriptCache();
  var key = 'req:' + requestId;

  var cached = cache.get(key);
  if (cached) {
    try {
      var previous = JSON.parse(cached);
      previous.replayed = true;
      return previous;
    } catch (err) {
      // A corrupted entry is not worth failing over: fall through and re-run.
      console.warn('Discarding unreadable idempotency record for ' + requestId);
    }
  }

  var result = fn();
  if (result && result.ok) {
    cache.put(key, JSON.stringify(result), IDEMPOTENCY_TTL_SECONDS);
  }
  return result;
}
