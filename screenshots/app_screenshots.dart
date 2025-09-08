import 'dart:io';

import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
//import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';
import 'package:screenshots/src/capture_screen.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'fake_data.dart';

void main() async {
  //final deviceName = const String.fromEnvironment("device");
  //final orientation = const String.fromEnvironment("orientation");

  //enableFlutterDriverExtension();

  /*Finder pageClose(String cupertinoValueKey) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return find.byKey(Key(cupertinoValueKey));
    }
    else {
      return find.byType(CloseButton);
    }
  }*/

  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  //final locale = (await findSystemLocale()).replaceAll('_', '-');
  tz_data.initializeTimeZones();

  late AppConfig appConfig;

  appMain({String? pilotName}) async {
    if (pilotName != null) {
      appConfig = FakeAppConfig.withPilotName(pilotName);
    }
    else {
      appConfig = FakeAppConfig();
    }
    await appConfig.init();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppConfig>.value(
            value: appConfig
        ),
        ChangeNotifierProvider<DownloadProvider>(
            create: (context) => DownloadProvider(() => HttpClient())
        ),
      ],
      child: const MainNavigationApp(),
    );
  }

  /// Precaches all images that will be loaded by the UI.
  /// This prevents empty [Image] widgets while doing screenshots.
  precacheImages(WidgetTester tester) async {
    final BuildContext context = tester.element(find.byType(MainNavigationApp));
    for (String name in appConfig.pilotNames) {
      await precacheImage(appConfig.getPilotAvatar(name), context);
    }
  }

  // because of an integration_test bug, only one screenshot per test is allowed
  // https://github.com/flutter/flutter/issues/92381

  group('Screenshots', () {
    testWidgets('Onboarding - Select pilot', (WidgetTester tester) async {
      runApp(await appMain());
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '50-onboarding-pilotselect');
    });

    testWidgets('Book flight - Agenda view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_bookFlight_view_schedule')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '01-bookflight-agenda');
    });

    testWidgets('Book flight - Month view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_bookFlight_view_month')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '02-bookflight-month');
    });

    testWidgets('Book flight - Flight editor', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_bookFlight')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '03-bookflight-flighteditor');
    });

    testWidgets('Log book - List view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_flight_log')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '04-logbook-list');
    });

    testWidgets('Log book - Flight editor', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_flight_log')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_logFlight')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '05-logbook-flighteditor');
    });

    testWidgets('Activities - List view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await precacheImages(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_activities')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, '06-activities-list');
    });
  });
}
