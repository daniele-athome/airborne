import 'dart:math';
import 'package:collection/collection.dart';

import '../models/flight_log_models.dart';
import '../helpers/googleapis.dart';

/// Items per page to fetch.
const _kItemsPerPage = 20;
/// Cell containing the row count.
const _kSheetCountRange = 'A1';
/// Data range for appending.
const _kSheetAppendRange = 'A:J';

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
  _itemIdToRowNumber(id) => id + 1;

  Future<void> reset() {
    return _ensureService().then((client) =>
      client.getRows(_spreadsheetId, _sheetName, _kSheetCountRange).then((value) {
        if (value.values == null) {
          throw const FormatException('No data found on sheet.');
        }
        _lastId = int.parse(value.values![0][0].toString());
        print('lastId is $_lastId');
      })
    );
  }

  Future<Iterable<FlightLogItem>> fetchItems() {
    return _ensureService().then((client) {
      final lastId = _lastId - 1;
      _lastId = max(_lastId - _kItemsPerPage, 0);
      final firstId = _lastId;
      print('getting rows from $firstId to $lastId (range: ${_sheetDataRange(firstId, lastId)})');
      return client.getRows(_spreadsheetId, _sheetName, _sheetDataRange(firstId, lastId)).then((value) {
        if (value.values == null) {
          throw const FormatException('No data found on sheet.');
        }
        return value.values!.mapIndexed<FlightLogItem>((index, rowData) => FlightLogItem(
          (firstId + index + 1).toString(),
          dateFromGsheets(rowData[1] as String),
          rowData[2] as String,
          rowData[3] as String,
          rowData[4] as String,
          rowData[5] as int,
          rowData[6] as int,
          rowData[7] as int,
          rowData[8] as double,
          rowData[9] as String?,
        ));
      });
    });
  }

  bool hasMoreData() {
    return _lastId > 0;
  }

}
