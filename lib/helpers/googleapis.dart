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

  final http.Client Function() _baseClientBuilder;

  GoogleServiceAccountService({
    required String json,
    http.Client Function()? baseClientBuilder,
  }) : _baseClientBuilder = baseClientBuilder ?? _defaultBaseClient {
    _serviceAccount = ServiceAccountCredentials.fromJson(json);
  }

  /// FIXME doesn't work on web platform
  static http.Client _defaultBaseClient() {
    final HttpClient httpClient = HttpClient();
    httpClient.findProxy = HttpClient.findProxyFromEnvironment;
    return http_io.IOClient(httpClient);
  }

  Future<http.Client> getAuthenticatedClient() {
    if (_client == null || _client!.credentials.accessToken.hasExpired) {
      return clientViaServiceAccount(
        _serviceAccount,
        scopes,
        baseClient: _baseClientBuilder(),
      ).then((AuthClient client) {
        _client = client;
        return client;
      });
    } else {
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

  Future<Events> listEvents(
    String calendarId,
    DateTime timeMin,
    DateTime timeMax,
  ) {
    return _api.events
        .list(
          calendarId,
          // FIXME toUtc is a workaround
          timeMin: timeMin.toUtc(),
          timeMax: timeMax.toUtc(),
        )
        .timeout(_defaultTimeout);
  }

  Future<Event> insertEvent(String calendarId, Event event) {
    return _api.events.insert(event, calendarId).timeout(_defaultTimeout);
  }

  Future<Event> updateEvent(String calendarId, String eventId, Event event) {
    return _api.events
        .update(event, calendarId, eventId)
        .timeout(_defaultTimeout);
  }

  Future<void> deleteEvent(String calendarId, String eventId) {
    return _api.events.delete(calendarId, eventId).timeout(_defaultTimeout);
  }
}

/// A service for interacting with Google Sheets.
class GoogleSheetsService {
  static const _defaultTimeout = Duration(seconds: 15);

  late final http.Client _client;
  late final SheetsApi _api;

  /// Creates a new [GoogleSheetsService] that uses the given [client].
  GoogleSheetsService(http.Client client) {
    _client = client;
    _api = SheetsApi(_client);
  }

  /// Creates a sheet range string in the format "'[sheetName]'![range]".
  ///
  /// The [range] is in Excel A1 notation (e.g. "A1:B2").
  String sheetRange(String sheetName, String range) => "'$sheetName'!$range";

  /// Gets rows from a sheet.
  ///
  /// The [range] is in Excel A1 notation (e.g. "A1:B2").
  Future<ValueRange> getRows(
    String spreadsheetId,
    String sheetName,
    String range,
  ) {
    final sheetRange = this.sheetRange(sheetName, range);
    return _api.spreadsheets.values
        .get(spreadsheetId, sheetRange, valueRenderOption: 'UNFORMATTED_VALUE')
        .timeout(_defaultTimeout);
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
