import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import '../models/flight_log_models.dart';
import '../helpers/googleapis.dart';
import 'metadata_services.dart';

/// Items per page to fetch.
const _kItemsPerPage = 20;

/// Cell containing the row count.
const _kSheetCountRange = 'A1';

/// Data range for appending.
const _kSheetAppendRange = 'A2:J2';

/// Flight date formatter
final _kDateFormatter = DateFormat('yyyy-MM-dd');

/// Metadata key for flight log row counter
const _kLogCountMetadataKey = 'flight_log.count';

/// Metadata key for flight log hash
const _kLogHashMetadataKey = 'flight_log.hash';

final Logger _log = Logger((FlightLogItem).toString());

/// A primitive way to abstract the real log book service.
class FlightLogBookService {
  late final GoogleServiceAccountService _accountService;
  late final MetadataService? _metadataService;
  late final String _spreadsheetId;
  late final String _sheetName;
  GoogleSheetsService? _client;

  /// State: last fetched row number
  int _lastId = 0;

  /// State: flight log hash (from last fetch)
  String? _dataHash;

  FlightLogBookService(GoogleServiceAccountService accountService,
      MetadataService? metadataService, Map<String, String> properties) {
    _accountService = accountService;
    _metadataService = metadataService;
    _spreadsheetId = properties['spreadsheet_id']!;
    _sheetName = properties['sheet_name']!;
  }

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

  /// Completes correctly if hash has not changed, throws exception otherwise.
  Future<void> _ensureUnchangedHash() async {
    if (_metadataService != null) {
      final store = await _metadataService!.reload();
      final newHash = store[_kLogHashMetadataKey];
      _log.finest('Old hash: $_dataHash, new hash: $newHash');
      if (newHash == null) {
        throw const FormatException('No data found on sheet.');
      } else if (newHash != _dataHash) {
        throw const DataChangedException();
      }
    }
  }

  /// Data range generator. +2 because the index is 0-based and to skip the header row.
  // TODO refactor this +2/-1/+1 stuff, it's too confusing
  String _sheetDataRange(int first, int last) => 'A${first + 2}:J${last + 2}';

  /// Convert item ID to sheet row number. +1 is for skipping the header row.
  int _itemIdToRowNumber(int id) => id + 1;

  /// Convert sheet row number to item ID. -1 is for adding the header row.
  // ignore: unused_element
  int _rowNumberToItemId(int rowNumber) => rowNumber - 1;

  Future<void> reset() {
    return _ensureService().then((client) {
      if (_metadataService != null) {
        // get row count from metadata
        return _metadataService!.get(_kLogCountMetadataKey).then((value) {
          if (value == null) {
            throw const FormatException('No data found on sheet.');
          }
          _lastId = int.parse(value);
          // hash will be retrieved during the first fetch
          _dataHash = null;
          _log.finest('lastId is $_lastId');
        });
      } else {
        // legacy method: first cell of the first row of the flight log sheet
        return client
            .getRows(_spreadsheetId, _sheetName, _kSheetCountRange)
            .then((value) {
          if (value.values == null) {
            throw const FormatException('No data found on sheet.');
          }
          _lastId = int.parse(value.values![0][0].toString());
          _log.finest('lastId (legacy) is $_lastId');
        });
      }
    });
  }

  Future<Iterable<FlightLogItem>> fetchItems() =>
      _ensureService().then((client) {
        final lastId = _lastId - 1;
        _lastId = max(_lastId - _kItemsPerPage, 0);
        final firstId = _lastId;
        _log.fine(
            'getting rows from $firstId to $lastId (range: ${_sheetDataRange(firstId, lastId)})');
        final getDataOp = client.getRows(
            _spreadsheetId, _sheetName, _sheetDataRange(firstId, lastId));

        final Future<ValueRange> fetchingOp;
        if (_metadataService != null) {
          fetchingOp = Future.wait([getDataOp, _metadataService!.reload()])
              .then((value) {
            // update our local copy of the flight log hash
            final store = value[1] as Map<String, String>;
            _dataHash = store[_kLogHashMetadataKey];
            return value[0] as ValueRange;
          });
        } else {
          fetchingOp = getDataOp;
        }

        return fetchingOp.then((value) {
          if (value.values == null) {
            throw const FormatException('No data found on sheet.');
          }
          _log.finest(value.values);
          return value.values!
              .mapIndexed<FlightLogItem>((index, rowData) => FlightLogItem(
                    (firstId + index + 1).toString(),
                    dateFromGsheets((rowData[1] as int).toDouble()),
                    rowData[2] as String,
                    rowData[5] as String,
                    rowData[6] as String,
                    rowData[3] as num,
                    rowData[4] as num,
                    rowData.length > 7 && rowData[7] is num
                        ? rowData[7] as num
                        : null,
                    rowData.length > 8 && rowData[8] is num
                        ? rowData[8] as num
                        : null,
                    rowData.length > 9 &&
                            rowData[9] is String &&
                            (rowData[9] as String).isNotEmpty
                        ? rowData[9] as String?
                        : null,
                  ));
        });
      });

  bool hasMoreData() {
    return _lastId > 0;
  }

  List<List<Object?>> _formatRowData(FlightLogItem item) => [
        [
          dateToGsheets(DateTime.now()),
          _kDateFormatter.format(item.date),
          item.pilotName,
          item.startHour,
          item.endHour,
          item.origin,
          item.destination,
          item.fuel ?? '',
          item.fuel != null ? item.fuelPrice : '',
          item.notes ?? '',
        ]
      ];

  Future<FlightLogItem> appendItem(FlightLogItem item) async {
    // check if flight log hash changed since last metadata reload
    // this will throw if hash has changed
    await _ensureUnchangedHash();

    final client = await _ensureService();
    final response = await client.appendRows(
        _spreadsheetId, _sheetName, _kSheetAppendRange, _formatRowData(item));
    if (response.updates != null && response.updates!.updatedRange != null) {
      // TODO return a copy of item with filled id (parse response)
      return item;
    } else {
      throw Exception('Unable to append rows to sheet');
    }
  }

  Future<FlightLogItem> updateItem(FlightLogItem item) async {
    // check if flight log hash changed since last metadata reload
    // this will throw if hash has changed
    await _ensureUnchangedHash();

    final client = await _ensureService();
    // FIXME does -1 but it's not the same as _rowNumberToItemId
    final rowNum = int.parse(item.id!) - 1;
    final response = await client.updateRows(_spreadsheetId, _sheetName,
        _sheetDataRange(rowNum, rowNum), _formatRowData(item));
    if (response.updatedRange != null && response.updatedRange!.isNotEmpty) {
      // TODO return a copy of item (parse response data if available?)
      return item;
    } else {
      throw Exception('Unable to append rows to sheet');
    }
  }

  Future<DeletedFlightLogItem> deleteItem(FlightLogItem item) async {
    // check if flight log hash changed since last metadata reload
    // this will throw if hash has changed
    await _ensureUnchangedHash();

    final client = await _ensureService();
    final rowNumber = _itemIdToRowNumber(int.parse(item.id!));
    final response = await client.deleteRows(
        _spreadsheetId, _sheetName, rowNumber, rowNumber);
    if (response.replies != null && response.replies!.length == 1) {
      return DeletedFlightLogItem(item.id!);
    } else {
      throw Exception('Unable to delete flight log item ${item.id!}');
    }
  }
}

/// Exception thrown when the hash of the flight log has changed.
class DataChangedException implements Exception {
  const DataChangedException();
}
