import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Points every path_provider directory at a folder under [root], so a
/// benchmark never reads or writes the app's real data.
class TempPathProvider extends PathProviderPlatform {
  TempPathProvider(this.root);
  final String root;

  String _dir(String name) {
    final dir = Directory('$root/$name')..createSync(recursive: true);
    return dir.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir('documents');
  @override
  Future<String?> getApplicationSupportPath() async => _dir('support');
  @override
  Future<String?> getApplicationCachePath() async => _dir('cache');
  @override
  Future<String?> getTemporaryPath() async => _dir('tmp');
  @override
  Future<String?> getLibraryPath() async => _dir('library');
  @override
  Future<String?> getDownloadsPath() async => _dir('downloads');
}
