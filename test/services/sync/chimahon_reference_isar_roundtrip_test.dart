import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_backup_semantic_diff.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/mihon_backup_exporter.dart';
import 'package:protobuf/protobuf.dart';

// This intentionally uses the user's real Chimahon backup and is therefore
// opt-in rather than a checked-in fixture:
// CHIMAHON_REFERENCE_BACKUP=/path/to/backup.tachibk flutter test \
//   test/services/sync/chimahon_reference_isar_roundtrip_test.dart
void main() {
  final referencePath = Platform.environment['CHIMAHON_REFERENCE_BACKUP'];

  test(
    'routine Isar import/export preserves a real Chimahon payload when merged',
    () async {
      await Isar.initializeIsarCore(
        libraries: {Abi.current(): await _isarLibraryPath()},
      );
      final databaseDirectory = await Directory.systemTemp.createTemp(
        'mangatan-chimahon-reference-roundtrip-',
      );
      Isar? database;
      try {
        database = await Isar.open(
          [
            MangaSchema,
            ChapterSchema,
            CategorySchema,
            HistorySchema,
            SourceSchema,
            EpubBookProgressSchema,
            TrackSchema,
          ],
          directory: databaseDirectory.path,
          name: 'chimahon_reference_roundtrip',
        );

        const codec = ChimahonSyncCodec();
        final reference = codec
            .decode(await File(referencePath!).readAsBytes())
            .backup;

        final sourcesByNativeId = _fixtureSources(reference);
        final seededNovels = <String, EpubBookProgress>{};
        database.writeTxnSync(() {
          database!.sources.putAllSync(sourcesByNativeId.values.toList());
          for (final indexed in reference.backupNovels.indexed) {
            final remote = indexed.$2;
            final parent = Manga(
              source: 'Local EPUB',
              author: remote.hasAuthor() ? remote.author : null,
              artist: null,
              genre: const [],
              imageUrl: null,
              lang: remote.hasLang() ? remote.lang : null,
              link: '/fixture-novel-${indexed.$1}',
              name: remote.title,
              sourceId: null,
              status: Status.unknown,
              description: null,
              itemType: ItemType.novel,
              favorite: true,
              isLocalArchive: true,
              categories: const [],
            );
            database.mangas.putSync(parent);
            final progress = EpubBookProgress(
              mangaId: parent.id!,
              archivePath:
                  '${databaseDirectory.path}${Platform.pathSeparator}'
                  'fixture-${indexed.$1}.epub',
              title: remote.title,
              author: remote.hasAuthor() ? remote.author : null,
              lang: 'before-import',
              chapterIndex: 0,
              progress: 0,
              characterCount: 0,
              lastModified: 0,
            );
            database.epubBookProgress.putSync(progress);
            seededNovels[_novelKey(remote)] = progress;
          }
        });

        final importResult = const ChimahonSyncImporter().apply(
          database: database,
          backup: reference,
        );
        expect(importResult.titlesCreated, greaterThan(0));
        expect(importResult.novelsUpdated, reference.backupNovels.length);

        final customRemote = reference.backupManga.singleWhere(
          (manga) => manga.hasCustomTitle(),
        );
        final customSource = sourcesByNativeId[customRemote.source.toInt()];
        expect(customSource, isNotNull);
        final customLocal = database.mangas
            .filter()
            .sourceIdEqualTo(customSource!.id)
            .linkEqualTo(customRemote.url)
            .findFirstSync();
        expect(customLocal, isNotNull);
        expect(customLocal!.sourceTitle, customRemote.title);
        expect(customLocal.name, customRemote.customTitle);

        final importedProgress = database.epubBookProgress
            .where()
            .findAllSync();
        expect(importedProgress, hasLength(reference.backupNovels.length));
        for (final remote in reference.backupNovels) {
          final seeded = seededNovels[_novelKey(remote)]!;
          final local = importedProgress.singleWhere(
            (progress) => progress.id == seeded.id,
          );
          expect(local.chapterIndex, remote.chapterIndex);
          expect(local.progress, remote.progress);
          expect(local.characterCount, remote.characterCount);
          expect(local.lastModified, remote.lastModified.toInt());
          if (remote.hasLang()) expect(local.lang, remote.lang);
        }

        final projected = const MihonBackupExporter().export(
          mangas: database.mangas.where().findAllSync(),
          categories: database.categorys.where().findAllSync(),
          chapters: database.chapters.where().findAllSync(),
          histories: database.historys.where().findAllSync(),
          sources: database.sources.where().findAllSync(),
          epubBookProgress: importedProgress,
          tracks: database.tracks.where().findAllSync(),
        );
        expect(
          projected.backupManga.map(
            (manga) => '${_mangaKey(manga)}|${manga.favorite}',
          ),
          everyElement(endsWith('|true')),
          reason: 'An empty target must not synthesize local tombstones.',
        );
        final projectedCustom = projected.backupManga.singleWhere(
          (manga) =>
              manga.source == customRemote.source &&
              manga.url == customRemote.url,
        );
        expect(projectedCustom.title, customRemote.title);
        expect(projectedCustom.customTitle, customRemote.customTitle);
        expect(
          projected.backupNovels,
          hasLength(reference.backupNovels.length),
        );
        for (final remote in reference.backupNovels) {
          final local = projected.backupNovels.singleWhere(
            (novel) => _novelKey(novel) == _novelKey(remote),
          );
          expect(local.chapterIndex, remote.chapterIndex);
          expect(local.progress, remote.progress);
          expect(local.characterCount, remote.characterCount);
          expect(local.lastModified, remote.lastModified);
        }

        // A complete deferred snapshot is the durable safety net for an
        // explicitly restored backup while its locally representable rows are
        // applied through the routine importer above.
        final deferred = FileChimahonDeferredPayloadStore(
          File(
            '${databaseDirectory.path}${Platform.pathSeparator}'
            'pending-reference.tachibk',
          ),
          retainMediaRecords: true,
          failOnCorruption: true,
        );
        await deferred.save(reference);
        final persistedReference = await deferred.load();
        expect(persistedReference, reference);

        final merged = const ChimahonSyncMerger().merge(
          local: projected,
          remote: persistedReference!,
          remoteWinsProjectionTies: true,
        );
        final chimahonConsumable = codec
            .decode(
              codec.encode(merged, format: ChimahonSyncWireFormat.gzipProtobuf),
            )
            .backup;

        final noEditDiff = ChimahonBackupSemanticDiff.compare(
          remote: reference,
          proposed: chimahonConsumable,
        );
        expect(
          chimahonConsumable.writeToBuffer(),
          orderedEquals(reference.writeToBuffer()),
          reason:
              'A no-edit database projection must preserve the exact current '
              'Chimahon protobuf representation. Safe schema diff: '
              '${jsonEncode(noEditDiff.toSafeJson())}',
        );

        expect(
          chimahonConsumable.backupManga,
          hasLength(reference.backupManga.length),
        );
        expect(
          chimahonConsumable.backupAnime,
          hasLength(reference.backupAnime.length),
        );
        expect(
          chimahonConsumable.backupPreferences,
          hasLength(reference.backupPreferences.length),
        );
        expect(
          chimahonConsumable.backupSourcePreferences,
          hasLength(reference.backupSourcePreferences.length),
        );
        expect(
          chimahonConsumable.backupMangaStats,
          hasLength(reference.backupMangaStats.length),
        );
        expect(
          chimahonConsumable.backupAnkiStats,
          hasLength(reference.backupAnkiStats.length),
        );
        final referenceTombstones = {
          for (final manga in reference.backupManga.where(
            (manga) => manga.hasFavorite() && !manga.favorite,
          ))
            _mangaKey(manga),
        };
        final roundTripTombstones = {
          for (final manga in chimahonConsumable.backupManga.where(
            (manga) => manga.hasFavorite() && !manga.favorite,
          ))
            _mangaKey(manga),
        };
        expect(
          roundTripTombstones.difference(referenceTombstones),
          isEmpty,
          reason: 'The database projection must not invent tombstones.',
        );
        expect(
          referenceTombstones.difference(roundTripTombstones),
          isEmpty,
          reason: 'Every explicit Chimahon tombstone must survive.',
        );

        final customRoundTrip = chimahonConsumable.backupManga.singleWhere(
          (manga) =>
              manga.source == customRemote.source &&
              manga.url == customRemote.url,
        );
        expect(customRoundTrip.title, customRemote.title);
        expect(customRoundTrip.customTitle, customRemote.customTitle);

        expect(
          _unknownFieldSummary(chimahonConsumable),
          _unknownFieldSummary(reference),
        );
        expect(
          chimahonConsumable.backupNovels,
          hasLength(reference.backupNovels.length),
        );
        for (final remote in reference.backupNovels) {
          final roundTrip = chimahonConsumable.backupNovels.singleWhere(
            (novel) => _novelKey(novel) == _novelKey(remote),
          );
          expect(roundTrip.chapterIndex, remote.chapterIndex);
          expect(roundTrip.progress, remote.progress);
          expect(roundTrip.characterCount, remote.characterCount);
          expect(roundTrip.lastModified, remote.lastModified);
          expect(roundTrip.stats, remote.stats);
          expect(
            _semanticNovelCategoryIds(roundTrip.categoryIds),
            _semanticNovelCategoryIds(remote.categoryIds),
          );
          expect(roundTrip.hasCover(), remote.hasCover());
          if (remote.hasCover()) expect(roundTrip.cover, remote.cover);
        }
      } finally {
        await database?.close(deleteFromDisk: true);
        if (await databaseDirectory.exists()) {
          await databaseDirectory.delete(recursive: true);
        }
      }
    },
    skip: referencePath == null
        ? 'Set CHIMAHON_REFERENCE_BACKUP to run this integration fixture.'
        : false,
  );
}

Map<int, Source> _fixtureSources(BackupMihon backup) {
  final remoteByNativeId = <int, BackupSource>{};
  for (final source in [
    ...backup.backupSources,
    ...backup.backupAnimeSources,
  ]) {
    remoteByNativeId.putIfAbsent(source.sourceId.toInt(), () => source);
  }
  var localId = 1000;
  return {
    for (final entry in remoteByNativeId.entries)
      entry.key: Source(
        id: localId++,
        name: entry.value.name,
        lang: 'en',
        isAdded: true,
        sourceCode: 'fixture-installed',
        additionalParams: encodeMihonSourceMetadata(
          sourceId: entry.key,
          packageName: 'fixture.source.${entry.key}',
        ),
      )..sourceCodeLanguage = SourceCodeLanguage.mihon,
  };
}

String _novelKey(BackupNovel novel) => const ChimahonNovelProgressAdapter()
    .stableId(title: novel.title, author: novel.author);

String _mangaKey(BackupManga manga) {
  final url = manga.url.trim();
  if (url.isNotEmpty) return '${manga.source}|$url';
  return '${manga.source}||${manga.title.trim().toLowerCase()}|'
      '${manga.author.trim().toLowerCase()}';
}

Set<String> _semanticNovelCategoryIds(Iterable<String> ids) {
  final normalized = ids
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (normalized.any((id) => id != 'default')) normalized.remove('default');
  return normalized.isEmpty ? const {'default'} : normalized;
}

Map<String, int> _unknownFieldSummary(GeneratedMessage root) {
  final result = <String, int>{};

  void visit(GeneratedMessage message) {
    final type = message.info_.qualifiedMessageName;
    for (final entry in message.unknownFields.asMap().entries) {
      final key = '$type#${entry.key}';
      final field = entry.value;
      result[key] =
          (result[key] ?? 0) +
          field.varints.length +
          field.fixed32s.length +
          field.fixed64s.length +
          field.lengthDelimited.length +
          field.groups.length;
    }
    for (final field in message.info_.fieldInfo.values) {
      final value = message.getField(field.tagNumber);
      if (value is GeneratedMessage) {
        visit(value);
      } else if (value is Iterable) {
        for (final element in value) {
          if (element is GeneratedMessage) visit(element);
        }
      }
    }
  }

  visit(root);
  return Map.fromEntries(
    result.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key)),
  );
}

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
