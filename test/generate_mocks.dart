import 'dart:io';

import 'package:airborne/helpers/config.dart';
import 'package:airborne/helpers/googleapis.dart';
import 'package:airborne/helpers/utils.dart';
import 'package:airborne/services/flight_log_services.dart';
import 'package:airborne/services/metadata_services.dart';
import 'package:flutter/widgets.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks(
  [
    GoogleCalendarService,
    GoogleServiceAccountService,
    GoogleSheetsService,
    MetadataService,
    DownloadProvider,
    AppConfig,
    FlightLogBookService,
    HttpClient,
  ],
  customMocks: [
    MockSpec<NavigatorObserver>(onMissingStub: OnMissingStub.returnDefault),
  ],
)
void main() {}
