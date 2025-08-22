import 'dart:io';
import 'dart:ui';

import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:integration_test/src/channel.dart' show integrationTestChannel;
import 'package:intl/intl_standalone.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'fake_data.dart';

void main() async {
  final deviceName = const String.fromEnvironment("device");
  final orientation = const String.fromEnvironment("orientation");

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
  final locale = (await findSystemLocale()).replaceAll('_', '-');
  tz_data.initializeTimeZones();

  appMain({String? pilotName}) async {
    final AppConfig appConfig;
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

  // because of an integration_test bug, only one screenshot per test is allowed
  // https://github.com/flutter/flutter/issues/923811

  group('Screenshots', () {
    testWidgets('Onboarding - Select pilot', (WidgetTester tester) async {
      runApp(await appMain());
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '50-onboarding-pilotselect');
    });

    testWidgets('Book flight - Agenda view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_bookFlight_view_schedule')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '01-bookflight-agenda');
    });

    testWidgets('Book flight - Month view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_bookFlight_view_month')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '02-bookflight-month');
    });

    testWidgets('Book flight - Flight editor', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_bookFlight')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '03-bookflight-flighteditor');
    });

    testWidgets('Log book - List view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_flight_log')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '04-logbook-list');
    });

    testWidgets('Log book - Flight editor', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_flight_log')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('button_logFlight')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '05-logbook-flighteditor');
    });

    testWidgets('Activities - List view', (WidgetTester tester) async {
      runApp(await appMain(pilotName: 'Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav_activities')));
      await tester.pumpAndSettle();
      await screenshot(binding, tester, locale, deviceName, orientation, '06-activities-list');
    });
  });
}

/// We cannot import integration_test or flutter_test because they lead to the following error: 'dart:ui' not found
/// More info here: https://github.com/flutter/flutter/issues/27826
/// Make sure to pass a IntegrationTestWidgetsFlutterBinding for `binding` and a WidgetTester for `tester`
Future screenshot(dynamic binding, dynamic tester, String locale, String deviceName, String orientation, String name) async {
  if (Platform.isAndroid) {
    // This is required prior to taking the screenshot (Android only).
    await binding.convertFlutterSurfaceToImage();
  }

  // Trigger a frame.
  await tester.pumpAndSettle();

  final String platform;
  if (Platform.isIOS) {
    platform = "ios";
  }
  // TODO remove isLinux
  else if (Platform.isAndroid || Platform.isLinux) {
    platform = "android";
  }
  else {
    fail('Unsupported platform for screenshots.');
  }

  // Take screenshot
  // FIXME args are supported on web only (!!)
  final args = <String, Object>{
    'platform': platform,
    'locale': locale,
    'device': deviceName,
    'orientation': orientation,
  };
  await takeScreenshot(name, args);
}

Future<Map<String, dynamic>> takeScreenshot(
    String screenshot, Map<String, Object?> args) async {
  integrationTestChannel.setMethodCallHandler(_onMethodChannelCall);
  final List<int>? rawBytes = await integrationTestChannel.invokeMethod<List<int>>(
    'captureScreenshot',
    <String, dynamic>{'name': screenshot, ...args},
  );
  if (rawBytes == null) {
    throw StateError('Expected a list of bytes, but instead captureScreenshot returned null');
  }
  return <String, dynamic>{'screenshotName': screenshot, 'bytes': rawBytes};
}

Future<dynamic> _onMethodChannelCall(MethodCall call) async {
  switch (call.method) {
    case 'scheduleFrame':
      PlatformDispatcher.instance.scheduleFrame();
  }
  return null;
}
