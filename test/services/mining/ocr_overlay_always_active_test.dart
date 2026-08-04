import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

/// Regression guard for issue #50 ("Always active overlay option").
///
/// The userscript era required a long-press to *activate* the OCR overlay on
/// every page. The current rewrite replaces that with a single persistent
/// preference — [MiningPreferences.getOcrOverlayEnabled] — that:
///
///   * defaults to ON, so a fresh install shows the overlay without any
///     per-page long-press activation, and
///   * persists the user's choice across reader sessions (box reopen), so the
///     overlay stays in the state the user last left it — "always active"
///     until the user explicitly turns it off.
///
/// These tests pin both halves of that contract so a future refactor cannot
/// silently regress to the long-press-to-activate model.
void main() {
  late Directory tempDirectory;

  Future<void> resetPreferences() async {
    if (Hive.isBoxOpen('mining_preferences')) {
      await Hive.box<dynamic>('mining_preferences').close();
    }
    await Hive.deleteBoxFromDisk('mining_preferences');
  }

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mangatan-ocr-overlay-always-active-',
    );
    Hive.init(tempDirectory.path);
    MiningPreferences.configureStorageDirectory(tempDirectory.path);
  });

  setUp(resetPreferences);

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'overlay is active by default on a fresh install (no long-press to activate)',
    () async {
      // A fresh install has never written the key. The overlay must already be
      // active — this is the "always active" default the issue asked for.
      expect(await MiningPreferences.getOcrOverlayEnabled(), isTrue);
    },
  );

  test(
    'enabling the overlay persists across a reader/session restart',
    () async {
      // User turns it off...
      await MiningPreferences.setOcrOverlayEnabled(false);
      expect(await MiningPreferences.getOcrOverlayEnabled(), isFalse);

      // ...simulate the app/reader being torn down and rebuilt (box reopen).
      await Hive.box<dynamic>('mining_preferences').close();
      expect(await MiningPreferences.getOcrOverlayEnabled(), isFalse);

      // ...user turns it back on; the choice survives another restart.
      await MiningPreferences.setOcrOverlayEnabled(true);
      await Hive.box<dynamic>('mining_preferences').close();
      expect(await MiningPreferences.getOcrOverlayEnabled(), isTrue);
    },
  );
}
