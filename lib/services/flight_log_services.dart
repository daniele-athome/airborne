import 'package:intl/intl.dart';

import '../helpers/googleapis.dart';
import '../models/flight_log_models.dart';
import 'base_sheets_services.dart';
import 'metadata_services.dart';

/// Flight date formatter
final _kDateFormatter = DateFormat('yyyy-MM-dd');

/// A primitive way to abstract the real log book service.
class FlightLogBookService extends GoogleAppsScriptStoreService<FlightLogItem> {
  FlightLogBookService(
    GoogleServiceAccountService accountService,
    MetadataService? metadataService,
    Map<String, String> properties,
  ) : super(
        accountService: accountService,
        metadataService: metadataService,
        spreadsheetId: properties['spreadsheet_id']!,
        sheetName: properties['sheet_name']!,
        scriptUrl: properties['script_url']!,
        scriptToken: properties['script_token']!,
      );

  @override
  String getMetadataPrefixKey() => 'flight_log';

  @override
  FlightLogItem buildItem(String rowId, List<Object?> rowData) => FlightLogItem(
    // item ID is a 1-based ordinal - we don't use it though
    rowData[10] as String,
    dateFromGsheets((rowData[1] as int).toDouble()),
    rowData[2] as String,
    rowData[5] as String,
    rowData[6] as String,
    rowData[3] as num,
    rowData[4] as num,
    rowData[7] is num ? rowData[7] as num : null,
    rowData[8] is num ? rowData[8] as num : null,
    rowData[9] is String && (rowData[9] as String).isNotEmpty
        ? rowData[9] as String?
        : null,
  );

  @override
  int getColumnCount() => 11;

  @override
  Map<String, dynamic> buildRowData(FlightLogItem item) => {
    'date': _kDateFormatter.format(item.date),
    'pilotName': item.pilotName,
    'startHour': item.startHour,
    'endHour': item.endHour,
    'origin': item.origin,
    'destination': item.destination,
    'fuel': item.fuel,
    'fuelPrice': item.fuelPrice,
    'notes': item.notes,
  };

  @override
  FlightLogItem newItem(FlightLogItem item, String newId) {
    return FlightLogItem.from(item, newId);
  }
}
