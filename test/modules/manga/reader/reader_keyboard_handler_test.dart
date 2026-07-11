import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_gestures.dart';

void main() {
  test('shift keys are ignored as standalone reader shortcuts', () {
    var previousChapterCalls = 0;
    var nextChapterCalls = 0;
    final handler = ReaderKeyboardHandler(
      onPreviousChapter: () => previousChapterCalls++,
      onNextChapter: () => nextChapterCalls++,
    );

    final handledLeftShift = handler.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.shiftLeft,
        logicalKey: LogicalKeyboardKey.shiftLeft,
        timeStamp: Duration.zero,
      ),
    );
    final handledRightShift = handler.handleKeyEvent(
      const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.shiftRight,
        logicalKey: LogicalKeyboardKey.shiftRight,
        timeStamp: Duration.zero,
      ),
    );

    expect(handledLeftShift, isFalse);
    expect(handledRightShift, isFalse);
    expect(previousChapterCalls, 0);
    expect(nextChapterCalls, 0);
  });

  test('lookup trigger receives both Shift press and release', () {
    final events = <KeyEvent>[];
    final handler = ReaderKeyboardHandler(
      onLookupTrigger: (event) {
        events.add(event);
        return true;
      },
    );
    const down = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.shiftLeft,
      logicalKey: LogicalKeyboardKey.shiftLeft,
      timeStamp: Duration.zero,
    );
    const up = KeyUpEvent(
      physicalKey: PhysicalKeyboardKey.shiftLeft,
      logicalKey: LogicalKeyboardKey.shiftLeft,
      timeStamp: Duration.zero,
    );

    expect(handler.handleKeyEvent(down), isTrue);
    expect(handler.handleKeyEvent(up), isTrue);
    expect(events, [down, up]);
  });

  test('explicit chapter shortcuts still navigate chapters', () {
    var previousChapterCalls = 0;
    var nextChapterCalls = 0;
    final handler = ReaderKeyboardHandler(
      onPreviousChapter: () => previousChapterCalls++,
      onNextChapter: () => nextChapterCalls++,
    );

    handler
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyN,
          logicalKey: LogicalKeyboardKey.keyN,
          timeStamp: Duration.zero,
        ),
      )
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.pageDown,
          logicalKey: LogicalKeyboardKey.pageDown,
          timeStamp: Duration.zero,
        ),
      )
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: Duration.zero,
        ),
      )
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.pageUp,
          logicalKey: LogicalKeyboardKey.pageUp,
          timeStamp: Duration.zero,
        ),
      );

    expect(nextChapterCalls, 2);
    expect(previousChapterCalls, 2);
  });

  test('novel mode maps page keys to pages while keeping N and P explicit', () {
    var previousPageCalls = 0;
    var nextPageCalls = 0;
    var previousChapterCalls = 0;
    var nextChapterCalls = 0;
    final handler = ReaderKeyboardHandler(
      onPreviousPage: () => previousPageCalls++,
      onNextPage: () => nextPageCalls++,
      onPreviousChapter: () => previousChapterCalls++,
      onNextChapter: () => nextChapterCalls++,
      pageKeysNavigatePages: true,
    );

    handler
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.pageDown,
          logicalKey: LogicalKeyboardKey.pageDown,
          timeStamp: Duration.zero,
        ),
      )
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.pageUp,
          logicalKey: LogicalKeyboardKey.pageUp,
          timeStamp: Duration.zero,
        ),
      )
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyN,
          logicalKey: LogicalKeyboardKey.keyN,
          timeStamp: Duration.zero,
        ),
      )
      ..handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyP,
          logicalKey: LogicalKeyboardKey.keyP,
          timeStamp: Duration.zero,
        ),
      );

    expect(nextPageCalls, 1);
    expect(previousPageCalls, 1);
    expect(nextChapterCalls, 1);
    expect(previousChapterCalls, 1);
  });

  test('embedded reader can own horizontal and page navigation keys', () {
    var pageCalls = 0;
    final handler = ReaderKeyboardHandler(
      onPreviousPage: () => pageCalls++,
      onNextPage: () => pageCalls++,
      pageKeysNavigatePages: true,
      delegateHorizontalPageKeysToChild: true,
    );

    for (final keys in [
      (PhysicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowLeft),
      (PhysicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowRight),
      (PhysicalKeyboardKey.pageUp, LogicalKeyboardKey.pageUp),
      (PhysicalKeyboardKey.pageDown, LogicalKeyboardKey.pageDown),
    ]) {
      expect(
        handler.handleKeyEvent(
          KeyDownEvent(
            physicalKey: keys.$1,
            logicalKey: keys.$2,
            timeStamp: Duration.zero,
          ),
        ),
        isFalse,
      );
    }
    expect(pageCalls, 0);
  });

  testWidgets('handled reader shortcuts do not propagate to ancestors', (
    tester,
  ) async {
    var escapeCalls = 0;
    var ancestorCalls = 0;
    final readerFocusNode = FocusNode();
    addTearDown(readerFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              ancestorCalls++;
            }
            return KeyEventResult.handled;
          },
          child: ReaderKeyboardHandler(onEscape: () => escapeCalls++)
              .wrapWithKeyboardListener(
                focusNode: readerFocusNode,
                child: const SizedBox(),
              ),
        ),
      ),
    );
    readerFocusNode.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);

    expect(escapeCalls, 1);
    expect(ancestorCalls, 0);
  });
}
