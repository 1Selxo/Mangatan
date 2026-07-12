import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_novel_progress_adapter.dart';

/// Pure mapper from Mangatan's persisted entities to the common Mihon backup
/// envelope. Database access and scheduling deliberately remain outside it.
class MihonBackupExporter {
  const MihonBackupExporter();

  BackupMihon export({
    required Iterable<Manga> mangas,
    required Iterable<Category> categories,
    required Iterable<Chapter> chapters,
    required Iterable<History> histories,
    required Iterable<Source> sources,
    required Iterable<EpubBookProgress> epubBookProgress,
    Iterable<BackupPreference> appPreferences = const [],
  }) {
    final mangaCategories = categories
        .where((category) => category.forItemType == ItemType.manga)
        .toList();
    final categoryOrderById = <int, int>{};
    for (final indexed in mangaCategories.indexed) {
      final category = indexed.$2;
      if (category.id != null) {
        categoryOrderById[category.id!] = category.pos ?? indexed.$1;
      }
    }

    final sourceByLocalId = {
      for (final source in sources)
        if (source.id != null) source.id!: source,
    };
    final chaptersByManga = <int, List<Chapter>>{};
    for (final chapter in chapters) {
      final mangaId = chapter.mangaId;
      if (mangaId != null) {
        chaptersByManga.putIfAbsent(mangaId, () => []).add(chapter);
      }
    }
    final historiesByManga = <int, List<History>>{};
    for (final history in histories) {
      final mangaId = history.mangaId;
      if (mangaId != null) {
        historiesByManga.putIfAbsent(mangaId, () => []).add(history);
      }
    }

    final exportedManga = <BackupManga>[];
    final usedSources = <int, BackupSource>{};
    for (final manga in mangas.where(
      (manga) =>
          manga.itemType == ItemType.manga &&
          (manga.favorite ?? false) &&
          !(manga.isLocalArchive ?? false),
    )) {
      final localSource = manga.sourceId == null
          ? null
          : sourceByLocalId[manga.sourceId!];
      final nativeId = _nativeSourceId(localSource);
      if (nativeId == null || manga.id == null) continue;
      usedSources[nativeId] = BackupSource(
        name: localSource?.name ?? manga.source ?? 'Unknown',
        sourceId: Int64(nativeId),
      );

      final mangaChapters = chaptersByManga[manga.id!] ?? const [];
      final chaptersById = {
        for (final chapter in mangaChapters)
          if (chapter.id != null) chapter.id!: chapter,
      };
      final backupHistory = <BackupHistory>[];
      for (final history in historiesByManga[manga.id!] ?? const []) {
        final chapter = history.chapterId == null
            ? null
            : chaptersById[history.chapterId!];
        if (chapter == null || (chapter.url?.isEmpty ?? true)) continue;
        backupHistory.add(
          BackupHistory(
            url: chapter.url,
            lastRead: Int64(int.tryParse(history.date ?? '') ?? 0),
            readDuration: Int64((history.readingTimeSeconds ?? 0) * 1000),
          ),
        );
      }

      exportedManga.add(
        BackupManga(
          source: Int64(nativeId),
          url: manga.link ?? '',
          title: manga.name ?? '',
          artist: manga.artist,
          author: manga.author,
          description: manga.description,
          genre: manga.genre,
          status: _status(manga.status),
          thumbnailUrl: manga.imageUrl,
          dateAdded: Int64(manga.dateAdded ?? 0),
          chapters: [
            for (final indexed in mangaChapters.indexed)
              _backupChapter(indexed.$2, indexed.$1),
          ],
          categories: (manga.categories ?? const [])
              .map((id) => categoryOrderById[id])
              .nonNulls
              .map(Int64.new),
          favorite: manga.favorite ?? true,
          history: backupHistory,
          lastModifiedAt: Int64(manga.lastUpdate ?? manga.updatedAt ?? 0),
          favoriteModifiedAt: Int64(manga.updatedAt ?? 0),
          version: Int64(manga.updatedAt ?? 0),
          initialized: true,
        ),
      );
    }

    return BackupMihon(
      backupManga: exportedManga,
      backupCategories: [
        for (final indexed in mangaCategories.indexed)
          BackupCategory(
            name: indexed.$2.name ?? '',
            order: Int64(indexed.$2.pos ?? indexed.$1),
            id: Int64(indexed.$2.id ?? indexed.$1),
          ),
      ],
      backupSources: usedSources.values,
      backupPreferences: appPreferences,
      backupNovels: const ChimahonNovelProgressAdapter().exportAll(
        epubBookProgress,
      ),
    );
  }

  BackupChapter _backupChapter(Chapter chapter, int sourceOrder) {
    final modified = chapter.updatedAt ?? 0;
    return BackupChapter(
      url: chapter.url ?? '',
      name: chapter.name ?? '',
      scanlator: chapter.scanlator,
      read: chapter.isRead ?? false,
      bookmark: chapter.isBookmarked ?? false,
      lastPageRead: Int64(int.tryParse(chapter.lastPageRead ?? '') ?? 0),
      dateFetch: Int64(0),
      dateUpload: Int64(int.tryParse(chapter.dateUpload ?? '') ?? 0),
      chapterNumber: _chapterNumber(chapter.name),
      sourceOrder: Int64(sourceOrder),
      lastModifiedAt: Int64(modified),
      version: Int64(modified),
    );
  }

  int? _nativeSourceId(Source? source) {
    if (source == null) return null;
    final metadata = mihonSourceMetadata(source);
    if (metadata != null) return int.tryParse(metadata.sourceId);
    return source.sourceCodeLanguage == SourceCodeLanguage.mihon
        ? source.id
        : null;
  }

  double _chapterNumber(String? name) {
    final matches = RegExp(r'\d+(?:\.\d+)?').allMatches(name ?? '').toList();
    return matches.isEmpty
        ? 0
        : double.tryParse(matches.last.group(0) ?? '') ?? 0;
  }

  int _status(Status status) => switch (status) {
    Status.ongoing => 1,
    Status.completed => 2,
    Status.publishingFinished => 4,
    Status.canceled => 5,
    Status.onHiatus => 6,
    Status.unknown => 0,
  };
}
