import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSavedSearch.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/sync/chimahon_local_intent_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

void main() {
  const audit = ChimahonLocalIntentSafetyAudit();

  test('accepts a complete merger result and reports an additive novel', () {
    final local = _completeLocal();
    local.unknownFields
      ..mergeVarintField(900, Int64(1))
      ..mergeVarintField(901, Int64(2));
    final remote = BackupMihon()
      ..unknownFields.mergeVarintField(901, Int64(99));
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );
    final result = _run(
      audit,
      local: local,
      remote: remote,
      proposed: proposed,
    );

    expect(result.failures, isEmpty);
    expect(result.observations['local_only_novel_records'], hasLength(1));
    expect(
      result.observations['local_remote_novel_title_only_collisions'],
      isEmpty,
    );
    expect(
      result.observations['local_remote_novel_near_identity_collisions'],
      isEmpty,
    );
  });

  test('rejects missing effective-local novels and categories', () {
    final local = _completeLocal()
      ..unknownFields.mergeVarintField(900, Int64(1));
    final result = _run(
      audit,
      local: local,
      remote: BackupMihon(),
      proposed: BackupMihon(),
    );

    expect(
      result.failures.keys,
      containsAll({
        'local_novel_missing_from_proposed',
        'local_novel_category_missing_from_proposed',
      }),
    );
  });

  test('rejects changed keyed rows, regressed stats, and novel losses', () {
    final local = _completeLocal()
      ..unknownFields.mergeVarintField(900, Int64(1));
    final localNovel = local.backupNovels.single;
    final proposed = BackupMihon(
      backupSources: [BackupSource(sourceId: Int64(42), name: 'Changed')],
      backupAnimeSources: [
        BackupSource(sourceId: Int64(84), name: 'Changed anime'),
      ],
      backupExtensionRepo: [_repo('https://manga.example', name: 'Changed')],
      backupAnimeExtensionRepo: [
        _repo('https://anime.example', name: 'Changed'),
      ],
      backupSavedSearches: [
        BackupSavedSearch(
          source: Int64(42),
          name: 'Learning',
          query: 'changed',
        ),
      ],
      backupFeeds: [
        BackupFeed(
          source: Int64(42),
          global: false,
          savedSearch: BackupSavedSearch(
            source: Int64(42),
            name: 'Learning',
            query: 'changed',
          ),
        ),
      ],
      backupNovels: [
        BackupNovel(
          id: localNovel.id,
          title: localNovel.title,
          author: localNovel.author,
          chapterIndex: 1,
          progress: 0.1,
          characterCount: 10,
          lastModified: Int64(10),
          stats: [
            BackupNovelStat(
              dateKey: '2026-07-18',
              charactersRead: 1,
              readingTime: 1,
              lastStatisticModified: Int64(10),
            ),
          ],
        ),
      ],
      backupNovelCategories: [
        BackupNovelCategory(
          id: 'different',
          name: 'Different',
          order: Int64.ZERO,
        ),
      ],
      backupMangaStats: [
        BackupMangaStats(
          dateKey: '2026-07-18',
          mangaId: Int64(7),
          charactersRead: 1,
          readingTime: Int64(1),
        ),
      ],
      backupAnkiStats: [
        BackupAnkiStats(
          dateKey: '2026-07-18',
          profileId: 'profile',
          titleId: 'title',
          mangaCards: 1,
          novelCards: 1,
        ),
      ],
    )..unknownFields.mergeVarintField(900, Int64(2));
    final result = _run(
      audit,
      local: local,
      remote: BackupMihon(),
      proposed: proposed,
    );

    expect(
      result.failures.keys,
      containsAll({
        'local_novel_progress_regressed_in_proposed',
        'local_novel_stat_regressed_in_proposed',
        'local_novel_category_missing_from_proposed',
        'local_novel_category_membership_missing_from_proposed',
      }),
    );
  });

  test('accepts semantic novel category ID remapping by name', () {
    final localNovel = _novel(categoryIds: const ['local-category']);
    final local = BackupMihon(
      backupNovels: [localNovel],
      backupNovelCategories: [
        BackupNovelCategory(
          id: 'local-category',
          name: 'Reading',
          order: Int64.ZERO,
        ),
      ],
    );
    final proposed = BackupMihon(
      backupNovels: [
        localNovel.deepCopy()
          ..categoryIds.clear()
          ..categoryIds.add('remote-category'),
      ],
      backupNovelCategories: [
        BackupNovelCategory(
          id: 'remote-category',
          name: ' reading ',
          order: Int64(4),
        ),
      ],
    );
    final result = _run(
      audit,
      local: local,
      remote: proposed,
      proposed: proposed,
    );

    expect(result.failures, isEmpty);
  });

  test(
    'prefers category name mapping when a remote row reuses the local ID',
    () {
      final localNovel = _novel(categoryIds: const ['shared-id']);
      final local = BackupMihon(
        backupNovels: [localNovel],
        backupNovelCategories: [
          BackupNovelCategory(id: 'shared-id', name: 'Reading'),
        ],
      );
      final remote = BackupMihon(
        backupNovelCategories: [
          BackupNovelCategory(id: 'shared-id', name: 'Renamed'),
          BackupNovelCategory(id: 'reading-id', name: 'Reading'),
        ],
      );
      final proposed = const ChimahonSyncMerger().merge(
        local: local,
        remote: remote,
      );

      final result = _run(
        audit,
        local: local,
        remote: remote,
        proposed: proposed,
      );

      expect(proposed.backupNovels.single.categoryIds, contains('reading-id'));
      expect(result.failures, isEmpty);
    },
  );

  test('rejects lost local-only novel metadata and future fields', () {
    final novel = _novel()..cover = 'cover';
    novel.unknownFields.mergeVarintField(900, Int64(1));
    novel.stats.single.unknownFields.mergeVarintField(901, Int64(2));
    final category = BackupNovelCategory(
      id: 'category',
      name: 'Reading',
      order: Int64(4),
      flags: Int64(8),
    )..unknownFields.mergeVarintField(902, Int64(3));
    final local = BackupMihon(
      backupNovels: [novel],
      backupNovelCategories: [category],
    );
    final proposed = BackupMihon(
      backupNovels: [
        novel.deepCopy()
          ..clearCover()
          ..unknownFields.clear()
          ..stats.single.unknownFields.clear(),
      ],
      backupNovelCategories: [
        category.deepCopy()
          ..flags = Int64.ZERO
          ..unknownFields.clear(),
      ],
    );

    final result = _run(
      audit,
      local: local,
      remote: BackupMihon(),
      proposed: proposed,
    );

    expect(
      result.failures.keys,
      containsAll({
        'local_only_novel_metadata_changed_in_proposed',
        'local_novel_unknown_envelope_not_preserved',
        'local_novel_stat_unknown_envelope_not_preserved',
        'local_only_novel_category_changed_in_proposed',
        'local_novel_category_unknown_envelope_not_preserved',
      }),
    );
  });

  test('observes title-only and punctuation-near novel collisions', () {
    final local = BackupMihon(
      backupNovels: [
        _novel(title: 'Shared Title', author: 'Local Author'),
        _novel(title: 'Near: Title!', author: 'Same Author'),
        _novel(title: 'Local addition', author: 'Author'),
      ],
    );
    final remote = BackupMihon(
      backupNovels: [
        _novel(title: 'Shared Title', author: 'Remote Author'),
        _novel(title: 'Near Title', author: 'Same-Author'),
      ],
    );
    final result = _run(
      audit,
      local: local,
      remote: remote,
      proposed: const ChimahonSyncMerger().merge(local: local, remote: remote),
    );

    expect(
      result.observations['local_remote_novel_title_only_collisions'],
      hasLength(1),
    );
    expect(
      result.observations['local_remote_novel_near_identity_collisions'],
      hasLength(1),
    );
    expect(result.observations['local_only_novel_records'], hasLength(3));
  });
}

BackupMihon _completeLocal() => BackupMihon(
  backupSources: [BackupSource(sourceId: Int64(42), name: 'Manga source')],
  backupAnimeSources: [BackupSource(sourceId: Int64(84), name: 'Anime source')],
  backupExtensionRepo: [_repo('https://manga.example')],
  backupAnimeExtensionRepo: [_repo('https://anime.example')],
  backupSavedSearches: [
    BackupSavedSearch(
      source: Int64(42),
      name: 'Learning',
      query: 'language',
      filterList: 'filters',
    ),
  ],
  backupFeeds: [
    BackupFeed(
      source: Int64(42),
      global: false,
      savedSearch: BackupSavedSearch(
        source: Int64(42),
        name: 'Learning',
        query: 'language',
        filterList: 'filters',
      ),
    ),
  ],
  backupNovels: [
    _novel(categoryIds: const ['local-category']),
  ],
  backupNovelCategories: [
    BackupNovelCategory(
      id: 'local-category',
      name: 'Reading',
      order: Int64.ZERO,
    ),
  ],
  backupMangaStats: [
    BackupMangaStats(
      dateKey: '2026-07-18',
      mangaId: Int64(7),
      charactersRead: 100,
      readingTime: Int64(200),
    ),
  ],
  backupAnkiStats: [
    BackupAnkiStats(
      dateKey: '2026-07-18',
      profileId: 'profile',
      titleId: 'title',
      mangaCards: 10,
      novelCards: 20,
    ),
  ],
);

BackupExtensionRepos _repo(String baseUrl, {String name = 'Repository'}) =>
    BackupExtensionRepos(
      baseUrl: baseUrl,
      name: name,
      shortName: 'Repo',
      website: '$baseUrl/site',
      signingKeyFingerprint: 'fingerprint',
    );

BackupNovel _novel({
  String title = 'Novel',
  String author = 'Author',
  Iterable<String> categoryIds = const [],
}) {
  final id = ChimahonNovelIdentity.stableIdOrNull(
    title: title,
    author: author,
  )!;
  return BackupNovel(
    id: id,
    title: title,
    author: author,
    chapterIndex: 5,
    progress: 0.75,
    characterCount: 500,
    lastModified: Int64(20),
    categoryIds: categoryIds,
    stats: [
      BackupNovelStat(
        dateKey: '2026-07-18',
        charactersRead: 50,
        readingTime: 5,
        minReadingSpeed: 80,
        altMinReadingSpeed: 90,
        lastReadingSpeed: 100,
        maxReadingSpeed: 120,
        lastStatisticModified: Int64(20),
      ),
    ],
  );
}

({Map<String, List<String>> failures, Map<String, List<String>> observations})
_run(
  ChimahonLocalIntentSafetyAudit audit, {
  required BackupMihon local,
  required BackupMihon remote,
  required BackupMihon proposed,
}) {
  final failures = <String, List<String>>{};
  final observations = <String, List<String>>{};
  audit.audit(
    local: local,
    remote: remote,
    proposed: proposed,
    fail: (code, affected) {
      final values = affected.toList(growable: false);
      if (values.isNotEmpty) failures[code] = values;
    },
    observe: (code, affected) {
      observations[code] = affected.toList(growable: false);
    },
  );
  return (failures: failures, observations: observations);
}
