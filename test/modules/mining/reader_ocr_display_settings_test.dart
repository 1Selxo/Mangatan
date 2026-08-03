// Regression coverage for GitHub issue #24 ("Display Settings Not Respected").
//
// The original userscript/Mokuro-era reader required an explicit
// "save and reload" step before OCR display settings took effect, which led
// users to believe adjusting a slider did nothing. The current Flutter reader
// exposes the OCR appearance settings as live [ValueNotifier]s that every
// attached [ReaderOcrController] listens to, so a change repaints the overlay
// immediately with no save/reload button, and also persists so the setting
// survives a reload.
//
// These tests pin that live-apply contract: mutating a display setting must
// (a) update the shared notifier value, (b) notify attached controllers so the
// overlay repaints, and (c) persist so a subsequent read observes the value.
// If a future refactor drops any of that wiring, issue #24 regresses and these
// tests fail.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mangatan-ocr-display-settings-',
    );
    Hive.init(tempDirectory.path);
  });

  setUp(() async {
    if (Hive.isBoxOpen('mining_preferences')) {
      await Hive.box<dynamic>('mining_preferences').close();
    }
    await Hive.deleteBoxFromDisk('mining_preferences');

    // Restore the shared appearance state to its packaged defaults so each
    // test observes a real transition rather than a stale value.
    ReaderOcrState.backgroundOpacity.value =
        MiningPreferences.defaultOcrBackgroundOpacity;
    ReaderOcrState.textOpacity.value = MiningPreferences.defaultOcrTextOpacity;
    ReaderOcrState.outlineVisible.value = false;
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('setBackgroundOpacity applies live and persists', () async {
    final observed = <double>[];
    void listener() => observed.add(ReaderOcrState.backgroundOpacity.value);
    ReaderOcrState.backgroundOpacity.addListener(listener);
    addTearDown(
      () => ReaderOcrState.backgroundOpacity.removeListener(listener),
    );

    await ReaderOcrState.setBackgroundOpacity(0.2);

    expect(ReaderOcrState.backgroundOpacity.value, 0.2);
    expect(observed, contains(0.2));
    // A reload reads back the persisted value, not the packaged default.
    expect(await MiningPreferences.getOcrBackgroundOpacity(), 0.2);
  });

  test('setTextOpacity applies live and persists', () async {
    final observed = <double>[];
    void listener() => observed.add(ReaderOcrState.textOpacity.value);
    ReaderOcrState.textOpacity.addListener(listener);
    addTearDown(() => ReaderOcrState.textOpacity.removeListener(listener));

    await ReaderOcrState.setTextOpacity(0.35);

    expect(ReaderOcrState.textOpacity.value, 0.35);
    expect(observed, contains(0.35));
    expect(await MiningPreferences.getOcrTextOpacity(), 0.35);
  });

  test('setOutlineVisible applies live and persists', () async {
    final observed = <bool>[];
    void listener() => observed.add(ReaderOcrState.outlineVisible.value);
    ReaderOcrState.outlineVisible.addListener(listener);
    addTearDown(() => ReaderOcrState.outlineVisible.removeListener(listener));

    await ReaderOcrState.setOutlineVisible(true);

    expect(ReaderOcrState.outlineVisible.value, isTrue);
    expect(observed, contains(true));
    expect(await MiningPreferences.getOcrOutlineVisible(), isTrue);
  });

  test(
    'display-setting changes repaint attached controllers without a reload',
    () async {
      // A transition page short-circuits load(), so no Isar image lookup is
      // needed to exercise the appearance listener wiring.
      final data = UChapDataPreload(
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        isTransitionPage: true,
      );
      final controller = ReaderOcrController(data, imageKey: GlobalKey());
      addTearDown(controller.dispose);

      var repaints = 0;
      void onRepaint() => repaints++;
      controller.addListener(onRepaint);
      addTearDown(() => controller.removeListener(onRepaint));

      await ReaderOcrState.setBackgroundOpacity(0.15);
      await ReaderOcrState.setTextOpacity(0.5);
      await ReaderOcrState.setOutlineVisible(true);

      // Each of the three appearance changes must have driven a repaint of the
      // overlay controller; issue #24 was the absence of exactly this signal.
      expect(repaints, greaterThanOrEqualTo(3));
    },
  );
}
