
import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:googleapis/sheets/v4.dart' as gapi_sheets;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'flight_log_services_test.mocks.dart';

@GenerateMocks([GoogleSheetsService, GoogleServiceAccountService])
void main() {
  late MockGoogleSheetsService mockSheetsService;
  late FlightLogBookService testService;
  final datetimeFormatter = DateFormat('yyyy-MM-dd HH:mm:SS');

  setUp(() {
    mockSheetsService = MockGoogleSheetsService();
    testService = FlightLogBookService(MockGoogleServiceAccountService(), {
      'spreadsheet_id': 'TEST',
      'sheet_name': 'SHEET',
    });
    testService.client = mockSheetsService;
  });
  tearDown(() {
  });

  test('fetch items (single page)', () async {
    testService.lastId = 2;
    final timestamp = DateTime.now();
    final rows = [
      [
        datetimeFormatter.format(timestamp),
        dateToGsheets(timestamp).toInt(),
        'Anna',
        1000,
        2000,
        'Fly Departure',
        'Fly Arrival',
      ],
      [
        datetimeFormatter.format(timestamp),
        dateToGsheets(timestamp).toInt(),
        'Anna',
        2000,
        3000,
        'Fly Start',
        'Fly End',
      ],
    ];
    final fakeRows = gapi_sheets.ValueRange(
      majorDimension: 'DIMENSION_UNSPECIFIED',
      range: 'A2:J11',
      values: rows,
    );
    when(mockSheetsService.getRows('TEST', 'SHEET', 'A2:J3'))
        .thenAnswer((_) => Future.value(fakeRows));

    final dateOnly = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
    final expectedItems = [
      FlightLogItem('1', dateOnly, 'Anna', 'Fly Departure', 'Fly Arrival', 1000, 2000, null, null, null),
      FlightLogItem('2', dateOnly, 'Anna', 'Fly Start', 'Fly End', 2000, 3000, null, null, null),
    ];
    expect(await testService.fetchItems(), expectedItems);
    expect(testService.lastId, 0);
  });
  // TODO test('fetch items (multiple pages)', ...);

  test('create item', () async {
    final timestamp = DateTime.now();
    final fakeAppended = gapi_sheets.AppendValuesResponse(
      spreadsheetId: 'TEST!SHEET',
      tableRange: 'A2:J2',
      // TODO other values one day...?
    );
    when(mockSheetsService.appendRows('TEST', 'SHEET', 'A:J', any))
      .thenAnswer((_) => Future.value(fakeAppended));

    final dateOnly = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
    final fakeItem = FlightLogItem(null, dateOnly, 'Anna', 'Fly Departure', 'Fly Arrival', 1000, 2000, null, null, null);
    // TODO for now the input item is returned...
    final expectedItem = fakeItem;
    expect(await testService.appendItem(fakeItem), expectedItem);
  });

  test('update item', () async {
    final timestamp = DateTime.now();
    final fakeAppended = gapi_sheets.UpdateValuesResponse(
      spreadsheetId: 'TEST!SHEET',
      updatedRange: 'A2:J2',
      // TODO other values one day...?
    );
    when(mockSheetsService.updateRows('TEST', 'SHEET', 'A2:J2', any))
      .thenAnswer((_) => Future.value(fakeAppended));

    final dateOnly = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
    final fakeItem = FlightLogItem('1', dateOnly, 'Anna', 'Fly Departure', 'Fly Arrival', 1000, 2000, null, null, null);
    // TODO for now the input item is returned...
    final expectedItem = fakeItem;
    expect(await testService.updateItem(fakeItem), expectedItem);
  });

  test('delete item', () async {
    final timestamp = DateTime.now();
    final fakeAppended = gapi_sheets.BatchUpdateSpreadsheetResponse(
      spreadsheetId: 'TEST!SHEET',
      replies: [
        gapi_sheets.Response(
          // TODO what here?
          deleteDimensionGroup: gapi_sheets.DeleteDimensionGroupResponse(),
        )
      ]
      // TODO other values one day...?
    );
    when(mockSheetsService.deleteRows('TEST', 'SHEET', 2, 2))
      .thenAnswer((_) => Future.value(fakeAppended));

    final dateOnly = DateTime.utc(timestamp.year, timestamp.month, timestamp.day);
    final fakeItem = FlightLogItem('1', dateOnly, 'Anna', 'Fly Departure', 'Fly Arrival', 1000, 2000, null, null, null);
    final expectedItem = DeletedFlightLogItem('1');
    expect(await testService.deleteItem(fakeItem), expectedItem);
  });
}
