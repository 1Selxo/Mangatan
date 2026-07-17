import 'package:bot_toast/bot_toast.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/manga/detail/widgets/manga_chapter_file_drop_target.dart';

void main() {
  testWidgets('drops manga archives into the existing local title', (
    tester,
  ) async {
    List<String>? importedPaths;
    await _pumpTarget(
      tester,
      manga: _manga(),
      onImport: (paths) async {
        importedPaths = paths;
      },
    );

    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile('/library/volume-1.epub'),
          DropItemFile('/library/volume-2.cbz'),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(importedPaths, ['/library/volume-1.epub', '/library/volume-2.cbz']);
    expect(
      find.byKey(const ValueKey('epub-library-choice-dialog')),
      findsNothing,
    );
  });

  testWidgets('stays inactive when Add chapters is unavailable', (
    tester,
  ) async {
    for (final manga in [
      _manga(isLocalArchive: false),
      _manga(itemType: ItemType.novel),
      _manga(source: 'torrent'),
    ]) {
      await _pumpTarget(tester, manga: manga, onImport: (_) async {});
      expect(find.byType(DropTarget), findsNothing);
    }
  });
}

Future<void> _pumpTarget(
  WidgetTester tester, {
  required Manga manga,
  required MangaChapterDropImporter onImport,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MangaChapterFileDropTarget(
        manga: manga,
        onImport: onImport,
        child: const Scaffold(body: Text('Manga detail')),
      ),
    ),
  );
}

Manga _manga({
  ItemType itemType = ItemType.manga,
  bool isLocalArchive = true,
  String source = 'archive',
}) {
  return Manga(
    source: source,
    author: '',
    artist: '',
    genre: const [],
    imageUrl: '',
    lang: '',
    link: '',
    name: 'Fixture',
    status: Status.unknown,
    description: '',
    sourceId: null,
    itemType: itemType,
    isLocalArchive: isLocalArchive,
  );
}
