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

import 'flight_log_modal_test.mocks.dart';

@GenerateMocks([AppConfig, FlightLogBookService])
void main() async {
  const locale = Locale('en');
  // used for asserting on text labels (e.g. specific error messages)
  final lang = await AppLocalizations.delegate.load(locale);

  Widget createSkeletonApp(FlightLogBookService flightLogService) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: locale,
        home: MultiProvider(
          providers: [
            _provideAppConfigForSampleAircraft(),
            Provider.value(value: flightLogService),
          ],
          child: FlightLogScreen(),
        ),
      );

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
      when(service.fetchItems()).thenAnswer((_) {
        return Future.value(List<FlightLogItem>.generate(20, (index) {
          return FlightLogItem(
            // TODO 1-based index?
            (index+1).toString(),
            DateTime.now(),
            pilots[random.nextInt(pilots.length)],
            'Fly@localhost',
            'Fly@localhost',
            1238+index,
            1238+index+1,
            null,
            null,
            null,
          );
        }, growable: false));
      });

      await tester.pumpWidget(createSkeletonApp(service));

      // verify list item count
      final listFinder = find.descendant(of: find.byKey(const Key('list_flight_log')),
          matching: find.byType(PagedListView));
      //final listWidget = tester.widget<PagedListView>(listFinder);
      final listWidget = tester.widget<PagedListView>(find.byType(PagedListView));
      expect(listWidget.pagingController.value.itemList!.length, 20);
    });
  });
}

ChangeNotifierProvider<AppConfig> _provideAppConfigForSampleAircraft() {
  final appConfig = MockAppConfig();
  when(appConfig.getPilotAvatar(any))
      .thenReturn(const AssetImage('assets/images/nopilot_avatar.png'));
  when(appConfig.fuelPriceCurrency).thenReturn('€');
  // TODO stub some stuff
  return ChangeNotifierProvider<AppConfig>.value(
    value: appConfig,
  );
}

Provider<FlightLogBookService> _provideFlightLogBookService() {
  final service = MockFlightLogBookService();
  // TODO stub some stuff
  return Provider.value(value: service);
}
