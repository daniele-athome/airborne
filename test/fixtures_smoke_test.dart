import 'dart:io';

import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:airborne/helpers/aircraft_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'fixtures/aircraft.dart';
import 'fixtures/app.dart';
import 'fixtures/images.dart';
import 'fixtures/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createTestApp', () {
    testWidgets('renders Material on android', (tester) async {
      final context = await pumpTestContext(tester);
      expect(isCupertino(context), false);
      expect(isMaterial(context), true);
      expect(AppLocalizations.of(context), isNotNull);
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('renders Cupertino on iOS', (tester) async {
      final context = await pumpTestContext(
        tester,
        platform: TargetPlatform.iOS,
        brightness: Brightness.dark,
      );
      expect(isCupertino(context), true);
      expect(CupertinoTheme.of(context).brightness, Brightness.dark);
      expect(AppLocalizations.of(context), isNotNull);
    });

    testWidgets('honours the requested locale', (tester) async {
      final context = await pumpTestContext(tester, locale: const Locale('it'));
      expect(Localizations.localeOf(context).languageCode, 'it');
    });

    testWidgets('reports navigator pushes to the observers', (tester) async {
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        createTestApp(
          home: const SizedBox.shrink(),
          navigatorObservers: [observer],
        ),
      );
      expect(observer.pushed, 1);
    });
  });

  testWidgets('FakeImage resolves without IO', (tester) async {
    await tester.pumpWidget(
      createTestApp(home: Image(image: FakeImage('anna'))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(FakeImage('anna'), FakeImage('anna'));
    expect(FakeImage('anna'), isNot(FakeImage('john')));
  });

  group('aircraft fixtures', () {
    useFakePathProvider();

    test('the fake path provider is rooted in a scratch directory', () async {
      final tmpDir = await getTemporaryDirectory();
      expect(tmpDir.path, path.join(fakePathProvider.baseDir, 'temp'));
      expect(Directory(fakePathProvider.baseDir).existsSync(), true);
    });

    test('createValidAircraftZipFile passes validation', () async {
      final zipFile = await createValidAircraftZipFile();
      final reader = AircraftDataReader(dataFile: zipFile, urlFile: null);
      expect(await reader.validate(), true);
    });

    test('createSampleAircraftData exposes files on disk', () async {
      final data = await createSampleAircraftData();
      expect(data.id, kSampleAircraftId);
      expect(data.callSign, kSampleCallSign);
      expect(data.pilotNames, kSamplePilotNames);
      expect(data.aircraftPicture.existsSync(), true);
      expect(data.getPilotAvatar('Anna').existsSync(), true);
    });

    test('aircraftMetadata drops the optional fields when unset', () {
      expect(aircraftMetadata().containsKey('no_pilot_name'), false);
      expect(aircraftMetadata().containsKey('hourmeter_multiplier'), false);
      final custom = aircraftMetadata(
        noPilotName: 'Nobody',
        hourmeterMultiplier: 100,
      );
      expect(custom['no_pilot_name'], 'Nobody');
      expect(custom['hourmeter_multiplier'], 100);
    });
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushed = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed++;
  }
}
