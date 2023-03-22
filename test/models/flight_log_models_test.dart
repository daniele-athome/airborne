import 'package:airborne/models/flight_log_models.dart';
import 'package:test/test.dart';

void main() {
  test('FlightLogItem ==', () {
    // equality is only against the id
    FlightLogItem model1 = FlightLogItem("ID123",
        DateTime.now(), "Anna", "Fly Berlin", "Fly Away",
        1283, 1284, null, null, "NOTES"
    );
    FlightLogItem model2 = FlightLogItem("ID123",
        DateTime.now(), "Bob", "Fly Here", "Fly Here",
        1283, 1284, null, null, null
    );
    expect(model1 == model2, true);

    FlightLogItem model3 = FlightLogItem("ID123",
        DateTime.now(), "Anna", "Fly Berlin", "Fly Away",
        1283, 1284, null, null, "NOTES"
    );
    FlightLogItem model4 = FlightLogItem("ID124",
        DateTime.now(), "Bob", "Fly Here", "Fly Here",
        1283, 1284, null, null, null
    );
    expect(model3 == model4, false);
  });
}
