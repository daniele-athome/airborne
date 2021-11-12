
class FlightLogItem {
  FlightLogItem(
    this.id,
    this.date,
    this.pilot,
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
  String pilot;
  String origin;
  String destination;
  int startHour;
  int endHour;
  int fuel;
  double fuelPrice;
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
    return 'FlightLogItem{date: $date, pilot: $pilot, destination: $destination, startHour: $startHour, endHour: $endHour}';
  }

}
