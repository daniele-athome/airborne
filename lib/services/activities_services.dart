import '../helpers/googleapis.dart';
import '../models/activities_models.dart';
import 'base_sheets_services.dart';
import 'metadata_services.dart';

/// A primitive way to abstract the real activities service.
class ActivitiesService extends GoogleSheetsStoreService<ActivityEntry> {
  ActivitiesService(GoogleServiceAccountService accountService,
      MetadataService? metadataService, Map<String, String> properties)
      : super(
            accountService: accountService,
            metadataService: metadataService,
            spreadsheetId: properties['spreadsheet_id']!,
            sheetName: properties['sheet_name']!);

  @override
  String getMetadataPrefixKey() => 'activities';

  @override
  ActivityEntry buildItem(String rowId, List<Object?> rowData) => ActivityEntry(
        id: rowId,
        creationDate: dateFromGsheets((rowData[1] as int).toDouble()),
        type: ActivityType.fromCode(rowData[2] as int),
        status: rowData[3] is String && (rowData[3] as String).isNotEmpty
            ? ActivityStatus.fromLabel(rowData[3] as String)
            : null,
        dueDate: rowData[4] is int
            ? dateFromGsheets((rowData[4] as int).toDouble())
            : null,
        author: rowData[5] as String,
        summary: rowData[6] as String,
        description: rowData.length > 7 &&
                rowData[7] is String &&
                (rowData[7] as String).isNotEmpty
            ? rowData[7] as String
            : null,
        // TODO alert:
      );

  @override
  int getColumnCount() => 9;

  @override
  List<Object?> buildRowData(ActivityEntry item) => throw UnimplementedError();
}
