import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_memory_management.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/modules/reader_common/widgets/reader_app_bar.dart';
import 'package:mangayomi/utils/extensions/others.dart';

export 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart'
    show ReaderOcrState;

/// The reader's side of OCR: reading the chapter's text ahead, from the page
/// shown on, and showing how far that got.
mixin ReaderOcrMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, ReaderMemoryManagement {
  /// Reads the text of the chapter's pages, starting with the page at
  /// [actualIndex] in [pages]. Asked again for the same chapter it carries
  /// on with the reading already going.
  void scanChapterOcr(int actualIndex) {
    if (!mounted || pages.isEmpty) return;
    final startPage = pages[actualIndex.clamp(0, pages.length - 1)];
    final chapter = startPage.chapter;
    if (chapter == null) return;
    final chapterPages = pages
        .where((page) => page.chapter?.id == chapter.id)
        .toList();
    if (chapterPages.isEmpty) return;
    var startIndex = chapterPages.indexWhere(
      (page) =>
          identical(page, startPage) ||
          (page.pageIndex != null && page.pageIndex == startPage.pageIndex),
    );
    if (startIndex < 0) startIndex = 0;
    unawaited(
      ReaderOcrState.scanChapter(
        chapterPages,
        startIndex: startIndex,
        preparePage: (page) async {
          if (!mounted) return;
          await precacheImage(page.getImageProvider(ref, true), context);
        },
      ),
    );
  }

  @override
  void dispose() {
    ReaderOcrState.cancelScan();
    super.dispose();
  }

  /// How far the chapter's text has been read, under the app bar while it
  /// shows.
  Widget ocrProgressHud({
    required bool uiVisible,
    required bool fullScreen,
  }) => ReaderOcrProgressHud(
    top: uiVisible
        ? ReaderAppBar.visibleHeight(context, fullScreenReader: fullScreen) + 12
        : 12.0,
  );
}
