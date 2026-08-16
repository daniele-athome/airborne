import 'package:intl/intl.dart';

import '../models/flight_log_models.dart';
import 'base_sheets_services.dart';

/// Flight date formatter
final _kDateFormatter = DateFormat('yyyy-MM-dd');

/// A primitive way to abstract the real log book service.
class FlightLogBookService extends RemoteStoreService<FlightLogItem> {
  FlightLogBookService(super.client);

  @override
  String get storeName => 'flight_log';

  @override
  FlightLogItem buildItem(Map<String, dynamic> data) => FlightLogItem(
    data['id'] as String?,
    DateTime.parse(data['date'] as String),
    data['pilotName'] as String,
    data['origin'] as String,
    data['destination'] as String,
    data['startHour'] as num,
    data['endHour'] as num,
    data['fuel'] as num?,
    data['fuelPrice'] as num?,
    data['notes'] as String?,
    fingerprint: data['fingerprint'] as String?,
  );

  /// The creation timestamp is filled by the backend, and the pilot name is
  /// taken from the token unless the caller is allowed to write someone else's.
  @override
  Map<String, dynamic> buildPayload(FlightLogItem item) => {
    'date': _kDateFormatter.format(item.date),
    'pilotName': item.pilotName,
    'startHour': item.startHour,
    'endHour': item.endHour,
    'origin': item.origin,
    'destination': item.destination,
    'fuel': item.fuel,
    'fuelPrice': item.fuel != null ? item.fuelPrice : null,
    'notes': item.notes,
  };

  @override
  String? fingerprintOf(FlightLogItem item) => item.fingerprint;

  @override
  String? idOf(FlightLogItem item) => item.id;
}
