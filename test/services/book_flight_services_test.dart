
import 'dart:math';

import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/models/book_flight_models.dart';
import 'package:airborne/services/book_flight_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gapi_calendar;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/timezone.dart';

import 'book_flight_services_test.mocks.dart';

@GenerateMocks([GoogleCalendarService, GoogleServiceAccountService])
void main() {
  GoogleCalendarService? mockCalendarService;
  BookFlightCalendarService? testService;

  setUp(() {
    mockCalendarService = MockGoogleCalendarService();
    testService = BookFlightCalendarService(MockGoogleServiceAccountService(), "TEST");
    testService!.client = mockCalendarService!;
  });
  tearDown(() {
  });

  test('search events', () async {
    final eventId = Random().nextInt(10000).toString();
    final dtStart = DateTime.now();
    final dtEnd = DateTime.now();
    final fakeEvent = gapi_calendar.Event(
      id: eventId,
      summary: 'Anna',
      start: gapi_calendar.EventDateTime(dateTime: dtStart),
      end: gapi_calendar.EventDateTime(dateTime: dtEnd),
      description: null,
    );
    final fakeEvents = gapi_calendar.Events(items: [fakeEvent], timeZone: 'UTC');
    when(mockCalendarService!.listEvents("TEST", dtStart, dtEnd)).thenAnswer((_) => Future.value(fakeEvents));

    final expectedEvent = FlightBooking(eventId, "Anna",
        TZDateTime.from(dtStart, UTC), TZDateTime.from(dtEnd, UTC), null);
    final expectedEvents = [expectedEvent];
    expect(await testService!.search(dtStart, dtEnd), expectedEvents);
  });

  // TODO booking conflict
  // TODO create booking
  // TODO update booking
  // TODO delete booking
}
