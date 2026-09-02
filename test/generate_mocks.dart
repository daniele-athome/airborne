import 'dart:io';

import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/helpers/script_client.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:airborne/services/book_flight_services.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:airborne/services/metadata_services.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks(
  [
    GoogleCalendarService,
    GoogleServiceAccountService,
    GoogleSheetsService,
    ScriptClient,
    MetadataService,
    DownloadProvider,
    AppConfig,
    BookFlightCalendarService,
    FlightLogBookService,
    HttpClient,
  ],
  customMocks: [
    MockSpec<NavigatorObserver>(onMissingStub: OnMissingStub.returnDefault),
  ],
)
void main() {}
