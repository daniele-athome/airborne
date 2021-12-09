
class FlightLogItem {
  FlightLogItem(
    this.id,
    this.date,
    this.pilotName,
    this.origin,
    this.destination,
    this.startHour,
    this.endHour,
    this.fuel,
    this.fuelPrice,
    this.notes,
  );

  String? id;
  DateTime date;
  String pilotName;
  String origin;
  String destination;
  num startHour;
  num endHour;
  int? fuel;
  num? fuelPrice;
  String? notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is FlightLogItem &&
              id == other.id;

  @override
  int get hashCode => id?.hashCode?? 0;

  @override
  String toString() {
    return 'FlightLogItem{date: $date, pilot: $pilotName, destination: $destination, startHour: $startHour, endHour: $endHour}';
  }

}

class DeletedFlightLogItem extends FlightLogItem {
  static final DateTime _dummy = DateTime.now();

  // FIXME this _dummy stuff is not nice
  DeletedFlightLogItem(String id) : super(id, _dummy, "", "", "", 0, 0, null, null, null);
}
