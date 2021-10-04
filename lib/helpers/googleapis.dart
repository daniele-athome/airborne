import 'dart:io';

import 'package:googleapis/calendar/v3.dart';
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
