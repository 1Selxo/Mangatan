import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupEpisode.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupTracking.pb.dart';
import 'package:mangayomi/services/sync/chimahon_media_child_projection_proof.dart';
import 'package:mangayomi/services/sync/chimahon_media_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';

void main() {
  const audit = ChimahonMediaSafetyAudit();

  Map<String, List<String>> failures({
    required BackupMihon remote,
    required BackupMihon local,
    required BackupMihon proposed,
    Set<({int source, String url, int syncId})> localTrackingDeletions =
        const {},
    bool remoteWinsTies = false,
  }) {
    final result = <String, List<String>>{};
    audit.audit(
      remote: remote,
      local: local,
      proposed: proposed,
      localTrackingDeletions: localTrackingDeletions,
      remoteWinsTies: remoteWinsTies,
      fail: (code, affected) {
        final values = affected.toList();
        if (values.isNotEmpty) result[code] = values;
      },
    );
    return result;
  }

  BackupManga manga({
    String url = '/manga',
    bool? favorite,
    int? favoriteClock,
    int version = 1,
    int modifiedAt = 10,
    String? customTitle,
    Iterable<BackupChapter> chapters = const [],
    Iterable<BackupHistory> history = const [],
    Iterable<BackupTracking> tracking = const [],
    Iterable<int> categories = const [],
  }) => BackupManga(
    source: Int64(1),
    url: url,
    title: 'Manga',
    favorite: favorite,
    favoriteModifiedAt: favoriteClock == null ? null : Int64(favoriteClock),
    lastModifiedAt: Int64(modifiedAt),
    version: Int64(version),
    customTitle: customTitle,
    chapters: chapters,
    history: history,
    tracking: tracking,
    categories: categories.map(Int64.new),
  );

  BackupAnime anime({
    String url = '/anime',
    bool? favorite,
    int? favoriteClock,
    int version = 1,
    int modifiedAt = 10,
    Iterable<BackupEpisode> episodes = const [],
    Iterable<BackupHistory> history = const [],
    Iterable<BackupTracking> tracking = const [],
    Iterable<int> categories = const [],
  }) => BackupAnime(
    source: Int64(2),
    url: url,
    title: 'Anime',
    favorite: favorite,
    favoriteModifiedAt: favoriteClock == null ? null : Int64(favoriteClock),
    lastModifiedAt: Int64(modifiedAt),
    version: Int64(version),
    episodes: episodes,
    history: history,
    tracking: tracking,
    categories: categories.map(Int64.new),
  );

  BackupCategory category(String name, int order) =>
      BackupCategory(name: name, order: Int64(order));

  group('clock-only child projection proof', () {
    final remoteChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 1',
      scanlator: 'Group',
      read: true,
      bookmark: true,
      lastPageRead: Int64(12),
      dateFetch: Int64(50),
      dateUpload: Int64(60),
      chapterNumber: 1,
      sourceOrder: Int64(9),
      lastModifiedAt: Int64(100),
      version: Int64(5),
    );
    final localChapter = remoteChapter.deepCopy()
      ..dateFetch = Int64.ZERO
      ..sourceOrder = Int64.ZERO
      ..lastModifiedAt = Int64(200)
      ..version = Int64.ZERO;
    final chapterChanges =
        <({String name, void Function(BackupChapter value) mutate})>[
          (name: 'URL', mutate: (value) => value.url = '/local-chapter'),
          (name: 'name', mutate: (value) => value.name = 'Local chapter'),
          (
            name: 'scanlator',
            mutate: (value) => value.scanlator = 'Local group',
          ),
          (name: 'read state', mutate: (value) => value.read = false),
          (name: 'bookmark', mutate: (value) => value.bookmark = false),
          (
            name: 'page progress',
            mutate: (value) => value.lastPageRead = Int64(13),
          ),
          (
            name: 'upload date',
            mutate: (value) => value.dateUpload = Int64(61),
          ),
          (name: 'number', mutate: (value) => value.chapterNumber = 2),
          (
            name: 'unknown envelope',
            mutate: (value) =>
                value.unknownFields.mergeVarintField(900, Int64(1)),
          ),
        ];

    for (final change in chapterChanges) {
      test('chapter proof rejects changed ${change.name}', () {
        final changedLocal = localChapter.deepCopy();
        change.mutate(changedLocal);

        expect(
          ChimahonMediaChildProjectionProof.exactRemoteChapterWinsClockOnlyLocalProjection(
            localProjection: changedLocal,
            remote: remoteChapter,
            proposed: remoteChapter.deepCopy(),
          ),
          isFalse,
        );
      });
    }

    final remoteEpisode = BackupEpisode(
      url: '/episode',
      name: 'Episode 1',
      scanlator: 'Group',
      seen: true,
      bookmark: true,
      lastSecondSeen: Int64(120),
      dateFetch: Int64(50),
      dateUpload: Int64(60),
      episodeNumber: 1,
      sourceOrder: Int64(9),
      lastModifiedAt: Int64(100),
      version: Int64(5),
      totalSeconds: Int64(1440),
      fillermark: true,
      summary: 'Summary',
      previewUrl: '/preview',
    );
    final localEpisode = remoteEpisode.deepCopy()
      ..dateFetch = Int64.ZERO
      ..sourceOrder = Int64.ZERO
      ..lastModifiedAt = Int64(200)
      ..version = Int64.ZERO;
    final episodeChanges =
        <({String name, void Function(BackupEpisode value) mutate})>[
          (name: 'URL', mutate: (value) => value.url = '/local-episode'),
          (name: 'name', mutate: (value) => value.name = 'Local episode'),
          (
            name: 'scanlator',
            mutate: (value) => value.scanlator = 'Local group',
          ),
          (name: 'seen state', mutate: (value) => value.seen = false),
          (name: 'bookmark', mutate: (value) => value.bookmark = false),
          (
            name: 'playback progress',
            mutate: (value) => value.lastSecondSeen = Int64(121),
          ),
          (
            name: 'upload date',
            mutate: (value) => value.dateUpload = Int64(61),
          ),
          (name: 'number', mutate: (value) => value.episodeNumber = 2),
          (
            name: 'nonzero duration',
            mutate: (value) => value.totalSeconds = Int64(1441),
          ),
          (name: 'filler mark', mutate: (value) => value.fillermark = false),
          (name: 'summary', mutate: (value) => value.summary = 'Local summary'),
          (
            name: 'preview URL',
            mutate: (value) => value.previewUrl = '/local-preview',
          ),
          (
            name: 'unknown envelope',
            mutate: (value) =>
                value.unknownFields.mergeVarintField(900, Int64(1)),
          ),
        ];

    for (final change in episodeChanges) {
      test('episode proof rejects changed ${change.name}', () {
        final changedLocal = localEpisode.deepCopy();
        change.mutate(changedLocal);

        expect(
          ChimahonMediaChildProjectionProof.exactRemoteEpisodeWinsClockOnlyLocalProjection(
            localProjection: changedLocal,
            remote: remoteEpisode,
            proposed: remoteEpisode.deepCopy(),
          ),
          isFalse,
        );
      });
    }
  });

  test('fails local manga child, history, tracking, and membership loss', () {
    final remote = BackupMihon(
      backupCategories: [category('Remote', 7), category('Local', 8)],
      backupManga: [
        manga(categories: [7]),
      ],
    );
    final local = BackupMihon(
      backupCategories: [category('Local', 2)],
      backupManga: [
        manga(
          chapters: [
            BackupChapter(
              url: '/local-chapter',
              name: 'Local',
              chapterNumber: 1,
              lastModifiedAt: Int64(20),
            ),
          ],
          history: [BackupHistory(url: '/local-history', lastRead: Int64(20))],
          tracking: [BackupTracking(syncId: 2)],
          categories: [2],
        ),
      ],
    );
    final proposed = BackupMihon(
      backupCategories: [category('Remote', 0), category('Local', 1)],
      backupManga: [
        manga(categories: [0]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: proposed).keys,
      containsAll({
        'local_manga_chapter_missing_from_proposed',
        'local_manga_history_missing_from_proposed',
        'local_manga_tracking_missing_from_proposed',
        'local_manga_category_membership_missing_from_proposed',
      }),
    );
  });

  test('fails remote anime child rows and a missing local parent', () {
    final remote = BackupMihon(
      backupAnimeCategories: [category('Watching', 9)],
      backupAnime: [
        anime(
          episodes: [
            BackupEpisode(
              url: '/episode',
              name: 'Episode',
              episodeNumber: 1,
              lastModifiedAt: Int64(20),
            ),
          ],
          history: [BackupHistory(url: '/episode', lastRead: Int64(20))],
          tracking: [BackupTracking(syncId: 3)],
          categories: [9],
        ),
      ],
    );
    final local = BackupMihon(backupAnime: [anime(url: '/local-only')]);
    final proposed = BackupMihon(
      backupAnimeCategories: [category('Watching', 0)],
      backupAnime: [
        anime(categories: [0]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: proposed).keys,
      containsAll({
        'remote_anime_episode_missing_from_proposed',
        'remote_anime_history_missing_from_proposed',
        'remote_anime_tracking_missing_from_proposed',
        'local_anime_missing_from_proposed',
      }),
    );
  });

  test('compares exact category membership after order remapping', () {
    final remote = BackupMihon(
      backupCategories: [category('Reading', 7)],
      backupAnimeCategories: [category('Watching', 9)],
      backupManga: [
        manga(categories: [7]),
      ],
      backupAnime: [
        anime(categories: [9]),
      ],
    );
    final local = BackupMihon(
      backupCategories: [category('Reading', 0)],
      backupAnimeCategories: [category('Watching', 1)],
      backupManga: [
        manga(categories: [0]),
      ],
      backupAnime: [
        anime(categories: [1]),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );

    expect(failures(remote: remote, local: local, proposed: proposed), isEmpty);
  });

  test('manga favorite clock ties follow declared parent tie authority', () {
    final remote = BackupMihon(
      backupManga: [manga(favorite: false, favoriteClock: 100)],
    );
    final local = BackupMihon(
      backupManga: [manga(favorite: true, favoriteClock: 100)],
    );
    final localWinner = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final remoteWinner = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      failures(remote: remote, local: local, proposed: localWinner),
      isEmpty,
    );
    expect(
      failures(
        remote: remote,
        local: local,
        proposed: remoteWinner,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
    expect(
      failures(
        remote: remote,
        local: local,
        proposed: localWinner,
        remoteWinsTies: true,
      ),
      contains('invalid_tombstone_resurrection'),
    );

    final newerFavorite = BackupMihon(
      backupManga: [manga(favorite: true, favoriteClock: 101)],
    );
    final newerFavoriteMerged = const ChimahonSyncMerger().merge(
      local: newerFavorite,
      remote: remote,
    );
    expect(
      failures(
        remote: remote,
        local: newerFavorite,
        proposed: newerFavoriteMerged,
      ),
      isEmpty,
    );
  });

  test('anime favorite clock ties follow declared parent tie authority', () {
    final remote = BackupMihon(
      backupAnime: [anime(favorite: false, favoriteClock: 100)],
    );
    final local = BackupMihon(
      backupAnime: [anime(favorite: true, favoriteClock: 100)],
    );
    final localWinner = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final remoteWinner = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      failures(remote: remote, local: local, proposed: localWinner),
      isEmpty,
    );
    expect(
      failures(
        remote: remote,
        local: local,
        proposed: remoteWinner,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
    expect(
      failures(
        remote: remote,
        local: local,
        proposed: localWinner,
        remoteWinsTies: true,
      ),
      contains('remote_anime_invalid_tombstone_resurrection'),
    );
  });

  test('accepts an explicitly recorded local portable-tracker deletion', () {
    final remoteManga = manga(tracking: [BackupTracking(syncId: 2)]);
    final localManga = manga();
    final result = failures(
      remote: BackupMihon(backupManga: [remoteManga]),
      local: BackupMihon(backupManga: [localManga]),
      proposed: BackupMihon(backupManga: [localManga]),
      localTrackingDeletions: const {(source: 1, url: '/manga', syncId: 2)},
    );

    expect(result, isEmpty);
  });

  test('accepts portable local tracking removed by a newer remote parent', () {
    final localManga = manga(tracking: [BackupTracking(syncId: 2)]);
    final remoteManga = manga()..version = Int64(2);
    final result = failures(
      remote: BackupMihon(backupManga: [remoteManga]),
      local: BackupMihon(backupManga: [localManga]),
      proposed: BackupMihon(backupManga: [remoteManga]),
    );

    expect(result, isEmpty);
  });

  test('fails a parent record clock regression', () {
    final remoteManga = manga()..version = Int64(4);
    final regressed = manga()..version = Int64(3);

    expect(
      failures(
        remote: BackupMihon(backupManga: [remoteManga]),
        local: BackupMihon(),
        proposed: BackupMihon(backupManga: [regressed]),
      ),
      contains('remote_manga_record_clock_regressed'),
    );
  });

  test('fails closed on duplicate parent and nested media identities', () {
    final chapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter',
      chapterNumber: 1,
      version: Int64(1),
    );
    final episode = BackupEpisode(
      url: '/episode',
      name: 'Episode',
      episodeNumber: 1,
      version: Int64(1),
    );
    final remoteManga = manga(chapters: [chapter, chapter.deepCopy()]);
    final remoteAnime = anime(
      episodes: [episode, episode.deepCopy()],
      history: [
        BackupHistory(url: '/episode', lastRead: Int64(10)),
        BackupHistory(url: '/episode', lastRead: Int64(10)),
      ],
      tracking: [BackupTracking(syncId: 2), BackupTracking(syncId: 2)],
    );
    final result = failures(
      remote: BackupMihon(
        backupManga: [remoteManga, remoteManga.deepCopy()],
        backupAnime: [remoteAnime],
      ),
      local: BackupMihon(),
      proposed: BackupMihon(
        backupManga: [
          manga(chapters: [chapter]),
        ],
        backupAnime: [
          anime(
            episodes: [episode],
            history: [BackupHistory(url: '/episode', lastRead: Int64(10))],
            tracking: [BackupTracking(syncId: 2)],
          ),
        ],
      ),
    );

    expect(
      result.keys,
      containsAll({
        'remote_manga_duplicate_identity',
        'remote_manga_chapter_duplicate_identity',
        'remote_anime_episode_duplicate_identity',
        'remote_anime_history_duplicate_identity',
        'remote_anime_tracking_duplicate_identity',
      }),
    );
  });

  test('fails an unversioned timestamp regression after promotion', () {
    final result = failures(
      remote: BackupMihon(backupManga: [manga(version: 0, modifiedAt: 20)]),
      local: BackupMihon(),
      proposed: BackupMihon(backupManga: [manga(version: 5, modifiedAt: 10)]),
    );

    expect(result, contains('remote_manga_record_clock_regressed'));
  });

  test('same source URL cannot hide an unproven local manga identity', () {
    final remoteManga = BackupManga(
      source: Int64(1),
      url: '/shared',
      title: 'Remote title',
      author: 'Remote author',
      lastModifiedAt: Int64(200),
      version: Int64(5),
    );
    final localManga = BackupManga(
      source: Int64(1),
      url: '/shared',
      title: 'Local title',
      author: 'Local author',
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );

    expect(
      failures(
        remote: BackupMihon(backupManga: [remoteManga]),
        local: BackupMihon(backupManga: [localManga]),
        proposed: BackupMihon(backupManga: [remoteManga]),
      ),
      contains('local_manga_missing_from_proposed'),
    );
  });

  test('same source URL cannot hide an unproven local anime identity', () {
    final remoteAnime = BackupAnime(
      source: Int64(2),
      url: '/shared',
      title: 'Remote title',
      author: 'Remote author',
      lastModifiedAt: Int64(200),
      version: Int64(5),
    );
    final localAnime = BackupAnime(
      source: Int64(2),
      url: '/shared',
      title: 'Local title',
      author: 'Local author',
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );

    expect(
      failures(
        remote: BackupMihon(backupAnime: [remoteAnime]),
        local: BackupMihon(backupAnime: [localAnime]),
        proposed: BackupMihon(backupAnime: [remoteAnime]),
      ),
      contains('local_anime_missing_from_proposed'),
    );
  });

  test('duplicate competing source URLs cannot authorize parent rebasing', () {
    final local = BackupMihon(
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/shared-manga',
          title: 'Local manga',
          author: 'Local manga author',
          favorite: false,
          favoriteModifiedAt: Int64(100),
          lastModifiedAt: Int64(100),
          version: Int64.ZERO,
        ),
      ],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/shared-anime',
          title: 'Local anime',
          author: 'Local anime author',
          favorite: false,
          favoriteModifiedAt: Int64(100),
          lastModifiedAt: Int64(100),
          version: Int64.ZERO,
        ),
      ],
    );
    final remote = BackupMihon(
      backupManga: [
        for (final title in ['Remote manga A', 'Remote manga B'])
          BackupManga(
            source: Int64(1),
            url: '/shared-manga',
            title: title,
            favorite: false,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(100),
            version: Int64(7),
          ),
      ],
      backupAnime: [
        for (final title in ['Remote anime A', 'Remote anime B'])
          BackupAnime(
            source: Int64(2),
            url: '/shared-anime',
            title: title,
            favorite: false,
            favoriteModifiedAt: Int64(100),
            lastModifiedAt: Int64(100),
            version: Int64(8),
          ),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()).keys,
      containsAll({
        'local_manga_missing_from_proposed',
        'local_anime_missing_from_proposed',
      }),
    );
  });

  test('accepts the merger\'s proven custom-title manga tombstone rebase', () {
    final remoteManga = BackupManga(
      source: Int64(1),
      url: '/shared',
      title: 'Canonical title',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64(7),
    );
    final localManga = BackupManga(
      source: Int64(1),
      url: '/shared',
      title: 'Stale source title',
      customTitle: 'My title',
      author: 'Stale author',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(backupManga: [remoteManga]);
    final local = BackupMihon(backupManga: [localManga]);
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(failures(remote: remote, local: local, proposed: proposed), isEmpty);
  });

  test('accepts the merger\'s proven anime tombstone rebase', () {
    final remoteAnime = BackupAnime(
      source: Int64(2),
      url: '/shared',
      title: 'Canonical title',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64(7),
    );
    final localAnime = BackupAnime(
      source: Int64(2),
      url: '/shared',
      title: 'Stale title',
      author: 'Stale author',
      favorite: false,
      favoriteModifiedAt: Int64(100),
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(backupAnime: [remoteAnime]);
    final local = BackupMihon(backupAnime: [localAnime]);
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(failures(remote: remote, local: local, proposed: proposed), isEmpty);
  });

  test(
    'accepts an exact remote chapter over a clock-only newer local projection',
    () {
      final remoteChapter = BackupChapter(
        url: '/chapter',
        name: 'Chapter 1',
        chapterNumber: 1,
        dateFetch: Int64(50),
        sourceOrder: Int64(9),
        lastModifiedAt: Int64(100),
        version: Int64(5),
      );
      final localChapter = BackupChapter(
        url: '/chapter',
        name: 'Chapter 1',
        scanlator: '',
        read: false,
        bookmark: false,
        lastPageRead: Int64.ZERO,
        dateFetch: Int64.ZERO,
        dateUpload: Int64.ZERO,
        chapterNumber: 1,
        sourceOrder: Int64.ZERO,
        lastModifiedAt: Int64(200),
        version: Int64.ZERO,
      );
      final remote = BackupMihon(
        backupManga: [
          manga(chapters: [remoteChapter]),
        ],
      );
      final local = BackupMihon(
        backupManga: [
          manga(chapters: [localChapter]),
        ],
      );

      expect(
        failures(
          remote: remote,
          local: local,
          proposed: remote.deepCopy(),
          remoteWinsTies: true,
        ),
        isEmpty,
      );
    },
  );

  test('audits the same proven legacy chapter-number rebase as the merger', () {
    final remoteChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 10',
      chapterNumber: 9.5,
      dateFetch: Int64(50),
      sourceOrder: Int64(9),
      lastModifiedAt: Int64(100),
      version: Int64(5),
    );
    final localChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 10',
      scanlator: '',
      read: false,
      bookmark: false,
      lastPageRead: Int64.ZERO,
      dateFetch: Int64.ZERO,
      dateUpload: Int64.ZERO,
      chapterNumber: 10,
      sourceOrder: Int64.ZERO,
      lastModifiedAt: Int64(200),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupManga: [
        manga(chapters: [remoteChapter]),
      ],
    );
    final local = BackupMihon(
      backupManga: [
        manga(chapters: [localChapter]),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      proposed.backupManga.single.chapters.single.writeToBuffer(),
      orderedEquals(remoteChapter.writeToBuffer()),
    );
    expect(
      failures(
        remote: remote,
        local: local,
        proposed: proposed,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
  });

  test('legacy chapter-number rebase never excuses real progress loss', () {
    final remoteChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 10',
      chapterNumber: 9.5,
      lastModifiedAt: Int64(100),
      version: Int64(5),
    );
    final localChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 10',
      read: true,
      bookmark: true,
      lastPageRead: Int64(12),
      chapterNumber: 10,
      lastModifiedAt: Int64(200),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupManga: [
        manga(chapters: [remoteChapter]),
      ],
    );
    final local = BackupMihon(
      backupManga: [
        manga(chapters: [localChapter]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_manga_chapter_clock_regressed'),
    );
  });

  test('same-URL unproven chapter identity cannot satisfy a local row', () {
    final remoteChapter = BackupChapter(
      url: '/chapter',
      name: 'Remote chapter',
      chapterNumber: 2,
      lastModifiedAt: Int64(200),
      version: Int64(5),
    );
    final localChapter = BackupChapter(
      url: '/chapter',
      name: 'Local chapter',
      chapterNumber: 7,
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupManga: [
        manga(chapters: [remoteChapter]),
      ],
    );
    final local = BackupMihon(
      backupManga: [
        manga(chapters: [localChapter]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_manga_chapter_missing_from_proposed'),
    );
  });

  test('duplicate local chapter URLs never authorize identity rebasing', () {
    final remoteChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 10',
      chapterNumber: 9.5,
      lastModifiedAt: Int64(200),
      version: Int64(5),
    );
    final local = BackupMihon(
      backupManga: [
        manga(
          chapters: [
            BackupChapter(
              url: '/chapter',
              name: 'Chapter 10',
              chapterNumber: 10,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
            BackupChapter(
              url: '/chapter',
              name: 'Chapter 11',
              chapterNumber: 11,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
      ],
    );
    final remote = BackupMihon(
      backupManga: [
        manga(chapters: [remoteChapter]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_manga_chapter_missing_from_proposed'),
    );
  });

  test('duplicate competing child URLs never authorize identity rebasing', () {
    final remote = BackupMihon(
      backupManga: [
        manga(
          chapters: [
            BackupChapter(
              url: '/chapter',
              name: 'Chapter 10',
              chapterNumber: 9.5,
              lastModifiedAt: Int64(200),
              version: Int64(5),
            ),
            BackupChapter(
              url: '/chapter',
              name: 'Chapter 11',
              chapterNumber: 11,
              lastModifiedAt: Int64(200),
              version: Int64(5),
            ),
          ],
        ),
      ],
      backupAnime: [
        anime(
          episodes: [
            BackupEpisode(
              url: '/episode',
              name: 'Episode 10',
              episodeNumber: 9.5,
              lastModifiedAt: Int64(200),
              version: Int64(5),
            ),
            BackupEpisode(
              url: '/episode',
              name: 'Episode 11',
              episodeNumber: 11,
              lastModifiedAt: Int64(200),
              version: Int64(5),
            ),
          ],
        ),
      ],
    );
    final local = BackupMihon(
      backupManga: [
        manga(
          chapters: [
            BackupChapter(
              url: '/chapter',
              name: 'Chapter 10',
              chapterNumber: 10,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
      ],
      backupAnime: [
        anime(
          episodes: [
            BackupEpisode(
              url: '/episode',
              name: 'Episode 10',
              episodeNumber: 10,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()).keys,
      containsAll({
        'local_manga_chapter_missing_from_proposed',
        'local_anime_episode_missing_from_proposed',
      }),
    );
  });

  test('still fails when the newer local chapter has genuine progress', () {
    final remoteChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 1',
      chapterNumber: 1,
      lastModifiedAt: Int64(100),
      version: Int64(5),
    );
    final localChapter = BackupChapter(
      url: '/chapter',
      name: 'Chapter 1',
      scanlator: 'Local group',
      read: true,
      bookmark: true,
      lastPageRead: Int64(12),
      chapterNumber: 1,
      lastModifiedAt: Int64(200),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupManga: [
        manga(chapters: [remoteChapter]),
      ],
    );
    final local = BackupMihon(
      backupManga: [
        manga(chapters: [localChapter]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_manga_chapter_clock_regressed'),
    );
  });

  test(
    'accepts an exact remote episode over a clock-only newer local projection',
    () {
      final remoteEpisode = BackupEpisode(
        url: '/episode',
        name: 'Episode 1',
        episodeNumber: 1,
        totalSeconds: Int64(1440),
        dateFetch: Int64(50),
        sourceOrder: Int64(9),
        lastModifiedAt: Int64(100),
        version: Int64(5),
      );
      final localEpisode = BackupEpisode(
        url: '/episode',
        name: 'Episode 1',
        scanlator: '',
        seen: false,
        bookmark: false,
        lastSecondSeen: Int64.ZERO,
        totalSeconds: Int64.ZERO,
        dateFetch: Int64.ZERO,
        dateUpload: Int64.ZERO,
        episodeNumber: 1,
        sourceOrder: Int64.ZERO,
        fillermark: false,
        summary: '',
        previewUrl: '',
        lastModifiedAt: Int64(200),
        version: Int64.ZERO,
      );
      final remote = BackupMihon(
        backupAnime: [
          anime(episodes: [remoteEpisode]),
        ],
      );
      final local = BackupMihon(
        backupAnime: [
          anime(episodes: [localEpisode]),
        ],
      );

      expect(
        failures(
          remote: remote,
          local: local,
          proposed: remote.deepCopy(),
          remoteWinsTies: true,
        ),
        isEmpty,
      );
    },
  );

  test('audits the same proven legacy episode-number rebase as the merger', () {
    final remoteEpisode = BackupEpisode(
      url: '/episode',
      name: 'Episode 10',
      episodeNumber: 9.5,
      totalSeconds: Int64(1440),
      dateFetch: Int64(50),
      sourceOrder: Int64(9),
      lastModifiedAt: Int64(100),
      version: Int64(5),
    );
    final localEpisode = BackupEpisode(
      url: '/episode',
      name: 'Episode 10',
      scanlator: '',
      seen: false,
      bookmark: false,
      lastSecondSeen: Int64.ZERO,
      totalSeconds: Int64.ZERO,
      dateFetch: Int64.ZERO,
      dateUpload: Int64.ZERO,
      episodeNumber: 10,
      sourceOrder: Int64.ZERO,
      fillermark: false,
      summary: '',
      previewUrl: '',
      lastModifiedAt: Int64(200),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupAnime: [
        anime(episodes: [remoteEpisode]),
      ],
    );
    final local = BackupMihon(
      backupAnime: [
        anime(episodes: [localEpisode]),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      proposed.backupAnime.single.episodes.single.writeToBuffer(),
      orderedEquals(remoteEpisode.writeToBuffer()),
    );
    expect(
      failures(
        remote: remote,
        local: local,
        proposed: proposed,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
  });

  test('still fails when the newer local episode has genuine progress', () {
    final remoteEpisode = BackupEpisode(
      url: '/episode',
      name: 'Episode 1',
      episodeNumber: 1,
      totalSeconds: Int64(1440),
      lastModifiedAt: Int64(100),
      version: Int64(5),
    );
    final localEpisode = BackupEpisode(
      url: '/episode',
      name: 'Episode 1',
      scanlator: 'Local group',
      seen: true,
      bookmark: true,
      lastSecondSeen: Int64(120),
      episodeNumber: 1,
      totalSeconds: Int64(1440),
      summary: 'Local summary',
      lastModifiedAt: Int64(200),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupAnime: [
        anime(episodes: [remoteEpisode]),
      ],
    );
    final local = BackupMihon(
      backupAnime: [
        anime(episodes: [localEpisode]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_anime_episode_clock_regressed'),
    );
  });

  test('same-URL unproven episode identity cannot satisfy a local row', () {
    final remoteEpisode = BackupEpisode(
      url: '/episode',
      name: 'Remote episode',
      episodeNumber: 2,
      lastModifiedAt: Int64(200),
      version: Int64(5),
    );
    final localEpisode = BackupEpisode(
      url: '/episode',
      name: 'Local episode',
      episodeNumber: 7,
      lastModifiedAt: Int64(100),
      version: Int64.ZERO,
    );
    final remote = BackupMihon(
      backupAnime: [
        anime(episodes: [remoteEpisode]),
      ],
    );
    final local = BackupMihon(
      backupAnime: [
        anime(episodes: [localEpisode]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_anime_episode_missing_from_proposed'),
    );
  });

  test('duplicate local episode URLs never authorize identity rebasing', () {
    final remoteEpisode = BackupEpisode(
      url: '/episode',
      name: 'Episode 10',
      episodeNumber: 9.5,
      lastModifiedAt: Int64(200),
      version: Int64(5),
    );
    final local = BackupMihon(
      backupAnime: [
        anime(
          episodes: [
            BackupEpisode(
              url: '/episode',
              name: 'Episode 10',
              episodeNumber: 10,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
            BackupEpisode(
              url: '/episode',
              name: 'Episode 11',
              episodeNumber: 11,
              lastModifiedAt: Int64(100),
              version: Int64.ZERO,
            ),
          ],
        ),
      ],
    );
    final remote = BackupMihon(
      backupAnime: [
        anime(episodes: [remoteEpisode]),
      ],
    );

    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_anime_episode_missing_from_proposed'),
    );
  });

  test(
    'does not exempt a proposed chapter that is not the exact remote row',
    () {
      final remoteChapter = BackupChapter(
        url: '/chapter',
        name: 'Chapter 1',
        chapterNumber: 1,
        dateFetch: Int64(50),
        lastModifiedAt: Int64(100),
        version: Int64(5),
      );
      final localChapter = BackupChapter(
        url: '/chapter',
        name: 'Chapter 1',
        chapterNumber: 1,
        dateFetch: Int64.ZERO,
        lastModifiedAt: Int64(200),
        version: Int64.ZERO,
      );
      final remote = BackupMihon(
        backupManga: [
          manga(chapters: [remoteChapter]),
        ],
      );
      final local = BackupMihon(
        backupManga: [
          manga(chapters: [localChapter]),
        ],
      );
      final proposedChapter = remoteChapter.deepCopy()..dateFetch = Int64(51);
      final proposed = BackupMihon(
        backupManga: [
          manga(chapters: [proposedChapter]),
        ],
      );

      expect(
        failures(remote: remote, local: local, proposed: proposed),
        contains('local_manga_chapter_clock_regressed'),
      );
    },
  );

  test('uses the winning parent snapshot for category membership', () {
    final remote = BackupMihon(
      backupCategories: [category('Reading', 7)],
      backupAnimeCategories: [category('Watching', 9)],
      backupManga: [
        manga(version: 1, categories: [7]),
      ],
      backupAnime: [anime(version: 2)],
    );
    final local = BackupMihon(
      backupCategories: [category('Reading', 1)],
      backupAnimeCategories: [category('Watching', 2)],
      backupManga: [manga(version: 2)],
      backupAnime: [
        anime(version: 1, categories: [2]),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );

    expect(failures(remote: remote, local: local, proposed: proposed), isEmpty);
  });

  test('protects local custom titles symmetrically', () {
    final local = manga(customTitle: 'Local title');
    final result = failures(
      remote: BackupMihon(),
      local: BackupMihon(backupManga: [local]),
      proposed: BackupMihon(backupManga: [manga()]),
    );

    expect(result, contains('local_custom_title_not_retained'));
  });

  test('accepts a strictly newer competing custom title', () {
    final local = manga(version: 1, customTitle: 'Local title');
    final remote = manga(version: 2, customTitle: 'Remote title');

    expect(
      failures(
        remote: BackupMihon(backupManga: [remote]),
        local: BackupMihon(backupManga: [local]),
        proposed: BackupMihon(backupManga: [remote]),
      ),
      isEmpty,
    );
  });

  test('accepts an equal favorite clock with a higher parent counter', () {
    final deleted = manga(favorite: false, favoriteClock: 100, version: 1);
    final restored = manga(favorite: true, favoriteClock: 100, version: 2);
    final remote = BackupMihon(backupManga: [deleted]);
    final local = BackupMihon(backupManga: [restored]);
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );

    expect(failures(remote: remote, local: local, proposed: proposed), isEmpty);
  });

  test('does not exempt a nonportable tracking deletion marker', () {
    final remote = manga(tracking: [BackupTracking(syncId: 4)]);
    final local = manga();
    final result = failures(
      remote: BackupMihon(backupManga: [remote]),
      local: BackupMihon(backupManga: [local]),
      proposed: BackupMihon(backupManga: [local]),
      localTrackingDeletions: const {(source: 1, url: '/manga', syncId: 4)},
    );

    expect(result, contains('remote_manga_tracking_missing_from_proposed'));
  });

  group('portable media values and unknown envelopes', () {
    test('rejects remote-only manga metadata and parent unknown changes', () {
      final remoteManga = manga(version: 5, modifiedAt: 100)
        ..description = 'Remote description'
        ..unknownFields.mergeVarintField(900, Int64(1));
      final changedMetadata = remoteManga.deepCopy()
        ..description = 'Changed description'
        ..version = Int64(6)
        ..lastModifiedAt = Int64(200);
      final changedUnknown = remoteManga.deepCopy()
        ..unknownFields.clear()
        ..version = Int64(6)
        ..lastModifiedAt = Int64(200);

      expect(
        failures(
          remote: BackupMihon(backupManga: [remoteManga]),
          local: BackupMihon(),
          proposed: BackupMihon(backupManga: [changedMetadata]),
        ),
        contains('remote_manga_portable_values_changed'),
      );
      expect(
        failures(
          remote: BackupMihon(backupManga: [remoteManga]),
          local: BackupMihon(),
          proposed: BackupMihon(backupManga: [changedUnknown]),
        ),
        contains('remote_manga_unknown_fields_not_retained'),
      );
    });

    test('rejects remote-only anime metadata and parent unknown changes', () {
      final remoteAnime = anime(version: 5, modifiedAt: 100)
        ..description = 'Remote description'
        ..unknownFields.mergeVarintField(900, Int64(1));
      final changedMetadata = remoteAnime.deepCopy()
        ..description = 'Changed description'
        ..version = Int64(6)
        ..lastModifiedAt = Int64(200);
      final changedUnknown = remoteAnime.deepCopy()
        ..unknownFields.clear()
        ..version = Int64(6)
        ..lastModifiedAt = Int64(200);

      expect(
        failures(
          remote: BackupMihon(backupAnime: [remoteAnime]),
          local: BackupMihon(),
          proposed: BackupMihon(backupAnime: [changedMetadata]),
        ),
        contains('remote_anime_portable_values_changed'),
      );
      expect(
        failures(
          remote: BackupMihon(backupAnime: [remoteAnime]),
          local: BackupMihon(),
          proposed: BackupMihon(backupAnime: [changedUnknown]),
        ),
        contains('remote_anime_unknown_fields_not_retained'),
      );
    });

    final chapterMutations =
        <({String name, void Function(BackupChapter) mutate})>[
          (name: 'read', mutate: (row) => row.read = false),
          (name: 'bookmark', mutate: (row) => row.bookmark = false),
          (name: 'page progress', mutate: (row) => row.lastPageRead = Int64(0)),
        ];
    for (final change in chapterMutations) {
      test('rejects remote-only chapter ${change.name} loss', () {
        final remoteChapter = BackupChapter(
          url: '/chapter',
          name: 'Chapter 1',
          chapterNumber: 1,
          read: true,
          bookmark: true,
          lastPageRead: Int64(12),
          lastModifiedAt: Int64(100),
          version: Int64(5),
        );
        final proposedChapter = remoteChapter.deepCopy()
          ..lastModifiedAt = Int64(200)
          ..version = Int64(6);
        change.mutate(proposedChapter);

        expect(
          failures(
            remote: BackupMihon(
              backupManga: [
                manga(chapters: [remoteChapter]),
              ],
            ),
            local: BackupMihon(),
            proposed: BackupMihon(
              backupManga: [
                manga(chapters: [proposedChapter]),
              ],
            ),
          ),
          contains('remote_manga_chapter_portable_values_changed'),
        );
      });
    }

    test('rejects a changed remote-only chapter unknown envelope', () {
      final remoteChapter = BackupChapter(
        url: '/chapter',
        name: 'Chapter 1',
        chapterNumber: 1,
        lastModifiedAt: Int64(100),
        version: Int64(5),
      )..unknownFields.mergeVarintField(900, Int64(1));
      final proposedChapter = remoteChapter.deepCopy()
        ..unknownFields.clear()
        ..lastModifiedAt = Int64(200)
        ..version = Int64(6);

      expect(
        failures(
          remote: BackupMihon(
            backupManga: [
              manga(chapters: [remoteChapter]),
            ],
          ),
          local: BackupMihon(),
          proposed: BackupMihon(
            backupManga: [
              manga(chapters: [proposedChapter]),
            ],
          ),
        ),
        contains('remote_manga_chapter_unknown_fields_not_retained'),
      );
    });

    final episodeMutations =
        <({String name, void Function(BackupEpisode) mutate})>[
          (name: 'seen', mutate: (row) => row.seen = false),
          (name: 'bookmark', mutate: (row) => row.bookmark = false),
          (
            name: 'playback progress',
            mutate: (row) => row.lastSecondSeen = Int64(0),
          ),
        ];
    for (final change in episodeMutations) {
      test('rejects remote-only episode ${change.name} loss', () {
        final remoteEpisode = BackupEpisode(
          url: '/episode',
          name: 'Episode 1',
          episodeNumber: 1,
          seen: true,
          bookmark: true,
          lastSecondSeen: Int64(120),
          lastModifiedAt: Int64(100),
          version: Int64(5),
        );
        final proposedEpisode = remoteEpisode.deepCopy()
          ..lastModifiedAt = Int64(200)
          ..version = Int64(6);
        change.mutate(proposedEpisode);

        expect(
          failures(
            remote: BackupMihon(
              backupAnime: [
                anime(episodes: [remoteEpisode]),
              ],
            ),
            local: BackupMihon(),
            proposed: BackupMihon(
              backupAnime: [
                anime(episodes: [proposedEpisode]),
              ],
            ),
          ),
          contains('remote_anime_episode_portable_values_changed'),
        );
      });
    }

    test('rejects a changed remote-only episode unknown envelope', () {
      final remoteEpisode = BackupEpisode(
        url: '/episode',
        name: 'Episode 1',
        episodeNumber: 1,
        lastModifiedAt: Int64(100),
        version: Int64(5),
      )..unknownFields.mergeVarintField(900, Int64(1));
      final proposedEpisode = remoteEpisode.deepCopy()
        ..unknownFields.clear()
        ..lastModifiedAt = Int64(200)
        ..version = Int64(6);

      expect(
        failures(
          remote: BackupMihon(
            backupAnime: [
              anime(episodes: [remoteEpisode]),
            ],
          ),
          local: BackupMihon(),
          proposed: BackupMihon(
            backupAnime: [
              anime(episodes: [proposedEpisode]),
            ],
          ),
        ),
        contains('remote_anime_episode_unknown_fields_not_retained'),
      );
    });

    test('rejects changed remote-only history and tracking envelopes', () {
      final remoteHistory = BackupHistory(
        url: '/chapter',
        lastRead: Int64(100),
        readDuration: Int64(5000),
      )..unknownFields.mergeVarintField(900, Int64(1));
      final remoteTracking = BackupTracking(syncId: 2)
        ..unknownFields.mergeVarintField(901, Int64(2));
      final proposedHistory = remoteHistory.deepCopy()..unknownFields.clear();
      final proposedTracking = remoteTracking.deepCopy()..unknownFields.clear();

      final result = failures(
        remote: BackupMihon(
          backupManga: [
            manga(history: [remoteHistory], tracking: [remoteTracking]),
          ],
        ),
        local: BackupMihon(),
        proposed: BackupMihon(
          backupManga: [
            manga(history: [proposedHistory], tracking: [proposedTracking]),
          ],
        ),
      );

      expect(
        result.keys,
        containsAll({
          'remote_manga_history_unknown_fields_not_retained',
          'remote_manga_tracking_unknown_fields_not_retained',
        }),
      );
    });

    final trackingMutations =
        <({String name, void Function(BackupTracking) mutate})>[
          (name: 'score', mutate: (row) => row.score = 3.5),
          (name: 'status', mutate: (row) => row.status = 4),
          (
            name: 'reading progress',
            mutate: (row) => row.lastChapterRead = 3.0,
          ),
        ];
    for (final change in trackingMutations) {
      test('rejects remote-only tracking ${change.name} mutation', () {
        final remoteTracking = BackupTracking(
          syncId: 2,
          score: 8.5,
          status: 2,
          lastChapterRead: 12.5,
          mediaId: Int64(123),
        );
        final proposedTracking = remoteTracking.deepCopy();
        change.mutate(proposedTracking);

        expect(
          failures(
            remote: BackupMihon(
              backupManga: [
                manga(version: 5, modifiedAt: 100, tracking: [remoteTracking]),
              ],
            ),
            local: BackupMihon(),
            proposed: BackupMihon(
              backupManga: [
                manga(
                  version: 6,
                  modifiedAt: 200,
                  tracking: [proposedTracking],
                ),
              ],
            ),
          ),
          contains('remote_manga_tracking_portable_values_changed'),
        );
      });
    }
  });

  test('pairs a proven manga parent rebase in both audit directions', () {
    final remote = BackupMihon(
      backupCategories: [category('Remote', 7)],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/shared',
          title: 'Canonical title',
          customTitle: 'Display title',
          favorite: true,
          favoriteModifiedAt: Int64(100),
          categories: [Int64(7)],
          tracking: [BackupTracking(syncId: 1)],
          lastModifiedAt: Int64(100),
          version: Int64(7),
        ),
      ],
    );
    final local = BackupMihon(
      backupCategories: [category('Local', 2)],
      backupManga: [
        BackupManga(
          source: Int64(1),
          url: '/shared',
          title: 'Display title',
          favorite: false,
          favoriteModifiedAt: Int64(200),
          categories: [Int64(2)],
          tracking: [BackupTracking(syncId: 2)],
          lastModifiedAt: Int64(200),
          version: Int64.ZERO,
        ),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      failures(
        remote: remote,
        local: local,
        proposed: proposed,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
  });

  test('pairs a proven anime parent rebase in both audit directions', () {
    final remote = BackupMihon(
      backupAnimeCategories: [category('Remote', 7)],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/shared',
          title: 'Canonical title',
          favorite: true,
          favoriteModifiedAt: Int64(100),
          categories: [Int64(7)],
          tracking: [BackupTracking(syncId: 1)],
          lastModifiedAt: Int64(100),
          version: Int64(7),
        ),
      ],
    );
    final local = BackupMihon(
      backupAnimeCategories: [category('Local', 2)],
      backupAnime: [
        BackupAnime(
          source: Int64(2),
          url: '/shared',
          title: 'Canonical title',
          author: '',
          favorite: false,
          favoriteModifiedAt: Int64(200),
          categories: [Int64(2)],
          tracking: [BackupTracking(syncId: 2)],
          lastModifiedAt: Int64(200),
          version: Int64.ZERO,
        ),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      failures(
        remote: remote,
        local: local,
        proposed: proposed,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
  });

  test('uses the declared tie authority for parent portable values', () {
    final remoteManga = manga(version: 5)..description = 'Remote';
    final localManga = manga(version: 5)..description = 'Local';
    final remote = BackupMihon(backupManga: [remoteManga]);
    final local = BackupMihon(backupManga: [localManga]);

    expect(
      failures(
        remote: remote,
        local: local,
        proposed: remote.deepCopy(),
        remoteWinsTies: true,
      ),
      isEmpty,
    );
    expect(
      failures(remote: remote, local: local, proposed: remote.deepCopy()),
      contains('local_manga_portable_values_changed'),
    );
  });

  test('uses tie authority for category and tracking winner state', () {
    final remote = BackupMihon(
      backupCategories: [category('Remote', 7)],
      backupManga: [
        manga(
          version: 5,
          modifiedAt: 100,
          categories: [7],
          tracking: [
            BackupTracking(syncId: 2, score: 8.5, lastChapterRead: 12.5),
          ],
        ),
      ],
    );
    final local = BackupMihon(
      backupCategories: [category('Local', 2)],
      backupManga: [
        manga(
          version: 5,
          modifiedAt: 100,
          categories: [2],
          tracking: [
            BackupTracking(syncId: 2, score: 3.0, lastChapterRead: 4.0),
          ],
        ),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
      remoteWinsProjectionTies: true,
    );

    expect(
      failures(
        remote: remote,
        local: local,
        proposed: proposed,
        remoteWinsTies: true,
      ),
      isEmpty,
    );
    final wrongPolicy = failures(
      remote: remote,
      local: local,
      proposed: proposed,
    );
    expect(
      wrongPolicy.keys,
      containsAll({
        'local_manga_tracking_portable_values_changed',
        'local_manga_category_membership_missing_from_proposed',
      }),
    );
  });

  group('ordered category payload audit', () {
    final categoryMutations =
        <({String name, void Function(BackupCategory) mutate})>[
          (name: 'order', mutate: (row) => row.order = Int64(6)),
          (name: 'id', mutate: (row) => row.id = Int64(52)),
          (name: 'flags', mutate: (row) => row.flags = Int64(12)),
          (name: 'hidden', mutate: (row) => row.hidden = false),
          (name: 'hidden presence', mutate: (row) => row.clearHidden()),
        ];
    for (final change in categoryMutations) {
      test('rejects same-name manga category ${change.name} mutation', () {
        final remoteCategory = BackupCategory(
          name: 'Reading',
          order: Int64(5),
          id: Int64(51),
          flags: Int64(11),
          hidden: true,
        );
        final proposedCategory = remoteCategory.deepCopy();
        change.mutate(proposedCategory);

        expect(
          failures(
            remote: BackupMihon(backupCategories: [remoteCategory]),
            local: BackupMihon(),
            proposed: BackupMihon(backupCategories: [proposedCategory]),
          ),
          contains('manga_category_portable_values_changed'),
        );
      });
    }

    test('rejects a changed same-name category unknown envelope', () {
      final remoteCategory = BackupCategory(name: 'Reading', order: Int64(5))
        ..unknownFields.mergeVarintField(1200, Int64(1));
      final proposedCategory = remoteCategory.deepCopy()..unknownFields.clear();

      expect(
        failures(
          remote: BackupMihon(backupCategories: [remoteCategory]),
          local: BackupMihon(),
          proposed: BackupMihon(backupCategories: [proposedCategory]),
        ),
        contains('manga_category_unknown_fields_not_retained'),
      );
    });

    test('rejects lost, extra, and duplicate exact category rows', () {
      final reading = category('Reading', 1);
      final extra = category('Extra', 2);
      final result = failures(
        remote: BackupMihon(backupAnimeCategories: [reading]),
        local: BackupMihon(),
        proposed: BackupMihon(backupAnimeCategories: [extra, extra.deepCopy()]),
      );

      expect(
        result.keys,
        containsAll({
          'proposed_anime_category_duplicate_exact_name',
          'anime_category_missing_from_proposed',
          'anime_category_extra_in_proposed',
        }),
      );
    });

    test('accepts winner fields and unknown order from a real merge', () {
      final localManga = BackupCategory(
        name: 'Reading',
        order: Int64(9),
        id: Int64(12),
        flags: Int64(1),
        hidden: false,
      )..unknownFields.mergeVarintField(1200, Int64(1));
      final remoteManga = BackupCategory(
        name: 'Reading',
        order: Int64(3),
        id: Int64(99),
        flags: Int64(7),
        hidden: true,
      )..unknownFields.mergeVarintField(1200, Int64(2));
      final localAnime = BackupCategory(
        name: 'Watching',
        order: Int64(4),
        hidden: false,
      )..unknownFields.mergeVarintField(1200, Int64(3));
      final remoteAnime = BackupCategory(
        name: 'Watching',
        order: Int64(4),
        id: Int64(100),
        flags: Int64(8),
        hidden: true,
      )..unknownFields.mergeVarintField(1200, Int64(4));
      final local = BackupMihon(
        backupCategories: [localManga],
        backupAnimeCategories: [localAnime],
      );
      final remote = BackupMihon(
        backupCategories: [remoteManga],
        backupAnimeCategories: [remoteAnime],
      );
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
      );

      expect(
        failures(remote: remote, local: local, proposed: proposed),
        isEmpty,
      );
      expect(proposed.backupCategories.single.id, Int64(99));
      expect(proposed.backupCategories.single.flags, Int64(7));
      expect(proposed.backupCategories.single.hidden, isFalse);
      expect(
        proposed.backupCategories.single.unknownFields.getField(1200)!.varints,
        [Int64(2), Int64(1)],
      );
      expect(proposed.backupAnimeCategories.single.hidden, isTrue);
      expect(
        proposed.backupAnimeCategories.single.unknownFields
            .getField(1200)!
            .varints,
        [Int64(3), Int64(4)],
      );
    });

    test('accepts deterministic local-only order collision allocation', () {
      final remote = BackupMihon(
        backupCategories: [category('Reading', 4), category('Reference', 4)],
        backupAnimeCategories: [
          category('Watching', 6),
          category('Reference', 6),
        ],
      );
      final local = BackupMihon(
        backupCategories: [category('Local manga', 4)],
        backupAnimeCategories: [category('Local anime', 6)],
      );
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
      );

      expect(
        failures(remote: remote, local: local, proposed: proposed),
        isEmpty,
      );
      expect(
        proposed.backupCategories
            .singleWhere((row) => row.name == 'Local manga')
            .order,
        Int64.ZERO,
      );
      expect(
        proposed.backupAnimeCategories
            .singleWhere((row) => row.name == 'Local anime')
            .order,
        Int64.ZERO,
      );
    });

    test('accepts case-normalized remote ambiguity without local guessing', () {
      final remote = BackupMihon(
        backupCategories: [category('Reading', 1), category(' reading ', 2)],
        backupAnimeCategories: [
          category('Watching', 3),
          category('watching', 4),
        ],
      );
      final local = BackupMihon(
        backupCategories: [category('READING', 9)],
        backupAnimeCategories: [category('WATCHING', 9)],
      );
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
      );

      expect(
        failures(remote: remote, local: local, proposed: proposed),
        isEmpty,
      );
      expect(proposed.backupCategories.map((row) => row.name), [
        'Reading',
        ' reading ',
      ]);
      expect(proposed.backupAnimeCategories.map((row) => row.name), [
        'Watching',
        'watching',
      ]);
    });
  });

  group('exact proposed identity union', () {
    test('rejects proposed-only manga and anime parents', () {
      final result = failures(
        remote: BackupMihon(),
        local: BackupMihon(),
        proposed: BackupMihon(
          backupManga: [manga(url: '/invented-manga')],
          backupAnime: [anime(url: '/invented-anime')],
        ),
      );

      expect(
        result.keys,
        containsAll({'manga_extra_in_proposed', 'anime_extra_in_proposed'}),
      );
    });

    test('rejects proposed-only child and history rows', () {
      final remote = BackupMihon(
        backupManga: [manga()],
        backupAnime: [anime()],
      );
      final proposed = remote.deepCopy();
      proposed.backupManga.single
        ..chapters.add(
          BackupChapter(
            url: '/invented-chapter',
            name: 'Invented',
            chapterNumber: 1,
          ),
        )
        ..history.add(
          BackupHistory(url: '/invented-manga-history', lastRead: Int64(1)),
        );
      proposed.backupAnime.single
        ..episodes.add(
          BackupEpisode(
            url: '/invented-episode',
            name: 'Invented',
            episodeNumber: 1,
          ),
        )
        ..history.add(
          BackupHistory(url: '/invented-anime-history', lastRead: Int64(1)),
        );

      final result = failures(
        remote: remote,
        local: BackupMihon(),
        proposed: proposed,
      );
      expect(
        result.keys,
        containsAll({
          'manga_chapter_extra_in_proposed',
          'manga_history_extra_in_proposed',
          'anime_episode_extra_in_proposed',
          'anime_history_extra_in_proposed',
        }),
      );
    });
  });

  group('exact favorite projection', () {
    for (final media in ['manga', 'anime']) {
      BackupMihon backup({required bool? favorite, int? clock}) =>
          media == 'manga'
          ? BackupMihon(
              backupManga: [manga(favorite: favorite, favoriteClock: clock)],
            )
          : BackupMihon(
              backupAnime: [anime(favorite: favorite, favoriteClock: clock)],
            );

      test('$media rejects a forged higher same-state favorite clock', () {
        final remote = backup(favorite: true, clock: 100);
        final local = backup(favorite: true, clock: 100);
        final proposed = const ChimahonSyncMerger().merge(
          local: local,
          remote: remote,
        );
        if (media == 'manga') {
          proposed.backupManga.single.favoriteModifiedAt = Int64(999);
        } else {
          proposed.backupAnime.single.favoriteModifiedAt = Int64(999);
        }

        final result = failures(
          remote: remote,
          local: local,
          proposed: proposed,
        );
        expect(
          result.keys.any((code) => code.contains('${media}_favorite_clock')),
          isTrue,
        );
      });

      test(
        '$media rejects a manufactured clock when both states are absent',
        () {
          final remote = backup(favorite: null);
          final local = backup(favorite: null);
          final proposed = const ChimahonSyncMerger().merge(
            local: local,
            remote: remote,
          );
          if (media == 'manga') {
            proposed.backupManga.single.favoriteModifiedAt = Int64(999);
          } else {
            proposed.backupAnime.single.favoriteModifiedAt = Int64(999);
          }

          final result = failures(
            remote: remote,
            local: local,
            proposed: proposed,
          );
          expect(
            result.keys.any((code) => code.contains('${media}_favorite_clock')),
            isTrue,
          );
        },
      );

      test('$media rejects dropping an expected explicit true field', () {
        final remote = backup(favorite: true, clock: 100);
        final local = backup(favorite: true, clock: 100);
        final proposed = const ChimahonSyncMerger().merge(
          local: local,
          remote: remote,
        );
        if (media == 'manga') {
          proposed.backupManga.single.clearFavorite();
        } else {
          proposed.backupAnime.single.clearFavorite();
        }

        final result = failures(
          remote: remote,
          local: local,
          proposed: proposed,
        );
        expect(
          result.keys.any((code) => code.contains('${media}_favorite_state')),
          isTrue,
        );
      });
    }
  });

  group('exact record clock projection', () {
    test('rejects forged manga and anime parent clocks', () {
      final remote = BackupMihon(
        backupManga: [manga(version: 2, modifiedAt: 20)],
        backupAnime: [anime(version: 2, modifiedAt: 20)],
      );
      final local = remote.deepCopy();
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
      );
      proposed.backupManga.single
        ..version = Int64(999)
        ..lastModifiedAt = Int64(999);
      proposed.backupAnime.single
        ..version = Int64(999)
        ..lastModifiedAt = Int64(999);

      final result = failures(remote: remote, local: local, proposed: proposed);
      expect(
        result.keys,
        containsAll({
          'remote_manga_record_clock_regressed',
          'remote_anime_record_clock_regressed',
        }),
      );
    });

    test('rejects forged chapter and episode clocks', () {
      final chapter = BackupChapter(
        url: '/chapter-clock',
        name: 'Chapter',
        chapterNumber: 1,
        lastModifiedAt: Int64(20),
        version: Int64(2),
      );
      final episode = BackupEpisode(
        url: '/episode-clock',
        name: 'Episode',
        episodeNumber: 1,
        lastModifiedAt: Int64(20),
        version: Int64(2),
      );
      final remote = BackupMihon(
        backupManga: [
          manga(chapters: [chapter]),
        ],
        backupAnime: [
          anime(episodes: [episode]),
        ],
      );
      final local = remote.deepCopy();
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
      );
      proposed.backupManga.single.chapters.single
        ..version = Int64(999)
        ..lastModifiedAt = Int64(999);
      proposed.backupAnime.single.episodes.single
        ..version = Int64(999)
        ..lastModifiedAt = Int64(999);

      final result = failures(remote: remote, local: local, proposed: proposed);
      expect(
        result.keys,
        containsAll({
          'remote_manga_chapter_clock_regressed',
          'remote_anime_episode_clock_regressed',
        }),
      );
    });

    for (final remoteWinsTies in [false, true]) {
      test(
        'accepts v0 parent promotion with remoteWinsTies=$remoteWinsTies',
        () {
          final remoteManga = manga(version: 7, modifiedAt: 100);
          final localManga = manga(version: 0, modifiedAt: 200)
            ..description = 'Local manga edit';
          final remoteAnime = anime(version: 9, modifiedAt: 100);
          final localAnime = anime(version: 0, modifiedAt: 200)
            ..description = 'Local anime edit';
          final remote = BackupMihon(
            backupManga: [remoteManga],
            backupAnime: [remoteAnime],
          );
          final local = BackupMihon(
            backupManga: [localManga],
            backupAnime: [localAnime],
          );
          final proposed = const ChimahonSyncMerger().merge(
            local: local,
            remote: remote,
            remoteWinsProjectionTies: remoteWinsTies,
          );

          expect(proposed.backupManga.single.version, Int64(8));
          expect(proposed.backupAnime.single.version, Int64(10));
          expect(
            failures(
              remote: remote,
              local: local,
              proposed: proposed,
              remoteWinsTies: remoteWinsTies,
            ),
            isEmpty,
          );
        },
      );

      test(
        'accepts v0 child promotion with remoteWinsTies=$remoteWinsTies',
        () {
          final remoteChapter = BackupChapter(
            url: '/promoted-chapter',
            name: 'Chapter',
            chapterNumber: 1,
            read: false,
            lastModifiedAt: Int64(100),
            version: Int64(7),
          );
          final localChapter = remoteChapter.deepCopy()
            ..read = true
            ..lastModifiedAt = Int64(200)
            ..version = Int64.ZERO;
          final remoteEpisode = BackupEpisode(
            url: '/promoted-episode',
            name: 'Episode',
            episodeNumber: 1,
            seen: false,
            lastModifiedAt: Int64(100),
            version: Int64(9),
          );
          final localEpisode = remoteEpisode.deepCopy()
            ..seen = true
            ..lastModifiedAt = Int64(200)
            ..version = Int64.ZERO;
          final remote = BackupMihon(
            backupManga: [
              manga(chapters: [remoteChapter]),
            ],
            backupAnime: [
              anime(episodes: [remoteEpisode]),
            ],
          );
          final local = BackupMihon(
            backupManga: [
              manga(chapters: [localChapter]),
            ],
            backupAnime: [
              anime(episodes: [localEpisode]),
            ],
          );
          final proposed = const ChimahonSyncMerger().merge(
            local: local,
            remote: remote,
            remoteWinsProjectionTies: remoteWinsTies,
          );

          expect(proposed.backupManga.single.chapters.single.version, Int64(8));
          expect(
            proposed.backupAnime.single.episodes.single.version,
            Int64(10),
          );
          expect(
            failures(
              remote: remote,
              local: local,
              proposed: proposed,
              remoteWinsTies: remoteWinsTies,
            ),
            isEmpty,
          );
        },
      );

      test(
        'accepts favorite override bump with remoteWinsTies=$remoteWinsTies',
        () {
          final remote = BackupMihon(
            backupManga: [
              manga(
                favorite: true,
                favoriteClock: 100,
                version: 2,
                modifiedAt: 100,
              ),
            ],
            backupAnime: [
              anime(
                favorite: true,
                favoriteClock: 100,
                version: 2,
                modifiedAt: 100,
              ),
            ],
          );
          final local = BackupMihon(
            backupManga: [
              manga(
                favorite: false,
                favoriteClock: 300,
                version: 1,
                modifiedAt: 100,
              ),
            ],
            backupAnime: [
              anime(
                favorite: false,
                favoriteClock: 300,
                version: 1,
                modifiedAt: 100,
              ),
            ],
          );
          final proposed = const ChimahonSyncMerger().merge(
            local: local,
            remote: remote,
            remoteWinsProjectionTies: remoteWinsTies,
          );

          expect(proposed.backupManga.single.version, Int64(3));
          expect(proposed.backupAnime.single.version, Int64(3));
          expect(proposed.backupManga.single.lastModifiedAt, Int64(300));
          expect(proposed.backupAnime.single.lastModifiedAt, Int64(300));
          expect(
            failures(
              remote: remote,
              local: local,
              proposed: proposed,
              remoteWinsTies: remoteWinsTies,
            ),
            isEmpty,
          );
        },
      );
    }
  });

  test('rejects extra and reordered winning category memberships', () {
    final remote = BackupMihon(
      backupCategories: [category('Reading', 1), category('Reference', 2)],
      backupAnimeCategories: [
        category('Watching', 3),
        category('Reference', 4),
      ],
      backupManga: [
        manga(categories: [1]),
      ],
      backupAnime: [
        anime(categories: [3, 4]),
      ],
    );
    final local = remote.deepCopy();
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    proposed.backupManga.single.categories.add(Int64(2));
    proposed.backupAnime.single.categories
      ..clear()
      ..addAll([Int64(4), Int64(3)]);

    final result = failures(remote: remote, local: local, proposed: proposed);
    expect(
      result.keys,
      containsAll({
        'remote_manga_category_membership_missing_from_proposed',
        'remote_anime_category_membership_missing_from_proposed',
      }),
    );
  });

  test(
    'exact-name category identities prevent false remote projection retention',
    () {
      final remoteManga = manga(version: 5, modifiedAt: 100, categories: [1]);
      final localManga = manga(version: 0, modifiedAt: 200, categories: [9]);
      final remoteAnime = anime(version: 7, modifiedAt: 100, categories: [1]);
      final localAnime = anime(version: 0, modifiedAt: 200, categories: [9]);
      final remote = BackupMihon(
        backupCategories: [category('Reading', 1), category('READING', 8)],
        backupAnimeCategories: [
          category('Watching', 1),
          category('WATCHING', 8),
        ],
        backupManga: [remoteManga],
        backupAnime: [remoteAnime],
      );
      final local = BackupMihon(
        backupCategories: [category('Reading', 0), category('READING', 9)],
        backupAnimeCategories: [
          category('Watching', 0),
          category('WATCHING', 9),
        ],
        backupManga: [localManga],
        backupAnime: [localAnime],
      );
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
        remoteWinsProjectionTies: true,
      );

      expect(proposed.backupManga.single.version, Int64(6));
      expect(proposed.backupManga.single.categories, [Int64(8)]);
      expect(proposed.backupAnime.single.version, Int64(8));
      expect(proposed.backupAnime.single.categories, [Int64(8)]);
      expect(
        failures(
          remote: remote,
          local: local,
          proposed: proposed,
          remoteWinsTies: true,
        ),
        isEmpty,
      );

      final forgedRemote = proposed.deepCopy();
      forgedRemote.backupManga
        ..clear()
        ..add(remoteManga);
      forgedRemote.backupAnime
        ..clear()
        ..add(remoteAnime);
      final forgedFailures = failures(
        remote: remote,
        local: local,
        proposed: forgedRemote,
        remoteWinsTies: true,
      );
      expect(
        forgedFailures.keys,
        containsAll({
          'local_manga_record_clock_regressed',
          'local_anime_record_clock_regressed',
          'local_manga_category_membership_missing_from_proposed',
          'local_anime_category_membership_missing_from_proposed',
        }),
      );
    },
  );
}
