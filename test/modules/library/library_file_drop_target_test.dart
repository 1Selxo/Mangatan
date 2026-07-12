import 'dart:async';

import 'package:bot_toast/bot_toast.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/modules/library/widgets/library_file_drop_target.dart';

void main() {
  testWidgets('shows and clears the import overlay during a drag', (
    tester,
  ) async {
    await _pumpDropTarget(tester, onImport: (_) async {});
    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));

    dropTarget.onDragEntered!(_eventDetails);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('library-file-drop-overlay')),
      findsOneWidget,
    );
    expect(find.text('Files (.cbz, .zip)'), findsOneWidget);

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
      onImport: (filePaths) {
        importedPaths = filePaths;
        return importCompleter.future;
      },
    );
    final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));

    dropTarget.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile('/library/first.CBZ'),
          DropItemFile('/library/ignore.epub'),
          DropItemFile('/library/second.zip'),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pump();

    expect(importedPaths, ['/library/first.CBZ', '/library/second.zip']);
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
      onImport: (_) async {
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
}

final _eventDetails = DropEventDetails(
  localPosition: Offset.zero,
  globalPosition: Offset.zero,
);

Future<void> _pumpDropTarget(
  WidgetTester tester, {
  required Future<void> Function(List<String>) onImport,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: BotToastInit(),
      navigatorObservers: [BotToastNavigatorObserver()],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LibraryFileDropTarget(
        itemType: ItemType.manga,
        onImport: onImport,
        child: const Scaffold(body: Text('Library')),
      ),
    ),
  );
}
