import 'dart:io';

// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// True only in a build made for a benchmark harness, with
/// `--dart-define=MANGATAN_PERF_HARNESS=true`.
///
/// In every other build this is false and [applyBenchmarkDataRoot] compiles to
/// nothing, so the app's storage locations are untouched.
const bool kBenchmarkHarness = bool.fromEnvironment('MANGATAN_PERF_HARNESS');

/// The environment variable naming the throwaway folder a harness build uses
/// for all of its data.
const benchmarkDataRootVariable = 'MANGATAN_PERF_ROOT';

/// In a benchmark harness build, points every path_provider directory of the
/// current isolate at the throwaway folder named by [benchmarkDataRootVariable].
///
/// The app runs the real startup in a harness build, including worker
/// isolates that open the database themselves. Each isolate has its own
/// path_provider, so this runs wherever the app first asks for storage (see
/// `StorageProvider`). A harness build without the folder refuses to start
/// rather than fall back to the user's real data.
void applyBenchmarkDataRoot() {
  if (!kBenchmarkHarness) return;
  if (PathProviderPlatform.instance is BenchmarkPathProvider) return;
  final root = Platform.environment[benchmarkDataRootVariable] ?? '';
  if (root.isEmpty) {
    throw StateError(
      'A benchmark harness build needs $benchmarkDataRootVariable to be set.',
    );
  }
  PathProviderPlatform.instance = BenchmarkPathProvider(root);
}

/// Places every path_provider directory under [root].
class BenchmarkPathProvider extends PathProviderPlatform {
  BenchmarkPathProvider(this.root);
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
