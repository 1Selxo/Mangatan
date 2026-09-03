import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

/// Regression guard for the persisted reader OCR enablement preference.
///
/// This preference controls OCR processing and hit testing. Passive paint
/// visibility is deliberately separate: inactive content follows the box
/// opacity and is hidden at the default 0% until the user activates a hit.
///
/// These tests keep the processing preference enabled by default and persistent
/// without asserting that passive OCR text is permanently painted.
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
    'OCR processing is enabled by default on a fresh install',
    () async {
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
