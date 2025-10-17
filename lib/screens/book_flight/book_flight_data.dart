import 'package:logging/logging.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import '../../helpers/utils.dart';
import '../../models/book_flight_models.dart';
import '../../services/book_flight_services.dart';

final Logger _log = Logger((FlightBooking).toString());

class FlightBookingDataSource extends CalendarDataSource {
  late BookFlightCalendarService _service;
  late final void Function(dynamic) _onError;

  FlightBookingDataSource(
    BookFlightCalendarService service,
    void Function(dynamic) onError,
  ) {
    _service = service;
    _onError = onError;
    appointments = [];
  }

  @override
  DateTime getStartTime(int index) {
    return (appointments![index] as FlightBooking).from;
  }

  @override
  DateTime getEndTime(int index) {
    return (appointments![index] as FlightBooking).to;
  }

  @override
  String getSubject(int index) {
    return (appointments![index] as FlightBooking).pilotName;
  }

  @override
  String? getNotes(int index) {
    return (appointments![index] as FlightBooking).notes;
  }

  @override
  Future<void> handleLoadMore(DateTime startDate, DateTime endDate) async {
    final List<FlightBooking> added = [];
    final List<FlightBooking> removed = [];
    final List<FlightBooking> changed = [];

    _log.fine(
      'Loading more events from ${startDate.toIso8601String()} to ${endDate.toIso8601String()}',
    );
    try {
      // FIXME trick to avoid race conditions with setState called by _changeVisibleDates
      await Future.delayed(const Duration(milliseconds: 500));

      // TODO maybe load a few days before and after if currently in schedule view?
      final events = await _service
          .search(startDate, endDate.add(const Duration(days: 1)))
          .timeout(kNetworkRequestTimeout);
      _log.finest('EVENTS: $events');

      // changed events
      changed.addAll(
        events.where((FlightBooking f) {
          final FlightBooking? otherEvent =
              appointments!.firstWhere((e) => e == f, orElse: () => null)
                  as FlightBooking?;
          return otherEvent != null && !otherEvent.equals(f);
        }),
      );
      if (changed.isNotEmpty) {
        changed.forEach(appointments!.remove);
        notifyListeners(CalendarDataSourceAction.remove, changed);
        appointments!.addAll(changed);
        notifyListeners(CalendarDataSourceAction.add, changed);
      }

      // changed events don't get caught in this (because equals only checks for event ID)
      added.addAll(
        events.where((FlightBooking f) => !appointments!.contains(f)),
      );

      // removed items are events that are not seen on the returned collection but are present on the internal data source
      removed.addAll(
        appointments!
            .where(
              (f) =>
                  (f as FlightBooking).from.compareTo(startDate) >= 0 &&
                  f.to.compareTo(endDate) <= 0 &&
                  !events.contains(f),
            )
            // FIXME probably not the best way to change the type
            .map((f) => f as FlightBooking),
      );

      appointments!.addAll(added);
      removed.forEach(appointments!.remove);

      _log.finest('ADDED: $added');
      _log.finest('REMOVED: $removed');
      _log.finest('CHANGED: $changed');
      notifyListeners(CalendarDataSourceAction.add, added);
      if (removed.isNotEmpty) {
        notifyListeners(CalendarDataSourceAction.remove, removed);
      }
    } catch (err, stacktrace) {
      _log.warning('Error loading events', err, stacktrace);
      _onError(err);
      notifyListeners(CalendarDataSourceAction.add, []);
    }
  }

  void updateEvent(FlightBooking updatedEvent, bool newEvent) {
    if (!newEvent) {
      appointments!.remove(updatedEvent);
      notifyListeners(CalendarDataSourceAction.remove, [updatedEvent]);
    }
    appointments!.add(updatedEvent);
    notifyListeners(CalendarDataSourceAction.add, [updatedEvent]);
  }

  void deleteEvent(DeletedFlightBooking deletedEvent) {
    appointments!.remove(deletedEvent);
    notifyListeners(CalendarDataSourceAction.remove, [deletedEvent]);
  }
}
