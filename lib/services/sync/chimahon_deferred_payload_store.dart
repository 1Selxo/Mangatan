import 'dart:io';

import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

abstract interface class ChimahonDeferredPayloadStore {
  Future<BackupMihon?> load();

  Future<void> save(BackupMihon backup);
}

/// Retains fields whose app features are not wired yet (notably novels,
/// language profiles, and statistics). This makes a Chimahon -> Mangatan ->
/// Chimahon round-trip non-destructive while those screens/models evolve.
class FileChimahonDeferredPayloadStore implements ChimahonDeferredPayloadStore {
  FileChimahonDeferredPayloadStore(
    this.file, {
    this.codec = const ChimahonSyncCodec(),
  });

  final File file;
  final ChimahonSyncCodec codec;

  @override
  Future<BackupMihon?> load() async {
    if (!await file.exists()) return null;
    return codec.decode(await file.readAsBytes()).backup;
  }

  @override
  Future<void> save(BackupMihon backup) async {
    final deferred = BackupMihon(
      backupPreferences: backup.backupPreferences,
      backupSourcePreferences: backup.backupSourcePreferences,
      backupExtensionRepo: backup.backupExtensionRepo,
      backupAnimeExtensionRepo: backup.backupAnimeExtensionRepo,
      backupSavedSearches: backup.backupSavedSearches,
      backupFeeds: backup.backupFeeds,
      backupNovels: backup.backupNovels,
      backupNovelCategories: backup.backupNovelCategories,
      backupMangaStats: backup.backupMangaStats,
      backupAnkiStats: backup.backupAnkiStats,
    )..mergeUnknownFields(backup.unknownFields);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      codec.encode(deferred, format: ChimahonSyncWireFormat.gzipProtobuf),
      flush: true,
    );
  }
}
