import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/novel/novel_reader_view.dart';
import 'package:mangayomi/modules/novel/widgets/ttsu_epub_reader.dart';

void main() {
  const viewport = Size(900, 900);

  test('reader tap zones preserve previous, menu, and next actions', () {
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(450, 50),
        viewport: viewport,
        usePageTapZones: true,
      ),
      NovelReaderTapAction.previousPage,
    );
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(450, 450),
        viewport: viewport,
        usePageTapZones: true,
      ),
      NovelReaderTapAction.toggleUi,
    );
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(850, 450),
        viewport: viewport,
        usePageTapZones: true,
      ),
      NovelReaderTapAction.nextPage,
    );
  });

  test('reader tap zones disabled always toggles UI', () {
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(10, 10),
        viewport: viewport,
        usePageTapZones: false,
      ),
      NovelReaderTapAction.toggleUi,
    );
  });

  test('vertical-rl tap zones advance from right to left', () {
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(50, 450),
        viewport: viewport,
        usePageTapZones: true,
        reverseHorizontal: true,
      ),
      NovelReaderTapAction.nextPage,
    );
    expect(
      novelReaderTapActionForPosition(
        position: const Offset(850, 450),
        viewport: viewport,
        usePageTapZones: true,
        reverseHorizontal: true,
      ),
      NovelReaderTapAction.previousPage,
    );
  });

  test(
    'return button follows saved-position direction in every EPUB layout',
    () {
      expect(
        epubReturnButtonEdgeFor(
          layout: EpubReadingLayout.horizontalContinuous,
          targetAfterSavedPosition: true,
        ),
        EpubReturnButtonEdge.top,
      );
      expect(
        epubReturnButtonEdgeFor(
          layout: EpubReadingLayout.horizontalContinuous,
          targetAfterSavedPosition: false,
        ),
        EpubReturnButtonEdge.bottom,
      );
      expect(
        epubReturnButtonEdgeFor(
          layout: EpubReadingLayout.horizontalPaged,
          targetAfterSavedPosition: true,
        ),
        EpubReturnButtonEdge.left,
      );
      expect(
        epubReturnButtonEdgeFor(
          layout: EpubReadingLayout.horizontalPaged,
          targetAfterSavedPosition: false,
        ),
        EpubReturnButtonEdge.right,
      );
      for (final layout in [
        EpubReadingLayout.verticalPaged,
        EpubReadingLayout.verticalContinuous,
      ]) {
        expect(
          epubReturnButtonEdgeFor(
            layout: layout,
            targetAfterSavedPosition: true,
          ),
          EpubReturnButtonEdge.right,
        );
        expect(
          epubReturnButtonEdgeFor(
            layout: layout,
            targetAfterSavedPosition: false,
          ),
          EpubReturnButtonEdge.left,
        );
      }
    },
  );

  testWidgets('vertical progress bar runs from right to left', (tester) async {
    double? changedValue;

    Future<void> pumpProgressBar({required bool reverseHorizontal}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 900,
              child: NovelReaderProgressBar(
                reverseHorizontal: reverseHorizontal,
                progressFraction: 0.69,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                onChanged: (value) => changedValue = value,
                onChangeEnd: (_) {},
              ),
            ),
          ),
        ),
      );
    }

    await pumpProgressBar(reverseHorizontal: false);
    expect(tester.getCenter(find.text('69')).dx, lessThan(450));
    expect(tester.getCenter(find.text('100')).dx, greaterThan(450));

    await pumpProgressBar(reverseHorizontal: true);
    expect(tester.getCenter(find.text('69')).dx, greaterThan(450));
    expect(tester.getCenter(find.text('100')).dx, lessThan(450));

    final sliderBounds = tester.getRect(find.byType(Slider));
    await tester.tapAt(Offset(sliderBounds.left + 10, sliderBounds.center.dy));
    expect(changedValue, isNotNull);
    expect(changedValue!, greaterThan(0.9));
  });
}
