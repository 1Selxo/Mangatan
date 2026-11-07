import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/reader/widgets/page_preview.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_bottom_bar.dart';
import 'package:shiori/shiori.dart';

/// Displays the thumbnail preview of the page under the reader bottom bar
/// slider while it is being dragged.
class ReaderSliderPreviewOverlay extends StatelessWidget {
  final ValueListenable<int?> sliderPreviewIndex;
  final bool isUiVisible;
  final int totalPages;
  final bool isReverseHorizontal;

  /// The image of the chapter's page at a slider position, or null while
  /// it is not known.
  final ImageProvider? Function(int pageInChapter) imageForPage;
  final String Function(int index) currentIndexLabel;

  const ReaderSliderPreviewOverlay({
    super.key,
    required this.sliderPreviewIndex,
    required this.isUiVisible,
    required this.totalPages,
    required this.isReverseHorizontal,
    required this.imageForPage,
    required this.currentIndexLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int?>(
      valueListenable: sliderPreviewIndex,
      builder: (context, index, _) {
        if (index == null || !isUiVisible) {
          return const SizedBox.shrink();
        }
        ImageProvider? image;
        try {
          image = imageForPage(index);
        } catch (_) {
          image = null;
        }
        // Over the slider's thumb, as a video's frame follows the finger:
        // the slider's share of the way, mirrored when reading right to
        // left.
        var fraction = totalPages > 1 ? index / (totalPages - 1) : 0.5;
        if (isReverseHorizontal) fraction = 1 - fraction;
        return Positioned(
          left: 0,
          right: 0,
          bottom: ReaderBottomBar.heightAbove(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                // The track's ends: the panel's margin, a chapter button and
                // a page figure each side.
                padding: const EdgeInsets.symmetric(
                  horizontal: ShioriSpace.s8 + 48 + 44,
                ),
                child: Align(
                  alignment: Alignment(fraction * 2 - 1, 0),
                  child: ReaderPagePreview(
                    image: image,
                    label: '${currentIndexLabel(index)} / $totalPages',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
