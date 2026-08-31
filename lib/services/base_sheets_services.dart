import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../helpers/googleapis.dart';
import 'metadata_services.dart';
import 'script_client.dart';

/// Items per page to fetch.
const _kItemsPerPage = 20;

/// Cell containing the row count.
@Deprecated('Use the metadata store.')
const _kSheetCountRange = 'A1';

const _columnLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// A base class for a Google Sheets-based data store.
///
/// `<T>` is the type of the data object represented in the store.
@Deprecated("Port all functionalities to AppsScriptGoogleStoreService")
abstract class GoogleSheetsStoreService<T> {
  late final Logger _log = Logger(runtimeType.toString());

  final GoogleServiceAccountService _accountService;
  final MetadataService? _metadataService;
  final String _spreadsheetId;
  final String _sheetName;
  GoogleSheetsService? _client;

  /// State: last fetched row number
  int _lastId = 0;

  /// State: flight log hash (from last fetch)
  String? _dataHash;

  GoogleSheetsStoreService({
    required GoogleServiceAccountService accountService,
    required MetadataService? metadataService,
    required String spreadsheetId,
    required String sheetName,
  }) : _accountService = accountService,
       _metadataService = metadataService,
       _spreadsheetId = spreadsheetId,
       _sheetName = sheetName;

  @visibleForTesting
  set client(GoogleSheetsService client) {
    _client = client;
  }

  @visibleForTesting
  set lastId(int lastId) {
    _lastId = lastId;
  }

  @visibleForTesting
  int get lastId => _lastId;

  @visibleForTesting
  set dataHash(String dataHash) {
    _dataHash = dataHash;
  }

  Future<void> reset() async {
    final client = await _ensureService();

    if (_metadataService != null) {
      // reload metadata
      final store = await _metadataService.reload();

      // last row number (i.e. store size)
      final lastIdValue = store[_getMetadataCountKey()];
      if (lastIdValue == null) {
        throw const FormatException('No data found on sheet.');
      }
      _lastId = int.parse(lastIdValue);

      // data hash (i.e. version number)
      // will increase monotonically with every change
      final hashValue = store[_getMetadataHashKey()];
      if (hashValue == null) {
        throw const FormatException('No data found on sheet.');
      }
      _dataHash = hashValue;

      _log.finest('lastId is $_lastId, hash is $_dataHash');
    } else {
      // legacy method: first cell of the first row of the sheet
      final value = await client.getRows(
        _spreadsheetId,
        _sheetName,
        _kSheetCountRange,
      );

      if (value.values == null) {
        throw const FormatException('No data found on sheet.');
      }
      _lastId = int.parse(value.values![0][0].toString());
      _log.finest('lastId (legacy) is $_lastId');
    }
  }

  Future<Iterable<T>> fetchItems() async {
    final client = await _ensureService();

    final lastId = _lastId;
    _lastId = max(_lastId - _kItemsPerPage, 0);
    final firstId = _lastId + 1;
    _log.fine(
      'getting rows from $firstId to $lastId (range: ${_sheetDataRange(firstId, lastId)})',
    );

    final value = await client.getRows(
      _spreadsheetId,
      _sheetName,
      _sheetDataRange(firstId, lastId),
    );

    if (value.values == null) {
      throw const FormatException('No data found on sheet.');
    }

    _log.finest(value.values);
    return value.values!.mapIndexed<T>(
      (index, rowData) => buildItem(
        // item ID is a 1-based ordinal
        (firstId + index).toString(),
        rowData,
      ),
    );
  }

  bool hasMoreData() => _lastId > 0;

  Future<GoogleSheetsService> _ensureService() async {
    if (_client != null) {
      return _client!;
    } else {
      _client = GoogleSheetsService(
        await _accountService.getAuthenticatedClient(),
      );
      return _client!;
    }
  }

  /// Metadata key for the store hash.
  String _getMetadataHashKey() => '${getMetadataPrefixKey()}.hash';

  /// Metadata key for the store counter.
  String _getMetadataCountKey() => '${getMetadataPrefixKey()}.count';

  /// Returns the last column letter of the sheet data range.
  String _columnCellNameFromCount() => _columnLetters[getColumnCount() - 1];

  /// Data range generator. [first] and [last] are 1-based indexes (i.e. flight log item ID).
  String _sheetDataRange(int first, int last) =>
      'A${_itemIdToRowNumber(first)}:${_columnCellNameFromCount()}${_itemIdToRowNumber(last)}';

  /// Convert item ID to sheet row number. +1 is for skipping the header row.
  int _itemIdToRowNumber(int id) => id + 1;

  /// The prefix of the metadata key for this store.
  String getMetadataPrefixKey();

  /// Returns the number of columns of the sheet data range.
  int getColumnCount();

  /// Builds a data object from a row of data from the sheet.
  T buildItem(String rowId, List<Object?> rowData);
}

/// A base class for a Google Sheets-based data store with Apps Script backend installed for write operations.
///
/// `<T>` is the type of the data object represented in the store.
abstract class GoogleAppsScriptStoreService<T>
    extends GoogleSheetsStoreService<T> {
  GoogleAppsScriptStoreService({
    required String scriptUrl,
    required String scriptToken,
    required super.accountService,
    required super.metadataService,
    required super.spreadsheetId,
    required super.sheetName,
  }) : _scriptClient = ScriptClient(url: scriptUrl, token: scriptToken);

  final ScriptClient _scriptClient;

  // TODO exception handling

  Future<T> appendItem(T item) async {
    final result = await _scriptClient.invoke(
      action: 'flight-log/insert',
      requestId: ScriptClient.newRequestId(),
      payload: buildRowData(item),
    );

    return newItem(item, result.id);
  }

  Future<T> updateItem(String id, T item) async {
    final result = await _scriptClient.invoke(
      action: 'flight-log/update',
      requestId: ScriptClient.newRequestId(),
      payload: {...buildRowData(item), 'id': id},
    );

    return newItem(item, result.id);
  }

  Future<String?> deleteItem(String id) async {
    final result = await _scriptClient.invoke(
      action: 'flight-log/delete',
      requestId: ScriptClient.newRequestId(),
      payload: {'id': id},
    );

    return result.id;
  }

  T newItem(T item, String newId);

  /// Subclasses should override this to convert a model into a map for the backend.
  Map<String, dynamic> buildRowData(T item);
}

/// Exception thrown when the hash of the flight log has changed.
class DataChangedException implements Exception {
  const DataChangedException();
}
