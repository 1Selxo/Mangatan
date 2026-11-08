import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/widgets/video_ocr_overlay.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

void main() {
  const block = OcrTextBlock(
    xmin: 0,
    ymin: 0,
    xmax: 1,
    ymax: 1,
    lines: ['偉大なる航路', '白土の島「バルディゴ」'],
  );

  for (final width in [180.0, 700.0]) {
    testWidgets('clicks use rendered characters at width $width', (
      tester,
    ) async {
      int? tappedOffset;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: 200,
                child: VideoOcrText(
                  block: block,
                  selected: false,
                  onLookup: (offset, _) => tappedOffset = offset,
                ),
              ),
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      // Select characters from both original OCR lines, including the second
      // line whose position was previously estimated across the whole box.
      for (final index in [0, 4, 7, 11]) {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(
                baseOffset: index >= 6 ? index + 1 : index,
                extentOffset: index >= 6 ? index + 2 : index + 1,
              ),
            )
            .first
            .toRect();
        await tester.tapAt(
          paragraph.localToGlobal(
            Offset(box.left + box.width * 0.2, box.center.dy),
          ),
        );
        expect(tappedOffset, index);
      }
      final displayed =
          paragraph.localToGlobal(Offset.zero) &
          Size(
            paragraph.localToGlobal(Offset(paragraph.size.width, 0)).dx -
                paragraph.localToGlobal(Offset.zero).dx,
            paragraph.localToGlobal(Offset(0, paragraph.size.height)).dy -
                paragraph.localToGlobal(Offset.zero).dy,
          );
      expect(displayed.width, lessThanOrEqualTo(width - 4 + 0.01));
      expect(displayed.height, lessThanOrEqualTo(196.01));
      expect(
        (displayed.width - (width - 4)).abs() < 0.1 ||
            (displayed.height - 196).abs() < 0.1,
        isTrue,
      );
      expect(paragraph.text.style!.color, Colors.white.withValues(alpha: 0.10));
      expect(paragraph.text.style!.backgroundColor, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  group('with line boxes', () {
    // Two horizontal subtitle lines; the second has the engine's character
    // edges, with a narrow 「 and 」.
    const lined = OcrTextBlock(
      xmin: 0.1,
      ymin: 0.7,
      xmax: 0.9,
      ymax: 0.9,
      lines: ['偉大なる航路', '「白土」'],
      lineGeometries: [
        OcrLineGeometry(xmin: 0.2, ymin: 0.7, xmax: 0.8, ymax: 0.78),
        OcrLineGeometry(
          xmin: 0.3,
          ymin: 0.8,
          xmax: 0.7,
          ymax: 0.9,
          glyphEdges: [0, 0.1, 0.5, 0.9, 1],
        ),
      ],
    );
    const lineRects = [
      Rect.fromLTWH(60, 0, 360, 48),
      Rect.fromLTWH(120, 60, 240, 60),
    ];

    test('places each line in its own box with its sentence offset', () {
      final lines = videoOcrLines(lined, lineRects)!;
      expect(lines, hasLength(2));
      expect(lines[0].rect, lineRects[0]);
      expect(lines[0].start, 0);
      expect(lines[0].cellEdges, hasLength(7));
      expect(lines[1].start, 6);
      // The engine's edges, not equal cells.
      expect(lines[1].cellEdges, [0, 0.1, 0.5, 0.9, 1]);
    });

    test('falls back to the paragraph without a box for each line', () {
      expect(videoOcrLines(block, null), isNull);
      expect(videoOcrLines(lined, lineRects.take(1).toList()), isNull);
    });

    test('a tap hits the character drawn under it', () {
      final lines = videoOcrLines(lined, lineRects)!;
      // Third cell of six on the first line.
      expect(videoOcrOffsetAt(lines, const Offset(60 + 360 * 2.5 / 6, 24)), 2);
      // 白 spans 10% to 50% of the second line.
      expect(videoOcrOffsetAt(lines, const Offset(120 + 240 * 0.3, 90)), 7);
      // Between the lines, the nearest one answers.
      expect(videoOcrOffsetAt(lines, const Offset(120 + 240 * 0.7, 125)), 8);
    });

    testWidgets('paints the lines instead of one centred paragraph', (
      tester,
    ) async {
      int? tappedOffset;
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 480,
              height: 120,
              child: VideoOcrText(
                block: lined,
                lineRects: lineRects,
                selected: true,
                selectionOffset: 7,
                matchLength: 2,
                onLookup: (offset, _) => tappedOffset = offset,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(RichText), findsNothing);
      await tester.tapAt(const Offset(60 + 360 * 4.5 / 6, 24));
      expect(tappedOffset, 4);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'selected text preserves the original opacity without a solid highlight',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 700,
            height: 200,
            child: VideoOcrText(
              block: block,
              selected: true,
              selectionOffset: 4,
              matchLength: 2,
              onLookup: (_, _) {},
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byType(RichText).last,
      );
      final spans = (paragraph.text as TextSpan).children!.cast<TextSpan>();
      expect(paragraph.text.style!.color, Colors.white.withValues(alpha: 0.75));
      expect(
        spans.every((span) => span.style?.backgroundColor == null),
        isTrue,
      );
    },
  );
}
