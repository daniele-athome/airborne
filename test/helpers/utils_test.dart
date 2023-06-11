import 'dart:io';

import 'package:airborne/helpers/utils.dart';
import 'package:test/test.dart';
import 'package:timezone/timezone.dart';

void main() {
  test('getExceptionMessage', () {
    expect(getExceptionMessage(Exception("test message")), "test message");
    const osError = OSError("os error message");
    expect(
        getExceptionMessage(const SocketException("ciaone", osError: osError)),
        "os error message");
    expect(getExceptionMessage(const SocketException("ciaone")), "ciaone");
  });

  test('getSunTimes', () {
    setLocalLocation(UTC);
    expect(
        getSunTimes(0, 0, DateTime.utc(2020), UTC),
        SunTimes(TZDateTime.parse(UTC, "2020-01-01 05:59:35.000Z"),
            TZDateTime.parse(UTC, "2020-01-01 18:07:03.000Z")));
  });
}
