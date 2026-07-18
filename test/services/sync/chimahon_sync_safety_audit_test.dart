import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupHistory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_safety_audit.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/utils/chimahon_novel_identity.dart';

void main() {
  const audit = ChimahonSyncSafetyAudit();

  Set<String> failureCodes(ChimahonSyncSafetyReport report) =>
      report.hardFailures.map((finding) => finding.code).toSet();

  Set<String> observationCodes(ChimahonSyncSafetyReport report) =>
      report.observations.map((finding) => finding.code).toSet();

  BackupManga manga({
    String url = '/series',
    String title = 'Source title',
    bool authorPresent = true,
    String author = 'Author',
    bool? favorite = true,
    int? favoriteModifiedAt,
    int lastModifiedAt = 10,
    int version = 1,
    String? customTitle,
    Iterable<BackupChapter> chapters = const [],
    Iterable<BackupHistory> history = const [],
  }) => BackupManga(
    source: Int64(42),
    url: url,
    title: title,
    author: authorPresent ? author : null,
    favorite: favorite,
    favoriteModifiedAt: favoriteModifiedAt == null
        ? null
        : Int64(favoriteModifiedAt),
    lastModifiedAt: Int64(lastModifiedAt),
    version: Int64(version),
    customTitle: customTitle,
    chapters: chapters,
    history: history,
  );

  BackupChapter chapter({
    String? url = '/chapter/1',
    String? name = 'Chapter 1',
    double number = 1,
  }) => BackupChapter(
    url: url,
    name: name,
    chapterNumber: number,
    lastModifiedAt: Int64(10),
    version: Int64(1),
  );

  BackupSource source({int id = 42, String name = 'Private source'}) =>
      BackupSource(sourceId: Int64(id), name: name);

  BackupPreference preference(String key) => BackupPreference(
    key: key,
    value: BackupPreferenceValue(type: 'IntPreferenceValue', value: [8, 1]),
  );

  BackupNovel novel({
    String title = 'Secret novel',
    String author = 'Private author',
    String? id,
    int modified = 20,
    int chapterIndex = 3,
    double progress = 0.4,
    int characterCount = 800,
    Iterable<String> categoryIds = const ['reading-private'],
    Iterable<BackupNovelStat> stats = const [],
  }) {
    final canonical = ChimahonNovelIdentity.stableIdOrNull(
      title: title,
      author: author,
      fallbackId: id,
    )!;
    return BackupNovel(
      id: id ?? canonical,
      title: title,
      author: author,
      lastModified: Int64(modified),
      chapterIndex: chapterIndex,
      progress: progress,
      characterCount: characterCount,
      categoryIds: categoryIds,
      stats: stats,
    );
  }

  BackupNovelStat novelStat({
    String date = '2026-07-17',
    int modified = 30,
    int characters = 1000,
    double time = 12.5,
  }) => BackupNovelStat(
    dateKey: date,
    lastStatisticModified: Int64(modified),
    charactersRead: characters,
    readingTime: time,
    minReadingSpeed: 80,
    altMinReadingSpeed: 90,
    lastReadingSpeed: 100,
    maxReadingSpeed: 120,
  );

  BackupMihon backup({
    Iterable<BackupManga> mangaRows = const [],
    Iterable<BackupSource>? sources,
    Iterable<BackupPreference> preferences = const [],
    Iterable<BackupSourcePreferences> sourcePreferences = const [],
    Iterable<BackupNovel> novels = const [],
    Iterable<BackupNovelCategory> novelCategories = const [],
  }) => BackupMihon(
    backupManga: mangaRows,
    backupSources: sources ?? [source()],
    backupPreferences: preferences,
    backupSourcePreferences: sourcePreferences,
    backupNovels: novels,
    backupNovelCategories: novelCategories,
  );

  test('safe first-contact preview passes and emits only aggregate data', () {
    final retained = manga(
      url: '/secret/retained',
      customTitle: 'My private display title',
      chapters: [chapter(url: '/secret/chapter')],
      history: [
        BackupHistory(
          url: '/secret/chapter',
          lastRead: Int64(100),
          readDuration: Int64(200),
        ),
      ],
    );
    final absentFavorite = manga(
      url: '/secret/legacy',
      title: 'Legacy private title',
      favorite: null,
    );
    final tombstone = manga(
      url: '/secret/deleted',
      title: 'Deleted private title',
      favorite: false,
      favoriteModifiedAt: 50,
      lastModifiedAt: 50,
      version: 2,
    );
    final stats = novelStat();
    final privateNovel = novel(stats: [stats]);
    final prefs = [preference('private_dictionary_path')];
    final sourcePrefs = [
      BackupSourcePreferences(
        sourceKey: 'private-source-key',
        prefs: [preference('private_cookie')],
      ),
    ];
    final categories = [
      BackupNovelCategory(
        id: 'reading-private',
        name: 'Private Reading',
        order: Int64(0),
      ),
    ];
    final reference = backup(
      mangaRows: [retained, absentFavorite],
      preferences: prefs,
      sourcePreferences: sourcePrefs,
      novels: [privateNovel],
      novelCategories: categories,
    );
    final remote = backup(
      mangaRows: [retained, absentFavorite, tombstone],
      preferences: prefs,
      sourcePreferences: sourcePrefs,
      novels: [privateNovel],
      novelCategories: categories,
    );

    final report = audit.audit(
      reference: reference,
      remote: remote,
      local: remote.deepCopy(),
      proposed: remote.deepCopy(),
    );

    expect(report.safeToUpload, isTrue);
    expect(report.hardFailures, isEmpty);
    expect(report.counts['remote.mangaRecords'], 3);
    expect(report.counts['remote.chapterRecords'], 1);
    expect(
      report.hashes.values,
      everyElement(matches(RegExp(r'^[0-9a-f]{64}$'))),
    );

    final safeJson = jsonEncode(report.toSafeJson());
    for (final secret in [
      '/secret/retained',
      '/secret/chapter',
      'My private display title',
      'private_dictionary_path',
      'private-source-key',
      'private_cookie',
      'Secret novel',
      'reading-private',
    ]) {
      expect(safeJson, isNot(contains(secret)));
    }
  });

  test('uses exact Chimahon manga identity and reports coarse collisions', () {
    final absentAuthor = manga(title: '  MIXED Case  ', authorPresent: false);
    final presentEmptyAuthor = manga(title: 'mixed case', author: '');
    final normalizedMatch = manga(title: 'mixed case', authorPresent: false);
    final normalizedReport = audit.audit(
      reference: backup(mangaRows: [absentAuthor]),
      remote: backup(mangaRows: [normalizedMatch]),
      local: backup(mangaRows: [normalizedMatch]),
      proposed: backup(mangaRows: [normalizedMatch]),
    );
    expect(
      failureCodes(normalizedReport),
      isNot(contains('reference_manga_missing_from_remote')),
    );

    final reference = backup(mangaRows: [absentAuthor]);
    final remote = backup(mangaRows: [presentEmptyAuthor]);

    final mismatch = audit.audit(
      reference: reference,
      remote: remote,
      local: remote,
      proposed: remote,
    );
    expect(
      failureCodes(mismatch),
      contains('reference_manga_missing_from_remote'),
    );

    final collisions = backup(mangaRows: [absentAuthor, presentEmptyAuthor]);
    final report = audit.audit(
      remote: collisions,
      local: collisions,
      proposed: collisions,
    );
    expect(report.counts['remote.mangaCoarseCollisionGroups'], 1);
    expect(report.counts['remote.mangaCoarseCollisionRecords'], 2);
  });

  test(
    'fails missing reference manga, chapter, history, and source subsets',
    () {
      final referenceManga = manga(
        chapters: [chapter(url: '/missing-chapter')],
        history: [BackupHistory(url: '/missing-history')],
      );
      final remoteManga = manga(chapters: [chapter(url: '/other-chapter')]);
      final reference = backup(
        mangaRows: [referenceManga],
        sources: [source(), source(id: 99)],
      );
      final remote = backup(mangaRows: [remoteManga]);

      final report = audit.audit(
        reference: reference,
        remote: remote,
        local: remote,
        proposed: remote,
      );

      expect(
        failureCodes(report),
        containsAll({
          'reference_chapter_missing_from_remote',
          'reference_history_missing_from_remote',
          'reference_source_missing_from_remote',
        }),
      );
    },
  );

  test('fails lost reference preference keys and field-800 custom titles', () {
    final reference = backup(
      mangaRows: [manga(customTitle: 'Reference private custom title')],
      preferences: [preference('reference-private-app-pref')],
      sourcePreferences: [
        BackupSourcePreferences(
          sourceKey: 'reference-private-source',
          prefs: [preference('reference-private-source-pref')],
        ),
      ],
    );
    final remote = backup(
      mangaRows: [manga(customTitle: 'Different private custom title')],
    );

    final report = audit.audit(
      reference: reference,
      remote: remote,
      local: remote,
      proposed: remote,
    );

    expect(
      failureCodes(report),
      containsAll({
        'reference_preference_key_missing_from_remote',
        'reference_source_preference_key_missing_from_remote',
        'reference_custom_title_missing_from_remote',
      }),
    );
    final encoded = jsonEncode(report.toSafeJson());
    expect(encoded, isNot(contains('Reference private custom title')));
    expect(encoded, isNot(contains('reference-private-app-pref')));
    expect(encoded, isNot(contains('reference-private-source')));
  });

  test('fails reference novel, progress, stat, and category regressions', () {
    final retainedReference = novel(
      stats: [
        novelStat(date: 'private-date-retained', modified: 30),
        novelStat(date: 'private-date-missing', modified: 31),
      ],
    );
    final missingReference = novel(
      title: 'Private missing reference novel',
      stats: [novelStat(date: 'private-missing-novel-stat')],
    );
    final reference = backup(
      novels: [retainedReference, missingReference],
      novelCategories: [
        BackupNovelCategory(
          id: 'reading-private',
          name: 'Private reference category',
          order: Int64(0),
        ),
      ],
    );
    final regressedRemote = novel(
      modified: 19,
      chapterIndex: 1,
      progress: 0.1,
      characterCount: 10,
      categoryIds: const [],
      stats: [
        novelStat(date: 'private-date-retained', modified: 29, characters: 1),
      ],
    );
    final remote = backup(novels: [regressedRemote]);

    final report = audit.audit(
      reference: reference,
      remote: remote,
      local: remote,
      proposed: remote,
    );

    expect(
      failureCodes(report),
      containsAll({
        'reference_novel_missing_from_remote',
        'reference_novel_progress_regressed_in_remote',
        'reference_novel_stat_missing_from_remote',
        'reference_novel_stat_regressed_in_remote',
        'reference_novel_category_missing_from_remote',
        'reference_novel_category_membership_missing_from_remote',
      }),
    );
    final encoded = jsonEncode(report.toSafeJson());
    expect(encoded, isNot(contains('Private missing reference novel')));
    expect(encoded, isNot(contains('private-date-missing')));
    expect(encoded, isNot(contains('Private reference category')));
  });

  test('requires every reference-surplus remote manga to be a tombstone', () {
    final reference = backup(mangaRows: [manga(url: '/retained')]);
    final remote = backup(
      mangaRows: [
        manga(url: '/retained'),
        manga(url: '/valid-delete', favorite: false, favoriteModifiedAt: 90),
        manga(url: '/not-deleted'),
      ],
    );

    final report = audit.audit(
      reference: reference,
      remote: remote,
      local: remote,
      proposed: remote,
    );

    final failure = report.hardFailures.singleWhere(
      (item) => item.code == 'remote_only_manga_not_clocked_tombstone',
    );
    expect(failure.affectedCount, 1);
  });

  test('pairs duplicate exact manga keys by multiset tombstone capacity', () {
    final retained = manga(url: '/duplicate-key');
    final tombstone = manga(
      url: '/duplicate-key',
      favorite: false,
      favoriteModifiedAt: 90,
      lastModifiedAt: 90,
    );
    final reference = backup(
      mangaRows: [retained.deepCopy(), retained.deepCopy()],
    );
    final sufficientRemote = backup(
      mangaRows: [
        retained.deepCopy(),
        retained.deepCopy(),
        tombstone.deepCopy(),
      ],
    );
    final sufficient = audit.audit(
      reference: reference,
      remote: sufficientRemote,
      local: sufficientRemote,
      proposed: sufficientRemote,
    );
    expect(
      failureCodes(sufficient),
      isNot(contains('remote_only_manga_not_clocked_tombstone')),
    );

    final insufficientRemote = backup(
      mangaRows: [
        retained.deepCopy(),
        retained.deepCopy(),
        tombstone.deepCopy(),
        retained.deepCopy(),
      ],
    );
    final insufficient = audit.audit(
      reference: reference,
      remote: insufficientRemote,
      local: insufficientRemote,
      proposed: insufficientRemote,
    );
    final failure = insufficient.hardFailures.singleWhere(
      (finding) => finding.code == 'remote_only_manga_not_clocked_tombstone',
    );
    expect(failure.affectedCount, 1);
  });

  test('allows only an explicit newer local resurrection clock', () {
    final deleted = manga(
      favorite: false,
      favoriteModifiedAt: 100,
      lastModifiedAt: 100,
    );
    final resurrected = manga(
      favorite: true,
      favoriteModifiedAt: 101,
      lastModifiedAt: 101,
      version: 0,
    );
    final promoted = resurrected.deepCopy()..version = Int64(2);
    final valid = audit.audit(
      remote: backup(mangaRows: [deleted]),
      local: backup(mangaRows: [resurrected]),
      proposed: backup(mangaRows: [promoted]),
    );
    expect(valid.safeToUpload, isTrue);

    final invalidProposed = promoted.deepCopy()
      ..favoriteModifiedAt = Int64(102);
    final invalid = audit.audit(
      remote: backup(mangaRows: [deleted]),
      local: backup(mangaRows: [resurrected]),
      proposed: backup(mangaRows: [invalidProposed]),
    );
    expect(failureCodes(invalid), contains('invalid_tombstone_resurrection'));
  });

  test('preserves tombstone clocks and favorite-field absence', () {
    final clockless = manga(favorite: false);
    final absent = manga(url: '/legacy', favorite: null);
    final remote = backup(mangaRows: [clockless, absent]);
    final proposed = backup(
      mangaRows: [
        clockless.deepCopy()..favoriteModifiedAt = Int64(1),
        absent.deepCopy()..favorite = true,
      ],
    );

    final report = audit.audit(
      remote: remote,
      local: remote,
      proposed: proposed,
    );

    expect(
      failureCodes(report),
      containsAll({
        'remote_tombstone_deletion_clock_missing',
        'remote_tombstone_not_preserved',
        'remote_favorite_absence_not_preserved',
      }),
    );
  });

  test('accepts a merged newer favorite without materializing field 100', () {
    final remote = backup(
      mangaRows: [
        manga(favorite: null, favoriteModifiedAt: 100, lastModifiedAt: 100),
      ],
    );
    final local = backup(
      mangaRows: [
        manga(
          favorite: true,
          favoriteModifiedAt: 200,
          lastModifiedAt: 200,
          version: 0,
        ),
      ],
    );
    final proposed = const ChimahonSyncMerger().merge(
      local: local,
      remote: remote,
    );

    expect(proposed.backupManga.single.hasFavorite(), isFalse);
    final report = audit.audit(
      remote: remote,
      local: local,
      proposed: proposed,
    );
    expect(
      failureCodes(report),
      isNot(contains('remote_favorite_absence_not_preserved')),
    );
    expect(report.safeToUpload, isTrue);
  });

  test('retains remote key sets, custom titles, and source resolution', () {
    final remote = backup(
      mangaRows: [manga(customTitle: 'Do not lose this title')],
      preferences: [preference('remote-app-pref')],
      sourcePreferences: [
        BackupSourcePreferences(
          sourceKey: 'remote-source',
          prefs: [preference('remote-source-pref')],
        ),
      ],
    );
    final proposed = backup(
      mangaRows: [manga(customTitle: null)],
      sources: const [],
    );

    final report = audit.audit(
      remote: remote,
      local: remote,
      proposed: proposed,
    );

    expect(
      failureCodes(report),
      containsAll({
        'remote_custom_title_not_retained',
        'remote_preference_key_missing',
        'remote_source_preference_key_missing',
        'proposed_manga_source_unresolved',
      }),
    );
  });

  test('rejects inferred manual and malformed local chapter identities', () {
    final local = backup(
      mangaRows: [
        manga(
          chapters: [
            chapter(url: null),
            chapter(url: ''),
            chapter(url: 'file:///private/book.epub'),
            chapter(url: r'C:\Books\book.epub'),
            chapter(url: r'\\server\share\book.epub'),
            chapter(url: '/Users/person/Books/book.epub'),
            chapter(url: '/portable/source/chapter'),
            chapter(url: '/empty-name', name: ''),
            chapter(url: '/nan', number: double.nan),
          ],
        ),
      ],
    );

    final report = audit.audit(remote: local, local: local, proposed: local);

    final failure = report.hardFailures.singleWhere(
      (item) => item.code == 'local_nonportable_chapter_identity',
    );
    expect(failure.affectedCount, 8);
  });

  test('enforces canonical novels and timestamp-safe progress and stats', () {
    final remoteStat = novelStat();
    final remoteNovel = novel(stats: [remoteStat]);
    final remote = backup(
      novels: [remoteNovel],
      novelCategories: [
        BackupNovelCategory(
          id: 'reading-private',
          name: 'Reading',
          order: Int64(0),
        ),
      ],
    );
    final proposedNovel = novel(
      id: 'not-the-canonical-id',
      chapterIndex: 1,
      progress: 0.1,
      characterCount: 10,
      stats: [novelStat(modified: 29, characters: 1)],
      categoryIds: const [],
    );
    final proposed = backup(novels: [proposedNovel]);

    final report = audit.audit(
      remote: remote,
      local: remote,
      proposed: proposed,
    );

    expect(
      failureCodes(report),
      containsAll({
        'proposed_novel_canonical_id_invalid',
        'remote_novel_progress_regressed',
        'remote_novel_stat_regressed',
        'remote_novel_category_missing',
        'remote_novel_category_membership_missing',
      }),
    );

    final newer = novel(
      modified: 21,
      chapterIndex: 1,
      progress: 0.1,
      characterCount: 10,
      stats: [novelStat(modified: 31, characters: 1)],
    );
    final safe = audit.audit(
      remote: remote,
      local: backup(
        novels: [newer],
        novelCategories: remote.backupNovelCategories,
      ),
      proposed: backup(
        novels: [newer],
        novelCategories: remote.backupNovelCategories,
      ),
    );
    expect(safe.safeToUpload, isTrue);

    final defaultRemote = backup(
      novels: [
        novel(categoryIds: const ['default']),
      ],
      novelCategories: [
        BackupNovelCategory(id: 'default', name: 'Default', order: Int64(-1)),
      ],
    );
    final categorizedProposed = backup(
      novels: [
        novel(categoryIds: const ['reading-private']),
      ],
      novelCategories: [
        ...defaultRemote.backupNovelCategories,
        BackupNovelCategory(
          id: 'reading-private',
          name: 'Reading',
          order: Int64(0),
        ),
      ],
    );
    final categorized = audit.audit(
      remote: defaultRemote,
      local: categorizedProposed,
      proposed: categorizedProposed,
    );
    expect(categorized.safeToUpload, isTrue);
  });

  test(
    'reports local-only rows and exact-identity conflicts without raw data',
    () {
      final remote = backup(
        mangaRows: [
          manga(
            title: 'Remote title',
            chapters: [chapter(name: 'Remote chapter name')],
          ),
          manga(
            url: '/chapter-conflict-parent',
            title: 'Shared parent title',
            chapters: [
              chapter(url: '/shared-chapter-url', name: 'Remote chapter'),
            ],
          ),
        ],
      );
      final local = backup(
        mangaRows: [
          manga(
            title: 'Local conflicting title',
            chapters: [chapter(name: 'Local conflicting chapter name')],
          ),
          manga(
            url: '/chapter-conflict-parent',
            title: 'Shared parent title',
            chapters: [
              chapter(url: '/shared-chapter-url', name: 'Local chapter'),
            ],
          ),
          manga(url: '/private/local-only', title: 'Private local-only title'),
        ],
      );
      final proposed = backup(
        mangaRows: [...remote.backupManga, ...local.backupManga],
      );

      final report = audit.audit(
        remote: remote,
        local: local,
        proposed: proposed,
      );

      expect(
        observationCodes(report),
        containsAll({
          'local_only_manga_records',
          'remote_only_manga_records',
          'local_remote_manga_identity_conflicts',
          'local_only_chapter_records',
          'remote_only_chapter_records',
          'local_remote_chapter_identity_conflicts',
        }),
      );
      final encoded = jsonEncode(report.toSafeJson());
      expect(encoded, isNot(contains('Private local-only title')));
      expect(encoded, isNot(contains('/private/local-only')));
    },
  );
}
