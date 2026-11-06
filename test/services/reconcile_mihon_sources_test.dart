import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/reconcile_mihon_sources.dart';

void main() {
  late Directory databaseDirectory;
  late Isar database;

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await _isarLibraryPath()},
    );
  });

  setUp(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'mangatan-mihon-reconcile-',
    );
    database = await Isar.open(
      [MangaSchema, ChapterSchema, SourceSchema],
      directory: databaseDirectory.path,
      name: 'mihon_reconcile_test',
    );
    app.isar = database;
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test(
    'new factory child rebinds synced anime without changing its id',
    () async {
      final template = Source(
        id: 101,
        name: 'Jellyfin (1)',
        sourceCodeUrl: 'https://extensions.example/jellyfin.apk',
        sourceCode: 'apk-bytes',
        itemType: ItemType.anime,
        additionalParams: encodeMihonSourceMetadata(
          sourceId: '1001',
          packageName: 'eu.kanade.tachiyomi.animeextension.all.jellyfin',
        ),
      )..sourceCodeLanguage = SourceCodeLanguage.mihon;
      final anime = Manga(
        id: 77,
        source: 'Remote Jellyfin alias',
        author: 'Author',
        artist: 'Artist',
        favorite: true,
        genre: const [],
        imageUrl: 'cover',
        lang: 'en',
        link: '/library/item',
        name: 'Anime',
        status: Status.ongoing,
        description: '',
        sourceId: null,
        mihonSourceId: '1004',
        itemType: ItemType.anime,
      );
      await database.writeTxn(() async {
        await database.sources.put(template);
        await database.mangas.put(anime);
      });

      await reconcileMihonFactorySources(template, const [
        MihonSourceDescriptor(
          id: '1001',
          name: 'Jellyfin (1)',
          lang: 'en',
          baseUrl: 'https://one.example',
        ),
        MihonSourceDescriptor(
          id: '1004',
          name: 'My Anime Library',
          lang: 'en',
          baseUrl: 'https://four.example',
        ),
      ]);

      final restored = database.mangas.getSync(77)!;
      final child = database.sources.getSync(mihonLocalSourceId('1004'))!;
      expect(restored.id, 77);
      expect(restored.itemType, ItemType.anime);
      expect(restored.sourceId, child.id);
      expect(restored.source, 'My Anime Library');
      expect(restored.mihonSourceId, '1004');
      expect(await database.mangas.count(), 1);
    },
  );

  test(
    'missing factory child is detached but retains native identity',
    () async {
      final template = Source(
        id: 101,
        name: 'Jellyfin parent',
        sourceCodeUrl: 'https://extensions.example/jellyfin.apk',
        sourceCode: 'apk-bytes',
        itemType: ItemType.anime,
        isAdded: true,
        additionalParams: encodeMihonSourceMetadata(
          sourceId: '1001',
          packageName: 'jellyfin',
        ),
      )..sourceCodeLanguage = SourceCodeLanguage.mihon;
      final missingChild = Source(
        id: mihonLocalSourceId('1004'),
        name: 'Old anime library',
        sourceCodeUrl: template.sourceCodeUrl,
        sourceCode: template.sourceCode,
        itemType: ItemType.anime,
        isAdded: true,
        additionalParams: encodeMihonSourceMetadata(
          sourceId: '1004',
          packageName: 'jellyfin',
        ),
      )..sourceCodeLanguage = SourceCodeLanguage.mihon;
      final anime = Manga(
        id: 77,
        source: missingChild.name,
        sourceId: missingChild.id,
        mihonSourceId: '1004',
        author: '',
        artist: '',
        favorite: true,
        genre: const [],
        imageUrl: '',
        lang: 'en',
        link: '/item',
        name: 'Anime',
        status: Status.ongoing,
        description: '',
        itemType: ItemType.anime,
      );
      await database.writeTxn(() async {
        await database.sources.putAll([template, missingChild]);
        await database.mangas.put(anime);
      });

      final result = await reconcileMihonFactorySources(template, const [
        MihonSourceDescriptor(
          id: '1001',
          name: 'Jellyfin parent',
          lang: 'all',
          baseUrl: '',
        ),
      ]);

      final storedChild = database.sources.getSync(missingChild.id!)!;
      final storedAnime = database.mangas.getSync(77)!;
      expect(mihonSourceMetadata(storedChild)?.factoryAvailable, isFalse);
      expect(storedAnime.sourceId, isNull);
      expect(storedAnime.mihonSourceId, '1004');
      expect(result.unavailable, 1);
      expect(result.detached, 1);
    },
  );

  test(
    'source rebinding cannot overwrite a concurrent favorite edit',
    () async {
      final template = Source(
        id: 101,
        name: 'RawINU parent',
        sourceCodeUrl: 'https://extensions.example/rawinu.apk',
        sourceCode: 'apk-bytes',
        itemType: ItemType.manga,
        additionalParams: encodeMihonSourceMetadata(
          sourceId: '1001',
          packageName: 'rawinu',
        ),
      )..sourceCodeLanguage = SourceCodeLanguage.mihon;
      final manga = Manga(
        id: 77,
        source: 'RawINU',
        sourceId: null,
        mihonSourceId: '1004',
        author: null,
        artist: null,
        favorite: true,
        favoriteModifiedAt: 100,
        genre: const [],
        imageUrl: '',
        lang: 'en',
        link: '/migrated-title',
        name: 'Migrated title',
        status: Status.ongoing,
        description: '',
        itemType: ItemType.manga,
      );
      await database.writeTxn(() async {
        await database.sources.put(template);
        await database.mangas.put(manga);
      });

      await reconcileMihonFactorySources(
        template,
        const [
          MihonSourceDescriptor(
            id: '1004',
            name: 'RawINU',
            lang: 'en',
            baseUrl: 'https://rawinu.example',
          ),
        ],
        beforeReconciliationWrite: () async {
          await database.writeTxn(() async {
            final edited = (await database.mangas.get(77))!
              ..updateFavorite(
                false,
                modifiedAt: DateTime.fromMillisecondsSinceEpoch(200000),
              );
            await database.mangas.put(edited);
          });
        },
      );

      final restored = database.mangas.getSync(77)!;
      expect(restored.sourceId, mihonLocalSourceId('1004'));
      expect(restored.favorite, isFalse);
      expect(restored.favoriteModifiedAt, 200);
    },
  );

  group('title restored before its extension was installed', () {
    Source template() => Source(
      id: 201,
      name: 'KissLove',
      lang: 'ja',
      sourceCodeUrl: 'https://extensions.example/kisslove.apk',
      sourceCode: 'apk-bytes',
      itemType: ItemType.manga,
      isAdded: true,
      additionalParams: encodeMihonSourceMetadata(
        sourceId: '6304',
        packageName: 'eu.kanade.tachiyomi.extension.ja.kisslove',
      ),
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;

    // What a backup restore stored without the extension: the backup's
    // source name, the placeholder language and neither id.
    Manga orphan() => Manga(
      id: 60,
      source: 'KissLove',
      author: '',
      artist: '',
      favorite: false,
      genre: const [],
      imageUrl: '',
      lang: 'en',
      link: 'kuso-onna-ni-sachiare',
      name: 'KUSO ONNA NI SACHIARE',
      status: Status.ongoing,
      description: '',
      sourceId: null,
      itemType: ItemType.manga,
    );

    const descriptors = [
      MihonSourceDescriptor(
        id: '6304',
        name: 'KissLove',
        lang: 'ja',
        baseUrl: 'https://klz9.com',
      ),
    ];

    test('is bound by its unique source name', () async {
      final source = template();
      await database.writeTxn(() async {
        await database.sources.put(source);
        await database.mangas.put(orphan());
      });

      await reconcileMihonFactorySources(source, descriptors);

      final rebound = database.mangas.getSync(60)!;
      expect(rebound.sourceId, source.id);
      expect(rebound.lang, 'ja');
      expect(rebound.mihonSourceId, '6304');
    });

    test(
      'stays unbound when another installed source shares the name',
      () async {
        final source = template();
        final namesake = Source(
          id: 202,
          name: 'kisslove',
          lang: 'en',
          sourceCodeUrl: 'https://extensions.example/other.apk',
          sourceCode: 'other-bytes',
          itemType: ItemType.manga,
          isAdded: true,
        );
        await database.writeTxn(() async {
          await database.sources.putAll([source, namesake]);
          await database.mangas.put(orphan());
        });

        await reconcileMihonFactorySources(source, descriptors);

        final untouched = database.mangas.getSync(60)!;
        expect(untouched.sourceId, isNull);
        expect(untouched.lang, 'en');
        expect(untouched.mihonSourceId, isNull);
      },
    );
  });
}

Future<String> _isarLibraryPath() async {
  final packageConfig = File(
    '${Directory.current.path}/.dart_tool/package_config.json',
  );
  final config = jsonDecode(await packageConfig.readAsString());
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final package = packages.firstWhere(
    (entry) => entry['name'] == 'isar_community_flutter_libs',
  );
  final rootUri = Uri.parse(package['rootUri'] as String);
  final packageDirectory = Directory.fromUri(
    rootUri.isAbsolute ? rootUri : packageConfig.parent.uri.resolveUri(rootUri),
  );
  if (Platform.isMacOS) {
    return '${packageDirectory.path}/macos/libisar.dylib';
  }
  if (Platform.isLinux) return '${packageDirectory.path}/linux/libisar.so';
  if (Platform.isWindows) {
    return '${packageDirectory.path}/windows/libisar.dll';
  }
  throw UnsupportedError('Isar test is unsupported on this platform');
}
