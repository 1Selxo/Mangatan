import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/sync/mihon_backup_exporter.dart';

void main() {
  test('exports native source identity, categories, progress, and history', () {
    final source = Source(
      id: 99,
      name: 'Manga source',
      lang: 'ja',
      isAdded: true,
      sourceCode: 'apk',
      additionalParams: encodeMihonSourceMetadata(
        sourceId: 123456789,
        packageName: 'pkg.source',
      ),
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;
    final category = Category(
      id: 10,
      name: 'Reading',
      pos: 3,
      forItemType: ItemType.manga,
    );
    final manga = Manga(
      id: 1,
      source: source.name,
      sourceId: source.id,
      author: 'Author',
      artist: 'Artist',
      genre: const ['Action'],
      imageUrl: 'cover',
      lang: 'ja',
      link: '/manga',
      name: 'Manga',
      status: Status.ongoing,
      description: 'Description',
      favorite: true,
      categories: [category.id!],
      updatedAt: 12,
    );
    final chapter = Chapter(
      id: 2,
      mangaId: manga.id,
      name: 'Chapter 4.5',
      url: '/chapter',
      isRead: false,
      lastPageRead: '8',
      updatedAt: 13,
    );
    final history = History(
      id: 3,
      itemType: ItemType.manga,
      chapterId: chapter.id,
      mangaId: manga.id,
      date: '1700000000000',
      readingTimeSeconds: 25,
    );

    final backup = const MihonBackupExporter().export(
      mangas: [manga],
      categories: [category],
      chapters: [chapter],
      histories: [history],
      sources: [source],
      epubBookProgress: const [],
    );

    expect(backup.backupSources.single.sourceId, Int64(123456789));
    expect(backup.backupManga.single.source, Int64(123456789));
    expect(backup.backupManga.single.categories, [Int64(3)]);
    expect(backup.backupManga.single.chapters.single.lastPageRead, Int64(8));
    expect(backup.backupManga.single.chapters.single.chapterNumber, 4.5);
    expect(
      backup.backupManga.single.history.single.lastRead,
      Int64(1700000000000),
    );
    expect(backup.backupManga.single.history.single.readDuration, Int64(25000));
  });

  test('exports anime source identity, categories, episodes, and watch history', () {
    final source = Source(
      id: 100,
      name: 'Anime source',
      lang: 'ja',
      isAdded: true,
      sourceCode: 'apk',
      additionalParams: encodeMihonSourceMetadata(
        sourceId: 987654321,
        packageName: 'pkg.anime',
      ),
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;
    final category = Category(
      id: 20,
      name: 'Watching',
      pos: 2,
      forItemType: ItemType.anime,
    );
    final anime = Manga(
      id: 4,
      source: source.name,
      sourceId: source.id,
      author: 'Director',
      artist: 'Studio',
      genre: const ['Adventure'],
      imageUrl: 'poster',
      lang: 'ja',
      link: '/anime',
      name: 'Anime',
      status: Status.ongoing,
      description: 'Anime description',
      favorite: true,
      categories: [category.id!],
      itemType: ItemType.anime,
      updatedAt: 22,
    );
    final episode = Chapter(
      id: 5,
      mangaId: anime.id,
      name: 'Episode 12',
      url: '/episode',
      isRead: true,
      lastPageRead: '713',
      updatedAt: 23,
    );
    final history = History(
      id: 6,
      itemType: ItemType.anime,
      chapterId: episode.id,
      mangaId: anime.id,
      date: '1700000005000',
      readingTimeSeconds: 120,
    );

    final backup = const MihonBackupExporter().export(
      mangas: [anime],
      categories: [category],
      chapters: [episode],
      histories: [history],
      sources: [source],
      epubBookProgress: const [],
    );

    expect(backup.backupAnimeSources.single.sourceId, Int64(987654321));
    expect(backup.backupAnime.single.source, Int64(987654321));
    expect(backup.backupAnime.single.categories, [Int64(2)]);
    expect(backup.backupAnime.single.episodes.single.lastSecondSeen, Int64(713));
    expect(backup.backupAnime.single.episodes.single.episodeNumber, 12);
    expect(
      backup.backupAnime.single.history.single.lastRead,
      Int64(1700000005000),
    );
    expect(backup.backupAnime.single.history.single.readDuration, Int64(120000));
  });
}
