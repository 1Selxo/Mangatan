// A series dropped into Mangatan's local folder, picked up by "Rescan all
// local folders now" and opened from Browse → Local source, with the
// metadata files people actually have: Mihon's details.json (the format
// Mihon, Komikku and Chimahon document) and Mangayomi's own keys.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'harness/journey.dart';
import 'harness/reader.dart';

/// Puts a series folder into the app's local library, the way someone does
/// it in Explorer: chapter folders of images, a cover and [details] as
/// [detailsName]. Also a stray empty folder, which is not a chapter.
Future<void> dropSeries(
  Journey j, {
  required String folder,
  String? details,
  String detailsName = 'details.json',
}) async {
  await j.tester.runAsync(() async {
    final series = Directory(
      p.join(platformDirectory!, 'documents', 'Mangatan', 'local', folder),
    );
    final pages = await j.seed.pageFolder(3);
    final chapter = Directory(p.join(series.path, 'Chapter 1'))
      ..createSync(recursive: true);
    for (final page in pages.listSync().whereType<File>()) {
      page.copySync(p.join(chapter.path, p.basename(page.path)));
    }
    Directory(p.join(series.path, 'New folder')).createSync();
    if (details != null) {
      File(p.join(series.path, detailsName)).writeAsStringSync(details);
    }
  });
}

Future<void> rescan(Journey j) async {
  await j.go('/downloads');
  await j.tapText('Rescan all local folders now');
  await j.wait(const Duration(seconds: 2));
}

Future<void> openLocalSource(Journey j) async {
  // Through the navigation, as a person goes there.
  await j.go('/MangaLibrary');
  await j.tapText('Browse');
  // "Local source Manga": the tile names the item type too.
  await j.tap(find.textContaining('Local source'));
  await j.wait(const Duration(seconds: 1));
}

void main() {
  testWidgets('a series with Mihon\'s details.json shows under Local source '
      'with its title and status, and opens', (tester) async {
    final j = await Journey.start(tester);
    // As Mihon's documentation writes it: "title", numbers as strings,
    // no genre.
    await dropSeries(
      j,
      folder: 'jojo-part-8',
      details:
          '{"title": "Jojo Part 8", "author": "Araki", '
          '"artist": "Araki", "description": "Whatever", "status": "2"}',
    );
    await rescan(j);
    await openLocalSource(j);
    await j.tapText('Jojo Part 8');
    await j.waitFor(find.text('Chapter 1'));
    // Mihon's 2 is completed (Mangayomi's list would read it as Canceled).
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Canceled'), findsNothing);
    expect(find.text('New folder'), findsNothing, reason: 'not a chapter');
    await j.openChapter('Chapter 1');
  });

  testWidgets('a series with Mangayomi\'s own keys keeps working', (
    tester,
  ) async {
    final j = await Journey.start(tester);
    await dropSeries(
      j,
      folder: 'own-keys',
      detailsName: 'metadata.json',
      details: '{"name": "Own keys", "genre": ["Action"], "status": 1}',
    );
    await rescan(j);
    await openLocalSource(j);
    await j.tapText('Own keys');
    await j.waitFor(find.text('Chapter 1'));
    // Mangayomi's 1 is its second status, completed.
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Action'), findsWidgets);
  });

  testWidgets('a metadata file without a title keeps the folder name', (
    tester,
  ) async {
    final j = await Journey.start(tester);
    await dropSeries(
      j,
      folder: 'Folder title',
      details: '{"description": "Only a description"}',
    );
    await rescan(j);
    await openLocalSource(j);
    await j.tapText('Folder title');
    await j.waitFor(find.text('Chapter 1'));
  });

  testWidgets('a broken metadata file says so in words, and the series still '
      'shows under its folder name', (tester) async {
    final j = await Journey.start(tester);
    await dropSeries(j, folder: 'Broken json', details: '{"title": "Oops",');
    await j.go('/downloads');
    await j.tapText('Rescan all local folders now');
    await j.waitFor(find.textContaining("Couldn't read details.json"));
    await j.wait(const Duration(seconds: 7));
    await openLocalSource(j);
    await j.tapText('Broken json');
    await j.waitFor(find.text('Chapter 1'));
  });
}
