import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/mixins/page_ocr_mixin.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/providers/reader_state_provider.dart';
import 'package:mangayomi/modules/manga/reader/subsampling_scale_image_view/src/min_subsampling_image_view.dart';
import 'package:mangayomi/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:mangayomi/modules/manga/reader/subsampling_scale_image_view/subsampling_scale_image_view.dart';

class ImageViewVertical extends ConsumerStatefulWidget {
  final UChapDataPreload data;
  final Function(UChapDataPreload data) onLongPressData;
  final bool isHorizontal;
  final Function(bool) failedToLoadImage;
  final Widget? Function(SubsamplingImageState)? loadStateChanged;
  final int rotation;
  final Function(double width, double height)? onImageLoaded;

  const ImageViewVertical({
    super.key,
    required this.data,
    required this.onLongPressData,
    required this.failedToLoadImage,
    required this.isHorizontal,
    this.loadStateChanged,
    this.rotation = 0,
    this.onImageLoaded,
  });

  @override
  ConsumerState<ImageViewVertical> createState() => _ImageViewVerticalState();
}

class _ImageViewVerticalState extends ConsumerState<ImageViewVertical>
    with PageOcrMixin {
  @override
  UChapDataPreload get ocrPage => widget.data;

  @override
  void didUpdateWidget(covariant ImageViewVertical oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateOcrPage(oldWidget.data);
  }

  @override
  Widget build(BuildContext context) {
    final (colorBlendMode, color) = chapterColorFIlterValues(context, ref);
    final cropBorders = ref.watch(cropBordersStateProvider);

    final imageWidget = MinSubsamplingImage(
      data: widget.data,
      fit: getBoxFit(ref.watch(scaleTypeStateProvider)),
      color: color,
      colorBlendMode: colorBlendMode,
      cropBorders: cropBorders,
      isHorizontal: widget.isHorizontal,
      failedToLoadImage: widget.failedToLoadImage,
      loadStateChanged: widget.loadStateChanged,
      rotation: widget.rotation,
      onImageLoaded: (width, height) {
        widget.onImageLoaded?.call(width, height);
        loadOcr();
      },
      overlayKey: ocrKey,
      paintOverlay: paintOcr,
      overlayRepaint: ocr,
    );

    return applyReaderColorFilter(
      GestureDetector(
        onLongPress: () => widget.onLongPressData.call(widget.data),
        child: imageWidget,
      ),
      ref,
    );
  }
}
