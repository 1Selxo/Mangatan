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
}
