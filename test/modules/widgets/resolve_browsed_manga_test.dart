import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/widgets/manga_image_card_widget.dart';

void main() {
  late Directory dir;

  setUp(() async {
    final overrides = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = overrides;
    }
    dir = await Directory.systemTemp.createTemp('resolve_browsed_manga');
    isar = await Isar.open(
      [MangaSchema, ChapterSchema],
      directory: dir.path,
      name: 'resolve_browsed_${dir.path.hashCode}',
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  Manga browsed(
    String source,
    int? sourceId, {
    String name = 'Re:Zero',
    String? link = 'https://example.test/series',
  }) => Manga(
    name: name,
    source: source,
    sourceId: sourceId,
    lang: 'all',
    link: link,
    imageUrl: '',
    genre: const [],
    author: '',
    artist: '',
    status: Status.unknown,
    description: '',
    itemType: ItemType.anime,
  );

  test('a renamed source reuses the stored entry', () async {
    // Jellyfin names its sources after a custom label that is not always
    // applied yet, so the same source can be browsed under two names.
    final stored = await resolveBrowsedMangaId(
      browsed('Jellyfin (Anime)', 7),
      'all',
      7,
    );

    final again = await resolveBrowsedMangaId(
      browsed('Jellyfin (1)', 7),
      'all',
      7,
    );

    expect(again, stored);
    expect(await isar.mangas.count(), 1);
  });

  test('the same title from another source stays separate', () async {
    final first = await resolveBrowsedMangaId(browsed('Source A', 7), 'all', 7);
    final second = await resolveBrowsedMangaId(
      browsed('Source B', 8),
      'all',
      8,
    );

    expect(second, isNot(first));
    expect(await isar.mangas.count(), 2);
  });

  test('same-named seasons of different series stay separate', () async {
    // Jellyfin titles every season "Season 1"; only the URL tells them apart.
    final honzuki = await resolveBrowsedMangaId(
      browsed('Jellyfin', 7, name: 'Season 1', link: '/honzuki#season'),
      'all',
      7,
    );
    final frieren = await resolveBrowsedMangaId(
      browsed('Jellyfin', 7, name: 'Season 1', link: '/frieren#season'),
      'all',
      7,
    );
    final frierenAgain = await resolveBrowsedMangaId(
      browsed('Jellyfin', 7, name: 'Season 1', link: '/frieren#season'),
      'all',
      7,
    );

    expect(frieren, isNot(honzuki));
    expect(frierenAgain, frieren);
    expect(await isar.mangas.count(), 2);
  });

  test('a stored row without a URL is still reused by title', () async {
    final legacy = await resolveBrowsedMangaId(
      browsed('Source', 7, link: null),
      'all',
      7,
    );
    final browsedAgain = await resolveBrowsedMangaId(
      browsed('Source', 7),
      'all',
      7,
    );

    expect(browsedAgain, legacy);
    expect(await isar.mangas.count(), 1);
  });
}
