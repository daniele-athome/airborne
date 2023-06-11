import 'dart:convert';

import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/main.dart' as app;
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/screens/flight_log/flight_log_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/intl.dart';
import 'package:nock/nock.dart';

import 'test_utils.dart';

void main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_US';

  group('flight log test', () {
    setUpAll(() async {
      await clearAppData();
      nock.init();
      mockGoogleAuthentication();
      setUpDummyAircraft();
    });

    tearDownAll(() async {
      await clearAppData();
      unmockAllHttp();
    });

    testWidgets('flight log: empty log book', (WidgetTester tester) async {
      app.main();

      final httpCountMock = mockGoogleSheetsCountApi(0);
      final httpRowsMock = mockGoogleSheetsRowsApi();

      await tester.pumpAndSettle();

      expect(await waitForWidget(tester, find.byKey(const Key('nav_flight_log')), 10), true);
      await tester.tap(find.byKey(const Key("nav_flight_log")));
      await tester.pumpAndSettle();

      expect(tester.any(find.byKey(const Key('list_flight_log'))), true);
      expect(tester.any(find.byKey(const Key('button_error_retry'))), true);
      expect(httpRowsMock.isDone, true);
      expect(httpCountMock.isDone, true);

      httpRowsMock.cancel();
      httpCountMock.cancel();
    });

    testWidgets('flight log: view log book', (WidgetTester tester) async {
      app.main();

      final mockItems = [
        randomFlightLogItem(1),
        randomFlightLogItem(2),
        randomFlightLogItem(3),
        randomFlightLogItem(4),
      ];
      final httpCountMock = mockGoogleSheetsCountApi(mockItems.length);
      final httpRowsMock = mockGoogleSheetsRowsApi(items: mockItems);

      await tester.pumpAndSettle();

      expect(await waitForWidget(tester, find.byKey(const Key('nav_flight_log')), 10), true);
      await tester.tap(find.byKey(const Key("nav_flight_log")));
      await tester.pumpAndSettle();

      expect(tester.any(find.byKey(const Key('list_flight_log'))), true);
      expect(httpRowsMock.isDone, true);
      expect(httpCountMock.isDone, true);
      expect(tester.widgetList(find.descendant(of: find.byKey(const Key('list_flight_log')),
          matching: find.byType(FlightLogListItem))).length, mockItems.length);

      httpRowsMock.cancel();
      httpCountMock.cancel();
    });

    // TODO C[R]UD tests
  });

}

// TODO copied (actually modified) from FlightLogBookService, consider abstracting
List<Object?> _formatRowData(FlightLogItem item) =>
    [
      dateToGsheets(DateTime.now()),
      dateToGsheets(item.date).toInt(),
      item.pilotName,
      item.startHour,
      item.endHour,
      item.origin,
      item.destination,
      item.fuel ?? '',
      item.fuel != null ? item.fuelPrice : '',
      item.notes ?? '',
    ];

/// Google Sheets API for the rows.
Interceptor mockGoogleSheetsRowsApi({List<FlightLogItem>? items}) {
  final base = nock('https://sheets.googleapis.com');
  return base.get(matches(r'^/v4/spreadsheets/NONE/values/%27NONE%27%21.{5}'))
    ..query((Map<String, String> params) => true)
    ..persist()
    ..reply(200, json.encode({
      "values": items != null ? items.map((e) => _formatRowData(e)).toList(growable: false) : [],
    }), headers: {
      'content-type': 'application/json',
    });
}

Interceptor mockGoogleSheetsCountApi(int count) {
  final base = nock('https://sheets.googleapis.com');
  return base.get(matches(r'^/v4/spreadsheets/NONE/values/%27NONE%27%21A1'))
    ..query((Map<String, String> params) => true)
    ..persist()
    ..reply(200, json.encode({
      "values": [[count.toString()]],
    }), headers: {
      'content-type': 'application/json',
    });
}
