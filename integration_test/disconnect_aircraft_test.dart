
import 'dart:io';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nock/nock.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_aircraft_data.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    clearData() async {
      await deleteAircraftCache();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }

    setUpAll(() async {
      await clearData();
      nock.init();
      // TODO make nock always reply with an error

      // TODO move this to a common utility module
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('currentAircraft', 'a1234');
      await prefs.setString('pilotName', 'Anna');

      final baseDir = await getApplicationSupportDirectory();
      final dataDir = Directory(path.join(baseDir.path, 'aircrafts'));
      await dataDir.create(recursive: true);
      final dataFile = File(path.join(dataDir.path, 'a1234.zip'));
      await dataFile.writeAsBytes(kTestAircraftData);
    });

    tearDownAll(() async {
      //await clearData();
      nock.cleanAll();
    });

    testWidgets('about: disconnect aircraft', (WidgetTester tester) async {
      app.main();

      // TODO this shouldn't be needed if we mock it to always return an error
      nock.cleanAll();
      HttpOverrides.global = null;

      await tester.pumpAndSettle();
      final infoNav = find.byKey(const Key('nav_info'));
      await _waitForWidget(tester, infoNav, 10);
      await tester.tap(infoNav);
      await tester.pumpAndSettle();

      // FIXME doesn't work because the error toaster gets in the way; toasters should disappear when changing screen
      final disconnectButton = find.byKey(const Key('about_button_disconnect_aircraft'));
      await tester.scrollUntilVisible(disconnectButton, 300);
      await tester.pumpAndSettle();
      await tester.tap(disconnectButton);

      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // TODO what now?
      await Future.delayed(const Duration(milliseconds: 5));
    });

  });

}

/// TODO move to utility module
/// TODO is there a better way to do this?
Future<bool> _waitForWidget(WidgetTester tester, Finder finder, int seconds) async {
  int retries = 0;
  while (!tester.any(finder) && retries++ < (seconds * 2)) {
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 500));
  }
  return tester.any(finder);
}
