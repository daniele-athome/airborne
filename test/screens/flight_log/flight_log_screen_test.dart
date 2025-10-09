import 'dart:math';

import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/flight_log/flight_log_screen.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'flight_log_screen_test.mocks.dart';

@GenerateMocks([
  AppConfig,
  FlightLogBookService
], customMocks: [
  MockSpec<NavigatorObserver>(onMissingStub: OnMissingStub.returnDefault)
])
void main() async {
  const locale = Locale('en');
  // used for asserting on text labels (e.g. specific error messages)
  //final lang = await AppLocalizations.delegate.load(locale);

  Widget createSkeletonApp(FlightLogBookService flightLogService,
      NavigatorObserver? navigatorObserver) {
    return MultiProvider(
      providers: [
        _provideAppConfigForSampleAircraft(),
        Provider.value(value: flightLogService),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: locale,
        home: FlightLogScreen(),
        navigatorObservers: [if (navigatorObserver != null) navigatorObserver],
      ),
    );
  }

  group('Load flight log items', () {
    testWidgets('First page', (tester) async {
      final pilots = [
        'Sara',
        'Anna',
        'John',
        'Peter',
      ];
      final random = Random();
      final service = MockFlightLogBookService();
      // generate the first page of data
      when(service.reset()).thenAnswer((_) => Future.value());
      when(service.hasMoreData()).thenReturn(true);
      when(service.fetchItems()).thenAnswer((_) {
        return Future.value(List<FlightLogItem>.generate(20, (index) {
          return FlightLogItem(
            // TODO 1-based index?
            (index + 1).toString(),
            DateTime.now(),
            pilots[random.nextInt(pilots.length)],
            'Fly@localhost',
            'Fly@localhost',
            1238 + index,
            1238 + index + 1,
            null,
            null,
            null,
          );
        }, growable: false));
      });

      await tester.pumpWidget(createSkeletonApp(service, null));

      // verify list item count
      final listFinder = find.descendant(
          of: find.byKey(const Key('list_flight_log')),
          matching: find.byType(PagedListView<int, FlightLogItem>));
      final listWidget =
          tester.widget<PagedListView<int, FlightLogItem>>(listFinder);
      expect(listWidget.pagingController.value.itemList!.length, 20);
    });
  });

  testWidgets('New flight log button opens flight log modal', (tester) async {
    final service = MockFlightLogBookService();
    // generate the first page of data
    when(service.reset()).thenAnswer((_) => Future.value());
    when(service.hasMoreData()).thenReturn(true);
    when(service.fetchItems()).thenAnswer((_) {
      return Future.value([]);
    });

    final navigatorObserver = MockNavigatorObserver();

    await tester.pumpWidget(createSkeletonApp(service, navigatorObserver));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('button_logFlight')));
    await tester.pump();

    // last call to Navigator.push would be the flight log editor modal
    final captured = verify(navigatorObserver.didPush(captureAny, any))
        .captured
        .last as Route;
    expect(captured, isA<MaterialPageRoute>());
    expect((captured.settings.name), isNull);
  });
}

ChangeNotifierProvider<AppConfig> _provideAppConfigForSampleAircraft() {
  final appConfig = MockAppConfig();
  when(appConfig.getPilotAvatar(any))
      .thenReturn(const AssetImage('assets/images/nopilot_avatar.png'));
  when(appConfig.fuelPriceCurrency).thenReturn('€');
  when(appConfig.pilotName).thenReturn('Sara');
  when(appConfig.locationName).thenReturn('Fly@localhost');
  // TODO stub some stuff
  return ChangeNotifierProvider<AppConfig>.value(
    value: appConfig,
  );
}
