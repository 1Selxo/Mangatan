import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/reader/utils/double_page_layout.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_pointer_signals.dart';
import 'package:mangayomi/modules/manga/reader/widgets/double_page_view.dart';
import 'package:mangayomi/modules/manga/reader/image_view_vertical.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/widgets/transition_view_vertical.dart';
import 'package:mangayomi/modules/more/settings/reader/reader_screen.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:mangayomi/models/settings.dart';

/// Main widget for virtual reading that replaces ScrollablePositionedList
class ImageViewWebtoon extends StatelessWidget {
  final List<UChapDataPreload> pages;
  final ItemScrollController itemScrollController;
  final ScrollOffsetController scrollOffsetController;
  final ItemPositionsListener itemPositionsListener;
  final Axis scrollDirection;
  final double minCacheExtent;
  final int initialScrollIndex;
  final ScrollPhysics physics;
  final Function(UChapDataPreload data) onLongPressData;
  final Function(bool) onFailedToLoadImage;
  final BackgroundColor backgroundColor;
  final bool isDoublePageMode;
  final PageMode pageMode;
  final bool isHorizontalContinuous;
  final ReaderMode readerMode;
  final PhotoViewController photoViewController;
  final PhotoViewScaleStateController photoViewScaleStateController;
  final Alignment scalePosition;
  final Function(ScaleEndDetails) onScaleEnd;
  final Function(Offset) onDoubleTapDown;
  final VoidCallback onDoubleTap;
  final int webtoonSidePadding;
  final bool showPageGaps;
  final bool reverse;
  final ValueNotifier<bool> isScrolling;

  const ImageViewWebtoon({
    super.key,
    required this.pages,
    required this.itemScrollController,
    required this.scrollOffsetController,
    required this.itemPositionsListener,
    required this.scrollDirection,
    required this.minCacheExtent,
    required this.initialScrollIndex,
    required this.physics,
    required this.onLongPressData,
    required this.onFailedToLoadImage,
    required this.backgroundColor,
    required this.isDoublePageMode,
    required this.pageMode,
    required this.isHorizontalContinuous,
    required this.readerMode,
    required this.photoViewController,
    required this.photoViewScaleStateController,
    required this.scalePosition,
    required this.onScaleEnd,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.isScrolling,
    this.webtoonSidePadding = 0,
    this.showPageGaps = true,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (zoomContext, _) => PhotoViewGallery.builder(
        itemCount: 1,
        builder: (_, _) => PhotoViewGalleryPageOptions.customChild(
          controller: photoViewController,
          scaleStateController: photoViewScaleStateController,
          basePosition: scalePosition,
          onScaleEnd: (context, details, controllerValue) =>
              onScaleEnd(details),
          child: _wrapPointerSignalHandler(
            zoomContext: zoomContext,
            child: ScrollablePositionedList.separated(
              scrollDirection: scrollDirection,
              reverse: reverse,
              minCacheExtent: minCacheExtent,
              initialScrollIndex: initialScrollIndex,
              itemCount: isDoublePageMode && !isHorizontalContinuous
                  ? doublePageViewCount(pages.length, pageMode)
                  : pages.length,
              physics: physics,
              itemScrollController: itemScrollController,
              scrollOffsetController: scrollOffsetController,
              itemPositionsListener: itemPositionsListener,
              itemBuilder: (context, index) =>
                  _buildItem(context, index, zoomContext),
              separatorBuilder: (context, index) =>
                  _buildSeparator(context, index, zoomContext),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, BuildContext zoomContext) {
    final currentActualIndex = isDoublePageMode && !isHorizontalContinuous
        ? doublePageViewToActualIndex(index, pages.length, pageMode)
        : index;
    final currentPage = pages[currentActualIndex];
    final uniqueKey = ValueKey(
      '${currentPage.chapter?.id ?? "trans"}-${currentPage.index ?? currentActualIndex}',
    );

    return _wrapPointerSignalHandler(
      zoomContext: zoomContext,
      child: KeyedSubtree(
        key: uniqueKey,
        child: (isDoublePageMode && !isHorizontalContinuous)
            ? _buildDoublePageItem(context, index)
            : _buildSinglePageItem(context, index),
      ),
    );
  }

  Widget _buildSinglePageItem(BuildContext context, int index) {
    final currentPage = pages[index];
    final double sidePad = webtoonSidePadding > 0
        ? MediaQuery.of(context).size.width * webtoonSidePadding / 100
        : 0;

    if (currentPage.isTransitionPage) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTapDown: (details) => onDoubleTapDown(details.globalPosition),
        onDoubleTap: onDoubleTap,
        child: TransitionViewVertical(data: currentPage),
      );
    }

    return Padding(
      padding: isHorizontalContinuous
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: sidePad),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTapDown: (details) => onDoubleTapDown(details.globalPosition),
        onDoubleTap: onDoubleTap,
        child: ImageViewVertical(
          data: currentPage,
          failedToLoadImage: onFailedToLoadImage,
          onLongPressData: onLongPressData,
          isHorizontal: isHorizontalContinuous,
          isScrolling: isScrolling,
        ),
      ),
    );
  }

  Widget _buildDoublePageItem(BuildContext context, int index) {
    final pageLength = pages.length;
    if (index >= pageLength) {
      return const SizedBox.shrink();
    }

    final datas = doublePageSpreadItems(pages, index, pageMode);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: (details) => onDoubleTapDown(details.globalPosition),
      onDoubleTap: onDoubleTap,
      child: DoublePageView.vertical(
        pages: datas,
        backgroundColor: backgroundColor,
        onFailedToLoadImage: onFailedToLoadImage,
        onLongPressData: onLongPressData,
      ),
    );
  }

  Widget _buildSeparator(
    BuildContext context,
    int index,
    BuildContext zoomContext,
  ) {
    if (!showPageGaps || readerMode == ReaderMode.webtoon) {
      return const SizedBox.shrink();
    }

    if (isHorizontalContinuous) {
      return _wrapPointerSignalHandler(
        zoomContext: zoomContext,
        child: VerticalDivider(
          color: getBackgroundColor(backgroundColor),
          width: 6,
        ),
      );
    } else {
      return _wrapPointerSignalHandler(
        zoomContext: zoomContext,
        child: Divider(color: getBackgroundColor(backgroundColor), height: 6),
      );
    }
  }

  Widget _wrapPointerSignalHandler({
    required BuildContext zoomContext,
    required Widget child,
  }) {
    return Builder(
      builder: (scrollContext) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) => _handlePointerSignal(
          event,
          zoomContext: zoomContext,
          scrollContext: scrollContext,
        ),
        child: child,
      ),
    );
  }

  void _handlePointerSignal(
    PointerSignalEvent event, {
    required BuildContext zoomContext,
    required BuildContext scrollContext,
  }) {
    if (registerReaderModifierWheelZoom(
      event,
      zoomContext: zoomContext,
      photoViewController: photoViewController,
      scaleStateController: photoViewScaleStateController,
      basePosition: scalePosition,
    )) {
      return;
    }

    registerHorizontalContinuousWheelScroll(
      event,
      isHorizontalContinuous: isHorizontalContinuous,
      scrollContext: scrollContext,
      scrollOffsetController: scrollOffsetController,
    );
  }
}
