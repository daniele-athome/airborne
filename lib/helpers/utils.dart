import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:solar_calculator/solar_calculator.dart';
import 'package:timezone/timezone.dart';
import 'package:url_launcher/url_launcher.dart';

/// Network request timeout used throughout the app.
const Duration kNetworkRequestTimeout = Duration(seconds: 15);

/// https://github.com/flutter/flutter/issues/6983
/// terrible hack (I'm not even handling the text size)
const double kPortraitToolbarHeight = kToolbarHeight;
/// per Material specs, toolbar in landscape should be 48dp
const double kLandscapeToolbarHeight = 48;

Brightness getBrightness(BuildContext context) => isCupertino(context) ?
    CupertinoTheme.brightnessOf(context) : Theme.of(context).brightness;

Color getModalBarrierColor(BuildContext context) => isCupertino(context) ?
  // from cupertino/dialog.dart:_kDialogColor
  const CupertinoDynamicColor.withBrightness(
    color: Color(0xCCF2F2F2),
    darkColor: Color(0xBF1E1E1E),
  ).resolveFrom(context) :
  Colors.black54;

String getExceptionMessage(dynamic error) {
  if (error is LocationNotFoundException) {
    return error.msg;
  }
  else if (error is SocketException) {
    return (error.osError?.message)?? "unknown";
  }
  else {
    return error.message.toString();
  }
}

class SunTimes {
  final TZDateTime sunrise;
  final TZDateTime sunset;
  SunTimes(this.sunrise, this.sunset);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SunTimes &&
              sunrise == other.sunrise &&
              sunset == other.sunset;

  @override
  int get hashCode => sunrise.hashCode ^ sunset.hashCode;

}

SunTimes getSunTimes(double latitude, double longitude, DateTime dateTime, Location tzLocation) {
  final instant = Instant(
    year: dateTime.year,
    month: dateTime.month,
    day: dateTime.day,
    timeZoneOffset: tzLocation.timeZone(dateTime.millisecondsSinceEpoch).offset / 1000 / 60 / 60
  );
  final times = SolarCalculator(instant, latitude, longitude);
  return SunTimes(
      TZDateTime.from(times.sunriseTime.toUtcDateTime(), tzLocation),
      TZDateTime.from(times.sunsetTime.toUtcDateTime(), tzLocation)
  );
}

void showToast(FToast fToast, String text, Duration duration) {
  fToast.showToast(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        // TODO hard-coded color
        color: Colors.greenAccent,
      ),
      child: Text(text),
    ),
    toastDuration: duration,
    positionedToastBuilder: (context, child) => Positioned(
      bottom: 50.0 * MediaQuery.of(context).devicePixelRatio + 50.0,
      left: 24.0,
      right: 24.0,
      child: child
    ),
  );
}

Future<void> showError(BuildContext context, String text) {
  return showPlatformDialog<void>(
    context: context,
    builder: (_context) => PlatformAlertDialog(
      title: Text(AppLocalizations.of(context)!.dialog_title_error),
      content: Text(text),
      actions: <Widget>[
        PlatformDialogAction(
          onPressed: () {
            Navigator.pop(_context);
          },
          child: Text(AppLocalizations.of(context)!.dialog_button_ok),
        ),
      ],
    ),
  );
}

Future<bool> openUrl(BuildContext context, String url) async {
  return launch(url)
    .catchError((_) {
      // TODO i18n
      showError(context, 'Cannot open a browser.');
      return false;
  });
}

Future<T?> showConfirm<T>({
  required BuildContext context,
  required String text,
  required String title,
  required void Function() okCallback,
  bool destructiveOk = false
}) {
  return showPlatformDialog<T>(
    context: context,
    builder: (_context) => PlatformAlertDialog(
      title: Text(title),
      content: Text(text),
      actions: <Widget>[
        PlatformDialogAction(
          onPressed: () => Navigator.pop(_context),
          child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
        ),
        PlatformDialogAction(
          onPressed: () {
            Navigator.pop(_context);
            okCallback();
          },
          // TODO destructiveOk for material
          cupertino: (_, __) => CupertinoDialogActionData(isDestructiveAction: destructiveOk),
          child: Text(AppLocalizations.of(context)!.dialog_button_ok),
        ),
      ],
    ),
  );
}

Future<File> downloadToFile(String url, String filename, String? username, String? password, bool temp) async {
  final uri = Uri.parse(url);
  final HttpClient httpClient = HttpClient();
  if (username != null && password != null) {
    httpClient.addCredentials(
        uri, "", HttpClientBasicCredentials(username, password));
  }
  final request = await httpClient.getUrl(uri);
  final response = await request.close();
  if (response.statusCode == 200) {
    final directory = await (temp ? getTemporaryDirectory() : getApplicationSupportDirectory());
    final file = File(path.join(directory.path, filename));
    return response
        .pipe(file.openWrite())
        .then((value) => file);
  }
  else {
    return Future.error(Exception('Download error (${response.statusCode})'));
  }
}

/// A basic controller for date and time pickers.
class DateTimePickerController extends ValueNotifier<DateTime?> {
  DateTimePickerController(DateTime? value) : super(value);
}
