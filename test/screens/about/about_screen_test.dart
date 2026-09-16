import 'package:airborne/helpers/aircraft_data.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:airborne/models/activities_models.dart';
import 'package:airborne/screens/about/about_screen.dart';
import 'package:airborne/screens/activities/activities_screen.dart';
import 'package:airborne/screens/main/main_screen.dart';
import 'package:airborne/services/activities_services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/app.dart';
import '../../fixtures/images.dart';
import '../../generate_mocks.mocks.dart';

/// Real config, with pictures that don't need files on disk.
class _TestAppConfig extends AppConfig {
  @override
  ImageProvider get aircraftPicture => FakeImage('aircraft');

  @override
  ImageProvider getPilotAvatar(String name) => FakeImage('avatar-$name');
}

class _FakeActivitiesService extends Fake implements ActivitiesService {
  @override
  Future<void> reset() async {}

  @override
  bool hasMoreData() => false;

  @override
  Future<Iterable<ActivityEntry>> fetchItems() async => [];
}

AircraftData _aircraft({
  required List<String> pilotNames,
  Map<String, dynamic> backendInfo = const {},
}) => AircraftData(
  dataPath: null,
  id: 'a1234',
  callSign: 'A-1234',
  backendInfo: backendInfo,
  hourmeterMultiplier: 60,
  pilotNames: pilotNames,
  noPilotName: null,
  locationName: 'Fly Berlin',
  locationLatitude: 52.8844253,
  locationLongitude: 12.7143166,
  locationTimeZone: 'Europe/Berlin',
  locationWeatherLive: null,
  locationWeatherForecast: null,
  documentsArchive: null,
  url: 'https://example.com/aircraft.zip',
);

void main() {
  const oldPilots = ['Mike', 'John'];
  const newPilots = ['Mike', 'John', 'Claudia'];

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Airborne',
      packageName: 'it.casaricci.airborne',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<AppConfig> pumpMainNavigation(
    WidgetTester tester,
    TargetPlatform platform,
    AircraftData aircraft,
  ) async {
    // tall enough for ListView to build every pilot row
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // a stored aircraft id would make init() load it from disk through
    // path_provider, which never answers under the fake clock
    SharedPreferences.setMockInitialValues({});
    final appConfig = _TestAppConfig();
    await appConfig.init();
    await appConfig.setCurrentAircraft(aircraft);

    await tester.pumpWidget(
      createTestApp(
        platform: platform,
        providers: [
          ChangeNotifierProvider<AppConfig>.value(value: appConfig),
          ChangeNotifierProvider<DownloadProvider>(
            create: (_) => DownloadProvider(MockHttpClient.new),
          ),
          Provider<ActivitiesService>.value(value: _FakeActivitiesService()),
        ],
        // same wiring as the '/' route in MyApp
        home: Consumer<AppConfig>(
          builder: (context, appConfig, child) => MainNavigation(appConfig),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return appConfig;
  }

  group('AboutScreen after an aircraft update', () {
    testWidgets('shows the new pilots when coming back to the tab', (
      tester,
    ) async {
      for (final platform in kTestPlatforms) {
        const backendInfo = {
          'activities_spreadsheet_id': 'ACT_ID',
          'activities_sheet_name': 'Activities',
        };
        final appConfig = await pumpMainNavigation(
          tester,
          platform,
          _aircraft(pilotNames: oldPilots, backendInfo: backendInfo),
        );

        await tester.tap(find.byKey(const Key('nav_info')));
        await tester.pumpAndSettle();
        expect(find.text('Claudia'), findsNothing, reason: '$platform');

        await appConfig.setCurrentAircraft(
          _aircraft(pilotNames: newPilots, backendInfo: backendInfo),
        );
        await tester.pumpAndSettle();

        // an aircraft update always goes back to the first tab
        expect(find.byType(ActivitiesScreen), findsOneWidget);
        expect(find.byType(AboutScreen), findsNothing);

        await tester.tap(find.byKey(const Key('nav_info')));
        await tester.pumpAndSettle();
        for (final name in newPilots) {
          expect(find.text(name), findsOneWidget, reason: '$platform / $name');
        }
      }
    });

    testWidgets('shows the new pilots when it is the only screen', (
      tester,
    ) async {
      for (final platform in kTestPlatforms) {
        final appConfig = await pumpMainNavigation(
          tester,
          platform,
          _aircraft(pilotNames: oldPilots),
        );
        expect(find.text('Claudia'), findsNothing, reason: '$platform');

        await appConfig.setCurrentAircraft(_aircraft(pilotNames: newPilots));
        await tester.pumpAndSettle();

        for (final name in newPilots) {
          expect(find.text(name), findsOneWidget, reason: '$platform / $name');
        }
      }
    });
  });
}
