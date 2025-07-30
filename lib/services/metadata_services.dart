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

  Future<GoogleSheetsService> _ensureService() {
    if (_client != null) {
      return Future.value(_client);
    } else {
      return _accountService.getAuthenticatedClient().then((client) {
        _client = GoogleSheetsService(client);
        return _client!;
      });
    }
  }

  Future<Map<String, String>> _ensureCache() {
    return _store != null
        ? Future.value(_store!)
        : reload().then((value) => _store!);
  }

  Future<void> reload() {
    return _ensureService().then((client) => client
            .getRows(_spreadsheetId, _sheetName, _kSheetKeyValueRange)
            .then((value) {
          if (value.values == null) {
            throw const FormatException('No data found on sheet.');
          }
          Map<String, String> store = HashMap();
          for (var item in value.values!) {
            store[item[0] as String] = item[1].toString();
          }

          _store = store;
          _log.info(store);
        }));
  }

  Future<String?> get(String key) {
    return _ensureCache().then((value) {
      return _store![key]?.toString();
    });
  }
}
