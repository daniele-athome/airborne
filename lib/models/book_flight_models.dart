import 'package:timezone/timezone.dart';

class FlightBooking {
  FlightBooking(this.id, this.pilotName, this.from, this.to, this.notes);

  /// If null, it's a new event.
  String? id;
  String pilotName;
  TZDateTime from;
  TZDateTime to;
  String? notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FlightBooking &&
              id == other.id;

  @override
  int get hashCode => id?.hashCode?? 0;

  bool equals(FlightBooking other) =>
      identical(this, other) ||
          (id == other.id &&
              pilotName == other.pilotName &&
              from == other.from &&
              to == other.to &&
              notes == other.notes);

  @override
  String toString() {
    return 'FlightBooking{pilotName: $pilotName, from: $from, to: $to, notes: $notes}';
  }

}

class DeletedFlightBooking extends FlightBooking {
  static TZDateTime _dummy = TZDateTime.now(UTC);

  // FIXME this _dummy stuff is not nice
  DeletedFlightBooking(String id) : super(id, "", _dummy, _dummy, null);
}
