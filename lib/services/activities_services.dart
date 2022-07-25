import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../helpers/googleapis.dart';
import '../models/activities_models.dart';

/// Items per page to fetch.
const _kItemsPerPage = 20;
/// Cell containing the row count.
const _kSheetCountRange = 'A1';

final Logger _log = Logger((ActivityEntry).toString());

/// A primitive way to abstract the real activities service.
class ActivitiesService {
  late final GoogleServiceAccountService _accountService;
  late final String _spreadsheetId;
  late final String _sheetName;
  GoogleSheetsService? _client;
  int _lastId = 0;

  ActivitiesService(GoogleServiceAccountService accountService, Map<String, String> properties) {
    _accountService = accountService;
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
  int get lastId =>_lastId;

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

  Future<Iterable<ActivityEntry>> fetchItems() =>
    _ensureService().then((client) {
      final lastId = _lastId - 1;
      _lastId = max(_lastId - _kItemsPerPage, 0);
      final firstId = _lastId;
      _log.fine('getting rows from $firstId to $lastId (range: ${_sheetDataRange(firstId, lastId)})');
      return client.getRows(_spreadsheetId, _sheetName, _sheetDataRange(firstId, lastId)).then((value) {
        if (value.values == null) {
          throw const FormatException('No data found on sheet.');
        }
        _log.finest(value.values);
        return value.values!.mapIndexed<ActivityEntry>((index, rowData) => ActivityEntry(
          id: (firstId + index + 1).toString(),
          creationDate: dateFromGsheets((rowData[1] as int).toDouble()),
          type: ActivityType.fromCode(rowData[2] as int),
          status: rowData[3] is String && (rowData[3] as String).isNotEmpty ? ActivityStatus.fromLabel(rowData[3] as String) : null,
          dueDate: rowData[4] is int ? dateFromGsheets((rowData[4] as int).toDouble()) : null,
          author: rowData[5] as String,
          summary: rowData[6] as String,
          description: rowData.length > 7 && rowData[7] is String && (rowData[7] as String).isNotEmpty ? rowData[7] as String : null,
          // TODO alert:
        ));
      });
    });

  bool hasMoreData() {
    return _lastId > 0;
  }

}
