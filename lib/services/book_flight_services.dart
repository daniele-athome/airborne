import 'package:googleapis/calendar/v3.dart' as gcalendar;
import 'package:timezone/timezone.dart';

import '../helpers/googleapis.dart';
import '../models/book_flight_models.dart';

/// A primitive way to abstract the real flight booking service.
class BookFlightCalendarService {
  late final GoogleServiceAccountService _accountService;
  GoogleCalendarService? _client;

  BookFlightCalendarService(GoogleServiceAccountService accountService) {
    _accountService = accountService;
  }

  Future<GoogleCalendarService> _ensureService() {
    if (_client != null) {
      return Future.value(_client);
    }
    else {
      return _accountService.getAuthenticatedClient().then((client) {
        _client = GoogleCalendarService(client);
        return _client!;
      });
    }
  }

  Future<Iterable<FlightBooking>> search(Object calendarId, DateTime timeMin, DateTime timeMax) {
    return _ensureService().then((client) =>
      client.listEvents(calendarId as String, timeMin, timeMax).then((events) =>
        events.items!
              .where((gcalendar.Event e) => e.summary != null && e.start != null && e.end != null)
              .map((gcalendar.Event e) {
                // e.timezone is always null but times are UTC!!!
                return FlightBooking(
                  e.id,
                  e.summary!,
                  getTzDateTime(e.start!, events.timeZone!),
                  getTzDateTime(e.end!, events.timeZone!),
                  e.description,
                );
              })
      ),
    );
  }

  Future<bool> bookingConflicts(Object calendarId, FlightBooking event) {
    return _ensureService().then((client) =>
      client.listEvents(calendarId as String, event.from, event.to).then((events) =>
        events.items!
          .where((gcalendar.Event e) => e.id != event.id)
          .isNotEmpty
      ),
    );
  }

  Future<FlightBooking> createBooking(Object calendarId, FlightBooking event) {
    return _ensureService().then((client) {
      final gevent = gcalendar.Event();
      gevent.summary = event.pilotName;
      gevent.description = event.notes;
      // TODO do we need to set the timezone too?
      gevent.start = gcalendar.EventDateTime();
      gevent.start!.dateTime = event.from;
      gevent.end = gcalendar.EventDateTime();
      gevent.end!.dateTime = event.to;
      return _client!
          .insertEvent(calendarId as String, gevent)
          .then((newEvent) => FlightBooking(
              newEvent.id,
              newEvent.summary!,
              // TODO check if new event has timezone in it and avoid using data from the source event
              TZDateTime.from(newEvent.start!.dateTime!, event.from.location),
              TZDateTime.from(newEvent.end!.dateTime!, event.to.location),
              newEvent.description));
    });
  }

  Future<Object> updateBooking(Object calendarId, FlightBooking event) {
    return _ensureService().then((client) {
      final gevent = gcalendar.Event();
      gevent.summary = event.pilotName;
      gevent.description = event.notes;
      // TODO do we need to set the timezone too?
      gevent.start = gcalendar.EventDateTime();
      gevent.start!.dateTime = event.from;
      gevent.end = gcalendar.EventDateTime();
      gevent.end!.dateTime = event.to;
      return _client!
          .updateEvent(calendarId as String, event.id!, gevent)
          .then((newEvent) => FlightBooking(
              newEvent.id,
              newEvent.summary!,
              // TODO check if new event has timezone in it and avoid using data from the source event
              TZDateTime.from(newEvent.start!.dateTime!, event.from.location),
              TZDateTime.from(newEvent.end!.dateTime!, event.to.location),
              newEvent.description));
    });
  }

  Future<DeletedFlightBooking> deleteBooking(Object calendarId, FlightBooking event) {
    return _ensureService().then((client) {
      return client.deleteEvent(calendarId as String, event.id!)
          .then((value) => DeletedFlightBooking(event.id!));
    });
  }

}

TZDateTime getTzDateTime(gcalendar.EventDateTime dateTime, String defaultTimeZone) {
  final timeZone = dateTime.timeZone ?? defaultTimeZone;
  return TZDateTime.from(dateTime.dateTime!, timeZone == 'UTC' ? UTC : getLocation(timeZone));
}
