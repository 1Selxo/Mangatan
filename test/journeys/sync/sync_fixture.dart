/// A generic Chimahon/SyncYomi sync payload, modelled on the shape of a real
/// one (2026-11): which record types occur and which of their fields are set,
/// not their contents. Every title, URL, name and number here is made up.
///
/// What the real payload had, and so this one has too:
/// - manga with chapters (read, bookmarked, in progress, decimal numbers,
///   scanlators, versions, `{}` memos), history with read durations,
///   tracking, categories, excluded scanlators, a custom title, a manga that
///   is in history but not in the library, and one without genres;
/// - anime with episodes (seen, resume second, total seconds, summaries,
///   preview URLs, filler), history, a background image, a fetch type;
/// - novels with reading statistics, chapters and history, novel categories;
/// - manga, anime and novel categories (with hidden flags and orders);
/// - sources and anime sources, extension stores and an anime extension
///   repository, feeds with a saved search, search history;
/// - app preferences of every value type (bool, int, long, float, string,
///   string set) and per-source preferences;
/// - manga reading statistics and Anki statistics;
/// - fields this app does not know (root #702, manga #601 and #602), which a
///   sync must pass through unchanged.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionStore.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSavedSearch.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSearchHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:protobuf/protobuf.dart';

/// Fixed clock for the fixture, so its bytes never change: 2026-11-20 12:00.
final fixtureNow = DateTime.utc(2026, 11, 20, 12);

/// Milliseconds, as Mihon stores dates (added, fetched, uploaded, read).
Int64 _at(Duration ago) =>
    Int64(fixtureNow.subtract(ago).millisecondsSinceEpoch);

/// Seconds, as Chimahon's sync clocks are (`lastModifiedAt`,
/// `favoriteModifiedAt`: SQLite `strftime('%s')`).
Int64 _sec(Duration ago) =>
    Int64(fixtureNow.subtract(ago).millisecondsSinceEpoch ~/ 1000);

/// The source every fixture manga comes from: not installed in a test app,
/// as when syncing to a new device.
/// Mihon source IDs are 64-bit hashes; these are made up.
const fixtureSourceId = 1998944621602463790;
const fixtureAnimeSourceId = 2208944621602461337;

/// What the journeys check the app received, by name.
abstract final class Fixture {
  static const inProgress = 'Fixture: Reading Now';
  static const caughtUp = 'Fixture: All Caught Up';
  static const decimal = 'Fixture: Decimal Chapters';
  static const noGenres = 'Fixture: No Genres';
  static const notInLibrary = 'Fixture: Only In History';
  static const customTitled = 'Fixture: Custom Titled';
  static const customTitle = 'My Own Name For It';
  static const anime = 'Fixture: Watching Now';
  static const seasonedShow = 'Fixture: Seasoned Show';
  static const novel = 'Fixture: Novel In Progress';
  static const categoryA = 'Fixture Shelf A';
  static const categoryB = 'Fixture Shelf B';
  static const hiddenCategory = 'Fixture Hidden Shelf';
  static const animeCategory = 'Fixture Anime Shelf';
  static const novelCategory = 'Fixture Novel Shelf';

  /// The page "Chapter 3" of [inProgress] was left on (1-based in the app).
  static const inProgressPage = 7;
}

BackupChapter _chapter(
  String seriesKey,
  num number, {
  bool read = false,
  bool bookmark = false,
  int lastPageRead = 0,
  String? scanlator,
  Duration modifiedAgo = const Duration(days: 3),
}) => BackupChapter(
  url: '/series/$seriesKey/chapter/$number',
  name: 'Chapter $number',
  scanlator: scanlator,
  read: read,
  bookmark: bookmark,
  lastPageRead: Int64(lastPageRead),
  dateFetch: _at(const Duration(days: 30)),
  dateUpload: _at(Duration(days: 60 - number.toInt())),
  chapterNumber: number.toDouble(),
  sourceOrder: Int64(100 - (number * 10).toInt()),
  lastModifiedAt: _sec(modifiedAgo),
  version: Int64(number.toInt() + 1),
  memo: utf8.encode('{}'),
);

BackupManga _manga(
  String key,
  String title, {
  required List<BackupChapter> chapters,
  List<Int64> categories = const [],
  bool favorite = true,
  List<String> genre = const ['Comedy', 'Slice of Life'],
  int status = 1,
  int viewer = 0,
  List<BackupHistory> history = const [],
  List<BackupTracking> tracking = const [],
  String? customTitle,
  List<String> excludedScanlators = const [],
  String memo = '{}',
}) => BackupManga(
  source: Int64(fixtureSourceId),
  url: '/series/$key',
  title: title,
  artist: 'Fixture Artist',
  author: 'Fixture Author',
  description: 'A made-up series for sync tests.',
  genre: genre,
  status: status,
  thumbnailUrl: '$_media/covers/$key.png',
  dateAdded: _at(const Duration(days: 90)),
  viewer: viewer,
  chapters: chapters,
  categories: categories,
  tracking: tracking,
  favorite: favorite,
  chapterFlags: 0,
  viewerFlags: viewer,
  history: history,
  updateStrategy: 0,
  lastModifiedAt: _sec(const Duration(days: 2)),
  favoriteModifiedAt: _sec(const Duration(days: 90)),
  excludedScanlators: excludedScanlators,
  version: Int64(chapters.length),
  initialized: true,
  memo: utf8.encode(memo),
  customTitle: customTitle,
);

BackupPreference _pref(String key, String type, List<int> value) =>
    BackupPreference(
      key: key,
      value: BackupPreferenceValue(
        type: 'eu.kanade.tachiyomi.data.backup.models.${type}PreferenceValue',
        value: value,
      ),
    );

/// A preference value as the real payload encodes it: a one-field message.
List<int> _boolValue(bool v) => [0x08, v ? 1 : 0];
List<int> _intValue(int v) =>
    (CodedBufferWriter()..writeField(1, PbFieldType.O3, v)).toBuffer();
List<int> _longValue(int v) =>
    (CodedBufferWriter()..writeField(1, PbFieldType.O6, Int64(v))).toBuffer();
List<int> _floatValue(double v) =>
    (CodedBufferWriter()..writeField(1, PbFieldType.OF, v)).toBuffer();
List<int> _stringValue(String v) =>
    (CodedBufferWriter()..writeField(1, PbFieldType.OS, v)).toBuffer();
List<int> _stringSetValue(List<String> v) =>
    (CodedBufferWriter()..writeField(1, PbFieldType.PS, v)).toBuffer();

/// A nested message of made-up bytes in the shape of the real unknown field.
List<int> _unknownMessage(Map<int, Object> fields) {
  final writer = CodedBufferWriter();
  for (final MapEntry(key: tag, value: value) in fields.entries) {
    switch (value) {
      case int v:
        writer.writeField(tag, PbFieldType.O6, Int64(v));
      case String v:
        writer.writeField(tag, PbFieldType.OS, v);
      case List<int> v:
        writer.writeField(tag, PbFieldType.OY, v);
    }
  }
  return writer.toBuffer();
}

/// Where the fixture's covers, previews and backgrounds live; the fake
/// SyncYomi server serves them, so the app's image loading stays real.
var _media = 'https://fixture.invalid';

BackupMihon buildSyncFixture({String mediaBase = 'https://fixture.invalid'}) {
  _media = mediaBase;
  final shelfA = BackupCategory(
    name: Fixture.categoryA,
    order: Int64(0),
    id: Int64(1),
    flags: Int64(3),
  );
  final shelfB = BackupCategory(
    name: Fixture.categoryB,
    order: Int64(1),
    id: Int64(2),
    flags: Int64(3),
  );
  final hidden = BackupCategory(
    name: Fixture.hiddenCategory,
    order: Int64(2),
    id: Int64(3),
    flags: Int64(3),
    hidden: true,
  );

  final inProgress =
      _manga(
          'reading-now',
          Fixture.inProgress,
          categories: [Int64(0)],
          viewer: 1,
          chapters: [
            _chapter('reading-now', 1, read: true, scanlator: 'Fixture Scans'),
            _chapter(
              'reading-now',
              2,
              read: true,
              bookmark: true,
              scanlator: 'Fixture Scans',
            ),
            _chapter(
              'reading-now',
              3,
              lastPageRead: Fixture.inProgressPage - 1,
              scanlator: 'Fixture Scans',
              modifiedAgo: const Duration(hours: 5),
            ),
            _chapter('reading-now', 4, scanlator: 'Other Group'),
          ],
          excludedScanlators: ['Other Group'],
          history: [
            BackupHistory(
              url: '/series/reading-now/chapter/3',
              lastRead: _at(const Duration(hours: 5)),
              readDuration: Int64(1800000),
            ),
            BackupHistory(
              url: '/series/reading-now/chapter/2',
              lastRead: _at(const Duration(days: 1)),
            ),
          ],
          tracking: [
            BackupTracking(
              syncId: 2,
              libraryId: Int64(70001),
              mediaId: Int64(80001),
              trackingUrl: 'https://tracker.invalid/manga/80001',
              title: Fixture.inProgress,
              lastChapterRead: 2,
              totalChapters: 12,
              score: 8,
              status: 1,
              startedReadingDate: _at(const Duration(days: 40)),
            ),
          ],
        )
        ..unknownFields.mergeLengthDelimitedField(
          601,
          _unknownMessage({
            1: _unknownMessage({
              1: 'fixture-slug',
              2: 'made-up text ' * 20,
              3: 'fixture',
              4: 7,
            }),
            2: _unknownMessage({1: 'fixture1', 2: 'fixture', 3: 3}),
            3: _unknownMessage({1: 'https://fixture.invalid/' * 3, 2: 1}),
          }),
        )
        ..unknownFields.mergeVarintField(602, Int64(1));

  final caughtUp = _manga(
    'caught-up',
    Fixture.caughtUp,
    categories: [Int64(1)],
    status: 2,
    chapters: [
      for (var n = 1; n <= 5; n++) _chapter('caught-up', n, read: true),
    ],
    history: [
      BackupHistory(
        url: '/series/caught-up/chapter/5',
        lastRead: _at(const Duration(days: 4)),
      ),
    ],
    tracking: [
      BackupTracking(
        syncId: 2,
        libraryId: Int64(70002),
        mediaId: Int64(80002),
        trackingUrl: 'https://tracker.invalid/manga/80002',
        title: Fixture.caughtUp,
        lastChapterRead: 5,
        totalChapters: 5,
        status: 2,
        startedReadingDate: _at(const Duration(days: 80)),
        finishedReadingDate: _at(const Duration(days: 4)),
      ),
    ],
  );

  final decimal = _manga(
    'decimals',
    Fixture.decimal,
    categories: [Int64(0), Int64(1)],
    status: 0,
    viewer: 4,
    chapters: [
      _chapter('decimals', 1, read: true),
      _chapter('decimals', 1.5, read: true),
      _chapter('decimals', 2),
      _chapter('decimals', 2.5),
    ],
    memo: '{"slug":"fixture-decimals"}',
  );

  final noGenres = _manga(
    'no-genres',
    Fixture.noGenres,
    genre: const [],
    status: 6,
    chapters: [_chapter('no-genres', 1)],
  );

  final notInLibrary = _manga(
    'only-history',
    Fixture.notInLibrary,
    favorite: false,
    chapters: [_chapter('only-history', 1, read: true)],
    history: [
      BackupHistory(
        url: '/series/only-history/chapter/1',
        lastRead: _at(const Duration(days: 9)),
      ),
    ],
  );

  final customTitled = _manga(
    'custom-titled',
    Fixture.customTitled,
    customTitle: Fixture.customTitle,
    categories: [Int64(2)],
    status: 4,
    viewer: 2,
    chapters: [_chapter('custom-titled', 1), _chapter('custom-titled', 2)],
  );

  final anime = BackupAnime(
    source: Int64(fixtureAnimeSourceId),
    url: '/anime/watching-now',
    title: Fixture.anime,
    artist: 'Fixture Studio',
    author: 'Fixture Director',
    description: 'A made-up anime for sync tests.',
    genre: const ['Adventure'],
    status: 1,
    thumbnailUrl: '$_media/covers/watching-now.png',
    dateAdded: _at(const Duration(days: 20)),
    episodes: [
      for (var n = 1; n <= 4; n++)
        BackupEpisode(
          url: '/anime/watching-now/episode/$n',
          name: 'Episode $n',
          seen: n <= 2,
          lastSecondSeen: Int64(n == 3 ? 612000 : 0),
          totalSeconds: Int64(1440000),
          dateFetch: _at(const Duration(days: 20)),
          dateUpload: _at(Duration(days: 30 - n)),
          episodeNumber: n.toDouble(),
          sourceOrder: Int64(10 - n),
          lastModifiedAt: _sec(const Duration(days: 1)),
          version: Int64(n),
          scanlator: n == 1 ? 'Fixture Subs' : null,
          summary: 'Made-up summary of episode $n.',
          previewUrl: '$_media/previews/$n.png',
          fillermark: n == 4,
        ),
    ],
    categories: [Int64(0)],
    favorite: true,
    history: [
      BackupHistory(
        url: '/anime/watching-now/episode/3',
        lastRead: _at(const Duration(days: 1)),
      ),
    ],
    lastModifiedAt: _sec(const Duration(days: 1)),
    favoriteModifiedAt: _sec(const Duration(days: 20)),
    version: Int64(4),
    backgroundUrl: '$_media/backgrounds/watching-now.png',
    fetchType: 1,
  );

  // A show split into seasons: the parent lists the seasons, each season
  // its own episodes (anime with a season fetch type).
  BackupAnime season(int number) => BackupAnime(
    source: Int64(fixtureAnimeSourceId),
    url: '/anime/seasoned-show/season-$number',
    title: '${Fixture.seasonedShow} Season $number',
    genre: const ['Drama'],
    status: number == 1 ? 2 : 1,
    episodes: [
      for (var n = 1; n <= 2; n++)
        BackupEpisode(
          url: '/anime/seasoned-show/season-$number/episode/$n',
          name: 'S${number}E$n',
          seen: number == 1,
          episodeNumber: n.toDouble(),
          sourceOrder: Int64(2 - n),
          dateUpload: _at(Duration(days: 200 - number * 50 - n)),
          version: Int64(1),
        ),
    ],
    favorite: false,
    favoriteModifiedAt: _sec(const Duration(days: 15)),
    lastModifiedAt: _sec(const Duration(days: 15)),
    parentId: Int64(900),
    id: Int64(900 + number),
    seasonNumber: number.toDouble(),
    seasonSourceOrder: Int64(number - 1),
    seasonFlags: Int64(0),
  );
  final seasonedShow = BackupAnime(
    source: Int64(fixtureAnimeSourceId),
    url: '/anime/seasoned-show',
    title: Fixture.seasonedShow,
    genre: const ['Drama'],
    status: 1,
    thumbnailUrl: '$_media/covers/seasoned-show.png',
    favorite: true,
    categories: [Int64(1)],
    favoriteModifiedAt: _sec(const Duration(days: 15)),
    lastModifiedAt: _sec(const Duration(days: 15)),
    id: Int64(900),
    fetchType: 0,
  );

  final novel = BackupNovel(
    id: 'fixture-novel-1',
    title: Fixture.novel,
    author: 'Fixture Novelist',
    cover: 'fixture-cover.jpg',
    chapterIndex: 2,
    progress: 0.4,
    characterCount: 120000,
    lastModified: _at(const Duration(days: 2)),
    lang: 'ja',
    categoryIds: const ['fixture-novel-shelf'],
    stats: [
      for (var d = 1; d <= 5; d++)
        BackupNovelStat(
          dateKey: '2026-11-${(10 + d).toString().padLeft(2, '0')}',
          charactersRead: 3000 * d,
          readingTime: 600.0 * d,
          minReadingSpeed: 4000,
          altMinReadingSpeed: 4200,
          lastReadingSpeed: 5000,
          maxReadingSpeed: 6000,
          lastStatisticModified: _at(Duration(days: 10 - d)),
        ),
    ],
    chapters: [
      for (var n = 1; n <= 3; n++)
        BackupChapter(
          url: 'fixture-novel-1/chapter-$n.xhtml',
          name: 'Novel chapter $n',
          chapterNumber: n.toDouble(),
          dateFetch: _at(const Duration(days: 10)),
          sourceOrder: Int64(n),
          version: Int64(1),
        ),
    ],
    history: [
      BackupNovelHistory(
        chapterUrl: 'fixture-novel-1/chapter-2.xhtml',
        lastRead: _at(const Duration(days: 2)),
        timeRead: Int64(2400000),
      ),
    ],
  );

  final backup = BackupMihon(
    backupManga: [
      inProgress,
      caughtUp,
      decimal,
      noGenres,
      notInLibrary,
      customTitled,
    ],
    backupCategories: [shelfA, shelfB, hidden],
    backupSources: [
      BackupSource(
        name: 'Fixture Source (EN)',
        sourceId: Int64(fixtureSourceId),
      ),
      BackupSource(sourceId: Int64(3108944621602469911)),
    ],
    backupPreferences: [
      _pref('pref_fixture_bool', 'Boolean', _boolValue(true)),
      _pref('reader_fixture_int', 'Int', _intValue(3)),
      _pref('last_fixture_long', 'Long', _longValue(1763640000000)),
      _pref('display_fixture_float', 'Float', _floatValue(1.25)),
      _pref('library_fixture_string', 'String', _stringValue('fixture value')),
      _pref('categories_fixture_set', 'StringSet', _stringSetValue(['1', '2'])),
    ],
    backupSourcePreferences: [
      BackupSourcePreferences(
        sourceKey: 'source_$fixtureSourceId',
        prefs: [
          _pref('fixture_source_switch', 'Boolean', _boolValue(false)),
          _pref(
            'fixture_source_domain',
            'String',
            _stringValue('https://fixture.invalid'),
          ),
          _pref(
            'fixture_source_tags',
            'StringSet',
            _stringSetValue(['a', 'b']),
          ),
        ],
      ),
    ],
    backupExtensionStores: [
      BackupExtensionStore(
        indexUrl: 'https://fixture.invalid/index.min.json',
        name: 'Fixture Store',
        badgeLabel: 'FX',
        contactWebsite: 'https://fixture.invalid',
        signingKey: 'FIXTURESIGNINGKEY',
        contactDiscord: 'https://fixture.invalid/chat',
        isLegacy: false,
      ),
    ],
    backupAnime: [anime, seasonedShow, season(1), season(2)],
    backupAnimeCategories: [
      BackupCategory(
        name: Fixture.animeCategory,
        order: Int64(0),
        id: Int64(10),
        flags: Int64(3),
      ),
      BackupCategory(
        name: 'Fixture Anime Second',
        order: Int64(1),
        id: Int64(11),
        flags: Int64(3),
      ),
    ],
    backupAnimeSources: [
      BackupSource(
        name: 'Fixture Anime Source',
        sourceId: Int64(fixtureAnimeSourceId),
      ),
    ],
    backupAnimeExtensionRepo: [
      BackupExtensionRepos(
        baseUrl: 'https://fixture.invalid/anime',
        name: 'Fixture Anime Repo',
        shortName: 'FXA',
        website: 'https://fixture.invalid',
        signingKeyFingerprint: 'FIXTUREFINGERPRINT',
      ),
    ],
    backupSavedSearches: [
      BackupSavedSearch(
        name: 'Fixture search',
        query: 'fixture',
        filterList: '[]',
        source: Int64(fixtureSourceId),
      ),
    ],
    backupFeeds: [
      BackupFeed(source: Int64(fixtureSourceId)),
      BackupFeed(
        source: Int64(fixtureSourceId),
        savedSearch: BackupSavedSearch(
          name: 'Fixture feed',
          query: 'feed',
          source: Int64(fixtureSourceId),
        ),
      ),
    ],
    backupSearchHistory: [
      BackupSearchHistory(
        scope: 'manga',
        query: 'fixture',
        lastSearchedAt: _at(const Duration(days: 3)),
      ),
    ],
    backupNovels: [novel],
    backupNovelCategories: [
      BackupNovelCategory(
        id: 'fixture-novel-shelf',
        name: Fixture.novelCategory,
        order: Int64(0),
      ),
      BackupNovelCategory(
        id: 'fixture-novel-second',
        name: 'Fixture Novel Second',
        order: Int64(1),
      ),
    ],
    backupMangaStats: [
      BackupMangaStats(
        dateKey: '2026-11-18',
        charactersRead: 5400,
        readingTime: Int64(1800),
        mangaId: Int64(1),
      ),
    ],
    backupAnkiStats: [
      BackupAnkiStats(
        dateKey: '2026-11-18',
        mangaCards: 3,
        novelCards: 1,
        profileId: 'fixture-profile',
        titleId: 'fixture-title',
      ),
    ],
  );
  backup.unknownFields.mergeLengthDelimitedField(
    702,
    _unknownMessage({
      1: fixtureSourceId,
      2: '/series/unknown-to-this-app',
      3: 'Fixture record this app does not know',
      5: 'fixture-tag',
      9: 'https://fixture.invalid/unknown.jpg',
      13: 1,
      102: 1,
      110: 2,
    }),
  );
  return backup;
}

/// The fixture as SyncYomi stores it: plain protobuf bytes.
Uint8List syncFixtureBytes({String mediaBase = 'https://fixture.invalid'}) =>
    buildSyncFixture(mediaBase: mediaBase).writeToBuffer();
