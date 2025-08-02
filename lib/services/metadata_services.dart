import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../helpers/googleapis.dart';

/// Data range for the key-value store.
const _kSheetKeyValueRange = 'A2:B';

final Logger _log = Logger((MetadataService).toString());

class MetadataService {
  late final GoogleServiceAccountService _accountService;
  late final String _spreadsheetId;
  late final String _sheetName;
  GoogleSheetsService? _client;

  /// Cached key-value store
  Map<String, String>? _store;

  MetadataService(GoogleServiceAccountService accountService,
      Map<String, String> properties) {
    _accountService = accountService;
    _spreadsheetId = properties['spreadsheet_id']!;
    _sheetName = properties['sheet_name']!;
  }

  @visibleForTesting
  set client(GoogleSheetsService client) {
    _client = client;
  }

  Future<GoogleSheetsService> _ensureService() async {
    if (_client != null) {
      return _client!;
    } else {
      _client = GoogleSheetsService(await _accountService.getAuthenticatedClient());
      return _client!;
    }
  }

  Future<Map<String, String>> _ensureCache() async {
    if (_store != null) {
      return _store!;
    } else {
      return await reload();
    }
  }

  Future<Map<String, String>> reload() async {
    final client = await _ensureService();
    final value =
        await client.getRows(_spreadsheetId, _sheetName, _kSheetKeyValueRange);
    if (value.values == null) {
      throw const FormatException('No data found on sheet.');
    }

    Map<String, String> store = HashMap();
    for (var item in value.values!) {
      if (item.length >= 2) {
        store[item[0].toString()] = item[1].toString();
      } else {
        _log.warning('Skipping malformed row in metadata: $item');
      }
    }

    _store = store;
    _log.info(store);
    return store;
  }

  Future<String?> get(String key) async {
    final store = await _ensureCache();
    return store[key];
  }
}
