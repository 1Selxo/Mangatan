import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/library/providers/library_filter_provider.dart';
import 'package:mangayomi/services/epub_chapter_metadata.dart';
import 'package:mangayomi/utils/extensions/manga_extensions.dart';

import '../../test_utils/isar_library.dart';

/// The library filter loads chapters only when a filter reads them, counts
/// unread chapters with one settings read, and reuses a tab's list. Its
/// results must be exactly those of the previous implementation, which is
/// kept below as the reference.
void main() {
  late Directory directory;
  final downloadedIds = <int>{};
  final trackedIds = <int>{};

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    directory = Directory.systemTemp.createTempSync('library_filter_eq');
    isar = await Isar.open(
      [
        MangaSchema,
        ChangedPartSchema,
        ChapterSchema,
        CategorySchema,
        CustomButtonSchema,
        UpdateSchema,
        HistorySchema,
        DownloadSchema,
        SourceSchema,
        SettingsSchema,
        TrackPreferenceSchema,
        TrackSchema,
        SourcePreferenceSchema,
        SourcePreferenceStringValueSchema,
      ],
      directory: directory.path,
      name: 'library_filter_eq',
    );
    final random = Random(5);
    final mangas = [
      for (var i = 0; i < 60; i++)
        Manga(
          source: 'Source ${i % 4}',
          author: '',
          artist: '',
          genre: ['Genre ${i % 5}'],
          imageUrl: '',
          lang: 'en',
          link: '/series/$i',
          // Repeated names, read times and update times exercise ties.
          name: 'Entry ${random.nextInt(25)}',
          status: Status.values[i % Status.values.length],
          description: '',
          sourceId: 1,
          favorite: true,
          categories: [if (i % 3 != 2) i % 3 + 1],
          dateAdded: random.nextInt(8),
          lastUpdate: i % 7 == 0 ? null : random.nextInt(8),
          lastRead: random.nextInt(8),
        ),
    ];
    isar.writeTxnSync(() {
      isar.mangas.putAllSync(mangas);
      for (final manga in mangas) {
        final count = random.nextInt(6);
        final chapters = [
          for (var c = 0; c < count; c++)
            Chapter(
              mangaId: manga.id,
              name: 'Chapter $c',
              url: '${manga.link}/$c',
              dateUpload: '${random.nextInt(5)}',
              scanlator: c.isEven ? 'A' : 'B',
              isRead: random.nextBool(),
              isBookmarked: random.nextInt(4) == 0,
            )..manga.value = manga,
        ];
        isar.chapters.putAllSync(chapters);
        for (final chapter in chapters) {
          chapter.manga.saveSync();
          if (random.nextInt(3) == 0) downloadedIds.add(chapter.id!);
        }
        if (random.nextInt(3) == 0) trackedIds.add(manga.id!);
      }
      isar.settings.putSync(
        Settings()
          ..filterScanlatorList = [
            for (final m in mangas.take(20))
              FilterScanlator(mangaId: m.id, scanlators: ['B']),
            // A later filter for the same entry is ignored.
            for (final m in mangas.take(10))
              FilterScanlator(mangaId: m.id, scanlators: ['A']),
            FilterScanlator(mangaId: mangas[30].id, scanlators: []),
          ],
      );
    });
  });

  tearDownAll(() async {
    await isar.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  List<Manga> freshLibrary() =>
      isar.mangas.filter().idIsNotNull().favoriteEqualTo(true).findAllSync();

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        downloadedChapterIdsProvider.overrideWith(
          (ref) => Stream.value(downloadedIds),
        ),
        trackedMangaIdsProvider.overrideWithValue(trackedIds),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('filters and sorts exactly like the previous implementation', () async {
    final c = container();
    c.listen(downloadedChapterIdsProvider, (_, _) {});
    await c.read(downloadedChapterIdsProvider.future);

    final random = Random(9);
    final combos = <_Args>[
      // Every value of every option, others at their defaults.
      for (var v = 0; v < 3; v++) ...[
        _Args(downloadFilterType: v),
        _Args(unreadFilterType: v),
        _Args(startedFilterType: v),
        _Args(bookmarkedFilterType: v),
        _Args(completedFilterType: v),
        _Args(trackingFilterType: v),
      ],
      for (var sort = 0; sort < 8; sort++) _Args(sortType: sort),
      _Args(downloadedOnly: true),
      _Args(searchQuery: 'entry 1, genre 2'),
      _Args(searchQuery: 'source 3', ignoreFiltersOnSearch: true),
      _Args(sourceIds: ['Source 1', 'Source 2']),
      // And random combinations of all of them.
      for (var i = 0; i < 400; i++)
        _Args(
          downloadFilterType: random.nextInt(3),
          unreadFilterType: random.nextInt(3),
          startedFilterType: random.nextInt(3),
          bookmarkedFilterType: random.nextInt(3),
          completedFilterType: random.nextInt(3),
          trackingFilterType: random.nextInt(3),
          sortType: random.nextInt(8),
          downloadedOnly: random.nextInt(4) == 0,
          searchQuery: [
            '',
            '',
            'entry 2',
            'genre 1, source 0',
          ][random.nextInt(4)],
          ignoreFiltersOnSearch: random.nextBool(),
          sourceIds: random.nextBool() ? const [] : ['Source ${i % 4}'],
        ),
    ];

    for (final args in combos) {
      final expected = _reference(
        freshLibrary(),
        args,
        downloadedIds: downloadedIds,
        trackedIds: trackedIds,
      ).map((m) => m.id).toList();
      final actual = c
          .read(
            filteredLibraryMangaProvider(
              data: freshLibrary(),
              downloadFilterType: args.downloadFilterType,
              unreadFilterType: args.unreadFilterType,
              startedFilterType: args.startedFilterType,
              bookmarkedFilterType: args.bookmarkedFilterType,
              completedFilterType: args.completedFilterType,
              trackingFilterType: args.trackingFilterType,
              sortType: args.sortType,
              downloadedOnly: args.downloadedOnly,
              searchQuery: args.searchQuery,
              ignoreFiltersOnSearch: args.ignoreFiltersOnSearch,
              sourceIds: args.sourceIds,
            ),
          )
          .map((m) => m.id)
          .toList();
      expect(actual, expected, reason: '$args');
    }
  });

  test('the shared unread counter matches the per-entry count', () {
    final count = unreadChaptersCounter();
    for (final manga in freshLibrary()) {
      expect(count(manga), manga.unreadChaptersCount, reason: '${manga.id}');
    }
  });

  test('reverse unread sort matches the per-entry count', () {
    final data = freshLibrary();
    expect(
      sortByUnreadCount(
        data,
        unreadCountOf: unreadChaptersCounter(),
        descending: true,
      ).map((m) => m.id),
      sortByUnreadCount(
        data,
        unreadCountOf: (m) => m.unreadChaptersCount,
        descending: true,
      ).map((m) => m.id),
    );
  });

  test('scanlator filters read the same as from the whole settings row', () {
    final original = isar.settings.getSync(227)!;
    addTearDown(() => isar.writeTxnSync(() => isar.settings.putSync(original)));
    final data = freshLibrary();

    // The previous code: decode the whole row, then read the list.
    int previousUnread(Manga manga) => manga.unreadChaptersCountWith(
      isar.settings
          .getSync(227)
          ?.filterScanlatorList
          ?.where((e) => e.mangaId == manga.id)
          .firstOrNull
          ?.scanlators,
    );
    Map<int?, List<String>?> previousHidden() {
      final byManga = <int?, List<String>?>{};
      for (final filter
          in isar.settings.getSync(227)?.filterScanlatorList ??
              const <FilterScanlator>[]) {
        byManga.putIfAbsent(filter.mangaId, () => filter.scanlators);
      }
      return byManga;
    }

    void check(String reason) {
      expect(hiddenScanlatorsByManga(), previousHidden(), reason: reason);
      for (final manga in data) {
        expect(
          manga.unreadChaptersCount,
          previousUnread(manga),
          reason: '$reason ${manga.id}',
        );
      }
    }

    check('saved filters');
    final variants = <String, List<FilterScanlator>?>{
      'no list': null,
      'empty list': [],
      'nulls and non-ASCII': [
        FilterScanlator(mangaId: null, scanlators: ['A']),
        FilterScanlator(mangaId: data[0].id, scanlators: null),
        FilterScanlator(mangaId: data[0].id, scanlators: ['B']),
        FilterScanlator(mangaId: data[1].id, scanlators: ['B', 'Ä 翻訳']),
        FilterScanlator(mangaId: data[2].id, scanlators: ['', 'A']),
      ],
    };
    for (final MapEntry(:key, :value) in variants.entries) {
      isar.writeTxnSync(
        () => isar.settings.putSync(
          isar.settings.getSync(227)!..filterScanlatorList = value,
        ),
      );
      check(key);
    }
    isar.writeTxnSync(() => isar.settings.deleteSync(227));
    check('no settings row');
  });

  test('a tab lists the same entries as before and reuses its list', () {
    final all = freshLibrary();
    final settings = isar.settings.getSync(227)!;
    for (final categoryId in [1, 2, 3]) {
      final entries = libraryTabEntries(all, settings, categoryId: categoryId);
      expect(
        entries.map((m) => m.id),
        all
            .where((m) => m.categories?.contains(categoryId) ?? false)
            .map((m) => m.id),
      );
      expect(
        libraryTabEntries(all, settings, categoryId: categoryId),
        same(entries),
      );
    }
    final uncategorized = libraryTabEntries(
      all,
      settings,
      withoutCategories: true,
    );
    expect(
      uncategorized.map((m) => m.id),
      all
          .where((m) => m.categories == null || m.categories!.isEmpty)
          .map((m) => m.id),
    );
    expect(
      libraryTabEntries(all, settings, withoutCategories: true),
      same(uncategorized),
    );
    // New settings or a new library snapshot give a new list, as before.
    final newSettings = isar.settings.getSync(227)!;
    expect(
      libraryTabEntries(all, newSettings, categoryId: 1),
      isNot(same(libraryTabEntries(all, settings, categoryId: 1))),
    );
    expect(
      libraryTabEntries(freshLibrary(), settings, categoryId: 1),
      isNot(same(libraryTabEntries(all, settings, categoryId: 1))),
    );
  });
}

class _Args {
  _Args({
    this.downloadFilterType = 0,
    this.unreadFilterType = 0,
    this.startedFilterType = 0,
    this.bookmarkedFilterType = 0,
    this.completedFilterType = 0,
    this.trackingFilterType = 0,
    this.sortType = 0,
    this.downloadedOnly = false,
    this.searchQuery = '',
    this.ignoreFiltersOnSearch = false,
    this.sourceIds = const [],
  });

  final int downloadFilterType;
  final int unreadFilterType;
  final int startedFilterType;
  final int bookmarkedFilterType;
  final int completedFilterType;
  final int trackingFilterType;
  final int sortType;
  final bool downloadedOnly;
  final String searchQuery;
  final bool ignoreFiltersOnSearch;
  final List<String> sourceIds;

  @override
  String toString() =>
      'download=$downloadFilterType unread=$unreadFilterType '
      'started=$startedFilterType bookmarked=$bookmarkedFilterType '
      'completed=$completedFilterType tracking=$trackingFilterType '
      'sort=$sortType downloadedOnly=$downloadedOnly '
      'search="$searchQuery" ignore=$ignoreFiltersOnSearch '
      'sources=$sourceIds';
}

/// The previous `filteredLibraryManga` body, unchanged.
List<Manga> _reference(
  List<Manga> data,
  _Args args, {
  required Set<int> downloadedIds,
  required Set<int> trackedIds,
}) {
  final downloadFilterType = args.downloadFilterType;
  final unreadFilterType = args.unreadFilterType;
  final startedFilterType = args.startedFilterType;
  final bookmarkedFilterType = args.bookmarkedFilterType;
  final completedFilterType = args.completedFilterType;
  final trackingFilterType = args.trackingFilterType;
  final sortType = args.sortType;
  final downloadedOnly = args.downloadedOnly;
  final searchQuery = args.searchQuery;
  final ignoreFiltersOnSearch = args.ignoreFiltersOnSearch;
  final sourceIds = args.sourceIds;

  List<Manga> mangas;

  if (searchQuery.isNotEmpty && ignoreFiltersOnSearch) {
    mangas = data
        .where((element) => _matchesSearchQuery(element, searchQuery))
        .toList();
  } else {
    mangas = data.where((element) {
      final chapters = userFacingChapters(element);
      if (downloadFilterType == 1 || downloadedOnly) {
        final hasDownloaded = chapters.any(
          (chap) => chap.id != null && downloadedIds.contains(chap.id),
        );
        if (!hasDownloaded) return false;
      } else if (downloadFilterType == 2) {
        final allNotDownloaded = chapters.every(
          (chap) => chap.id == null || !downloadedIds.contains(chap.id),
        );
        if (!allNotDownloaded) return false;
      }

      if (unreadFilterType == 1 || startedFilterType == 1) {
        final hasUnread = chapters.any((chap) => !chap.isRead!);
        if (!hasUnread) return false;
      } else if (unreadFilterType == 2 || startedFilterType == 2) {
        final allRead = chapters.every((chap) => chap.isRead!);
        if (!allRead) return false;
      }

      if (bookmarkedFilterType == 1) {
        final hasBookmarked = chapters.any((chap) => chap.isBookmarked!);
        if (!hasBookmarked) return false;
      } else if (bookmarkedFilterType == 2) {
        final allNotBookmarked = chapters.every((chap) => !chap.isBookmarked!);
        if (!allNotBookmarked) return false;
      }

      if (completedFilterType == 1) {
        if (element.status != Status.completed) return false;
      } else if (completedFilterType == 2) {
        if (element.status == Status.completed) return false;
      }

      if (trackingFilterType == 1) {
        if (element.id == null || !trackedIds.contains(element.id)) {
          return false;
        }
      } else if (trackingFilterType == 2) {
        if (element.id != null && trackedIds.contains(element.id)) {
          return false;
        }
      }

      if (sourceIds.isNotEmpty) {
        if (element.source == null || !sourceIds.contains(element.source)) {
          return false;
        }
      }

      if (searchQuery.isNotEmpty) {
        if (!_matchesSearchQuery(element, searchQuery)) return false;
      }

      return true;
    }).toList();
  }

  if (mangas.isNotEmpty) {
    if (sortType == 3) {
      final unreadCounts = <int, int>{};
      for (final manga in mangas) {
        if (manga.id != null) {
          unreadCounts[manga.id!] = manga.unreadChaptersCount;
        }
      }
      mangas = sortByUnreadCount(
        mangas,
        unreadCountOf: (manga) =>
            manga.id != null ? (unreadCounts[manga.id] ?? 0) : 0,
      );
    } else if (sortType == 4) {
      final totalCounts = <int, int>{};
      for (final manga in mangas) {
        if (manga.id != null) {
          totalCounts[manga.id!] = userFacingChapters(manga).length;
        }
      }
      mangas.sort((a, b) {
        final aVal = a.id != null ? (totalCounts[a.id] ?? 0) : 0;
        final bVal = b.id != null ? (totalCounts[b.id] ?? 0) : 0;
        return aVal.compareTo(bVal);
      });
    } else {
      mangas.sort((a, b) {
        switch (sortType) {
          case 0:
            return a.name!.compareTo(b.name!);
          case 1:
            return a.lastRead!.compareTo(b.lastRead!);
          case 2:
            return a.lastUpdate?.compareTo(b.lastUpdate ?? 0) ?? 0;
          case 5:
            return (userFacingChapters(a).lastOrNull?.dateUpload ?? "")
                .compareTo(userFacingChapters(b).lastOrNull?.dateUpload ?? "");
          case 6:
            return a.dateAdded?.compareTo(b.dateAdded ?? 0) ?? 0;
          default:
            return 0;
        }
      });
    }
  }

  return mangas;
}

bool _matchesSearchQuery(Manga manga, String query) {
  final keywords = query
      .toLowerCase()
      .split(',')
      .map((k) => k.trim())
      .where((k) => k.isNotEmpty);

  return keywords.any(
    (keyword) =>
        (manga.name?.toLowerCase().contains(keyword) ?? false) ||
        (manga.source?.toLowerCase().contains(keyword) ?? false) ||
        (manga.genre?.any((g) => g.toLowerCase().contains(keyword)) ?? false),
  );
}
