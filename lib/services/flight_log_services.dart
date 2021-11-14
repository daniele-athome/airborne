import 'dart:math';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../models/flight_log_models.dart';
import '../helpers/googleapis.dart';

/// Items per page to fetch.
const _kItemsPerPage = 20;
/// Cell containing the row count.
const _kSheetCountRange = 'A1';
/// Data range for appending.
// ignore: unused_element
const _kSheetAppendRange = 'A:J';

final Logger _log = Logger((FlightLogItem).toString());

/// A primitive way to abstract the real log book service.
class FlightLogBookService {
  late final GoogleServiceAccountService _accountService;
  late final String _spreadsheetId;
  late final String _sheetName;
  GoogleSheetsService? _client;
  int _lastId = 0;

  FlightLogBookService(GoogleServiceAccountService accountService, Object spreadsheetId) {
    _accountService = accountService;
    _spreadsheetId = (spreadsheetId as Map<String, String>)['spreadsheetId']!;
    _sheetName = spreadsheetId['sheetName']!;
  }

  Future<GoogleSheetsService> _ensureService() {
    if (_client != null) {
      return Future.value(_client);
    }
    else {
      return _accountService.getAuthenticatedClient().then((client) {
        _client = GoogleSheetsService(client);
        return _client!;
      });
    }
  }

  /// Data range generator. +2 because the index is 0-based and to skip the header row.
  _sheetDataRange(first, last) => 'A${first + 2}:J${last + 2}';

  /// Convert item ID to sheet row number. +1 is for skipping the header row.
  // ignore: unused_element
  _itemIdToRowNumber(id) => id + 1;

  Future<void> reset() {
    return _ensureService().then((client) =>
      client.getRows(_spreadsheetId, _sheetName, _kSheetCountRange).then((value) {
        if (value.values == null) {
          throw const FormatException('No data found on sheet.');
        }
        _lastId = int.parse(value.values![0][0].toString());
        _log.finest('lastId is $_lastId');
      })
    );
  }

  Future<Iterable<FlightLogItem>> fetchItems() {
    return _ensureService().then((client) {
      final lastId = _lastId - 1;
      _lastId = max(_lastId - _kItemsPerPage, 0);
      final firstId = _lastId;
      _log.fine('getting rows from $firstId to $lastId (range: ${_sheetDataRange(firstId, lastId)})');
      return client.getRows(_spreadsheetId, _sheetName, _sheetDataRange(firstId, lastId)).then((value) {
        if (value.values == null) {
          throw const FormatException('No data found on sheet.');
        }
        _log.finest(value.values);
        return value.values!.mapIndexed<FlightLogItem>((index, rowData) => FlightLogItem(
          (firstId + index + 1).toString(),
          dateFromGsheets((rowData[1] as int).toDouble()),
          rowData[2] as String,
          rowData[5] as String,
          rowData[6] as String,
          rowData[3] as num,
          rowData[4] as num,
          rowData.length > 7 && rowData[7] is int ? rowData[7] as int : null,
          rowData.length > 8 && rowData[8] is num ? rowData[8] as num : null,
          rowData.length > 9 && rowData[9] is String && (rowData[9] as String).isNotEmpty ? rowData[9] as String? : null,
        ));
      });
    });
  }

  bool hasMoreData() {
    return _lastId > 0;
  }

}
