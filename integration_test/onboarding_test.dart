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
      mockGoogleAuthentication();
      mockGoogleCalendarApi();
    });

    tearDownAll(() async {
      await clearAppData();
      unmockAllHttp();
    });

    testWidgets('onboarding: register aircraft', (WidgetTester tester) async {
      nock('http://localhost').get('/a1234.zip').reply(200, kTestAircraftData);

      app.main();

      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is PlatformTextFormField &&
              widget.keyboardType == TextInputType.url,
        ),
        'http://localhost/a1234.zip',
      );
      await tester.tap(find.byKey(const Key('aircraft_data_button_install')));
      await tester.pumpAndSettle();

      expect(tester.any(find.byType(PilotSelectScreen)), true);
    });

    testWidgets('onboarding: select pilot', (WidgetTester tester) async {
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

    testWidgets('about: update aircraft', (WidgetTester tester) async {
      app.main();

      final infoNav = find.byKey(const Key('nav_info'));
      expect(await waitForWidget(tester, infoNav, 10), true);
      await tester.tap(infoNav);
      await tester.pumpAndSettle();

      final updateButton = find.byKey(
        const Key('about_button_update_aircraft'),
      );
      await tester.scrollUntilVisible(updateButton, 300);
      await tester.pumpAndSettle();
      await tester.tap(updateButton);

      nock('http://localhost').get('/a1234.zip').reply(200, kTestAircraftData);

      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // FIXME we should actually check that all went well
      expect(await waitForWidget(tester, infoNav, 10), true);
    });
  });

  group('offboarding test', () {
    setUpAll(() async {
      await clearAppData();
      nock.init();
      mockGoogleAuthentication();
      mockGoogleCalendarApi();
      setUpDummyAircraft();
    });

    tearDownAll(() async {
      await clearAppData();
      unmockAllHttp();
    });

    testWidgets('about: disconnect aircraft', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();

      final infoNav = find.byKey(const Key('nav_info'));
      expect(await waitForWidget(tester, infoNav, 10), true);
      await tester.tap(infoNav);
      await tester.pumpAndSettle();

      final disconnectButton = find.byKey(
        const Key('about_button_disconnect_aircraft'),
      );
      await tester.scrollUntilVisible(disconnectButton, 300);
      await tester.pumpAndSettle();
      await tester.tap(disconnectButton);

      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // did we return to the aircraft data screen?
      expect(
        tester.any(find.byKey(const Key('aircraft_data_button_install'))),
        true,
      );
    });
  });
}
