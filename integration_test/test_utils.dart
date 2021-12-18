import 'dart:io';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_aircraft_data.dart';

/// TODO is there a better way to do this?
Future<bool> waitForWidget(WidgetTester tester, Finder finder, int seconds) async {
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
