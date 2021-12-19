import 'dart:io';

import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

class GoogleServiceAccountService {
  static const scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  late ServiceAccountCredentials _serviceAccount;

  AuthClient? _client;

  GoogleServiceAccountService({required String json}) {
    _serviceAccount = ServiceAccountCredentials.fromJson(json);
  }

  Future<http.Client> getAuthenticatedClient() {
    if (_client == null || _client!.credentials.accessToken.hasExpired) {
      // FIXME doesn't work on web platform
      final HttpClient httpClient = HttpClient();
      httpClient.findProxy = HttpClient.findProxyFromEnvironment;
      return clientViaServiceAccount(_serviceAccount, scopes, baseClient: http_io.IOClient(httpClient))
          .then((AuthClient client) {
        _client = client;
        return client;
      });
    }
    else {
      return Future.value(_client);
    }
  }
}

class GoogleCalendarService {
  static const _defaultTimeout = Duration(seconds: 15);

  late final http.Client _client;
  late final CalendarApi _api;

  GoogleCalendarService(http.Client client) {
    _client = client;
    _api = CalendarApi(_client);
  }

  Future<Events> listEvents(String calendarId, DateTime timeMin, DateTime timeMax) {
    return _api.events.list(calendarId,
      // FIXME toUtc is a workaround
      timeMin: timeMin.toUtc(),
      timeMax: timeMax.toUtc(),
    ).timeout(_defaultTimeout);
  }

  Future<Event> insertEvent(String calendarId, Event event) {
    return _api.events.insert(event, calendarId).timeout(_defaultTimeout);
  }

  Future<Event> updateEvent(String calendarId, String eventId, Event event) {
    return _api.events.update(event, calendarId, eventId).timeout(_defaultTimeout);
  }

  Future<void> deleteEvent(String calendarId, String eventId) {
    return _api.events.delete(calendarId, eventId).timeout(_defaultTimeout);
  }

}

class GoogleSheetsService {
  static const _defaultTimeout = Duration(seconds: 15);

  late final http.Client _client;
  late final SheetsApi _api;

  GoogleSheetsService(http.Client client) {
    _client = client;
    _api = SheetsApi(_client);
  }

  String sheetRange(String sheetName, String range) => "'$sheetName'!$range";

  Future<ValueRange> getRows(String spreadsheetId, String sheetName, String range) {
    final sheetRange = this.sheetRange(sheetName, range);
    return _api.spreadsheets.values.get(spreadsheetId, sheetRange,
      valueRenderOption: 'UNFORMATTED_VALUE',
    ).timeout(_defaultTimeout);
  }

  Future<AppendValuesResponse> appendRows(String spreadsheetId, String sheetName, String range, List<List<Object?>> values) {
    final _range = sheetRange(sheetName, range);
    return _api.spreadsheets.values.append(ValueRange(
      range: _range,
      values: values,
    ), spreadsheetId, _range, valueInputOption: 'USER_ENTERED');
  }

  Future<UpdateValuesResponse> updateRows(String spreadsheetId, String sheetName, String range, List<List<Object?>> values) {
    final _range = sheetRange(sheetName, range);
    return _api.spreadsheets.values.update(ValueRange(
      range: _range,
      values: values,
    ), spreadsheetId, _range, valueInputOption: 'USER_ENTERED');
  }

  Future<BatchUpdateSpreadsheetResponse> deleteRows(String spreadsheetId, String sheetName, int startRow, int endRow) {
    return _getSheetId(spreadsheetId, sheetName).then((spreadsheet) {
      final Sheet sheetInfo;
      try {
        sheetInfo = spreadsheet.sheets!.firstWhere((element) => element.properties!.title == sheetName);
      }
      on StateError catch (_) {
        throw Exception('Sheet not found: $sheetName');
      }
      final request = BatchUpdateSpreadsheetRequest(requests: [
        Request(
          deleteDimension: DeleteDimensionRequest(
            range: DimensionRange(
              sheetId: sheetInfo.properties!.sheetId,
              dimension: 'ROWS',
              startIndex: startRow - 1,
              endIndex: endRow,
            ),
          ),
        ),
      ]);
      return _api.spreadsheets.batchUpdate(request, spreadsheetId);
    });
  }

  Future<Spreadsheet> _getSheetId(String spreadsheetId, String sheetName) {
    return _api.spreadsheets.get(spreadsheetId, $fields: 'sheets.properties');
  }

}

const _kGsDateBase = 2209161600 / 86400;
const _kGsDateFactor = 86400000;

/// https://github.com/a-marenkov/gsheets/issues/31
double dateToGsheets(DateTime dateTime, {bool localTime = true}) {
  final offset = dateTime.millisecondsSinceEpoch / _kGsDateFactor;
  final shift = localTime ? dateTime.timeZoneOffset.inHours / 24 : 0;
  return _kGsDateBase + offset + shift;
}

/// https://github.com/a-marenkov/gsheets/issues/31
DateTime dateFromGsheets(double value, {bool localTime = true}) {
  final millis = (value - _kGsDateBase) * _kGsDateFactor;
  return DateTime.fromMillisecondsSinceEpoch(millis.round(), isUtc: localTime);
}
