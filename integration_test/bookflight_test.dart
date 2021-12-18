
import 'package:airborne/main.dart' as app;
import 'package:airborne/screens/book_flight/book_flight_modal.dart';
import 'package:airborne/screens/book_flight/book_flight_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nock/nock.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('book flight test', () {
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

    testWidgets('book flight: calendar views', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();

      expect(await waitForWidget(tester, find.byKey(const Key('nav_book_flight')), 10), true);

      // TODO what are we testing here?

      await tester.tap(find.byKey(const Key("button_bookFlight_view_schedule")));
      await tester.pumpAndSettle();
      expect(tester.state<BookFlightScreenState>(find.byType(BookFlightScreen)).calendarController.view, CalendarView.schedule);
      // TODO check that http interceptor was called

      await tester.tap(find.byKey(const Key("button_bookFlight_view_month")));
      await tester.pumpAndSettle();
      expect(tester.state<BookFlightScreenState>(find.byType(BookFlightScreen)).calendarController.view, CalendarView.month);
      // TODO check that http interceptor was called

      await tester.tap(find.byKey(const Key("button_bookFlight_view_week")));
      await tester.pumpAndSettle();
      expect(tester.state<BookFlightScreenState>(find.byType(BookFlightScreen)).calendarController.view, CalendarView.week);
      // TODO check that http interceptor was called

      await tester.tap(find.byKey(const Key("button_bookFlight_view_day")));
      await tester.pumpAndSettle();
      expect(tester.state<BookFlightScreenState>(find.byType(BookFlightScreen)).calendarController.view, CalendarView.day);
      // TODO check that http interceptor was called
    });
    testWidgets('book flight: edit event', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();
      // TODO
    });
    testWidgets('book flight: create event', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();

      await waitForWidget(tester, find.byKey(const Key('nav_book_flight')), 10);

      await tester.tap(find.byKey(const Key('button_bookFlight')));
      await tester.pumpAndSettle();
      expect(await waitForWidget(tester, find.byType(BookFlightModal), 10), true);

      // TODO play with the form

      await tester.tap(find.byKey(const Key('button_bookFlightModal_save')));
      await tester.pumpAndSettle();
      expect(await waitForWidget(tester, find.byType(BookFlightModal), 2), false);

      // TODO check that http interceptor was called
    });
    testWidgets('book flight: delete event', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();
      // TODO
    });

  });

}
