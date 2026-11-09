import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/subsampling_scale_image_view/subsampling_scale_image_view.dart'
    as ssiv;
import 'package:mangayomi/modules/manga/reader/utils/double_page_zoom_pan.dart';
import 'package:photo_view/photo_view.dart';

/// Manages single-page and double-page zoom state, keyboard zoom steps,
/// and pan navigation across zoomed double-page spreads.
mixin ReaderZoomControl<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, TickerProviderStateMixin<T> {
  final Map<int, ssiv.SubsamplingScaleImageViewController> pageControllers = {};
  final Map<int, PhotoViewController> doublePageControllers = {};

  /// The scale a double spread had before the keyboard zoomed it, so
  /// zooming back out stops there.
  final Map<int, double> _doublePageBaseScale = {};

  late final DoublePagePanAnimator panAnimator = DoublePagePanAnimator(this);
  static const DoublePageZoomNavigation _zoomNav = DoublePageZoomNavigation();

  bool isCurrentPageZoomed = false;

  int? get currentZoomPageViewIndex;
  bool get isReverseHorizontalForZoom;
  bool get isDoublePageActiveForZoom;
  int pageViewToActualIndexForZoom(int pageViewIndex);
  void handlePageNavigationFromZoom({required bool forward});

  void disposeZoomControl() {
    panAnimator.dispose();
    for (final controller in pageControllers.values) {
      controller.dispose();
    }
    pageControllers.clear();
  }

  void handleNextPageZoomed() {
    final controller = doublePageControllers[currentZoomPageViewIndex];
    if (controller == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final scale = controller.scale ?? 1.0;
    final maxX = screenWidth * (scale - 1.0) / 2.0;

    final targetDx = _zoomNav.nextPanTarget(
      dx: controller.position.dx,
      maxX: maxX,
      step: screenWidth * 0.4,
      isReverseHorizontal: isReverseHorizontalForZoom,
    );
    if (targetDx == null) {
      handlePageNavigationFromZoom(forward: true);
    } else {
      panAnimator.animateTo(
        controllerLookup: () => doublePageControllers[currentZoomPageViewIndex],
        targetDx: targetDx,
      );
    }
  }

  void handlePreviousPageZoomed() {
    final controller = doublePageControllers[currentZoomPageViewIndex];
    if (controller == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final scale = controller.scale ?? 1.0;
    final maxX = screenWidth * (scale - 1.0) / 2.0;

    final targetDx = _zoomNav.previousPanTarget(
      dx: controller.position.dx,
      maxX: maxX,
      step: screenWidth * 0.4,
      isReverseHorizontal: isReverseHorizontalForZoom,
    );
    if (targetDx == null) {
      handlePageNavigationFromZoom(forward: false);
    } else {
      panAnimator.animateTo(
        controllerLookup: () => doublePageControllers[currentZoomPageViewIndex],
        targetDx: targetDx,
      );
    }
  }

  /// Zooms the page on show by [factor] from the keyboard, about its centre:
  /// the single page through its image view, a double spread through its
  /// photo view. The continuous modes zoom with the pointer only.
  ///
  /// [focalPoint], where the wheel was turned in the reader, stays put, as
  /// it does in a browser; without one the page zooms about its centre.
  void zoomBy(double factor, {Offset? focalPoint}) {
    final index = currentZoomPageViewIndex ?? 0;
    final spread = doublePageControllers[index];
    if (isDoublePageActiveForZoom && spread != null) {
      final current = spread.scale ?? 1.0;
      final base = _doublePageBaseScale[index] ??= current;
      final next = (current * factor).clamp(base, base * 8);
      if (next <= base * 1.01) {
        _doublePageBaseScale.remove(index);
        spread.reset();
      } else if (focalPoint != null) {
        // The spread's position is from the centre of the view.
        final size = MediaQuery.sizeOf(context);
        final focal = focalPoint - Offset(size.width / 2, size.height / 2);
        final ratio = next / current;
        spread.updateMultiple(
          scale: next,
          position: spread.position * ratio + focal * (1 - ratio),
        );
      } else {
        spread.scale = next;
      }
      return;
    }
    final page = pageControllers[pageViewToActualIndexForZoom(index)];
    if (page == null || !page.isReady) return;
    final next = (page.scale * factor).clamp(page.minScale, page.minScale * 8);
    if (focalPoint != null) {
      final ratio = next / page.scale;
      page.setScaleAndTranslation(
        next,
        focalPoint - (focalPoint - page.translation) * ratio,
      );
      return;
    }
    page.animateScaleAndCenter(
      next,
      page.center ?? Offset(page.sWidth / 2, page.sHeight / 2),
    );
  }

  /// Fits the page on show again, as it opened.
  void zoomReset() {
    final index = currentZoomPageViewIndex ?? 0;
    final spread = doublePageControllers[index];
    if (isDoublePageActiveForZoom && spread != null) {
      _doublePageBaseScale.remove(index);
      spread.reset();
      return;
    }
    pageControllers[pageViewToActualIndexForZoom(index)]?.resetScaleAndCenter();
  }

  void updateZoomStateForIndex(int index) {
    if (!mounted) return;
    if (index != pageViewToActualIndexForZoom(currentZoomPageViewIndex ?? 0)) {
      return;
    }
    final controller = pageControllers[index];
    if (controller == null) return;
    final bool isZoomed = controller.scale > controller.minScale * 1.01;
    if (isCurrentPageZoomed != isZoomed) {
      setState(() {
        isCurrentPageZoomed = isZoomed;
      });
    }
  }
}
