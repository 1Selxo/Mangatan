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

  group('readerOcrCurrentScanPage', () {
    UChapDataPreload page(int index, {bool isTransitionPage = false}) =>
        UChapDataPreload(
          null,
          null,
          null,
          !isTransitionPage,
          null,
          index,
          null,
          index,
          isTransitionPage: isTransitionPage,
          localArtifactPath: 'current-page/page-$index.avif',
        );

    test('returns the page at the current start index only', () {
      final pages = [page(0), page(1), page(2)];
      expect(
        readerOcrCurrentScanPage(pages, startIndex: 1)?.pageIndex,
        1,
        reason: 'a manual scan must target the current page, not the chapter',
      );
    });

    test('defaults to the first page when no index is given', () {
      final pages = [page(5), page(6)];
      expect(readerOcrCurrentScanPage(pages)?.pageIndex, 5);
    });

    test('clamps an out-of-range index to the last page', () {
      final pages = [page(0), page(1)];
      expect(readerOcrCurrentScanPage(pages, startIndex: 99)?.pageIndex, 1);
    });

    test('skips a transition current page to the next real page', () {
      final pages = [page(0), page(1, isTransitionPage: true), page(2)];
      expect(readerOcrCurrentScanPage(pages, startIndex: 1)?.pageIndex, 2);
    });

    test('returns null when every page is a transition page', () {
      final pages = [
        page(0, isTransitionPage: true),
        page(1, isTransitionPage: true),
      ];
      expect(readerOcrCurrentScanPage(pages, startIndex: 0), isNull);
    });

    test('returns null for an empty page list', () {
      expect(readerOcrCurrentScanPage(const [], startIndex: 0), isNull);
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

    test('manual request scans only the current page on demand', () async {
      await MiningPreferences.setOcrScanTrigger(OcrScanTrigger.manual);
      final prepared = <int>[];

      // Opening the chapter at page index 11 (the second of three) stores the
      // pending pages without scanning anything.
      await ReaderOcrState.scanChapter(
        [page(10), page(11), page(12)],
        startIndex: 1,
        preparePage: (target) async {
          prepared.add(target.pageIndex ?? -1);
          throw StateError('stop before real OCR');
        },
      );
      expect(prepared, isEmpty);

      // An explicit user request now runs OCR for ONLY the current page (11),
      // not the whole chapter — this is the issue #35 on-click behavior.
      await ReaderOcrState.scanCurrentPageManually();
      expect(
        prepared,
        [11],
        reason:
            'a manual request must scan only the current page, not the chapter',
      );
    });
  });
}
