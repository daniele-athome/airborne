import 'dart:io';

import 'package:airborne/main.dart' as app;
import 'package:airborne/screens/pilot_select/pilot_select_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nock/nock.dart';

import 'test_aircraft_data.dart';
import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('onboarding test', () {
    setUpAll(() async {
      await clearAppData();
      nock.init();
    });

    tearDownAll(() async {
      await clearAppData();
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

  group('offboarding test', () {
    setUpAll(() async {
      await clearAppData();
      nock.init();
      // TODO make nock always reply with an error

      setUpDummyAircraft();
    });

    tearDownAll(() async {
      await clearAppData();
      nock.cleanAll();
    });

    testWidgets('about: disconnect aircraft', (WidgetTester tester) async {
      app.main();

      // TODO this shouldn't be needed if we mock it to always return an error
      nock.cleanAll();
      HttpOverrides.global = null;

      await tester.pumpAndSettle();

      final infoNav = find.byKey(const Key('nav_info'));
      await waitForWidget(tester, infoNav, 10);
      await tester.tap(infoNav);
      await tester.pumpAndSettle();

      final disconnectButton = find.byKey(const Key('about_button_disconnect_aircraft'));
      await tester.scrollUntilVisible(disconnectButton, 300);
      await tester.pumpAndSettle();
      await tester.tap(disconnectButton);

      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // did we return to the aircraft data screen?
      expect(tester.any(find.byKey(const Key('aircraft_data_button_install'))), true);
    });
  });

}
