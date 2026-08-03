class OcrLineGeometry {
  final double xmin;
  final double ymin;
  final double xmax;
  final double ymax;
  final double rotation;

  const OcrLineGeometry({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
    this.rotation = 0,
  });
}

class OcrTextBlock {
  final double xmin;
  final double ymin;
  final double xmax;
  final double ymax;
  final List<String> lines;
  final bool vertical;
  final List<OcrLineGeometry> lineGeometries;
  final String language;

  const OcrTextBlock({
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
    required this.lines,
    this.vertical = false,
    this.lineGeometries = const [],
    this.language = '',
  });

  String get text => lines.where((line) => line.trim().isNotEmpty).join('\n');

  /// The block's lines joined into a single continuous sentence.
  ///
  /// Unlike [text], this never inserts a hard newline between merged OCR
  /// lines. A raw `\n` between auto-merged fragments makes downstream
  /// sentence extraction (Yomitan) stop at the first line and produces an
  /// incomplete Anki sentence field. Use this whenever a block is handed to a
  /// dictionary popup or mining context as the example sentence.
  String get sentence => lines.where((line) => line.trim().isNotEmpty).join();
}
