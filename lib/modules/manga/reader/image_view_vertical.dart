import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_colors.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:mangayomi/modules/manga/reader/widgets/circular_progress_indicator_animate_rotate.dart';

class ImageViewVertical extends ConsumerStatefulWidget {
  final UChapDataPreload data;
  final Function(UChapDataPreload data) onLongPressData;
  final bool isHorizontal;
  final ValueNotifier<bool> isScrolling;

  final Function(bool) failedToLoadImage;

  const ImageViewVertical({
    super.key,
    required this.data,
    required this.onLongPressData,
    required this.failedToLoadImage,
    required this.isHorizontal,
    required this.isScrolling,
  });

  @override
  ConsumerState<ImageViewVertical> createState() => _ImageViewVerticalState();
}

class _ImageViewVerticalState extends ConsumerState<ImageViewVertical> {
  final GlobalKey _imageKey = GlobalKey();
  late ReaderOcrController _ocr = ReaderOcrController(
    widget.data,
    imageKey: _imageKey,
  )..addListener(_repaint);

  void _repaint() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _imageKey.currentContext?.findRenderObject()?.markNeedsPaint();
    });
  }

  @override
  void didUpdateWidget(covariant ImageViewVertical oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _ocr
        ..removeListener(_repaint)
        ..dispose();
      _ocr = ReaderOcrController(widget.data, imageKey: _imageKey)
        ..addListener(_repaint);
    }
  }

  @override
  void dispose() {
    _ocr
      ..removeListener(_repaint)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ocr.updateTheme(Theme.of(context).colorScheme.primary);
    final (colorBlendMode, color) = chapterColorFIlterValues(context, ref);

    Rect? ocrHitTestImageRect(Rect paintedRect) {
      final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      return readerOcrHitTestImageRect(
        paintedImageRect: paintedRect,
        renderBoxSize: box.size,
        normalizePaintCoordinates: true,
      );
    }

    final imageWidget = ValueListenableBuilder<bool>(
      valueListenable: widget.isScrolling,
      builder: (context, scrolling, _) => ExtendedImage(
        key: _imageKey,
        colorBlendMode: colorBlendMode,
        color: color,
        image: widget.data.getImageProvider(ref, true),
        filterQuality: scrolling ? FilterQuality.low : FilterQuality.medium,
        handleLoadingProgress: true,
        fit: getBoxFit(ref.watch(scaleTypeStateProvider)),
        enableLoadState: true,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.completed) {
            widget.failedToLoadImage(false);
            _ocr.load();
            final rawSize = state.extendedImageInfo?.image;
            if (rawSize != null && widget.data.loadedHeight == null) {
              final screenWidth = widget.isHorizontal
                  ? context.width(0.8)
                  : MediaQuery.of(context).size.width;
              final aspect = rawSize.width / rawSize.height;
              widget.data.loadedWidth = screenWidth;
              widget.data.loadedHeight = screenWidth / aspect;
            }
          }
          final placeholderHeight =
              widget.data.loadedHeight ?? context.height(0.8);
          final placeholderWidth = widget.isHorizontal
              ? (widget.data.loadedWidth ?? context.width(0.8))
              : null;
          if (state.extendedImageLoadState == LoadState.loading) {
            final ImageChunkEvent? loadingProgress = state.loadingProgress;
            final double progress = loadingProgress?.expectedTotalBytes != null
                ? loadingProgress!.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : 0;
            return Container(
              color: Colors.black,
              height: placeholderHeight,
              width: placeholderWidth,
              child: CircularProgressIndicatorAnimateRotate(progress: progress),
            );
          }
          if (state.extendedImageLoadState == LoadState.failed) {
            widget.failedToLoadImage(true);
            return Container(
              color: Colors.black,
              height: placeholderHeight,
              width: placeholderWidth,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.image_loading_error,
                    style: TextStyle(
                      color: readerErrorForegroundColor(Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onLongPress: () {
                        state.reLoadImage();
                        widget.failedToLoadImage(false);
                      },
                      onTap: () {
                        state.reLoadImage();
                        widget.failedToLoadImage(false);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.primaryColor,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Text(
                            context.l10n.retry,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return null;
        },
        afterPaintImage: (canvas, rect, image, paint) {
          _ocr.paint(
            canvas,
            rect,
            image,
            paint,
            hitTestImageRect: ocrHitTestImageRect(rect),
          );
        },
      ),
    );
    return applyReaderColorFilter(
      GestureDetector(
        onLongPress: () => widget.onLongPressData.call(widget.data),
        child: widget.isHorizontal
            ? imageWidget
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.data.index == 0)
                    SizedBox(height: MediaQuery.of(context).padding.top),
                  imageWidget,
                ],
              ),
      ),
      ref,
    );
  }
}
