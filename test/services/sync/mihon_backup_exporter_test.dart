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
}
