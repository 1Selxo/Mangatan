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
      expect(displayed.width, lessThanOrEqualTo(width - 20 + 0.01));
      expect(displayed.height, lessThanOrEqualTo(188.01));
      expect(
        (displayed.width - (width - 20)).abs() < 0.1 ||
            (displayed.height - 188).abs() < 0.1,
        isTrue,
      );
      expect(paragraph.text.style!.color, Colors.white);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('matched word has a contrasting highlight', (tester) async {
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
    final highlighted = spans.singleWhere(
      (span) => span.style?.backgroundColor == Colors.amber,
    );
    expect(highlighted.text, '航路');
    expect(highlighted.style!.color, Colors.black);
  });
}
