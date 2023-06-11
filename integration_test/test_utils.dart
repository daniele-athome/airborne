import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nock/nock.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:random_date/random_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_aircraft_data.dart';

final _kRandom = Random();

/// TODO is there a better way to do this?
Future<bool> waitForWidget(
    WidgetTester tester, Finder finder, int seconds) async {
  int retries = 0;
  while (!tester.any(finder) && retries++ < (seconds * 2)) {
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 500));
  }
  return tester.any(finder);
}

Future clearAppData() async {
  await deleteAircraftCache();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

Future setUpDummyAircraft({bool setPilot = true}) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('currentAircraft', 'a1234');
  if (setPilot) {
    await prefs.setString('pilotName', 'Anna');
  }

  final baseDir = await getApplicationSupportDirectory();
  final dataDir = Directory(path.join(baseDir.path, 'aircrafts'));
  await dataDir.create(recursive: true);
  final dataFile = File(path.join(dataDir.path, 'a1234.zip'));
  await dataFile.writeAsBytes(kTestAircraftData);
}

int randomBetween(int min, int max) => min + _kRandom.nextInt((max + 1) - min);

FlightLogItem randomFlightLogItem(int id) {
  final hourStart = randomBetween(1000, 2000);
  final hourEnd = randomBetween(hourStart, 2000);
  return FlightLogItem(
      id.toString(),
      RandomDate.withRange(2021, 2023).random(),
      "Anna",
      "Fly Berlin",
      "London Heathrow",
      hourStart,
      hourEnd,
      null,
      null,
      "HELLO");
}

Interceptor mockGoogleAuthentication() {
  return nock('https://oauth2.googleapis.com').post(
    '/token',
    (List<int> body, ContentType contentType) => true,
  )
    ..persist()
    ..reply(
        200,
        json.encode({
          "access_token": "DUMMYTOKEN",
          "scope": "https://www.googleapis.com/auth/prediction",
          "token_type": "Bearer",
          "expires_in": 3600,
        }),
        headers: {
          'content-type': 'application/json',
        });
}

Interceptor mockGoogleCalendarApi() {
  final base = nock('https://www.googleapis.com/calendar/v3');
  return base.get(startsWith('/calendars/NONE/events'))
    ..query((Map<String, String> params) => true)
    ..persist()
    ..reply(
        200,
        json.encode({
          "items": [],
        }),
        headers: {
          'content-type': 'application/json',
        });
}

void unmockAllHttp() {
  nock.cleanAll();
  HttpOverrides.global = null;
}
