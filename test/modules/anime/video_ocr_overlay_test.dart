import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/widgets/video_ocr_overlay.dart';

void main() {
  test(
    'passive video OCR text remains discoverable at ten percent opacity',
    () {
      expect(videoOcrTextOpacity(selected: false), 0.10);
      expect(videoOcrTextOpacity(selected: false), greaterThanOrEqualTo(0.10));
    },
  );

  test('selected video OCR text becomes clearly visible', () {
    expect(videoOcrTextOpacity(selected: true), greaterThan(0.10));
  });
}
