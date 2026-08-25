import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

/// Docs-drift guard for `docs/ocr_engines.md`.
///
/// This test only verifies *structural* coverage: that every
/// [OcrEnginePreference] value is documented, and that endpoint strings the doc
/// cites still match the source constants. It deliberately does NOT try to
/// validate semantic privacy claims (where inference runs, what data leaves the
/// device) — those are grounded by the code citations in the PR body and cannot
/// be asserted by a string test. Keeping that boundary explicit is why PR #87's
/// enum-name-only test was insufficient.
void main() {
  final root = _repoRoot();
  final docFile = File('${root.path}/docs/ocr_engines.md');
  final docText = docFile.existsSync() ? docFile.readAsStringSync() : '';

  test('OCR engine documentation exists', () {
    expect(
      docFile.existsSync(),
      isTrue,
      reason: 'docs/ocr_engines.md must exist so engine choices are documented',
    );
  });

  test('every OcrEnginePreference value is documented', () {
    // Human-facing labels the doc is expected to explain, keyed by enum value.
    // If a new engine is added to the enum without a matching label here, this
    // map is incomplete and the test below (the enum-count check) fails.
    const expectedLabels = <OcrEnginePreference, String>{
      OcrEnginePreference.automatic: 'Automatic',
      OcrEnginePreference.appleVision: 'Apple Vision',
      OcrEnginePreference.screenAi: 'ScreenAI',
      OcrEnginePreference.hayai: 'Hayai OCR v2.1',
      OcrEnginePreference.googleLens: 'Google Lens',
      OcrEnginePreference.mokuroOnly: 'Mokuro only',
    };

    expect(
      expectedLabels.keys.toSet(),
      OcrEnginePreference.values.toSet(),
      reason:
          'A new OcrEnginePreference value was added; document it in '
          'docs/ocr_engines.md and add its label to this test.',
    );

    for (final entry in expectedLabels.entries) {
      expect(
        docText.contains(entry.value),
        isTrue,
        reason:
            'docs/ocr_engines.md is missing a section for '
            '${entry.key.name} (expected label "${entry.value}")',
      );
    }
  });

  test('documented Google Lens endpoint matches the client constant', () {
    // The doc names a concrete remote endpoint for Google Lens. Pin it to the
    // real source so the doc cannot drift to a stale/fabricated URL.
    final clientText = File(
      '${root.path}/lib/services/mining/chrome_lens_ocr.dart',
    ).readAsStringSync();
    const endpointHost = 'lensfrontend-pa.googleapis.com';

    expect(
      clientText.contains(endpointHost),
      isTrue,
      reason: 'Google Lens client no longer targets $endpointHost',
    );
    expect(
      docText.contains(endpointHost),
      isTrue,
      reason:
          'docs/ocr_engines.md must name the real Google Lens endpoint '
          '($endpointHost) it claims the page image is uploaded to',
    );
  });

  test('documented Mokuro-website host matches the client constant', () {
    final clientText = File(
      '${root.path}/lib/services/mining/mokuro_extension_ocr.dart',
    ).readAsStringSync();
    const mokuroHost = 'mokuro.moe';

    expect(
      clientText.contains(mokuroHost),
      isTrue,
      reason: 'Mokuro extension client no longer targets $mokuroHost',
    );
    expect(
      docText.contains(mokuroHost),
      isTrue,
      reason:
          'docs/ocr_engines.md must name the Mokuro-website host ($mokuroHost) '
          'it warns can be contacted regardless of engine',
    );
  });
}

/// Walks up from the test file until it finds the repo root (identified by
/// `pubspec.yaml`), so the test resolves the same paths under `flutter test`
/// regardless of the current working directory.
Directory _repoRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        Directory('${dir.path}/lib/services/mining').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return Directory.current;
}
