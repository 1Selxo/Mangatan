import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupFeed.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSavedSearch.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupStatistics.pb.dart';
import 'package:mangayomi/services/sync/chimahon_generic_collection_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';

void main() {
  const audit = ChimahonGenericCollectionSafetyAudit();

  test('rejects missing local and remote generic root collections', () {
    final local = _payload(1)..unknownFields.mergeVarintField(900, Int64(1));
    final remote = _payload(2)..unknownFields.mergeVarintField(901, Int64(2));
    final result = _run(
      audit,
      local: local,
      remote: remote,
      proposed: BackupMihon(),
    );

    expect(
      result.failures.keys,
      containsAll({
        'local_source_missing_from_proposed',
        'remote_source_missing_from_proposed',
        'local_anime_source_missing_from_proposed',
        'remote_anime_source_missing_from_proposed',
        'local_extension_repo_missing_from_proposed',
        'remote_extension_repo_missing_from_proposed',
        'local_anime_extension_repo_missing_from_proposed',
        'remote_anime_extension_repo_missing_from_proposed',
        'local_saved_search_missing_from_proposed',
        'remote_saved_search_missing_from_proposed',
        'local_feed_missing_from_proposed',
        'remote_feed_missing_from_proposed',
        'local_root_unknown_field_missing_from_proposed',
        'remote_root_unknown_field_missing_from_proposed',
        'local_manga_stat_missing_from_proposed',
        'remote_manga_stat_missing_from_proposed',
        'local_anki_stat_missing_from_proposed',
        'remote_anki_stat_missing_from_proposed',
      }),
    );
  });

  test('accepts remote prefixes and selected local root suffixes', () {
    final local = BackupMihon();
    local.unknownFields.mergeVarintField(900, Int64(1));
    local.unknownFields.mergeVarintField(902, Int64(20));
    final remote = BackupMihon();
    remote.unknownFields.mergeVarintField(901, Int64(2));
    remote.unknownFields.mergeVarintField(902, Int64(10));
    final proposed = BackupMihon();
    proposed.unknownFields.mergeVarintField(900, Int64(1));
    proposed.unknownFields.mergeVarintField(900, Int64(1));
    proposed.unknownFields.mergeVarintField(901, Int64(2));
    proposed.unknownFields.mergeVarintField(902, Int64(10));
    proposed.unknownFields.mergeVarintField(902, Int64(20));

    final result = _run(
      audit,
      local: local,
      remote: remote,
      proposed: proposed,
    );

    expect(result.failures, isEmpty);
  });

  test('detects lost row and nested feed unknown envelopes', () {
    final source = BackupSource(sourceId: Int64(42), name: 'Source')
      ..unknownFields.mergeVarintField(900, Int64(1));
    final feed = BackupFeed(
      source: Int64(42),
      savedSearch: BackupSavedSearch(name: 'Reading', source: Int64(42))
        ..unknownFields.mergeVarintField(901, Int64(2)),
    );
    final local = BackupMihon(backupSources: [source], backupFeeds: [feed]);
    final proposed = BackupMihon(
      backupSources: [BackupSource(sourceId: Int64(42), name: 'Source')],
      backupFeeds: [
        BackupFeed(
          source: Int64(42),
          savedSearch: BackupSavedSearch(name: 'Reading', source: Int64(42)),
        ),
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
        'local_source_unknown_envelope_not_preserved',
        'local_feed_unknown_envelope_not_preserved',
      }),
    );
  });

  test('uses Chimahon absent-global true feed identity', () {
    final localFeed = BackupFeed(
      source: Int64(42),
      global: true,
      savedSearch: BackupSavedSearch(name: 'Reading', source: Int64(42)),
    );
    final remoteFeed = BackupFeed(
      source: Int64(42),
      savedSearch: BackupSavedSearch(name: 'Reading', source: Int64(42)),
    );
    final local = BackupMihon(backupFeeds: [localFeed]);
    final remote = BackupMihon(backupFeeds: [remoteFeed]);
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );

    expect(proposed.backupFeeds, hasLength(1));
    expect(
      _run(audit, local: local, remote: remote, proposed: proposed).failures,
      isEmpty,
    );
  });

  test('global statistics remain exact opaque rows', () {
    final localManga = BackupMangaStats(
      dateKey: '2026-07-18',
      mangaId: Int64(7),
      charactersRead: 100,
      readingTime: Int64(50),
    );
    final remoteManga = BackupMangaStats(
      dateKey: '2026-07-18',
      mangaId: Int64(7),
      charactersRead: 80,
      readingTime: Int64(90),
    );
    final duplicateAnki = BackupAnkiStats(
      dateKey: '2026-07-18',
      profileId: 'profile',
      mangaCards: 3,
    );
    final local = BackupMihon(
      backupMangaStats: [localManga],
      backupAnkiStats: [duplicateAnki, duplicateAnki.deepCopy()],
    );
    final remote = BackupMihon(
      backupMangaStats: [remoteManga],
      backupAnkiStats: [duplicateAnki.deepCopy()],
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

    expect(proposed.backupMangaStats, hasLength(2));
    expect(proposed.backupAnkiStats, hasLength(2));
    expect(result.failures, isEmpty);
    expect(
      result.observations['manga_statistics_manual_backup_only'],
      hasLength(2),
    );
    expect(
      result.observations['anki_statistics_manual_backup_only'],
      hasLength(2),
    );
  });

  test('fails closed on duplicate generic identities on every side', () {
    final source = BackupSource(sourceId: Int64(42), name: 'Source');
    final local = BackupMihon(
      backupSources: [source.deepCopy(), source.deepCopy()],
    );
    final remote = BackupMihon(
      backupSources: [source.deepCopy(), source.deepCopy()],
    );
    final proposed = BackupMihon(
      backupSources: [source.deepCopy(), source.deepCopy()],
    );

    final result = _run(
      audit,
      local: local,
      remote: remote,
      proposed: proposed,
    );

    expect(
      result.failures.keys,
      containsAll({
        'local_source_duplicate_identity',
        'remote_source_duplicate_identity',
        'proposed_source_duplicate_identity',
      }),
    );
    expect(result.failures['local_source_duplicate_identity'], ['42']);
    expect(result.failures['remote_source_duplicate_identity'], ['42']);
    expect(result.failures['proposed_source_duplicate_identity'], ['42']);
  });
}

BackupMihon _payload(int suffix) => BackupMihon(
  backupSources: [BackupSource(sourceId: Int64(suffix), name: 'Manga $suffix')],
  backupAnimeSources: [
    BackupSource(sourceId: Int64(100 + suffix), name: 'Anime $suffix'),
  ],
  backupExtensionRepo: [_repo('https://manga$suffix.example')],
  backupAnimeExtensionRepo: [_repo('https://anime$suffix.example')],
  backupSavedSearches: [
    BackupSavedSearch(
      source: Int64(suffix),
      name: 'Search $suffix',
      query: 'query',
    ),
  ],
  backupFeeds: [
    BackupFeed(
      source: Int64(suffix),
      global: false,
      savedSearch: BackupSavedSearch(
        source: Int64(suffix),
        name: 'Feed $suffix',
      ),
    ),
  ],
  backupMangaStats: [
    BackupMangaStats(
      dateKey: '2026-07-$suffix',
      mangaId: Int64(suffix),
      charactersRead: suffix,
    ),
  ],
  backupAnkiStats: [
    BackupAnkiStats(
      dateKey: '2026-07-$suffix',
      profileId: 'profile-$suffix',
      mangaCards: suffix,
    ),
  ],
);

BackupExtensionRepos _repo(String baseUrl) => BackupExtensionRepos(
  baseUrl: baseUrl,
  name: 'Repository',
  website: '$baseUrl/site',
  signingKeyFingerprint: 'fingerprint',
);

({Map<String, List<String>> failures, Map<String, List<String>> observations})
_run(
  ChimahonGenericCollectionSafetyAudit audit, {
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
