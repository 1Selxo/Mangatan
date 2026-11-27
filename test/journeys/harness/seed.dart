/// Builders for the data an installation already has when a journey starts:
/// library entries, chapters with pages on disk, categories, history.
library;

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/update.dart';
import 'package:path/path.dart' as p;

class Seed {
  Seed(this.directory);

  /// The database the app runs on, which a kill and relaunch replaces.
  Isar get db => app.isar;
  final Directory directory;
  var _folders = 0;

  Future<void> settings(void Function(Settings s) change) =>
      db.writeTxn(() async {
        final s = (await db.settings.get(227))!;
        change(s);
        await db.settings.put(s);
      });

  Future<Category> category(
    String name, {
    ItemType type = ItemType.manga,
    int? pos,
  }) async {
    final category = Category(name: name, forItemType: type, pos: pos);
    await db.writeTxn(() => db.categorys.put(category));
    return category;
  }

  /// A library entry. Local entries open without any source installed.
  Future<Manga> manga(
    String name, {
    ItemType type = ItemType.manga,
    bool favorite = true,
    List<int>? categories,
    bool local = true,
    String lang = 'ja',
    int? dateAdded,
  }) async {
    final manga = Manga(
      source: local ? 'local' : 'Test Source',
      author: 'Author',
      artist: 'Artist',
      genre: const ['Romance', 'Comedy'],
      imageUrl: null,
      lang: lang,
      link: '/${name.hashCode}',
      name: name,
      status: Status.ongoing,
      description: 'A description of $name.',
      sourceId: local ? null : 1,
      favorite: favorite,
      itemType: type,
      categories: categories,
      isLocalArchive: local,
      dateAdded: dateAdded ?? DateTime.now().millisecondsSinceEpoch,
    );
    await db.writeTxn(() => db.mangas.put(manga));
    return manga;
  }

  /// A chapter of [manga]. With [pages], it is a folder of that many PNG
  /// pages on disk that the reader opens without a source, the way an
  /// imported folder or archive does.
  Future<Chapter> chapter(
    Manga manga,
    String name, {
    int pages = 0,
    double? number,
    bool read = false,
    String lastPageRead = '',
    bool bookmarked = false,
  }) async {
    final folder = pages > 0 ? await pageFolder(pages, name: name) : null;
    final chapter = Chapter(
      mangaId: manga.id,
      name: name,
      chapterNumber: number,
      isRead: read,
      lastPageRead: lastPageRead,
      isBookmarked: bookmarked,
      archivePath: folder?.path ?? '',
      url: folder == null ? '/chapter/${name.hashCode}' : '',
      dateUpload: '${DateTime(2026, 1, 1).millisecondsSinceEpoch}',
    )..manga.value = manga;
    await db.writeTxn(() async {
      await db.chapters.put(chapter);
      await chapter.manga.save();
    });
    return chapter;
  }

  /// [count] numbered chapters, each with [pages] pages, oldest first.
  Future<List<Chapter>> chapters(
    Manga manga,
    int count, {
    int pages = 4,
  }) async => [
    for (var i = 1; i <= count; i++)
      await chapter(manga, 'Chapter $i', number: i.toDouble(), pages: pages),
  ];

  Future<History> history(Manga manga, Chapter chapter, {DateTime? at}) async {
    final history = History(
      itemType: manga.itemType,
      chapterId: chapter.id,
      mangaId: manga.id,
      date: '${(at ?? DateTime.now()).millisecondsSinceEpoch}',
    )..chapter.value = chapter;
    await db.writeTxn(() async {
      await db.historys.put(history);
      await history.chapter.save();
    });
    return history;
  }

  Future<Update> update(Manga manga, Chapter chapter, {DateTime? at}) async {
    final update = Update(
      mangaId: manga.id,
      chapterName: chapter.name,
      date: '${(at ?? DateTime.now()).millisecondsSinceEpoch}',
    )..chapter.value = chapter;
    await db.writeTxn(() async {
      await db.updates.put(update);
      await update.chapter.save();
    });
    return update;
  }

  /// A lived-in library: categories, series in each item type with read,
  /// unread and in-progress chapters, history and updates. For sweeps that
  /// need every screen to have something to show.
  Future<void> livedIn() async {
    final romance = await category('Romance', pos: 0);
    final action = await category('Action', pos: 1);
    final now = DateTime.now();
    for (final (i, (name, type)) in [
      ('KUSO ONNA NO SACHIARE', ItemType.manga),
      ('请欺负我吧，恶役小姐！', ItemType.manga),
      ('わたしが恋人になれるわけないじゃん、ムリムリ！', ItemType.manga),
      (
        'A title long enough to wrap onto several lines in narrow tiles',
        ItemType.manga,
      ),
      ('Frieren', ItemType.anime),
      ('Watanare', ItemType.novel),
    ].indexed) {
      final m = await manga(
        name,
        type: type,
        categories: [if (i.isEven) romance.id! else action.id!],
      );
      final list = [
        for (var c = 1; c <= 4; c++)
          await chapter(
            m,
            '${type == ItemType.anime ? 'Episode' : 'Chapter'} $c',
            number: c.toDouble(),
            read: c == 1,
            lastPageRead: c == 2 ? '3' : '',
            pages: type == ItemType.manga && c <= 2 ? 3 : 0,
          ),
      ];
      await history(m, list[1], at: now.subtract(Duration(hours: i * 7)));
      await update(m, list[3], at: now.subtract(Duration(days: i)));
    }
  }

  /// A folder of [count] small PNG pages, each a different colour and
  /// numbered in its name so the reader's page order is checkable.
  Future<Directory> pageFolder(
    int count, {
    String name = 'pages',
    int width = 60,
    int height = 90,
    bool wideEvery3rd = false,
  }) async {
    final folder = Directory(
      p.join(directory.path, 'chapters', '${_folders++}-${name.hashCode}'),
    );
    await folder.create(recursive: true);
    for (var i = 1; i <= count; i++) {
      final wide = wideEvery3rd && i % 3 == 0;
      final image = img.Image(width: wide ? width * 2 : width, height: height)
        ..clear(img.ColorRgb8((i * 40) % 256, (i * 90) % 256, (i * 150) % 256));
      await File(p.join(folder.path, '${i.toString().padLeft(3, '0')}.png'))
          .writeAsBytes(img.encodePng(image));
    }
    return folder;
  }
}
