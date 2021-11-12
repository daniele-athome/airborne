
import '../helpers/googleapis.dart';

/// A primitive way to abstract the real log book service.
class FlightLogBookService {
  late final GoogleServiceAccountService _accountService;
  GoogleSheetsService? _client;

  FlightLogBookService(GoogleServiceAccountService accountService) {
    _accountService = accountService;
  }

  Future<GoogleSheetsService> _ensureService() {
    if (_client != null) {
      return Future.value(_client);
    }
    else {
      return _accountService.getAuthenticatedClient().then((client) {
        _client = GoogleSheetsService(client);
        return _client!;
      });
    }
  }

}
