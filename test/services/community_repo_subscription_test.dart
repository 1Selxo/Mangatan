import 'dart:convert';
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/model/source_preference.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/category.dart';
import 'package:mangayomi/models/changed.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/custom_button.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/epub_book_progress.dart';
import 'package:mangayomi/models/history.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/sync_preference.dart';
import 'package:mangayomi/models/track.dart';
import 'package:mangayomi/models/track_preference.dart';
import 'package:mangayomi/models/update.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';

/// Regression coverage for issue #37 (community-driven extension repositories).
///
/// Issue #37 asked for a way to share and subscribe to community-hosted source
/// configurations for non-Suwayomi sites. In the current app that intent is
/// served by extension repositories added through `mangayomi://add-repo` deep
/// links: the handler in `lib/main.dart` reads the `manga_url` / `anime_url` /
/// `novel_url` query parameters, wraps each into a [Repo], and persists it via
/// `ExtensionsRepoState.set(...)`.
///
/// These tests exercise MANGATAN'S OWN subscription workflow end to end — the
/// `ExtensionsRepoState` notifier writing to and reloading from the Isar-backed
/// [Settings] row — rather than `dart:core` `Uri` parsing. Each assertion pins
/// that a subscribed repo actually lands in the persisted preferences and
/// survives a fresh read, which is the behavior a user relies on when they tap
/// a community add-repo link.
void main() {
  late Directory databaseDirectory;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await _isarLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-community-repo-subscription-',
    );
    app.isar = await Isar.open(
      [
        MangaSchema,
        ChangedPartSchema,
        ChapterSchema,
        CategorySchema,
        CustomButtonSchema,
        UpdateSchema,
        HistorySchema,
        DownloadSchema,
        EpubBookProgressSchema,
        SourceSchema,
        SettingsSchema,
        TrackPreferenceSchema,
        TrackSchema,
        SyncPreferenceSchema,
        SourcePreferenceSchema,
        SourcePreferenceStringValueSchema,
      ],
      directory: databaseDirectory.path,
      name: 'community_repo_subscription',
    );
    // Seed the singleton settings row (id 227) the notifiers read/write.
    // `checkForExtensionUpdates: false` keeps `set(...)` from kicking off the
    // network extension refresh so the persistence path stays deterministic.
    app.isar.writeTxnSync(() {
      app.isar.settings.putSync(Settings()..checkForExtensionUpdates = false);
    });
  });

  tearDown(() async {
    await app.isar.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  /// Mirrors how `lib/main.dart`'s `add-repo` deep-link handler turns the
  /// per-content-type query parameter URLs into [Repo] rows before persisting.
  Future<List<Repo>> subscribe(
    ProviderContainer container,
    ItemType type,
    List<String> jsonUrls, {
    String? repoName,
    String? repoWebsite,
  }) async {
    final notifier = container.read(extensionsRepoStateProvider(type).notifier);
    final current = container.read(extensionsRepoStateProvider(type));
    final updated = [
      ...current,
      ...jsonUrls.map(
        (url) => Repo(name: repoName, jsonUrl: url, website: repoWebsite),
      ),
    ];
    await notifier.set(updated);
    return updated;
  }

  test(
    'subscribing to a manga repo persists it to the Settings row and reloads',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // No community repos before the user acts on an add-repo link.
      expect(
        container.read(extensionsRepoStateProvider(ItemType.manga)),
        isEmpty,
      );

      await subscribe(
        container,
        ItemType.manga,
        ['https://example.com/community/index.min.json'],
        repoName: 'Community Manga Repo',
        repoWebsite: 'https://example.com/community',
      );

      // The subscription is written into the persisted preferences...
      final persisted = app.isar.settings.getSync(227)!.mangaExtensionsRepo;
      expect(persisted, isNotNull);
      expect(persisted!, hasLength(1));
      expect(
        persisted.single.jsonUrl,
        'https://example.com/community/index.min.json',
      );
      expect(persisted.single.name, 'Community Manga Repo');
      expect(persisted.single.website, 'https://example.com/community');

      // ...and a fresh notifier rebuild reloads it straight from Isar,
      // proving the repo survives an app restart, not just in-memory state.
      final reread = ProviderContainer();
      addTearDown(reread.dispose);
      final reloaded = reread.read(extensionsRepoStateProvider(ItemType.manga));
      expect(reloaded, hasLength(1));
      expect(
        reloaded.single.jsonUrl,
        'https://example.com/community/index.min.json',
      );
    },
  );

  test(
    'repeated add-repo links append instead of replacing existing repos',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await subscribe(container, ItemType.manga, [
        'https://a.example/repo.json',
      ], repoName: 'A');
      await subscribe(container, ItemType.manga, [
        'https://b.example/repo.json',
      ], repoName: 'B');

      final persisted = app.isar.settings.getSync(227)!.mangaExtensionsRepo!;
      expect(
        persisted.map((repo) => repo.jsonUrl),
        containsAll(<String>[
          'https://a.example/repo.json',
          'https://b.example/repo.json',
        ]),
      );
      expect(persisted, hasLength(2));
    },
  );

  test(
    'a single add-repo link can subscribe repos for multiple content types',
    () async {
      // An add-repo deep link may carry manga_url, anime_url and novel_url at
      // once; each content type persists to its own preference list.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await Future.wait([
        subscribe(container, ItemType.manga, [
          'https://repo.example/manga.json',
        ]),
        subscribe(container, ItemType.anime, [
          'https://repo.example/anime.json',
        ]),
        subscribe(container, ItemType.novel, [
          'https://repo.example/novel.json',
        ]),
      ]);

      final settings = app.isar.settings.getSync(227)!;
      expect(
        settings.mangaExtensionsRepo!.single.jsonUrl,
        'https://repo.example/manga.json',
      );
      expect(
        settings.animeExtensionsRepo!.single.jsonUrl,
        'https://repo.example/anime.json',
      );
      expect(
        settings.novelExtensionsRepo!.single.jsonUrl,
        'https://repo.example/novel.json',
      );
    },
  );

  test('repository writes queue behind an active async transaction', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final transactionStarted = Completer<void>();
    final releaseTransaction = Completer<void>();
    final activeWrite = app.isar.writeTxn(() async {
      transactionStarted.complete();
      await releaseTransaction.future;
    });
    await transactionStarted.future;

    final subscription = subscribe(container, ItemType.anime, [
      'https://repo.example/queued.json',
    ]);
    releaseTransaction.complete();
    await Future.wait([activeWrite, subscription]);

    expect(
      app.isar.settings.getSync(227)!.animeExtensionsRepo!.single.jsonUrl,
      'https://repo.example/queued.json',
    );
  });
}

Future<String> _isarLibraryPath() async {
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages
      .where((entry) => entry['name'] == 'isar_community_flutter_libs')
      .firstOrNull;
  if (package == null) {
    throw StateError('Could not locate isar_community_flutter_libs');
  }
  final rootUri = Uri.parse(package['rootUri'] as String);
  final packageDirectory = Directory.fromUri(
    rootUri.isAbsolute ? rootUri : packageConfig.parent.uri.resolveUri(rootUri),
  );
  if (Platform.isMacOS) {
    return '${packageDirectory.path}/macos/libisar.dylib';
  }
  if (Platform.isLinux) {
    return '${packageDirectory.path}/linux/libisar.so';
  }
  if (Platform.isWindows) {
    return '${packageDirectory.path}/windows/libisar.dll';
  }
  throw UnsupportedError('Isar test is unsupported on this platform');
}
