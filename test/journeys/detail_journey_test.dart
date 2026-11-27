// Journeys through a manga's page: selecting chapters, marking them read and
// unread, bookmarking, the library heart, and selection state that must not
// leak elsewhere. From the 2026-11-09 and 2026-11-21 test rounds.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness/journey.dart';
import 'harness/reader.dart';

// The selection bar slides away rather than leaving the tree, so these find
// only what is actually on screen and reachable.
final markReadButton = find.byIcon(Icons.done_all_sharp).hitTestable();
final markUnreadButton = find.byIcon(Icons.remove_done_sharp).hitTestable();
final bookmarkButton = find.byIcon(Icons.bookmark_add_outlined).hitTestable();

void main() {
  Future<(Journey, List<int>)> openManga(
    WidgetTester tester, {
    int chapters = 3,
    Set<int> read = const {},
  }) async {
    late List<int> ids;
    final j = await Journey.start(
      tester,
      arrange: (seed) async {
        final manga = await seed.manga('Kuso Onna');
        final list = await seed.chapters(manga, chapters, pages: 3);
        for (final i in read) {
          list[i].isRead = true;
        }
        await seed.db.writeTxn(() => seed.db.chapters.putAll(list));
        ids = [for (final c in list) c.id!];
      },
    );
    await j.tapText('Kuso Onna');
    await j.waitFor(chapterCount);
    return (j, ids);
  }

  testWidgets('selecting a chapter and leaving selection brings the read '
      'button back without a grey screen (fix: no grey screen after '
      'selecting or unreading chapters)', (tester) async {
    final (j, _) = await openManga(tester);
    await j.longPress(find.text('Chapter 2'));
    expect(markReadButton, findsOneWidget);

    // Tapping the only selected chapter again ends the selection.
    await j.tap(find.text('Chapter 2'));
    await j.settle(rounds: 10);
    // The bug threw "Stream has already been listened to" right here, which
    // fails the test on its own; the page must also still be usable.
    expect(markReadButton, findsNothing);
    await j.openChapter('Chapter 1');
  });

  testWidgets('marking a chapter read from the selection saves it and '
      'clears the selection', (tester) async {
    final (j, ids) = await openManga(tester);
    await j.longPress(find.text('Chapter 2'));
    await j.tap(markReadButton);
    expect(await j.isRead(ids[1]), isTrue);
    expect(markReadButton, findsNothing);
    expect(markUnreadButton, findsNothing);
  });

  testWidgets('marking the only read chapter unread brings the resume button '
      'back without a grey screen', (tester) async {
    final (j, ids) = await openManga(tester, chapters: 2, read: {0, 1});
    await j.longPress(find.text('Chapter 1'));
    await j.tap(markUnreadButton);
    expect(await j.isRead(ids[0]), isFalse);
    await j.settle(rounds: 10);
    // The floating read button is back and opens the unread chapter.
    final readButton = find.descendant(
      of: find.byType(FloatingActionButton),
      matching: find.byType(Text),
    );
    await j.waitFor(readButton);
    await j.tap(readButton);
    await j.waitFor(find.textContaining(RegExp(r'^\d+ / \d+$')));
    expect(find.text('Chapter 1'), findsWidgets);
  });

  testWidgets('selecting several chapters and bookmarking them', (
    tester,
  ) async {
    final (j, ids) = await openManga(tester);
    await j.longPress(find.text('Chapter 1'));
    await j.tap(find.text('Chapter 3'));
    await j.tap(bookmarkButton);
    final rows = await tester.runAsync(() => j.db.chapters.getAll(ids));
    expect([for (final c in rows!) c!.isBookmarked], [true, false, true]);
  });

  testWidgets('leaving the manga page with chapters selected leaves no '
      'selection bar on the library', (tester) async {
    final (j, _) = await openManga(tester);
    await j.longPress(find.text('Chapter 2'));
    expect(markReadButton, findsOneWidget);
    await j.back();
    await j.waitFor(find.text('Kuso Onna'));
    expect(markReadButton, findsNothing);
    expect(bookmarkButton, findsNothing);

    // And coming back, nothing is still selected.
    await j.tapText('Kuso Onna');
    await j.waitFor(chapterCount);
    expect(markReadButton, findsNothing);
  });

  testWidgets('reading a chapter to the end marks it read on the manga page', (
    tester,
  ) async {
    final (j, ids) = await openManga(tester, chapters: 2);
    await j.openChapter('Chapter 1');
    for (var i = 0; i < 3; i++) {
      await j.key(LogicalKeyboardKey.space);
    }
    await j.leaveReader();
    expect(await j.isRead(ids[0]), isTrue);
  });

  testWidgets('removing a series from the library with the heart', (
    tester,
  ) async {
    final (j, _) = await openManga(tester);
    await j.tapText('In library');
    await j.settle(rounds: 10);
    final manga = await tester.runAsync(
      () => j.db.mangas.filter().nameEqualTo('Kuso Onna').findFirst(),
    );
    expect(manga!.favorite, isFalse);
    await j.back();
    await j.settle(rounds: 10);
    expect(find.text('Kuso Onna'), findsNothing);
  });

  testWidgets('long-pressing the heart opens the category picker', (
    tester,
  ) async {
    late Journey j;
    j = await Journey.start(
      tester,
      arrange: (seed) async {
        await seed.category('Romance');
        final manga = await seed.manga('Kuso Onna');
        await seed.chapters(manga, 1);
      },
    );
    await j.tapText('Kuso Onna');
    await j.waitFor(chapterCount);
    await j.longPress(find.text('In library'));
    await j.waitFor(find.text('Romance'));
    // A tap afterwards still only removes; the picker does not stick around.
    await j.key(LogicalKeyboardKey.escape);
    expect(find.text('Kuso Onna'), findsWidgets);
  });
}
