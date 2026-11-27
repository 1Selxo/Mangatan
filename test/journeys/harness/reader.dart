/// Reader steps shared by the journeys.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/reader_view.dart';

import 'journey.dart';

final _pageIndicator = RegExp(r'^\d+([-–]\d+)? / \d+$');

/// The manga page's "N chapters" heading, shown once its chapters load.
final chapterCount = find.textContaining(RegExp(r'^\d+ chapters?$'));

extension ReaderSteps on Journey {
  /// Taps [chapter] in the open manga page and waits for the reader.
  Future<void> openChapter(String chapter) async {
    // The heading is English-only; the chapter's own name is not.
    for (var i = 0; i < 60; i++) {
      if (chapterCount.evaluate().isNotEmpty ||
          find.text(chapter).hitTestable().evaluate().isNotEmpty) {
        break;
      }
      await settle(rounds: 1);
    }
    await scrollTo(find.text(chapter));
    await tap(find.text(chapter));
    await waitFor(find.byType(MangaReaderView));
    await waitFor(find.textContaining(_pageIndicator));
    await settle(rounds: 10);
  }

  /// Presses the next-page key until the page indicator moves, as someone
  /// does in a continuous mode where a press scrolls a screen, not a page.
  /// Returns the indicator it moved to.
  Future<String?> nextPage({int maxPresses = 10}) =>
      _pressUntilMoved(LogicalKeyboardKey.space, maxPresses);

  Future<String?> previousPage({int maxPresses = 10}) =>
      _pressUntilMoved(LogicalKeyboardKey.arrowUp, maxPresses);

  Future<String?> _pressUntilMoved(LogicalKeyboardKey k, int maxPresses) async {
    final before = pageIndicator;
    for (var i = 0; i < maxPresses && pageIndicator == before; i++) {
      await key(k);
    }
    expect(
      pageIndicator,
      isNot(before),
      reason: '${k.keyLabel} moved the page',
    );
    return pageIndicator;
  }

  /// Brings the reader's bars back (they hide after opening), the way a
  /// click on the middle of the page does.
  Future<void> showReaderBars() async {
    final settingsButton = find.byTooltip('Settings').hitTestable();
    for (var i = 0; i < 2 && settingsButton.evaluate().isEmpty; i++) {
      await key(LogicalKeyboardKey.keyM);
    }
    expect(settingsButton, findsWidgets, reason: 'reader bars shown');
  }

  /// Dismisses the tap-zone guide a reading mode change shows, by tapping
  /// it as it asks.
  Future<void> dismissTapZoneGuide() async {
    final guide = find.text('Tap anywhere to continue').hitTestable();
    if (guide.evaluate().isNotEmpty) await tap(guide);
    // The page count shows while the bars are hidden.
    if (pageIndicator == null &&
        find.byTooltip('Settings').hitTestable().evaluate().isNotEmpty) {
      await key(LogicalKeyboardKey.keyM);
    }
  }

  /// The reader's "page / pages" indicator, as shown.
  String? get pageIndicator =>
      visibleTexts().where(_pageIndicator.hasMatch).lastOrNull;

  /// Leaves the reader with Escape, as on desktop, back to the manga page.
  Future<void> leaveReader() async {
    await key(LogicalKeyboardKey.escape);
    for (
      var i = 0;
      i < 40 && find.byType(MangaReaderView).evaluate().isNotEmpty;
      i++
    ) {
      await settle(rounds: 1);
    }
    expect(find.byType(MangaReaderView), findsNothing, reason: 'reader closed');
    await waitFor(chapterCount);
    await settle(rounds: 8);
  }

  Future<String?> savedPage(int chapterId) async =>
      (await tester.runAsync(() => db.chapters.get(chapterId)))?.lastPageRead;

  Future<bool?> isRead(int chapterId) async =>
      (await tester.runAsync(() => db.chapters.get(chapterId)))?.isRead;
}
