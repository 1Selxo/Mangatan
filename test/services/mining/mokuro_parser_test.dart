import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/page.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/services/download_manager/downloaded_manga_artifact.dart';
import 'package:mangayomi/services/mining/mokuro_parser.dart';
import 'package:mangayomi/services/mining/mokuro_sidecar_path.dart';
import 'package:path/path.dart' as p;

void main() {
  test('falls back to the chapter-local page index', () {
    const volume = MokuroVolume(
      title: 'Example',
      volume: '1',
      pages: [
        MokuroPage(
          imagePath: '001.webp',
          imageWidth: 100,
          imageHeight: 100,
          blocks: [],
        ),
        MokuroPage(
          imagePath: '002.webp',
          imageWidth: 100,
          imageHeight: 100,
          blocks: [],
        ),
        MokuroPage(
          imagePath: '003.webp',
          imageWidth: 100,
          imageHeight: 100,
          blocks: [],
        ),
      ],
    );
    final data = UChapDataPreload(
      null,
      null,
      PageUrl('http://127.0.0.1:39640/image/opaque-token'),
      false,
      null,
      2,
      null,
      47,
    );

    final page = const MokuroParser().resolvePage(volume, data: data);

    expect(page?.imagePath, '003.webp');
  });

  test('finds a sibling sidecar for a downloaded CBZ', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'mangatan-mokuro-parser-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final chapter = Chapter(mangaId: 1, name: 'Volume: 1');
    final cbz = downloadedMangaChapterCbz(temporaryDirectory, chapter);
    await cbz.writeAsBytes(const [1]);
    await mokuroSidecarFor(cbz).writeAsString(_volumeJson('Downloaded'));
    final data = UChapDataPreload(
      chapter,
      Directory(p.join(temporaryDirectory.path, 'deleted-page-folder')),
      PageUrl(''),
      true,
      null,
      0,
      null,
      0,
      localArtifactPath: cbz.path,
    );

    final volume = await const MokuroParser().findForReaderPage(data);

    expect(volume?.title, 'Downloaded');
  });

  test('tries another local candidate after a corrupt sidecar', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'mangatan-mokuro-parser-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final cbz = File(p.join(temporaryDirectory.path, 'Volume.cbz'));
    await cbz.writeAsBytes(const [1]);
    await mokuroSidecarFor(cbz).writeAsString('{invalid');
    await File(
      p.setExtension(cbz.path, '.json'),
    ).writeAsString(_volumeJson('Fallback'));
    final data = UChapDataPreload(
      Chapter(mangaId: 1, name: 'Volume'),
      temporaryDirectory,
      PageUrl(''),
      true,
      null,
      0,
      null,
      0,
      localArtifactPath: cbz.path,
    );

    final volume = await const MokuroParser().findForReaderPage(data);

    expect(volume?.title, 'Fallback');
  });

  test('does not use another chapter sibling sidecar', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'mangatan-mokuro-parser-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    await File(
      p.join(temporaryDirectory.path, 'Another Volume.mokuro'),
    ).writeAsString(_volumeJson('Wrong chapter'));
    final chapterDirectory = Directory(
      p.join(temporaryDirectory.path, 'This_Volume'),
    );
    await chapterDirectory.create();
    final data = UChapDataPreload(
      Chapter(mangaId: 1, name: 'This Volume'),
      chapterDirectory,
      PageUrl(''),
      true,
      null,
      0,
      null,
      0,
      localArtifactPath: chapterDirectory.path,
    );

    expect(await const MokuroParser().findForReaderPage(data), isNull);
  });
}

String _volumeJson(String title) =>
    jsonEncode({'title': title, 'volume': '1', 'pages': <Object>[]});
