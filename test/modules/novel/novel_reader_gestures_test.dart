import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/novel/novel_reader_view.dart';

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
}
