/**
 * Airborne backend — onChange trigger.
 *
 * This replaces the standalone script that used to live in the spreadsheet
 * template. Keeping it in the same project is the whole point: a trigger in a
 * separate project could not share `LockService.getScriptLock()` with the web
 * app, so a sort could run halfway through a write. Here they serialize.
 *
 * Install it as an installable trigger on the "On change" event (see
 * docs/backend.md); it cannot be a simple trigger because it needs
 * authorization to write.
 */

/**
 * Sorts the edited store and bumps its version.
 *
 * Edits that arrive through the web app have already sorted and bumped inside
 * their own critical section, so this mostly runs for changes typed directly
 * into the spreadsheet — which is exactly the case the app could not otherwise
 * detect.
 */
function onChange(event) {
  var sheet = event && event.source ? event.source.getActiveSheet() : null;
  if (!sheet) {
    return;
  }

  var storeConfig = storeConfigForSheet(sheet.getName());
  if (!storeConfig) {
    return;
  }

  var lock = LockService.getScriptLock();
  if (!lock.tryLock(LOCK_TIMEOUT_MS)) {
    // A write is in flight and will sort and bump on its way out; doing it now
    // would duplicate the version bump for a single logical change.
    console.warn('onChange skipped for ' + sheet.getName() + ': lock held');
    return;
  }

  try {
    sortStore(sheet, storeConfig);
    var metadata = readMetadata();
    bumpVersion(storeConfig, metadata);
    writeMetadata(countKey(storeConfig), String(getRowCount(sheet, storeConfig)));
  } finally {
    SpreadsheetApp.flush();
    lock.releaseLock();
  }
}

/**
 * Matches a sheet name to a store.
 *
 * The template ships localized sheet names, so the configured name is compared
 * as a prefix, exactly as the original trigger did.
 */
function storeConfigForSheet(sheetName) {
  var names = Object.keys(STORES);
  for (var i = 0; i < names.length; i++) {
    var storeConfig = STORES[names[i]];
    var configured = getProperty(storeConfig.sheetNameProperty, false);
    if (configured && sheetName.indexOf(configured) === 0) {
      return storeConfig;
    }
  }
  return null;
}

/**
 * Applies the store's sort order.
 *
 * The range is derived from the store definition rather than written out as
 * `A:K`, for two reasons. It cannot accidentally exclude the id column —
 * `Range.sort()` rearranges the values inside its range and leaves everything
 * outside in place, so an id column left out would end up describing the wrong
 * rows. And it stops below the header instead of relying on the header row
 * being frozen, which is what keeps a full-column sort from shuffling it into
 * the data.
 *
 * `L1` keeps the template's manual escape hatch: setting it to LOCKED suspends
 * sorting, which is what makes the id backfill migration safe to perform.
 */
function sortStore(sheet, storeConfig) {
  if (!storeConfig.sortBy) {
    return;
  }
  if (String(sheet.getRange('L1').getValue()) === 'LOCKED') {
    return;
  }
  var rows = getRowCount(sheet, storeConfig);
  if (rows < 2) {
    return;
  }
  sheet
    .getRange(storeConfig.headerRows + 1, 1, rows, storeConfig.columnCount)
    .sort(storeConfig.sortBy);
}
