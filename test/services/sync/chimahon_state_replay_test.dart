import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/statistics/immersion_stats_storage.dart';
import 'package:mangayomi/services/sync/chimahon_app_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_backup_semantic_diff.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_local_sync_projection_service.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_mining_settings_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_pre_upload_safety_gate.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_source_preferences_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_stats_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

// Private fixtures stay outside source control. See docs/chimahon_sync_contract.md.
// Only disposable copies are opened for writing; the transport has no network.
void main() {
  final environment = Platform.environment;
  final databasePath = environment['CHIMAHON_REPLAY_DATABASE'];
  final accountPath = environment['CHIMAHON_REPLAY_ACCOUNT'];
  final remotePath = environment['CHIMAHON_REPLAY_REMOTE'];
  test(
    'failed-state replay commits, imports, and converges without cloud writes',
    () async {
      await Isar.initializeIsarCore(
        libraries: {Abi.current(): await _isarLibraryPath()},
      );
      final scratch = await Directory.systemTemp.createTemp('chimahon-replay-');
      Isar? database;
      try {
        await File('$databasePath/mangayomiDb.isar')
            .copy('${scratch.path}/replay.isar');
        for (final name in [
          'mining_preferences.hive',
          'immersion_statistics.hive',
        ]) {
          final input = File('$databasePath/$name');
          if (await input.exists()) await input.copy('${scratch.path}/$name');
        }
        final accountCopy = Directory('${scratch.path}/account');
        await _copySidecars(Directory(accountPath!), accountCopy);
        await _copySidecars(
          Directory('${Directory(accountPath).parent.path}/manual_restore'),
          Directory('${scratch.path}/sync/chimahon/manual_restore'),
        );
        Hive.init(scratch.path);
        MiningPreferences.configureStorageDirectory(scratch.path);
        database = await Isar.open(
          [
            MangaSchema,
            ChapterSchema,
            DownloadSchema,
            UpdateSchema,
            CategorySchema,
            HistorySchema,
            SourceSchema,
            EpubBookProgressSchema,
            TrackSchema,
            SettingsSchema,
            SyncPreferenceSchema,
            ChangedPartSchema,
            SourcePreferenceSchema,
          ],
          directory: scratch.path,
          name: 'replay',
        );
        final db = database;
        final preferences = db.syncPreferences.where().findAllSync().single;
        final dictionaries = _ReplayDictionaries(
          Directory(
            '${Directory(accountPath).parent.parent.parent.path}/dictionaries',
          ),
        );
        final projection = ChimahonLocalSyncProjectionService(
          database: db,
          readOnly: true,
          dictionaryStorage: dictionaries,
          mediaSelection: ChimahonMediaSyncSelection(
            manga: preferences.chimahonSyncManga,
            anime: preferences.chimahonSyncAnime,
            novels: preferences.chimahonSyncNovels,
          ),
          mediaSelectionInitialized:
              preferences.chimahonMediaSelectionInitialized,
          mediaSelectionUserSelected:
              preferences.chimahonMediaSelectionUserSelected,
        );
        final pending = await defaultChimahonPendingManualRestoreStore(
          applicationSupportDirectory: scratch,
        );
        final store = LayeredChimahonDeferredPayloadStore(
          primary: FileChimahonDeferredPayloadStore(
            File('${accountCopy.path}/chimahon_deferred.tachibk'),
          ),
          pendingManualRestore: pending,
        );
        final storage = _ReplayStorage(await File(remotePath!).readAsBytes());
        final gate = ChimahonPreUploadSafetyGate(
          recoveryStore: FileChimahonRemoteRecoveryStore(
            Directory('${scratch.path}/recovery'),
          ),
        );
        var snapshot = await projection.createSnapshot();
        final engine = CrossDeviceSyncEngine(
          storage: storage,
          deferredPayloadStore: store,
          exportLocal: () async {
            snapshot = await projection.createSnapshot();
            return snapshot.backup;
          },
          localUnrepresentablePreferenceKeys: () =>
              snapshot.unrepresentablePreferenceKeys,
          localTrackingDeletions: snapshot.trackingDeletionKeys,
          localMediaSelection: snapshot.mediaSelection,
          localMediaSelectionInitialized: snapshot.mediaSelectionInitialized,
          localMediaSelectionUserSelected: snapshot.mediaSelectionUserSelected,
          importMerged: (backup) => _import(db, backup, dictionaries),
          preUpload: gate.check,
        );
        final result = await engine.synchronize();
        expect(result.requiresRetry, isFalse);
        expect(await pending.load(), isNull);
        final committed = storage.bytes;
        for (var iteration = 0; iteration < 3; iteration++) {
          final preview = await engine.preview();
          await gate.check(preview);
          final unchanged = const ListEquality<int>().equals(
            const ChimahonSyncCodec().decode(committed).protobufBytes,
            const ChimahonSyncCodec()
                .decode(preview.proposedBytes)
                .protobufBytes,
          );
          expect(
            unchanged,
            isTrue,
            reason: jsonEncode(
              ChimahonBackupSemanticDiff.compare(
                remote: const ChimahonSyncCodec().decode(committed).backup,
                proposed: preview.proposedMerged,
              ).toSafeJson(),
            ),
          );
          await engine.synchronize();
        }
      } finally {
        await database?.close();
        await Hive.close();
        // The exact directory was created above, never supplied by the user.
        await scratch.delete(recursive: true);
      }
    },
    skip: databasePath == null || accountPath == null || remotePath == null
        ? 'Set CHIMAHON_REPLAY_DATABASE, CHIMAHON_REPLAY_ACCOUNT, and CHIMAHON_REPLAY_REMOTE.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _copySidecars(Directory source, Directory destination) async {
  if (!await source.exists()) return;
  await destination.create(recursive: true);
  await for (final entity in source.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name.startsWith('chimahon_')) {
      await entity.copy('${destination.path}/$name');
    }
  }
}

Future<void> _import(
  Isar db,
  BackupMihon backup,
  DictionaryStorage dictionaries,
) async {
  const ChimahonSyncImporter().apply(database: db, backup: backup);
  db.writeTxnSync(() {
    final settings = db.settings.getSync(227);
    if (settings == null) return;
    const adapter = ChimahonAppSettingsAdapter();
    adapter.importInto(
      settings,
      backup.backupPreferences,
      preserveLocalKeys: adapter.project(settings).unrepresentableKeys,
    );
    db.settings.putSync(settings);
  });
  const ChimahonSourcePreferencesAdapter().importInto(
    database: db,
    sourcePreferences: backup.backupSourcePreferences,
  );
  const mining = ChimahonMiningSettingsAdapter();
  final portable = chimahonPortableSourceOverrideIds(
    db.sources.where().findAllSync(),
  );
  final projection = await mining.project(
    dictionaryStorage: dictionaries,
    portableSourceIds: portable,
  );
  await mining.import(
    backup.backupPreferences,
    dictionaryStorage: dictionaries,
    portableSourceIds: portable,
    preserveLocalKeys: projection.unrepresentableKeys,
  );
  const statistics = ChimahonStatsAdapter();
  await ImmersionStatsStorage.mergeMangaStats(
    statistics.importAllMangaStats(backup.backupMangaStats),
  );
  await ImmersionStatsStorage.mergeAnkiStats(
    statistics.importAllAnkiStats(backup.backupAnkiStats),
  );
  for (final novel in backup.backupNovels) {
    if (novel.id.isNotEmpty && novel.stats.isNotEmpty) {
      await ImmersionStatsStorage.mergeNovelStats(
        novel.id,
        statistics.importAllNovelStats(novel.stats),
      );
    }
  }
}

class _ReplayStorage implements CrossDeviceSyncStorage {
  _ReplayStorage(this.bytes);
  Uint8List bytes;
  int revision = 0;
  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;
  @override
  Future<RemoteSyncSnapshot?> download() async => RemoteSyncSnapshot(
    bytes: bytes,
    revision: '$revision',
    isCompleteRecovery: true,
  );
  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    expect(expectedRevision, '$revision');
    this.bytes = bytes;
    return '${++revision}';
  }
}

class _ReplayDictionaries implements DictionaryStorage {
  _ReplayDictionaries(this.root);
  final Directory root;
  List<String> _order = [];
  @override
  Future<List<InstalledDictionary>> installed({
    Directory? root,
    List<String> order = const [],
  }) => installedReadOnly(order: order);
  @override
  Future<List<InstalledDictionary>> installedReadOnly({
    Directory? root,
    List<String> order = const [],
  }) => DictionaryStorage.instance.installedReadOnly(
    root: this.root,
    order: order.isEmpty ? _order : order,
  );
  @override
  Future<void> reorder(List<String> names, {Directory? root}) async {
    _order = List.of(names);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Replay dictionary write');
}

Future<String> _isarLibraryPath() async {
  final override = Platform.environment['CHIMAHON_REPLAY_ISAR_LIBRARY'];
  if (override != null) return override;
  final configFile = File('.dart_tool/package_config.json').absolute;
  final config =
      jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
  final package = (config['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((entry) => entry['name'] == 'isar_community_flutter_libs');
  final root = configFile.parent.uri.resolve(package['rootUri'] as String);
  final relative = Platform.isWindows
      ? 'windows/libisar.dll'
      : Platform.isMacOS
      ? 'macos/libisar.dylib'
      : 'linux/libisar.so';
  return File.fromUri(Directory.fromUri(root).uri.resolve(relative)).path;
}
