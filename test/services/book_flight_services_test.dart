
import 'dart:math';

import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/models/book_flight_models.dart';
import 'package:airborne/services/book_flight_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/calendar/v3.dart' as gapi_calendar;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart';

import 'book_flight_services_test.mocks.dart';

@GenerateMocks([GoogleCalendarService, GoogleServiceAccountService])
void main() {
  late MockGoogleCalendarService mockCalendarService;
  late BookFlightCalendarService testService;

  setUpAll(() {
    // initialize timezone data
    tz_data.initializeTimeZones();
  });
  setUp(() {
    mockCalendarService = MockGoogleCalendarService();
    testService = BookFlightCalendarService(MockGoogleServiceAccountService(), "TEST");
    testService.client = mockCalendarService;
  });

  test('search events', () async {
    final eventId = Random().nextInt(10000).toString();
    final dtStart = DateTime.now();
    final dtEnd = DateTime.now();
    final fakeEvent = gapi_calendar.Event(
      id: eventId,
      summary: 'Anna',
      start: gapi_calendar.EventDateTime(dateTime: dtStart, timeZone: local.name),
      end: gapi_calendar.EventDateTime(dateTime: dtEnd, timeZone: local.name),
      description: null,
    );
    final fakeEvents = gapi_calendar.Events(items: [fakeEvent], timeZone: 'UTC');
    when(mockCalendarService.listEvents("TEST", dtStart, dtEnd)).thenAnswer((_) => Future.value(fakeEvents));

    final expectedEvent = FlightBooking(eventId, "Anna",
        TZDateTime.from(dtStart, UTC), TZDateTime.from(dtEnd, UTC), null);
    final expectedEvents = [expectedEvent];
    expect(await testService.search(dtStart, dtEnd), expectedEvents);
  });

  test('booking conflict', () async {
    final dtStart = DateTime.now();
    final dtEnd = DateTime.now();
    final fakeEvent = gapi_calendar.Event(
      id: 'OLDEVENT',
      summary: 'Anna',
      start: gapi_calendar.EventDateTime(dateTime: dtStart.toUtc(), timeZone: local.name),
      end: gapi_calendar.EventDateTime(dateTime: dtEnd.toUtc(), timeZone: local.name),
      description: null,
    );
    final fakeEvents = gapi_calendar.Events(items: [fakeEvent], timeZone: local.name);
    when(mockCalendarService.listEvents("TEST", TZDateTime.from(dtStart, local), TZDateTime.from(dtEnd, local)))
        .thenAnswer((_) => Future.value(fakeEvents));

    final fakeBooking = FlightBooking("NEWEVENT", "Anna",
        TZDateTime.from(dtStart, local), TZDateTime.from(dtEnd, local), null);
    expect(await testService.bookingConflicts(fakeBooking), true);

    final emptyFakeEvents = gapi_calendar.Events(items: [], timeZone: local.name);
    when(mockCalendarService.listEvents("TEST", TZDateTime.from(dtStart, local), TZDateTime.from(dtEnd, local)))
        .thenAnswer((_) => Future.value(emptyFakeEvents));
    expect(await testService.bookingConflicts(fakeBooking), false);
  });

  test('create booking', () async {
    final dtStart = DateTime.now();
    final dtEnd = DateTime.now();
    final fakeEvent = gapi_calendar.Event(
      id: "NEWEVENT",
      summary: 'Anna',
      start: gapi_calendar.EventDateTime(dateTime: dtStart),
      end: gapi_calendar.EventDateTime(dateTime: dtEnd),
      description: null,
    );
    // TODO stub event parameter (needs custom ArgMatcher)
    when(mockCalendarService.insertEvent("TEST", any)).thenAnswer((_) => Future.value(fakeEvent));

    final fakeBooking = FlightBooking("NEWEVENT", "Anna",
        TZDateTime.from(dtStart, local), TZDateTime.from(dtEnd, local), null);
    expect(await testService.createBooking(fakeBooking), fakeBooking);
  });

  test('update booking', () async {
    final dtStart = DateTime.now();
    final dtEnd = DateTime.now();
    final fakeEvent = gapi_calendar.Event(
      id: "NEWEVENT",
      summary: 'Anna',
      start: gapi_calendar.EventDateTime(dateTime: dtStart),
      end: gapi_calendar.EventDateTime(dateTime: dtEnd),
      description: null,
    );
    // TODO stub event parameter (needs custom ArgMatcher)
    when(mockCalendarService.updateEvent("TEST", "NEWEVENT", any)).thenAnswer((_) => Future.value(fakeEvent));

    final fakeBooking = FlightBooking("NEWEVENT", "Anna",
        TZDateTime.from(dtStart, local), TZDateTime.from(dtEnd, local), null);
    expect(await testService.updateBooking(fakeBooking), fakeBooking);
  });

  test('delete booking', () async {
    final dtStart = DateTime.now();
    final dtEnd = DateTime.now();
    when(mockCalendarService.deleteEvent("TEST", "NEWEVENT")).thenAnswer((_) => Future.value());

    final fakeBooking = FlightBooking("NEWEVENT", "Anna",
        TZDateTime.from(dtStart, local), TZDateTime.from(dtEnd, local), null);
    final fakeDeletedBooking = DeletedFlightBooking("NEWEVENT");
    expect(await testService.deleteBooking(fakeBooking), fakeDeletedBooking);
  });
}
