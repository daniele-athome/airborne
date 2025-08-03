import 'package:intl/intl.dart';

import '../helpers/googleapis.dart';
import '../models/flight_log_models.dart';
import 'base_sheets_services.dart';
import 'metadata_services.dart';

/// Flight date formatter
final _kDateFormatter = DateFormat('yyyy-MM-dd');

/// A primitive way to abstract the real log book service.
class FlightLogBookService extends GoogleSheetsStoreService<FlightLogItem> {
  FlightLogBookService(GoogleServiceAccountService accountService,
      MetadataService? metadataService, Map<String, String> properties)
      : super(
            accountService: accountService,
            metadataService: metadataService,
            spreadsheetId: properties['spreadsheet_id']!,
            sheetName: properties['sheet_name']!);

  @override
  String getMetadataPrefixKey() => 'flight_log';

  @override
  FlightLogItem buildItem(String rowId, List<Object?> rowData) => FlightLogItem(
        // item ID is a 1-based ordinal
        rowId,
        dateFromGsheets((rowData[1] as int).toDouble()),
        rowData[2] as String,
        rowData[5] as String,
        rowData[6] as String,
        rowData[3] as num,
        rowData[4] as num,
        rowData.length > 7 && rowData[7] is num ? rowData[7] as num : null,
        rowData.length > 8 && rowData[8] is num ? rowData[8] as num : null,
        rowData.length > 9 &&
                rowData[9] is String &&
                (rowData[9] as String).isNotEmpty
            ? rowData[9] as String?
            : null,
      );

  @override
  int getColumnCount() => 10;

  @override
  List<Object?> buildRowData(FlightLogItem item) => [
        dateToGsheets(DateTime.now()),
        _kDateFormatter.format(item.date),
        item.pilotName,
        item.startHour,
        item.endHour,
        item.origin,
        item.destination,
        item.fuel ?? '',
        item.fuel != null ? item.fuelPrice : '',
        item.notes ?? '',
      ];
}

/// Exception thrown when the hash of the flight log has changed.
class DataChangedException implements Exception {
  const DataChangedException();
}
