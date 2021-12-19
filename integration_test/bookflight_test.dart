
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:googleapis/calendar/v3.dart' as gapi_calendar;
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
    testWidgets('book flight: create event (no conflict)', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();

      await waitForWidget(tester, find.byKey(const Key('nav_book_flight')), 10);

      await tester.tap(find.byKey(const Key('button_bookFlight')));
      await tester.pumpAndSettle();
      expect(await waitForWidget(tester, find.byType(BookFlightModal), 10), true);

      // TODO play with the form

      // temporarly disable calendar view mock
      nock.cleanAll();
      final interceptors = mockGoogleCalendarCreateApi();

      await tester.tap(find.byKey(const Key('button_bookFlightModal_save')));
      await tester.pumpAndSettle();
      await waitForWidget(tester, find.byKey(const Key('nav_book_flight')), 10);

      expect(interceptors['create']!.isDone, true);
      expect(interceptors['conflicts']!.isDone, true);

      // restore mocks
      mockGoogleAuthentication();
      mockGoogleCalendarApi();
    });
    // FIXME somehow the progress dialog won't be dismissed so this test will hang
    /*
    testWidgets('book flight: create event (conflict)', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();

      await waitForWidget(tester, find.byKey(const Key('nav_book_flight')), 10);

      await tester.tap(find.byKey(const Key('button_bookFlight')));
      await tester.pumpAndSettle();
      expect(await waitForWidget(tester, find.byType(BookFlightModal), 10), true);

      // TODO play with the form

      // temporarly disable calendar view mock
      nock.cleanAll();
      final interceptors = mockGoogleCalendarCreateApi(replyConflict: true);

      await tester.tap(find.byKey(const Key('button_bookFlightModal_save')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await waitForWidget(tester, find.byKey(const Key('nav_book_flight')), 10);

      expect(interceptors['create']!.isDone, true);
      expect(interceptors['conflicts']!.isDone, true);

      // restore mocks
      mockGoogleAuthentication();
      mockGoogleCalendarApi();
    });
     */
    testWidgets('book flight: delete event', (WidgetTester tester) async {
      app.main();

      await tester.pumpAndSettle();
      // TODO
    });

  });

}

Map<String, Interceptor> mockGoogleCalendarCreateApi({bool replyConflict = false}) {
  final fakeEvent = gapi_calendar.Event(
    id: Random().nextInt(10000).toString(),
    summary: 'Anna',
    start: gapi_calendar.EventDateTime(dateTime: DateTime.now()),
    end: gapi_calendar.EventDateTime(dateTime: DateTime.now()),
    description: null,
  );
  final interceptors = <String, Interceptor>{};
  final base = nock('https://www.googleapis.com/calendar/v3');
  interceptors['create'] = base.post(startsWith('/calendars/NONE/events'),
        (List<int> body, ContentType contentType) => true,)
    ..query((Map<String, String> params) => true)
    ..reply(200, json.encode(fakeEvent), headers: {
      'content-type': 'application/json',
    });
  // warning: this will conflict with the generic persistent mock (it should be disabled first)
  interceptors['conflicts'] = base.get(startsWith('/calendars/NONE/events'))
    ..query((Map<String, String> params) => true)
    ..persist()
    ..reply(200, json.encode({
      "items": [
        if (replyConflict) fakeEvent,
      ],
    }), headers: {
      'content-type': 'application/json',
    });
  return interceptors;
}
