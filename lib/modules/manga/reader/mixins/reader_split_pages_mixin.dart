import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_double_page_mixin.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_memory_management.dart';
import 'package:mangayomi/modules/manga/reader/services/page_navigation_service.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/providers/reader_state_provider.dart';

/// Keeps pages that are already split in step with the splitting settings.
///
/// The reader splits a wide page once, when its image loads. Turning
/// "Split wide pages" off, inverting the split order or changing the
/// reading direction afterwards would otherwise leave every page already
/// split as it was. The halves are put back together instead, and each page
/// is split again, as now set, when it loads.
mixin ReaderSplitPagesMixin<T extends ConsumerStatefulWidget>
    on
        ConsumerState<T>,
        ReaderMemoryManagement,
        ReaderDoublePageMixin<T>,
        PageNavigationMixin<T> {
  /// Puts split pages back together when a splitting setting changes; call
  /// from build.
  void listenToSplitSettings() {
    for (final provider in [
      splitWidePagesStateProvider,
      dualPageInvertStateProvider,
    ]) {
      ref.listen<bool>(provider, (previous, next) {
        if (previous != next) rejoinSplitPages();
      });
    }
  }

  /// Puts the halves of split wide pages back together, staying on the page
  /// shown.
  void rejoinSplitPages() {
    if (!mounted || isDoublePageActive) return;
    final current = getCurrentPagesActualIndex();
    var removedBefore = 0;
    for (var i = pages.length - 2; i >= 0; i--) {
      final first = pages[i];
      final second = pages[i + 1];
      final a = first.srcRect;
      final b = second.srcRect;
      // Two halves of one page side by side; a tall page's slices are
      // stacked instead.
      if (a == null ||
          b == null ||
          first.index != second.index ||
          first.chapter?.id != second.chapter?.id ||
          a.top != 0 ||
          b.top != 0 ||
          a.size != b.size) {
        continue;
      }
      final whole =
          UChapDataPreload(
              first.chapter,
              first.directory,
              first.pageUrl,
              first.isLocale,
              first.archiveImage,
              first.index,
              first.chapterUrlModel,
              first.pageIndex,
              localArtifactPath: first.localArtifactPath,
              localImagePath: first.localImagePath,
            )
            ..resolvedFilePath = first.resolvedFilePath
            ..loadedWidth = a.width + b.width
            ..loadedHeight = a.height;
      preloadManager.replacePage(i, [whole], count: 2);
      if (i < current) removedBefore++;
      i--;
    }
    if (removedBefore == 0) {
      setState(() {});
      return;
    }
    final target = (current - removedBefore).clamp(0, pages.length - 1);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigationService.jumpToPage(
        index: target,
        readerMode: activeReaderMode ?? cachedReaderMode,
      );
    });
  }
}
