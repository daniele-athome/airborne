import 'dart:io';

import 'package:airborne/generated/intl/app_localizations.dart';
import 'package:airborne/helpers/config.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/flight_log/flight_log_list.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../../golden_config.dart';
import 'flight_log_modal_test.mocks.dart';

@GenerateMocks([AppConfig, FlightLogBookService])
void main() async {
  const locale = Locale('en');
  // used for asserting on text labels (e.g. specific error messages)
  //final lang = await AppLocalizations.delegate.load(locale);

  Widget createSkeletonApp(FlightLogBookService flightLogService) {
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
        home: RepaintBoundary(
          key: const Key('golden_box'),
          // Material is needed by some child widget
          child: Material(
            child: FlightLogList(
                controller: FlightLogListController(),
                logBookService: flightLogService,
                onTapItem: (context, item) => {}),
          ),
        ),
      ),
    );
  }

  group('Load and show flight log items', () {
    testWidgets('First page', (tester) async {
      await setupGolden(tester);

      final pilots = [
        'Sara',
        'Anna',
        'John',
        'Peter',
      ];
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
            pilots[index % pilots.length],
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

      await tester.pumpWidget(createSkeletonApp(service));
      await tester.pumpAndSettle();

      // verify list item count
      final listFinder = find.byType(PagedListView<int, FlightLogItem>);
      final listWidget =
          tester.widget<PagedListView<int, FlightLogItem>>(listFinder);
      expect(listWidget.pagingController.value.itemList!.length, 20);

      // check against golden
      await expectLater(find.byKey(const Key('golden_box')),
          matchesGoldenFile('goldens/flight_log_list_first_page.png'),
          skip: !Platform.isLinux);
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
