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
    this.notes, {
    this.fingerprint,
  });

  /// Flight ID, assigned by the backend and stable for the life of the entry.
  String? id;

  /// Precondition token for editing, as received from the backend.
  ///
  /// Opaque: it is stored and echoed back, never parsed or compared, and it
  /// deliberately takes no part in equality — the same entry with fresher
  /// content is still the same entry as far as list diffing is concerned.
  String? fingerprint;
  DateTime date;
  String pilotName;
  String origin;
  String destination;
  num startHour;
  num endHour;
  num? fuel;
  num? fuelPrice;
  String? notes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FlightLogItem && id == other.id;

  @override
  int get hashCode => id?.hashCode ?? 0;

  @override
  String toString() {
    return 'FlightLogItem{date: $date, pilot: $pilotName, destination: $destination, startHour: $startHour, endHour: $endHour}';
  }
}

/// A dummy [FlightLogItem] that represents a deletion.
class DeletedFlightLogItem extends FlightLogItem {
  static final DateTime _dummy = DateTime.now();

  // FIXME this _dummy stuff is not nice
  DeletedFlightLogItem(String id)
    : super(id, _dummy, "", "", "", 0, 0, null, null, null);
}
