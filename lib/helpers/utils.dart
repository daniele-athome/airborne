import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:solar_calculator/solar_calculator.dart';
import 'package:timezone/timezone.dart';

const double kPortraitToolbarHeight = kToolbarHeight;
// per Material specs, toolbar in landscape should be 48dp
const double kLandscapeToolbarHeight = 48;

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
