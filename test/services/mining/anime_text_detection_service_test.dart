import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/anime_text_detection_service.dart';

void main() {
  test('accepts common NHWC and NCHW YOLO export shapes', () {
    expect(
      animeTextModelShapesSupported(
        inputShape: [1, 640, 640, 3],
        outputShape: [1, 5, 8400],
      ),
      true,
    );
    expect(
      animeTextModelShapesSupported(
        inputShape: [1, 3, 640, 640],
        outputShape: [1, 8400, 5],
      ),
      true,
    );
  });

  test('maps channel-major normalized YOLO boxes out of letterboxing', () {
    final output = Float32List.fromList([.5, 0, .4, 0, .4, 0, .4, 0, .9, 0]);
    final boxes = parseAnimeTextOutput(
      output,
      outputShape: const [1, 5, 2],
      sourceWidth: 1000,
      sourceHeight: 2000,
    );

    expect(boxes, hasLength(1));
    expect(boxes.single.left, closeTo(.1, .001));
    expect(boxes.single.top, closeTo(.2, .001));
    expect(boxes.single.right, closeTo(.9, .001));
    expect(boxes.single.bottom, closeTo(.6, .001));
  });

  test('suppresses strongly overlapping lower-confidence boxes', () {
    final output = Float32List.fromList([
      .5,
      .5,
      .5,
      .5,
      .4,
      .4,
      .4,
      .4,
      .9,
      .7,
    ]);
    expect(
      parseAnimeTextOutput(
        output,
        outputShape: const [1, 5, 2],
        sourceWidth: 640,
        sourceHeight: 640,
      ),
      hasLength(1),
    );
  });
}
