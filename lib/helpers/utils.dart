import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sunrise_sunset_calc/sunrise_sunset_calc.dart';
import 'package:timezone/timezone.dart';

String getExceptionMessage(error) {
  if (error is LocationNotFoundException) {
    return error.msg;
  }
  else if (error is SocketException) {
    return (error.osError?.message)?? "unknown";
  }
  else {
    return error.message;
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
  // WARNING very VERY slow library, but the other (faster) one is buggy
  final times = getSunriseSunset(latitude, longitude,
      tzLocation.timeZone(dateTime.millisecondsSinceEpoch).offset / 1000 / 60 ~/ 60,
      dateTime);
  return SunTimes(
      TZDateTime.from(times.sunrise, tzLocation),
      TZDateTime.from(times.sunset, tzLocation)
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
    gravity: ToastGravity.BOTTOM,
  );
}

Future<File> downloadToFile(String url, String filename, String? username, String? password, bool temp) async {
  final uri = Uri.parse(url);
  HttpClient httpClient = new HttpClient();
  if (username != null && password != null) {
    httpClient.addCredentials(
        uri, "", HttpClientBasicCredentials(username, password));
  }
  var request = await httpClient.getUrl(uri);
  var response = await request.close();
  if (response.statusCode == 200) {
    final directory = await (temp ? getTemporaryDirectory() : getApplicationSupportDirectory());
    final file = File(directory.path + '/' + filename);
    print('downloading to ' + file.toString());
    return response
        .pipe(file.openWrite())
        .then((value) => file);
  }
  else {
    return Future.error(Exception('Download error (' + response.statusCode.toString() + ')'));
  }
}
