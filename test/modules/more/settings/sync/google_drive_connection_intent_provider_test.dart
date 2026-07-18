import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/modules/more/settings/sync/providers/sync_providers.dart';
import 'package:mangayomi/services/sync/google_drive_connection_intent.dart';

void main() {
  late Directory databaseDirectory;
  late Isar database;
  late ProviderContainer container;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await _isarLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-drive-intent-',
    );
    database = await Isar.open(
      [SyncPreferenceSchema],
      directory: databaseDirectory.path,
      name: 'drive_connection_intent_test',
    );
    app.isar = database;
    database.writeTxnSync(
      () => database.syncPreferences.putSync(
        SyncPreference(
          syncId: 1,
          syncMode: SyncMode.chimahon,
          chimahonSyncProvider: ChimahonSyncProvider.googleDrive,
          googleDriveConnected: true,
        ),
      ),
    );
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test('automatic health disconnect does not cancel a queued Connect', () {
    final intent = container
        .read(synchingProvider(syncId: 1).notifier)
        .captureGoogleDriveConnectionIntent();

    // Token expiry and other health updates are not explicit user intent.
    container
        .read(synchingProvider(syncId: 1).notifier)
        .setGoogleDriveConnected(false);

    expect(
      () => container
          .read(synchingProvider(syncId: 1).notifier)
          .persistGoogleDriveConnectionIfIntentCurrent(
            intent: intent,
            mediaSelection: null,
          ),
      returnsNormally,
    );
    expect(database.syncPreferences.getSync(1)?.googleDriveConnected, isTrue);
  });

  test('mode away-and-back invalidates a queued Connect', () {
    final intent = _captureIntent(container);

    container
        .read(synchingProvider(syncId: 1).notifier)
        .setSyncMode(SyncMode.native);
    container
        .read(synchingProvider(syncId: 1).notifier)
        .setSyncMode(SyncMode.chimahon);

    expect(
      () => _persistIntent(container, intent),
      throwsA(isA<GoogleDriveConnectionIntentChangedException>()),
    );
  });

  test('provider away-and-back invalidates a queued Connect', () {
    final intent = _captureIntent(container);

    container
        .read(synchingProvider(syncId: 1).notifier)
        .setChimahonSyncProvider(ChimahonSyncProvider.syncYomi);
    container
        .read(synchingProvider(syncId: 1).notifier)
        .setChimahonSyncProvider(ChimahonSyncProvider.googleDrive);

    expect(
      () => _persistIntent(container, intent),
      throwsA(isA<GoogleDriveConnectionIntentChangedException>()),
    );
  });

  test('explicit disconnect intent invalidates a queued Connect', () {
    final intent = _captureIntent(container);

    container
        .read(synchingProvider(syncId: 1).notifier)
        .invalidateGoogleDriveConnectionIntent();

    expect(
      () => _persistIntent(container, intent),
      throwsA(isA<GoogleDriveConnectionIntentChangedException>()),
    );
  });
}

GoogleDriveConnectionIntentToken _captureIntent(ProviderContainer container) =>
    container
        .read(synchingProvider(syncId: 1).notifier)
        .captureGoogleDriveConnectionIntent();

void _persistIntent(
  ProviderContainer container,
  GoogleDriveConnectionIntentToken intent,
) => container
    .read(synchingProvider(syncId: 1).notifier)
    .persistGoogleDriveConnectionIfIntentCurrent(
      intent: intent,
      mediaSelection: null,
    );

Future<String> _isarLibraryPath() async {
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages
      .where((entry) => entry['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (package == null) {
    throw StateError('Could not locate isar_community_flutter_libs');
  }
  final rootUri = Uri.parse(package['rootUri'] as String);
  final packageDirectory = Directory.fromUri(
    rootUri.isAbsolute ? rootUri : packageConfig.parent.uri.resolveUri(rootUri),
  );
  if (Platform.isMacOS) {
    return '${packageDirectory.path}/macos/libisar.dylib';
  }
  if (Platform.isLinux) {
    return '${packageDirectory.path}/linux/libisar.so';
  }
  if (Platform.isWindows) {
    return '${packageDirectory.path}/windows/libisar.dll';
  }
  throw UnsupportedError('Isar test is unsupported on this platform');
}
