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
}
