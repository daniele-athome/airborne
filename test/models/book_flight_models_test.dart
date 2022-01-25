import 'package:airborne/models/book_flight_models.dart';
import 'package:test/test.dart';
import 'package:timezone/timezone.dart';

void main() {
  test('FlightBooking ==', () {
    // equality is only against the id
    FlightBooking model1 = FlightBooking("ID123", "Anna",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        "NOTES"
    );
    FlightBooking model2 = FlightBooking("ID123", "Bob",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        null
    );
    expect(model1 == model2, true);

    FlightBooking model3 = FlightBooking("ID124", "Anna",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        "NOTES"
    );
    FlightBooking model4 = FlightBooking("ID123", "Bob",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        null
    );
    expect(model3 == model4, false);

    final timestamp = TZDateTime.now(UTC);
    FlightBooking model5 = FlightBooking("ID124", "Anna",
        timestamp, timestamp,
        "NOTES"
    );
    FlightBooking model6 = FlightBooking("ID123", "Anna",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        "NOTES"
    );
    expect(model5 == model6, false);
  });

  test('FlightBooking equals', () {
    // equality is against all attributes
    FlightBooking model1 = FlightBooking("ID123", "Anna",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        "NOTES"
    );
    FlightBooking model2 = FlightBooking("ID123", "Bob",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        null
    );
    expect(model1.equals(model2), false);

    FlightBooking model3 = FlightBooking("ID124", "Anna",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        "NOTES"
    );
    FlightBooking model4 = FlightBooking("ID123", "Bob",
        TZDateTime.now(UTC), TZDateTime.now(UTC),
        null
    );
    expect(model3.equals(model4), false);

    final timestamp5 = TZDateTime.fromMicrosecondsSinceEpoch(UTC, 10000000000);
    final timestamp6 = TZDateTime.fromMicrosecondsSinceEpoch(UTC, 10000000000);
    FlightBooking model5 = FlightBooking("ID124", "Anna",
        timestamp5, timestamp5,
        "NOTES"
    );
    FlightBooking model6 = FlightBooking("ID124", "Anna",
        timestamp6, timestamp6,
        "NOTES"
    );
    expect(model5.equals(model6), true);
  });

}
