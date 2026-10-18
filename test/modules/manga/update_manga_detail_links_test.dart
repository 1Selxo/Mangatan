import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/m_chapter.dart';
import 'package:mangayomi/eval/model/m_manga.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/manga/detail/providers/update_manga_detail_providers.dart';
import 'package:mangayomi/services/get_detail.dart';

import '../../test_utils/isar_library.dart';

/// Fetched chapters are linked to their manga in one database call. The
/// stored links must be the same as linking every chapter on its own.
void main() {
  late Directory directory;
  late Source source;
  late List<MChapter> remote;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
  });

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('update_detail_links');
    isar = await Isar.open(
      [MangaSchema, ChapterSchema, UpdateSchema, SourceSchema, SettingsSchema],
      directory: directory.path,
      name: 'links_${directory.path.hashCode}',
    );
    source = Source(
      id: 77,
      name: 'Links',
      lang: 'en',
      baseUrl: 'https://links.example',
      isAdded: true,
      sourceCode: 'code',
    );
    isar.writeTxnSync(() {
      isar.settings.putSync(Settings());
      isar.sources.putSync(source);
    });
    remote = [
      for (var i = 5; i >= 1; i--)
        MChapter(name: 'Chapter $i', url: '/series/chapter-$i'),
    ];
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        getDetailProvider.overrideWith(
          (ref, args) async =>
              MManga(name: 'Links Title', link: '/series', chapters: remote),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Manga addManga() {
    final manga = Manga(
      source: source.name,
      author: '',
      artist: '',
      genre: const [],
      imageUrl: '',
      lang: source.lang,
      link: '/series',
      name: 'Links Title',
      status: Status.unknown,
      description: '',
      sourceId: source.id,
    );
    isar.writeTxnSync(() => isar.mangas.putSync(manga));
    return manga;
  }

  void expectLinked(Manga manga, int count) {
    final chapters = isar.chapters
        .filter()
        .mangaIdEqualTo(manga.id)
        .findAllSync();
    expect(chapters, hasLength(count));
    for (final chapter in chapters) {
      chapter.manga.loadSync();
      expect(chapter.manga.value?.id, manga.id, reason: chapter.name);
    }
    final stored = isar.mangas.getSync(manga.id!)!..chapters.loadSync();
    expect(
      stored.chapters.map((c) => c.id).toSet(),
      chapters.map((c) => c.id).toSet(),
    );
  }

  test('links every chapter of a first open both ways', () async {
    final manga = addManga();

    await container().read(
      updateMangaDetailProvider(
        mangaId: manga.id,
        isInit: true,
        showToast: false,
      ).future,
    );

    expectLinked(manga, 5);
    expect(isar.updates.countSync(), 0);
  });

  test('links chapters added by a refresh and their updates', () async {
    final manga = addManga();
    await container().read(
      updateMangaDetailProvider(
        mangaId: manga.id,
        isInit: true,
        showToast: false,
      ).future,
    );

    remote = [
      MChapter(name: 'Chapter 7', url: '/series/chapter-7'),
      MChapter(name: 'Chapter 6', url: '/series/chapter-6'),
      ...remote,
    ];
    await container().read(
      updateMangaDetailProvider(
        mangaId: manga.id,
        isInit: false,
        showToast: false,
      ).future,
    );

    expectLinked(manga, 7);
    final updates = isar.updates.where().findAllSync();
    expect(updates.map((u) => u.chapterName), ['Chapter 6', 'Chapter 7']);
    for (final update in updates) {
      update.chapter.loadSync();
      expect(update.chapter.value?.name, update.chapterName);
      expect(update.chapter.value?.mangaId, manga.id);
    }
  });
}
