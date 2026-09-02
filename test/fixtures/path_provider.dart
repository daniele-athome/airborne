import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// A [PathProviderPlatform] rooted at a throwaway directory, so tests can use
/// the real filesystem without touching the developer's app data.
class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform()
    : baseDir = Directory.systemTemp.createTempSync('airborne_test_').path;

  /// Root of every path handed out by this instance.
  final String baseDir;

  @override
  Future<String?> getTemporaryPath() async => path.join(baseDir, 'temp');

  @override
  Future<String?> getApplicationSupportPath() async =>
      path.join(baseDir, 'appdata');

  @override
  Future<String?> getApplicationCachePath() async =>
      path.join(baseDir, 'cache');

  @override
  Future<String?> getLibraryPath() async => path.join(baseDir, 'lib');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      path.join(baseDir, 'docs');

  @override
  Future<String?> getExternalStoragePath() async => path.join(baseDir, 'ext');

  @override
  Future<List<String>?> getExternalCachePaths() async => [];

  @override
  Future<String?> getDownloadsPath() async => path.join(baseDir, 'download');
}

/// The fake installed by [useFakePathProvider].
FakePathProviderPlatform get fakePathProvider =>
    PathProviderPlatform.instance as FakePathProviderPlatform;

/// Installs a fresh [FakePathProviderPlatform] before each test of the
/// enclosing group and wipes its directory afterwards.
void useFakePathProvider() {
  late PathProviderPlatform previous;

  setUp(() {
    previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform();
  });

  tearDown(() {
    final directory = Directory(fakePathProvider.baseDir);
    PathProviderPlatform.instance = previous;
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
}
