import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

void main() {
  group('readerOcrShouldAutoScan', () {
    test('automatic trigger auto-scans without an explicit request', () {
      expect(
        readerOcrShouldAutoScan(
          trigger: OcrScanTrigger.automatic,
          manualRequest: false,
        ),
        isTrue,
      );
    });

    test('manual trigger does not auto-scan on chapter open', () {
      expect(
        readerOcrShouldAutoScan(
          trigger: OcrScanTrigger.manual,
          manualRequest: false,
        ),
        isFalse,
      );
    });

    test('manual trigger scans when the user explicitly requests it', () {
      expect(
        readerOcrShouldAutoScan(
          trigger: OcrScanTrigger.manual,
          manualRequest: true,
        ),
        isTrue,
      );
    });

    test('automatic trigger still scans for an explicit request', () {
      expect(
        readerOcrShouldAutoScan(
          trigger: OcrScanTrigger.automatic,
          manualRequest: true,
        ),
        isTrue,
      );
    });
  });

  group('readerOcrButtonAction', () {
    test('automatic mode toggles the overlay', () {
      expect(
        readerOcrButtonAction(trigger: OcrScanTrigger.automatic, enabled: true),
        ReaderOcrButtonAction.toggleOverlay,
      );
      expect(
        readerOcrButtonAction(
          trigger: OcrScanTrigger.automatic,
          enabled: false,
        ),
        ReaderOcrButtonAction.toggleOverlay,
      );
    });

    test('manual mode with overlay hidden reveals then scans', () {
      expect(
        readerOcrButtonAction(trigger: OcrScanTrigger.manual, enabled: false),
        ReaderOcrButtonAction.enableAndScan,
      );
    });

    test('manual mode with overlay visible scans the current page', () {
      expect(
        readerOcrButtonAction(trigger: OcrScanTrigger.manual, enabled: true),
        ReaderOcrButtonAction.scan,
      );
    });
  });

  group('OcrScanTrigger preference', () {
    late Directory tempDirectory;

    setUpAll(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mangatan-ocr-trigger-preferences-',
      );
      Hive.init(tempDirectory.path);
    });

    setUp(() async {
      if (Hive.isBoxOpen('mining_preferences')) {
        await Hive.box<dynamic>('mining_preferences').close();
      }
      await Hive.deleteBoxFromDisk('mining_preferences');
    });

    tearDownAll(() async {
      await Hive.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('defaults to automatic to preserve existing behavior', () async {
      expect(
        await MiningPreferences.getOcrScanTrigger(),
        OcrScanTrigger.automatic,
      );
    });

    test('persists the manual trigger across box reopen', () async {
      await MiningPreferences.setOcrScanTrigger(OcrScanTrigger.manual);
      await Hive.box<dynamic>('mining_preferences').close();

      expect(
        await MiningPreferences.getOcrScanTrigger(),
        OcrScanTrigger.manual,
      );
    });

    test('falls back to automatic for an unknown stored value', () async {
      final box = await Hive.openBox<dynamic>('mining_preferences');
      await box.put('ocr_scan_trigger', 'not-a-real-mode');

      expect(
        await MiningPreferences.getOcrScanTrigger(),
        OcrScanTrigger.automatic,
      );
    });
  });

  group('ReaderOcrState scan gating', () {
    late Directory tempDirectory;

    UChapDataPreload page(int index) => UChapDataPreload(
      null,
      null,
      null,
      true,
      null,
      index,
      null,
      index,
      localArtifactPath: 'gating-chapter/page-$index.avif',
    );

    setUpAll(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'mangatan-ocr-gating-preferences-',
      );
      Hive.init(tempDirectory.path);
    });

    tearDownAll(() async {
      await Hive.close();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    tearDown(() {
      ReaderOcrState.progress.value = null;
    });

    test('manual trigger suppresses the automatic chapter scan', () async {
      await MiningPreferences.setOcrScanTrigger(OcrScanTrigger.manual);
      var prepared = 0;

      await ReaderOcrState.scanChapter(
        [page(0), page(1)],
        preparePage: (_) async {
          prepared++;
          throw StateError('stop before real OCR');
        },
      );

      expect(
        prepared,
        0,
        reason: 'manual mode must not scan pages in the background',
      );
    });

    test('manual request scans the pending chapter on demand', () async {
      await MiningPreferences.setOcrScanTrigger(OcrScanTrigger.manual);
      var prepared = 0;

      // Opening the chapter stores the pending pages without scanning.
      await ReaderOcrState.scanChapter(
        [page(10), page(11)],
        preparePage: (_) async {
          prepared++;
          throw StateError('stop before real OCR');
        },
      );
      expect(prepared, 0);

      // An explicit user request now runs OCR for the pending chapter.
      await ReaderOcrState.scanCurrentChapterManually();
      expect(
        prepared,
        greaterThan(0),
        reason: 'a manual request must scan the pending chapter',
      );
    });
  });
}
