import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/widgets/library_file_drop_target.dart';
import 'package:mangayomi/services/epub_manga.dart';

void main() {
  testWidgets('shows and clears the import overlay during a drag', (
    tester,
  ) async {
    await _pumpDropTarget(tester, onImport: (_, _) async {});
    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));

    dropTarget.onDragEntered!(_eventDetails);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('library-file-drop-overlay')),
      findsOneWidget,
    );
    expect(find.text('Files (.cbz, .zip, .epub)'), findsOneWidget);

    dropTarget.onDragExited!(_eventDetails);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('library-file-drop-overlay')),
      findsNothing,
    );
  });

  testWidgets('imports one filtered batch without opening a dialog', (
    tester,
  ) async {
    final importCompleter = Completer<void>();
    List<String>? importedPaths;
    await _pumpDropTarget(
      tester,
      onImport: (filePaths, _) {
        importedPaths = filePaths;
        return importCompleter.future;
      },
    );
    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));

    dropTarget.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile('/library/first.CBZ'),
          DropItemFile('/library/comic.epub'),
          DropItemFile('/library/ignore.txt'),
          DropItemFile('/library/second.zip'),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(importedPaths, [
      '/library/first.CBZ',
      '/library/comic.epub',
      '/library/second.zip',
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Import'), findsOneWidget);

    importCompleter.complete();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-file-drop-overlay')),
      findsNothing,
    );
  });

  testWidgets('clears failed import state and accepts a later drop', (
    tester,
  ) async {
    var importAttempts = 0;
    await _pumpDropTarget(
      tester,
      onImport: (_, _) async {
        importAttempts++;
        if (importAttempts == 1) throw StateError('Import failed');
      },
    );

    void dropFile() {
      tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
        DropDoneDetails(
          files: [DropItemFile('/library/book.cbz')],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
    }

    dropFile();
    await tester.pumpAndSettle();
    expect(importAttempts, 1);
    expect(
      find.byKey(const ValueKey('library-file-drop-overlay')),
      findsNothing,
    );
    expect(tester.widget<DropTarget>(find.byType(DropTarget)).enable, isTrue);

    dropFile();
    await tester.pumpAndSettle();
    expect(importAttempts, 2);

    BotToast.cleanAll();
    await tester.pumpAndSettle();
  });

  testWidgets('lets a text-based EPUB stay in manga as an override', (
    tester,
  ) async {
    ItemType? importedType;
    await _pumpDropTarget(
      tester,
      classifyEpub: (_) async => EpubContentKind.textBased,
      onImport: (_, itemType) async {
        importedType = itemType;
      },
    );

    _drop(tester, '/library/novel.epub');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('epub-library-choice-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('epub-import-as-manga')));
    await tester.pumpAndSettle();

    expect(importedType, ItemType.manga);
  });

  testWidgets('routes only mismatched EPUBs to the recommended library', (
    tester,
  ) async {
    final imports = <(List<String>, ItemType)>[];
    await _pumpDropTarget(
      tester,
      classifyEpub: (_) async => EpubContentKind.textBased,
      onImport: (paths, itemType) async {
        imports.add((paths, itemType));
      },
    );

    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile('/library/chapter.cbz'),
          DropItemFile('/library/novel.epub'),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('epub-import-as-novel')));
    await tester.pumpAndSettle();

    expect(imports, hasLength(2));
    expect(imports[0].$1, ['/library/chapter.cbz']);
    expect(imports[0].$2, ItemType.manga);
    expect(imports[1].$1, ['/library/novel.epub']);
    expect(imports[1].$2, ItemType.novel);
  });

  testWidgets('suggests manga for image-based EPUBs dropped on novels', (
    tester,
  ) async {
    ItemType? importedType;
    await _pumpDropTarget(
      tester,
      itemType: ItemType.novel,
      classifyEpub: (_) async => EpubContentKind.imageBased,
      onImport: (_, itemType) async {
        importedType = itemType;
      },
    );

    _drop(tester, '/library/comic.epub');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('epub-import-as-manga')));
    await tester.pumpAndSettle();

    expect(importedType, ItemType.manga);
  });

  testWidgets('canceling a recommendation imports nothing', (tester) async {
    var importAttempts = 0;
    await _pumpDropTarget(
      tester,
      classifyEpub: (_) async => EpubContentKind.textBased,
      onImport: (_, _) async {
        importAttempts++;
      },
    );

    _drop(tester, '/library/novel.epub');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(importAttempts, 0);
  });
}

final _eventDetails = DropEventDetails(
  localPosition: Offset.zero,
  globalPosition: Offset.zero,
);

Future<void> _pumpDropTarget(
  WidgetTester tester, {
  required Future<void> Function(List<String>, ItemType) onImport,
  ItemType itemType = ItemType.manga,
  EpubDropClassifier? classifyEpub,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LibraryFileDropTarget(
        itemType: itemType,
        onImport: onImport,
        classifyEpub: classifyEpub ?? (_) async => EpubContentKind.ambiguous,
        child: const Scaffold(body: Text('Library')),
      ),
    ),
  );
}

void _drop(WidgetTester tester, String path) {
  tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
    DropDoneDetails(
      files: [DropItemFile(path)],
      localPosition: Offset.zero,
      globalPosition: Offset.zero,
    ),
  );
}
