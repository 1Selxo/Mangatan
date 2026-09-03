import 'package:flutter_test/flutter_test.dart';

import 'dart:ui';

import 'package:mangayomi/services/mining/generated_ocr.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';

void main() {
  test('Automatic falls back from cloud OCR to Apple Vision', () {
    expect(
      generatedOcrEngineOrder(
        engine: OcrEnginePreference.automatic,
        appleVisionAvailable: true,
        screenAiAvailable: false,
      ),
      [OcrEnginePreference.googleLens, OcrEnginePreference.appleVision],
    );
  });

  test('Automatic falls back from cloud OCR to ScreenAI', () {
    expect(
      generatedOcrEngineOrder(
        engine: OcrEnginePreference.automatic,
        appleVisionAvailable: false,
        screenAiAvailable: true,
      ),
      [OcrEnginePreference.googleLens, OcrEnginePreference.screenAi],
    );
  });

  test('Automatic uses only cloud OCR when no local engine is available', () {
    expect(
      generatedOcrEngineOrder(
        engine: OcrEnginePreference.automatic,
        appleVisionAvailable: false,
        screenAiAvailable: false,
      ),
      [OcrEnginePreference.googleLens],
    );
  });

  test('explicit engines never add a fallback provider', () {
    for (final engine in [
      OcrEnginePreference.appleVision,
      OcrEnginePreference.screenAi,
      OcrEnginePreference.hayai,
      OcrEnginePreference.googleLens,
    ]) {
      expect(
        generatedOcrEngineOrder(
          engine: engine,
          appleVisionAvailable: false,
          screenAiAvailable: false,
        ),
        [engine],
      );
    }
  });

  test('maps crop-level OCR geometry back onto the full page', () {
    const block = OcrTextBlock(
      xmin: .25,
      ymin: .2,
      xmax: .75,
      ymax: .8,
      lines: ['text'],
      lineGeometries: [
        OcrLineGeometry(xmin: .25, ymin: .2, xmax: .75, ymax: .8),
      ],
    );
    final mapped = remapOcrBlockToRegion(
      block,
      const Rect.fromLTRB(.1, .3, .5, .7),
    );

    expect(mapped.xmin, closeTo(.2, .0001));
    expect(mapped.ymin, closeTo(.38, .0001));
    expect(mapped.xmax, closeTo(.4, .0001));
    expect(mapped.ymax, closeTo(.62, .0001));
    expect(mapped.lineGeometries.single.xmin, closeTo(.2, .0001));
  });
}
