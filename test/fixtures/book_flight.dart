import 'package:airborne/helpers/config.dart';
import 'package:airborne/models/book_flight_models.dart';
import 'package:airborne/services/book_flight_services.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:timezone/timezone.dart';

import '../generate_mocks.mocks.dart';
import 'aircraft.dart';
import 'images.dart';

/// The pilot using the app.
const kPilot = 'Mike';

/// Any other pilot of the sample aircraft.
const kOtherPilot = 'John';

/// Home base of the sample aircraft, see [aircraftMetadata].
const kLatitude = 52.8844253;
const kLongitude = 12.7143166;
const kTimeZone = 'Europe/Berlin';

/// Timezone data has to be loaded before this is read.
Location get kHomeBase => getLocation(kTimeZone);

/// A date in the past, so that nothing depends on the day the tests run.
TZDateTime get kSampleFrom => bookingDateTime(2023, 10, 27, 10, 0);
TZDateTime get kSampleTo => bookingDateTime(2023, 10, 27, 12, 30);

/// How long the mocked service takes to answer. It has to outlast a frame: an
/// answer that lands before the progress dialog is on screen leaves the modal
/// popping the wrong route, which no real backend is fast enough to do.
const kServiceDelay = Duration(milliseconds: 250);

/// Answers [value] the way a real backend would, a few frames later.
Future<T> answersLater<T>(T value) =>
    Future.delayed(kServiceDelay, () => value);

/// Fails with [error] a few frames later.
Future<T> failsLater<T>(Object error) =>
    Future.delayed(kServiceDelay, () => throw error);

TZDateTime bookingDateTime(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) => TZDateTime(kHomeBase, year, month, day, hour, minute);

/// A booking of the sample aircraft. A null [id] means a new booking.
FlightBooking sampleBooking({
  String? id,
  String pilotName = kPilot,
  TZDateTime? from,
  TZDateTime? to,
  String? notes,
}) => FlightBooking(id, pilotName, from ?? kSampleFrom, to ?? kSampleTo, notes);

/// An [AppConfig] of the sample aircraft, with [pilotName] using the app.
MockAppConfig mockAppConfig({bool admin = false, String pilotName = kPilot}) {
  final appConfig = MockAppConfig();
  when(appConfig.pilotName).thenReturn(pilotName);
  when(appConfig.pilotNames).thenReturn(kSamplePilotNames);
  when(appConfig.admin).thenReturn(admin);
  when(appConfig.locationTimeZone).thenReturn(kHomeBase);
  when(appConfig.locationLatitude).thenReturn(kLatitude);
  when(appConfig.locationLongitude).thenReturn(kLongitude);
  when(
    appConfig.getPilotAvatar(any),
  ).thenAnswer((call) => FakeImage(call.positionalArguments.first as String));
  return appConfig;
}

/// A calendar service that accepts everything it is given, [kServiceDelay]
/// later. Tests that need another answer stub the call again.
MockBookFlightCalendarService mockCalendarService() {
  final service = MockBookFlightCalendarService();
  when(service.bookingConflicts(any)).thenAnswer((_) => answersLater(false));
  when(service.createBooking(any)).thenAnswer(
    (call) => answersLater(call.positionalArguments.first as FlightBooking),
  );
  when(service.updateBooking(any)).thenAnswer(
    (call) => answersLater(call.positionalArguments.first as FlightBooking),
  );
  when(service.deleteBooking(any)).thenAnswer(
    (call) => answersLater(
      DeletedFlightBooking(
        (call.positionalArguments.first as FlightBooking).id!,
      ),
    ),
  );
  return service;
}

/// What the booking modal reads from its ancestors.
List<SingleChildWidget> bookFlightProviders(
  MockAppConfig appConfig,
  MockBookFlightCalendarService service,
) => [
  ChangeNotifierProvider<AppConfig>.value(value: appConfig),
  Provider<BookFlightCalendarService>.value(value: service),
];
