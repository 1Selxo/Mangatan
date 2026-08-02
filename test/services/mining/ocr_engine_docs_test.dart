import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

/// Regression guard for issue #31 ("General Clarifications").
///
/// Issue #31 reported that the OCR setup documentation did not match the
/// engines the app actually shipped (naming drift, undocumented "combined"
/// behaviour, and unclear local-vs-cloud tradeoffs). The Python OCR-server
/// subsystem the issue referenced no longer exists; OCR is now fully in-app
/// and selected via [OcrEnginePreference]. This test keeps the user/developer
/// documentation of that resolved behaviour from silently drifting away from
/// the enum again: every OCR engine the app can select MUST be named in
/// docs/ocr_engines.md.
void main() {
  final docFile = File('docs/ocr_engines.md');

  test('OCR engine documentation exists', () {
    expect(
      docFile.existsSync(),
      isTrue,
      reason:
          'docs/ocr_engines.md must document the in-app OCR engines (issue #31).',
    );
  });

  test('documentation names every selectable OCR engine', () {
    final contents = docFile.readAsStringSync();
    for (final engine in OcrEnginePreference.values) {
      expect(
        contents.contains(engine.name),
        isTrue,
        reason:
            'docs/ocr_engines.md must document OcrEnginePreference.${engine.name}. '
            'If an engine is added or renamed, update the documentation so the '
            'setup guide never drifts from the code again (issue #31).',
      );
    }
  });
}
