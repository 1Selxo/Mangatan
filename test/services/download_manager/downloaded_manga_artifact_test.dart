import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/download_manager/downloaded_manga_artifact.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mangatan-downloaded-manga-artifact-',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('rejects downloaded image folders with a missing page', () async {
    await File(p.join(temporaryDirectory.path, '001.jpg')).writeAsBytes([1]);
    await File(p.join(temporaryDirectory.path, '002.jpg')).writeAsBytes([2]);
    await File(p.join(temporaryDirectory.path, '004.jpg')).writeAsBytes([4]);

    expect(await downloadedMangaChapterImagePageCount(temporaryDirectory), 0);
  });

  test('counts a complete downloaded image folder', () async {
    await File(p.join(temporaryDirectory.path, '001.jpg')).writeAsBytes([1]);
    await File(p.join(temporaryDirectory.path, '002.jpg')).writeAsBytes([2]);

    expect(await downloadedMangaChapterImagePageCount(temporaryDirectory), 2);
  });
}
