
import 'dart:io';

import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/main.dart' as app;
import 'package:airborne/screens/pilot_select/pilot_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nock/nock.dart';
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
    });

    tearDownAll(() async {
      await clearData();
      nock.cleanAll();
    });

    testWidgets('onboarding: register aircraft', (WidgetTester tester) async {
      nock('http://localhost').get('/a1234.zip')
        .reply(200, kTestAircraftData);

      app.main();

      await tester.pumpAndSettle();
      await tester.enterText(
          find.byWidgetPredicate((widget) => widget is PlatformTextFormField &&
              widget.keyboardType == TextInputType.url), 'http://localhost/a1234.zip');
      await tester.tap(find.byKey(const Key('aircraft_data_button_install')));
      await tester.pumpAndSettle();

      expect(tester.any(find.byType(PilotSelectScreen)), true);
    });

    testWidgets('onboarding: select pilot', (WidgetTester tester) async {
      // we should mock google apis, but in this case we won't use it so who cares :)
      nock.cleanAll();
      HttpOverrides.global = null;

      app.main();

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pilot_select_list:Anna')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // check for main navigation bar
      expect(tester.any(find.byKey(const Key('nav_book_flight'))), true);
      expect(tester.any(find.byKey(const Key('nav_flight_log'))), true);
      expect(tester.any(find.byKey(const Key('nav_info'))), true);
    });

  });
}
