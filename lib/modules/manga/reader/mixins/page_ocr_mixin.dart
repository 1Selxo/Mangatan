import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';

/// The OCR text boxes over one page of the reader: the state of an image view
/// passes [paintOcr], [ocrKey] and [ocr] to it, and keeps [ocrPage] current
/// through [updateOcrPage].
mixin PageOcrMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The page shown.
  UChapDataPreload get ocrPage;

  /// The box the boxes are painted in, to map taps and hovers onto them.
  final GlobalKey ocrKey = GlobalKey();

  late ReaderOcrController ocr = ReaderOcrController(ocrPage, imageKey: ocrKey);

  /// The theme's accent, which the boxes are drawn in.
  Color? _ocrAccent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ocrAccent = Theme.of(context).colorScheme.primary;
  }

  @override
  void initState() {
    super.initState();
    _loadOcrSoon();
  }

  /// Follows the view onto another page.
  void updateOcrPage(UChapDataPreload oldPage) {
    if (identical(oldPage, ocrPage)) return;
    ocr.dispose();
    ocr = ReaderOcrController(ocrPage, imageKey: ocrKey);
    _loadOcrSoon();
  }

  /// Reads the page's text, once its image is there to read.
  void loadOcr() => ocr.load();

  // Not during a build: loading notifies the view, which repaints.
  void _loadOcrSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) ocr.load();
  });

  @override
  void dispose() {
    ocr.dispose();
    super.dispose();
  }

  /// Paints the boxes, matched to the theme, over the page at [pageRect].
  void paintOcr(Canvas canvas, Offset origin, Rect pageRect, Rect clipRect) {
    final accent = _ocrAccent;
    if (accent != null) ocr.updateTheme(accent);
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    ocr.paint(canvas, pageRect, clipRect: clipRect);
    canvas.restore();
  }
}
