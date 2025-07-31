import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/services/metadata_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as gapi_sheets;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'metadata_services_test.mocks.dart';

@GenerateMocks([GoogleSheetsService, GoogleServiceAccountService])
void main() {
  late MockGoogleSheetsService mockSheetsService;
  late MockGoogleServiceAccountService mockAccountService;
  late MetadataService testService;

  setUp(() {
    mockSheetsService = MockGoogleSheetsService();
    mockAccountService = MockGoogleServiceAccountService();

    testService =
        MetadataService(mockAccountService, {'spreadsheet_id': 'test_id', 'sheet_name': 'test_sheet'});
    testService.client = mockSheetsService;
  });

  test('get() should return value from cache after first load', () async {
    final fakeRows = gapi_sheets.ValueRange(
      values: [
        ['key1', 'value1'],
        ['key2', 'value2'],
      ],
    );
    when(mockSheetsService.getRows('test_id', 'test_sheet', any))
        .thenAnswer((_) => Future.value(fakeRows));

    // First call, should fetch from sheets
    expect(await testService.get('key1'), 'value1');
    verify(mockSheetsService.getRows('test_id', 'test_sheet', any)).called(1);

    // Second call, should use cache
    expect(await testService.get('key2'), 'value2');
    verifyNever(mockSheetsService.getRows('test_id', 'test_sheet', any));
  });

  test('get() should return null for non-existent key', () async {
     final fakeRows = gapi_sheets.ValueRange(
      values: [
        ['key1', 'value1'],
      ],
    );
    when(mockSheetsService.getRows('test_id', 'test_sheet', any))
        .thenAnswer((_) => Future.value(fakeRows));

    expect(await testService.get('non_existent_key'), isNull);
  });

  test('reload() should fetch fresh data', () async {
    final fakeRows1 = gapi_sheets.ValueRange(
      values: [
        ['key1', 'value1'],
      ],
    );
    when(mockSheetsService.getRows('test_id', 'test_sheet', any))
        .thenAnswer((_) => Future.value(fakeRows1));

    expect(await testService.get('key1'), 'value1');
    verify(mockSheetsService.getRows('test_id', 'test_sheet', any)).called(1);

     final fakeRows2 = gapi_sheets.ValueRange(
      values: [
        ['key1', 'new_value'],
      ],
    );
    when(mockSheetsService.getRows('test_id', 'test_sheet', any))
        .thenAnswer((_) => Future.value(fakeRows2));

    final reloadedData = await testService.reload();
    expect(reloadedData['key1'], 'new_value');
    expect(await testService.get('key1'), 'new_value');
     verify(mockSheetsService.getRows('test_id', 'test_sheet', any)).called(1);
  });

  test('reload() should handle malformed rows', () async {
    final fakeRows = gapi_sheets.ValueRange(
      values: [
        ['key1', 'value1'],
        ['malformed_key'], // Malformed row
        ['key2', 'value2'],
      ],
    );
     when(mockSheetsService.getRows('test_id', 'test_sheet', any))
        .thenAnswer((_) => Future.value(fakeRows));

    final data = await testService.reload();
    expect(data.containsKey('key1'), isTrue);
    expect(data.containsKey('key2'), isTrue);
    expect(data.containsKey('malformed_key'), isFalse);
  });

    test('reload() should throw FormatException on no data', () async {
    final fakeRows = gapi_sheets.ValueRange(
      values: null, // No data
    );
     when(mockSheetsService.getRows('test_id', 'test_sheet', any))
        .thenAnswer((_) => Future.value(fakeRows));

    expect(testService.reload(), throwsA(isA<FormatException>()));
  });
}
