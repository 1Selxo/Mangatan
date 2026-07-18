import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupAnime.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupCategory.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

void main() {
  const codec = ChimahonPreferenceCodec();

  test('defaults all Chimahon media switches on', () {
    expect(
      ChimahonMediaSyncSelection.fromPreferences(const []),
      const ChimahonMediaSyncSelection(),
    );
  });

  test('encodes and decodes the exact backed boolean keys and types', () {
    const selection = ChimahonMediaSyncSelection(
      manga: true,
      anime: false,
      novels: true,
    );
    final projected = selection.withBackedPreferences(
      BackupMihon(backupPreferences: [codec.encode('before', 'value')]),
    );

    expect(projected.backupPreferences.map((preference) => preference.key), [
      'before',
      ChimahonMediaSyncSelection.mangaPreferenceKey,
      ChimahonMediaSyncSelection.animePreferenceKey,
      ChimahonMediaSyncSelection.novelsPreferenceKey,
    ]);
    for (final preference in projected.backupPreferences.skip(1)) {
      expect(codec.decode(preference).kind, ChimahonPreferenceKind.boolean);
      expect(preference.value.type, endsWith('.BooleanPreferenceValue'));
    }
    expect(
      ChimahonMediaSyncSelection.fromPreferences(projected.backupPreferences),
      selection,
    );
  });

  test('canonicalizes duplicate controls without moving their anchor', () {
    const selection = ChimahonMediaSyncSelection(anime: false);
    final projected = selection.withBackedPreferences(
      BackupMihon(
        backupPreferences: [
          codec.encode('before', 1),
          codec.encode(ChimahonMediaSyncSelection.animePreferenceKey, true),
          codec.encode('middle', 2),
          codec.encode(ChimahonMediaSyncSelection.animePreferenceKey, false),
          codec.encode('after', 3),
        ],
      ),
    );

    expect(projected.backupPreferences.map((preference) => preference.key), [
      'before',
      ChimahonMediaSyncSelection.animePreferenceKey,
      'middle',
      'after',
      ChimahonMediaSyncSelection.mangaPreferenceKey,
      ChimahonMediaSyncSelection.novelsPreferenceKey,
    ]);
    final animeRows = projected.backupPreferences.where(
      (preference) =>
          preference.key == ChimahonMediaSyncSelection.animePreferenceKey,
    );
    expect(animeRows, hasLength(1));
    expect(codec.decode(animeRows.single).value, isFalse);
  });

  test('malformed controls use true semantically and remain detectable', () {
    final preferences = [
      codec.encode(
        ChimahonMediaSyncSelection.animePreferenceKey,
        'not a boolean',
      ),
    ];

    expect(
      ChimahonMediaSyncSelection.fromPreferences(preferences).anime,
      isTrue,
    );
    expect(
      ChimahonMediaSyncSelection.hasMalformedPreference(preferences),
      isTrue,
    );
    expect(
      ChimahonMediaSyncSelection.hasMalformedPreference(const []),
      isFalse,
    );
    expect(
      ChimahonMediaSyncSelection.forFiltering(
        preferences,
        malformedFallback: const ChimahonMediaSyncSelection(anime: false),
      ),
      const ChimahonMediaSyncSelection(anime: false),
      reason: 'missing keys default true; the present malformed key is kept',
    );
  });

  test('an absent download selector set preserves every local value', () {
    const current = ChimahonMediaSyncSelection(
      manga: false,
      anime: true,
      novels: false,
    );
    final unrelated = [codec.encode('unrelated', true)];

    expect(ChimahonMediaSyncSelection.hasAnyPreference(unrelated), isFalse);
    expect(
      ChimahonMediaSyncSelection.fromPreferences(unrelated, fallback: current),
      current,
    );
    expect(
      chimahonMediaSelectionForExplicitRestore(
        preferences: unrelated,
        current: current,
      ),
      current,
    );
  });

  test('partial explicit restore defaults its missing selector keys true', () {
    const current = ChimahonMediaSyncSelection(
      manga: false,
      anime: true,
      novels: false,
    );
    final partial = [
      codec.encode(ChimahonMediaSyncSelection.animePreferenceKey, false),
    ];

    expect(
      chimahonMediaSelectionForExplicitRestore(
        preferences: partial,
        current: current,
      ),
      const ChimahonMediaSyncSelection(anime: false),
      reason: 'download and manual restore share Chimahon partial semantics',
    );
  });

  test('compare-and-set updates only an unchanged complete selector state', () {
    final preference = SyncPreference(
      chimahonSyncManga: true,
      chimahonSyncAnime: false,
      chimahonSyncNovels: true,
      chimahonMediaSelectionInitialized: false,
    );
    final expected = ChimahonMediaSyncSelectionState.fromPreference(preference);
    const updated = ChimahonMediaSyncSelection(
      manga: false,
      anime: true,
      novels: false,
    );

    expect(
      applyChimahonMediaSelectionIfUnchanged(
        preference: preference,
        expected: expected,
        updated: updated,
        updatedInitialized: true,
        updatedUserSelected: false,
        updatedScopeToken: 'scope-b',
      ),
      isTrue,
    );
    expect(
      ChimahonMediaSyncSelection(
        manga: preference.chimahonSyncManga,
        anime: preference.chimahonSyncAnime,
        novels: preference.chimahonSyncNovels,
      ),
      updated,
    );
    expect(preference.chimahonMediaSelectionInitialized, isTrue);
    expect(preference.chimahonMediaSelectionGeneration, 1);
    expect(preference.chimahonMediaSelectionScopeToken, 'scope-b');

    final afterSuccess = preference.toJson();
    expect(
      applyChimahonMediaSelectionIfUnchanged(
        preference: preference,
        expected: expected,
        updated: const ChimahonMediaSyncSelection(),
        updatedInitialized: true,
        updatedUserSelected: false,
        updatedScopeToken: 'scope-b',
      ),
      isFalse,
      reason: 'a stale network result cannot overwrite a later state',
    );
    expect(preference.toJson(), afterSuccess, reason: 'rejection is immutable');
  });

  test('compare-and-set includes the initialization marker', () {
    final preference = SyncPreference(chimahonMediaSelectionInitialized: true);

    expect(
      applyChimahonMediaSelectionIfUnchanged(
        preference: preference,
        expected: const ChimahonMediaSyncSelectionState(),
        updated: const ChimahonMediaSyncSelection(anime: false),
        updatedInitialized: true,
        updatedUserSelected: false,
        updatedScopeToken: 'scope',
      ),
      isFalse,
    );
    expect(preference.chimahonSyncAnime, isTrue);
  });

  test('generation rejects a true-false-true ABA edit', () {
    final preference = SyncPreference(chimahonMediaSelectionGeneration: 4);
    final expected = ChimahonMediaSyncSelectionState.fromPreference(preference);
    applyChimahonMediaSelectionUserEdit(preference, anime: false);
    applyChimahonMediaSelectionUserEdit(preference, anime: true);

    expect(preference.chimahonMediaSelectionGeneration, 6);
    expect(preference.chimahonSyncAnime, expected.selection.anime);
    expect(
      applyChimahonMediaSelectionIfUnchanged(
        preference: preference,
        expected: expected,
        updated: const ChimahonMediaSyncSelection(anime: false),
        updatedInitialized: true,
        updatedUserSelected: false,
        updatedScopeToken: 'scope',
      ),
      isFalse,
    );
    expect(preference.chimahonSyncAnime, isTrue);
  });

  test('rapid independent field edits compose from the current row', () {
    final preference = SyncPreference();
    applyChimahonMediaSelectionUserEdit(preference, manga: false);
    applyChimahonMediaSelectionUserEdit(preference, novels: false);

    expect(preference.chimahonSyncManga, isFalse);
    expect(preference.chimahonSyncAnime, isTrue);
    expect(preference.chimahonSyncNovels, isFalse);
    expect(preference.chimahonMediaSelectionGeneration, 2);
    expect(preference.chimahonMediaSelectionUserSelected, isTrue);
  });

  test('remote-derived vectors are scoped; user choices are portable', () {
    final scopeA = chimahonMediaSelectionScopeToken('provider|account-a');
    final scopeB = chimahonMediaSelectionScopeToken('provider|account-b');
    final remoteState = ChimahonMediaSyncSelectionState(
      selection: const ChimahonMediaSyncSelection(anime: false),
      initialized: true,
      scopeToken: scopeA,
    );

    expect(scopeA, hasLength(64));
    expect(scopeA, isNot(scopeB));
    expect(scopeA, isNot(contains('account-a')));
    expect(remoteState.isInitializedForScope(scopeA), isTrue);
    expect(remoteState.isInitializedForScope(scopeB), isFalse);
    expect(
      remoteState.selectionForScope(scopeB),
      const ChimahonMediaSyncSelection(),
    );

    final explicitState = ChimahonMediaSyncSelectionState(
      selection: remoteState.selection,
      initialized: true,
      userSelected: true,
      scopeToken: scopeA,
    );
    expect(explicitState.isInitializedForScope(scopeB), isTrue);
    expect(explicitState.selectionForScope(scopeB).anime, isFalse);
  });

  test('connect malformed fallback is account-scoped', () {
    final scopeA = chimahonMediaSelectionScopeToken('provider|account-a');
    final scopeB = chimahonMediaSelectionScopeToken('provider|account-b');
    final current = ChimahonMediaSyncSelectionState(
      selection: const ChimahonMediaSyncSelection(anime: false),
      initialized: false,
      scopeToken: scopeA,
    );
    final malformed = [
      codec.encode(ChimahonMediaSyncSelection.animePreferenceKey, 'wrong type'),
    ];

    expect(
      chimahonMediaSelectionBootstrapForScope(
        current: current,
        activeScopeToken: scopeA,
        remotePreferences: malformed,
      )?.anime,
      isFalse,
      reason: 'same-account malformed restores leave its value unchanged',
    );
    expect(
      chimahonMediaSelectionBootstrapForScope(
        current: current,
        activeScopeToken: scopeB,
        remotePreferences: malformed,
      )?.anime,
      isTrue,
      reason: 'another account cannot inherit the first account fallback',
    );
  });

  test('filters entries and sources with Chimahon category behavior', () {
    final local = BackupMihon(
      backupManga: [BackupManga(source: Int64(1), url: '/manga')],
      backupSources: [BackupSource(sourceId: Int64(1), name: 'Manga source')],
      backupCategories: [
        BackupCategory(name: 'Manga category', order: Int64.ZERO),
      ],
      backupAnime: [BackupAnime(source: Int64(2), url: '/anime')],
      backupAnimeSources: [
        BackupSource(sourceId: Int64(2), name: 'Anime source'),
      ],
      backupAnimeCategories: [
        BackupCategory(name: 'Anime category', order: Int64.ZERO),
      ],
      backupNovels: [BackupNovel(id: 'novel')],
      backupNovelCategories: [
        BackupNovelCategory(id: 'novel-category', name: 'Novel category'),
      ],
    );

    final projected = const ChimahonMediaSyncSelection(
      manga: false,
      anime: false,
      novels: false,
    ).projectLocal(local);

    expect(projected.backupManga, isEmpty);
    expect(projected.backupSources, isEmpty);
    expect(projected.backupCategories, hasLength(1));
    expect(projected.backupAnime, isEmpty);
    expect(projected.backupAnimeSources, isEmpty);
    expect(projected.backupAnimeCategories, hasLength(1));
    expect(projected.backupNovels, isEmpty);
    expect(projected.backupNovelCategories, isEmpty);
    expect(local.backupManga, hasLength(1), reason: 'projection is immutable');
  });

  test('each media selector projects independently', () {
    final local = BackupMihon(
      backupManga: [BackupManga(source: Int64(1), url: '/manga')],
      backupSources: [BackupSource(sourceId: Int64(1), name: 'Manga source')],
      backupAnime: [BackupAnime(source: Int64(2), url: '/anime')],
      backupAnimeSources: [
        BackupSource(sourceId: Int64(2), name: 'Anime source'),
      ],
      backupNovels: [BackupNovel(id: 'novel')],
      backupNovelCategories: [
        BackupNovelCategory(id: 'novel-category', name: 'Novel category'),
      ],
    );

    final mangaOff = const ChimahonMediaSyncSelection(
      manga: false,
    ).projectLocal(local);
    expect(mangaOff.backupManga, isEmpty);
    expect(mangaOff.backupAnime, hasLength(1));
    expect(mangaOff.backupNovels, hasLength(1));

    final animeOff = const ChimahonMediaSyncSelection(
      anime: false,
    ).projectLocal(local);
    expect(animeOff.backupManga, hasLength(1));
    expect(animeOff.backupAnime, isEmpty);
    expect(animeOff.backupNovels, hasLength(1));

    final novelsOff = const ChimahonMediaSyncSelection(
      novels: false,
    ).projectLocal(local);
    expect(novelsOff.backupManga, hasLength(1));
    expect(novelsOff.backupAnime, hasLength(1));
    expect(novelsOff.backupNovels, isEmpty);
    expect(novelsOff.backupNovelCategories, isEmpty);
  });
}
