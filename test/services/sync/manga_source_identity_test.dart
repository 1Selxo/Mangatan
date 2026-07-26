import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/manga.dart';

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
      'mangatan-source-identity-',
    );
    database = await Isar.open(
      [MangaSchema, ChapterSchema],
      directory: databaseDirectory.path,
      name: 'source_identity_test',
    );
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test('restored custom title prevents duplicate source insertion', () async {
    final restored = _manga(
      name: 'Custom display title',
      sourceTitle: 'Source title',
    );
    await database.writeTxn(() => database.mangas.put(restored));

    final existing = await database.mangas
        .filter()
        .langEqualTo('ja')
        .titleMatchesSourceIdentity('Source title')
        .sourceEqualTo('Manga source')
        .findFirst();

    if (existing == null) {
      await database.writeTxn(
        () => database.mangas.put(
          _manga(name: 'Source title', sourceTitle: 'Source title'),
        ),
      );
    }

    expect(existing?.id, restored.id);
    expect(existing?.name, 'Custom display title');
    expect(await database.mangas.count(), 1);
  });
}

Manga _manga({required String name, required String sourceTitle}) => Manga(
  source: 'Manga source',
  sourceId: 7,
  author: 'Author',
  artist: 'Artist',
  genre: const [],
  imageUrl: 'cover',
  lang: 'ja',
  link: '/manga',
  name: name,
  sourceTitle: sourceTitle,
  status: Status.ongoing,
  description: 'Description',
);

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
