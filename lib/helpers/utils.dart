import 'dart:io';
import 'dart:math' as math;

import 'package:airborne/helpers/cupertinoplus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:solar_calculator/solar_calculator.dart';
import 'package:timezone/timezone.dart';
import 'package:url_launcher/url_launcher.dart';

/// Time format for aviation use (i.e. no am/pm)
const String kAviationTimeFormat = 'HH:mm';
/// Hour format for aviation use (i.e. no am/pm)
const String kAviationHourFormat = 'HH';

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
    return (error.osError?.message)?? error.message;
  }
  else {
    try {
      return error.message.toString();
    }
    on NoSuchMethodError catch (_) {
      return error.toString();
    }
  }
}

extension NumberFormatTryParse on NumberFormat {
  num? tryParse(String text) {
    try {
      return parse(text);
    }
    on FormatException catch (_) {
      return null;
    }
  }
}

double roundDouble(num value, int places) {
  num mod = math.pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
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
    builder: (dialogContext) => PlatformAlertDialog(
      title: Text(AppLocalizations.of(context)!.dialog_title_error),
      content: Text(text),
      actions: <Widget>[
        PlatformDialogAction(
          onPressed: () {
            Navigator.pop(dialogContext);
          },
          child: Text(AppLocalizations.of(context)!.dialog_button_ok),
        ),
      ],
    ),
  );
}

Future<bool> openUrl(BuildContext context, String url) async {
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
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
    builder: (dialogContext) => PlatformAlertDialog(
      title: Text(title),
      content: Text(text),
      actions: <Widget>[
        PlatformDialogAction(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizations.of(context)!.dialog_button_cancel),
        ),
        PlatformDialogAction(
          onPressed: () {
            Navigator.pop(dialogContext);
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

class DownloadProvider extends ChangeNotifier {
  DownloadProvider(this.clientBuilder);

  /// FIXME doesn't work on web platform (we should use http package)
  final HttpClient Function() clientBuilder;

  Future<File> downloadToFile(String url, String filename, String? username, String? password, bool temp) async {
    final uri = Uri.parse(url);
    HttpClient client = clientBuilder();
    client.findProxy = HttpClient.findProxyFromEnvironment;
    if (username != null && password != null) {
      client.addCredentials(uri, "", HttpClientBasicCredentials(username, password));
    }
    final request = await client.getUrl(uri);
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
}

/// A basic controller for date and time pickers.
class DateTimePickerController extends ValueNotifier<DateTime?> {
  DateTimePickerController(DateTime? value) : super(value);
}

/// Basic layout for indicating that an exception occurred.
/// Forked from [infinite\_scroll\_pagination].
class FirstPageExceptionIndicator extends StatelessWidget {
  const FirstPageExceptionIndicator({
    required this.title,
    this.message,
    this.onTryAgain,
    Key? key,
  }) : super(key: key);

  final String title;
  final String? message;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: isCupertino(context) ?
                CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle :
                Theme.of(context).textTheme.headline6,
            ),
            if (message != null)
              const SizedBox(
                height: 16,
              ),
            if (message != null)
              Text(
                message,
                textAlign: TextAlign.center,
                style: isCupertino(context) ?
                  CupertinoTheme.of(context).textTheme.textStyle :
                  Theme.of(context).textTheme.bodyText2,
              ),
            if (onTryAgain != null)
              const SizedBox(
                height: 48,
              ),
            if (onTryAgain != null)
              SizedBox(
                height: 50,
                width: double.infinity,
                child: isCupertino(context) ?
                  CupertinoButton.filled(
                    onPressed: onTryAgain,
                    child: Text(
                      AppLocalizations.of(context)!.flightLog_button_error_retry,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ) :
                  ElevatedButton.icon(
                    onPressed: onTryAgain,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.flightLog_button_error_retry,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Forked from [infinite\_scroll\_pagination].
class FooterTile extends StatelessWidget {
  const FooterTile({
    required this.child,
    Key? key,
  }) : super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: 16,
      bottom: 16,
    ),
    child: Center(child: child),
  );
}

/// Forked from [infinite\_scroll\_pagination].
class NewPageErrorIndicator extends StatelessWidget {
  const NewPageErrorIndicator({
    Key? key,
    required this.message,
    this.onTap,
  }) : super(key: key);
  final String message;
  final VoidCallback? onTap;

  Widget _buildChildWidget(BuildContext context) {
    return FooterTile(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: isCupertino(context) ?
              CupertinoTheme.of(context).textTheme.navActionTextStyle :
              Theme.of(context).textTheme.bodyText2,
          ),
          const SizedBox(
            height: 4,
          ),
          const Icon(
            Icons.refresh,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCupertinoWidget(BuildContext context) =>
    CupertinoInkWell(
      onPressed: onTap,
      child: _buildChildWidget(context),
    );

  Widget _buildMaterialWidget(BuildContext context) =>
    InkWell(
      onTap: onTap,
      child: _buildChildWidget(context),
    );

  @override
  Widget build(BuildContext context) => isCupertino(context) ?
    _buildCupertinoWidget(context) : _buildMaterialWidget(context);
}
