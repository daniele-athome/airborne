import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/helpers/script_client.dart';
import 'package:airborne/models/flight_log_models.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as gapi_sheets;
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';

import '../generate_mocks.mocks.dart';

void main() {
  late MockGoogleSheetsService mockSheetsService;
  late MockMetadataService mockMetadataService;
  late MockScriptClient mockScriptClient;
  late FlightLogBookService testService;
  final datetimeFormatter = DateFormat('yyyy-MM-dd HH:mm:SS');

  setUp(() {
    mockScriptClient = MockScriptClient();
    mockSheetsService = MockGoogleSheetsService();
    mockMetadataService = MockMetadataService();
    testService = FlightLogBookService(
      MockGoogleServiceAccountService(),
      mockMetadataService,
      {
        'spreadsheet_id': 'TEST',
        'sheet_name': 'SHEET',
        'script_url': 'URL',
        'script_token': 'TOKEN',
      },
      mockScriptClient,
    );
    testService.client = mockSheetsService;
  });
  tearDown(() {});

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
        null,
        null,
        null,
        '1',
      ],
      [
        datetimeFormatter.format(timestamp),
        dateToGsheets(timestamp).toInt(),
        'Anna',
        2000,
        3000,
        'Fly Start',
        'Fly End',
        null,
        null,
        null,
        '2',
      ],
    ];
    final fakeRows = gapi_sheets.ValueRange(
      majorDimension: 'DIMENSION_UNSPECIFIED',
      range: 'A2:J11',
      values: rows,
    );
    when(
      mockSheetsService.getRows('TEST', 'SHEET', 'A2:K3'),
    ).thenAnswer((_) => Future.value(fakeRows));
    when(
      mockMetadataService.reload(),
    ).thenAnswer((_) => Future.value(<String, String>{}));
    when(mockMetadataService.get(any)).thenAnswer((_) => Future.value(null));

    final dateOnly = DateTime.utc(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );
    final expectedItems = [
      FlightLogItem(
        '1',
        dateOnly,
        'Anna',
        'Fly Departure',
        'Fly Arrival',
        1000,
        2000,
        null,
        null,
        null,
      ),
      FlightLogItem(
        '2',
        dateOnly,
        'Anna',
        'Fly Start',
        'Fly End',
        2000,
        3000,
        null,
        null,
        null,
      ),
    ];
    expect(await testService.fetchItems(), expectedItems);
    expect(testService.lastId, 0);
  });
  // TODO test('fetch items (multiple pages)', ...);

  test('create item', () async {
    final timestamp = DateTime.now();
    final fakeAppended = ScriptResult(id: 'NEW_ID', replayed: false);
    when(
      mockScriptClient.invoke(
        action: argThat(equals('flight-log/insert'), named: 'action'),
        requestId: anyNamed('requestId'),
        payload: anyNamed('payload'),
      ),
    ).thenAnswer((_) => Future.value(fakeAppended));

    // flight log only uses reload, no get call
    var metadataCallCount = 0;
    when(mockMetadataService.reload()).thenAnswer((_) {
      metadataCallCount++;
      return Future.value(<String, String>{
        'flight_log.count': '0',
        'flight_log.hash': (metadataCallCount < 2) ? '0' : '1',
      });
    });

    testService.dataHash = '0';

    final dateOnly = DateTime.utc(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );
    final fakeItem = FlightLogItem(
      'NEW_ID',
      dateOnly,
      'Anna',
      'Fly Departure',
      'Fly Arrival',
      1000,
      2000,
      null,
      null,
      null,
    );
    // TODO for now the input item is returned...
    final expectedItem = fakeItem;
    expect(await testService.appendItem(fakeItem), expectedItem);
  });

  test('update item', () async {
    final timestamp = DateTime.now();
    final fakeAppended = ScriptResult(id: 'OLD_ID', replayed: false);
    when(
      mockScriptClient.invoke(
        action: argThat(equals('flight-log/update'), named: 'action'),
        requestId: anyNamed('requestId'),
        payload: anyNamed('payload'),
      ),
    ).thenAnswer((_) => Future.value(fakeAppended));

    // flight log only uses reload, no get call
    var metadataCallCount = 0;
    when(mockMetadataService.reload()).thenAnswer((_) {
      metadataCallCount++;
      return Future.value(<String, String>{
        'flight_log.count': '0',
        'flight_log.hash': (metadataCallCount < 2) ? '0' : '1',
      });
    });

    testService.dataHash = '0';

    final dateOnly = DateTime.utc(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );
    final fakeItem = FlightLogItem(
      'OLD_ID',
      dateOnly,
      'Anna',
      'Fly Departure',
      'Fly Arrival',
      1000,
      2000,
      null,
      null,
      null,
    );
    // TODO for now the input item is returned...
    final expectedItem = fakeItem;
    expect(await testService.updateItem(fakeItem.id!, fakeItem), expectedItem);
  });

  test('delete item', () async {
    final timestamp = DateTime.now();
    final fakeAppended = ScriptResult(id: 'REMOVED_ID', replayed: false);
    when(
      mockScriptClient.invoke(
        action: argThat(equals('flight-log/delete'), named: 'action'),
        requestId: anyNamed('requestId'),
        payload: anyNamed('payload'),
      ),
    ).thenAnswer((_) => Future.value(fakeAppended));

    // flight log only uses reload, no get call
    var metadataCallCount = 0;
    when(mockMetadataService.reload()).thenAnswer((_) {
      metadataCallCount++;
      return Future.value(<String, String>{
        'flight_log.count': '0',
        'flight_log.hash': (metadataCallCount < 2) ? '0' : '1',
      });
    });

    testService.dataHash = '0';

    final dateOnly = DateTime.utc(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );
    final fakeItem = FlightLogItem(
      'REMOVED_ID',
      dateOnly,
      'Anna',
      'Fly Departure',
      'Fly Arrival',
      1000,
      2000,
      null,
      null,
      null,
    );
    expect(await testService.deleteItem(fakeItem.id!), 'REMOVED_ID');
  });
}
