import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/generated_ocr.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

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
}
