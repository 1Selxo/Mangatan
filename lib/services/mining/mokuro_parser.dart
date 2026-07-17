import 'dart:convert';
import 'dart:io';

import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/services/download_manager/downloaded_manga_artifact.dart';
import 'package:mangayomi/services/mining/mokuro_sidecar_path.dart';
import 'package:mangayomi/services/mining/ocr_models.dart';
import 'package:path/path.dart' as p;

class MokuroVolume {
  final String title;
  final String volume;
  final List<MokuroPage> pages;

  const MokuroVolume({
    required this.title,
    required this.volume,
    required this.pages,
  });
}

class MokuroPage {
  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final List<MokuroBlock> blocks;

  const MokuroPage({
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.blocks,
  });
}

class MokuroBlock {
  final List<double> box;
  final bool vertical;
  final List<String> lines;
  final List<List<List<double>>> lineCoordinates;

  const MokuroBlock({
    required this.box,
    required this.vertical,
    required this.lines,
    this.lineCoordinates = const [],
  });
}

class MokuroParser {
  const MokuroParser();

  MokuroVolume parse(String content) {
    final json = jsonDecode(content) as Map<String, dynamic>;
    final pages = (json['pages'] as List? ?? const [])
        .whereType<Map>()
        .map((page) => _parsePage(page.cast<String, dynamic>()))
        .toList();
    return MokuroVolume(
      title: json['title']?.toString() ?? '',
      volume: json['volume']?.toString() ?? '',
      pages: pages,
    );
  }

  Future<MokuroVolume?> findForReaderPage(UChapDataPreload data) async {
    for (final candidate in _candidateFiles(data)) {
      if (await candidate.exists()) {
        try {
          return parse(await candidate.readAsString());
        } catch (_) {
          // Ignore stale, partial, or manually copied files and continue to
          // another local candidate before the reader falls back to network
          // or generated OCR.
        }
      }
    }
    return null;
  }

  MokuroPage? resolvePage(
    MokuroVolume volume, {
    required UChapDataPreload data,
  }) {
    // [index] is chapter-local, while [pageIndex] becomes global when the
    // continuous reader appends or prepends adjacent chapters.
    final pageIndex = data.index ?? data.pageIndex ?? 0;
    final localName = data.isLocale == true && data.index != null
        ? '${data.index.toString().padLeft(5, '0')}.jpg'
        : null;
    for (final page in volume.pages) {
      final mokuroName = p.basename(page.imagePath).toLowerCase();
      if (localName != null && mokuroName == localName.toLowerCase()) {
        return page;
      }
      final urlName =
          data.pageUrl?.fileName ?? p.basename(data.pageUrl?.url ?? '');
      if (urlName.isNotEmpty && mokuroName == urlName.toLowerCase()) {
        return page;
      }
    }
    if (pageIndex >= 0 && pageIndex < volume.pages.length) {
      return volume.pages[pageIndex];
    }
    return null;
  }

  List<OcrTextBlock> convertPage(MokuroPage page) {
    final width = page.imageWidth.toDouble();
    final height = page.imageHeight.toDouble();
    if (width <= 0 || height <= 0) return const [];
    return page.blocks
        .map((block) {
          return _convertBlock(block, width, height);
        })
        .whereType<OcrTextBlock>()
        .toList();
  }

  MokuroPage _parsePage(Map<String, dynamic> json) {
    return MokuroPage(
      imagePath: json['img_path']?.toString() ?? '',
      imageWidth: _asInt(json['img_width']),
      imageHeight: _asInt(json['img_height']),
      blocks: (json['blocks'] as List? ?? const [])
          .whereType<Map>()
          .map((block) => _parseBlock(block.cast<String, dynamic>()))
          .toList(),
    );
  }

  MokuroBlock _parseBlock(Map<String, dynamic> json) {
    return MokuroBlock(
      box: _asDoubleList(json['box']),
      vertical: json['vertical'] == true,
      lines: (json['lines'] as List? ?? const [])
          .map((line) => line.toString())
          .where((line) => line.trim().isNotEmpty)
          .toList(),
      lineCoordinates: _asPolygonList(json['lines_coords']),
    );
  }

  OcrTextBlock? _convertBlock(MokuroBlock block, double width, double height) {
    if (block.box.length < 4 || block.lines.isEmpty) return null;
    final x1 = block.box[0];
    final y1 = block.box[1];
    final x2 = block.box[2];
    final y2 = block.box[3];
    if (x2 <= x1 || y2 <= y1) return null;
    return OcrTextBlock(
      xmin: (x1 / width).clamp(0, 1).toDouble(),
      ymin: (y1 / height).clamp(0, 1).toDouble(),
      xmax: (x2 / width).clamp(0, 1).toDouble(),
      ymax: (y2 / height).clamp(0, 1).toDouble(),
      lines: block.lines,
      vertical: block.vertical,
      lineGeometries: block.lineCoordinates
          .map((polygon) => _lineGeometry(polygon, width, height))
          .whereType<OcrLineGeometry>()
          .toList(),
    );
  }

  OcrLineGeometry? _lineGeometry(
    List<List<double>> polygon,
    double width,
    double height,
  ) {
    if (polygon.isEmpty) return null;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final point in polygon) {
      if (point.length < 2) continue;
      minX = point[0] < minX ? point[0] : minX;
      minY = point[1] < minY ? point[1] : minY;
      maxX = point[0] > maxX ? point[0] : maxX;
      maxY = point[1] > maxY ? point[1] : maxY;
    }
    if (maxX <= minX || maxY <= minY) return null;
    return OcrLineGeometry(
      xmin: (minX / width).clamp(0, 1).toDouble(),
      ymin: (minY / height).clamp(0, 1).toDouble(),
      xmax: (maxX / width).clamp(0, 1).toDouble(),
      ymax: (maxY / height).clamp(0, 1).toDouble(),
    );
  }

  Iterable<File> _candidateFiles(UChapDataPreload data) sync* {
    final localArtifactPath = data.localArtifactPath;
    if (localArtifactPath != null && localArtifactPath.trim().isNotEmpty) {
      yield* _artifactCandidates(localArtifactPath);
    }

    final archivePath = data.chapter?.archivePath;
    if (archivePath != null && archivePath.trim().isNotEmpty) {
      final parsed = p.setExtension(archivePath, '.mokuro');
      yield File(parsed);
      yield File(
        p.join(
          p.dirname(archivePath),
          '${p.basenameWithoutExtension(archivePath)}.json',
        ),
      );
    }
    final directory = data.directory;
    if (directory != null) {
      yield File(p.join(directory.path, '.mokuro'));
      yield File(p.join(directory.path, 'mokuro.json'));
      yield mokuroSidecarFor(directory);

      // Reader data created before [localArtifactPath] was added still knows
      // the intended chapter directory. Derive the exact downloaded CBZ
      // sibling rather than scanning the manga directory and risking another
      // chapter's OCR.
      final chapter = data.chapter;
      if (chapter != null) {
        final cbz = downloadedMangaChapterCbz(directory.parent, chapter);
        yield mokuroSidecarFor(cbz);
      }
      if (directory.existsSync()) {
        for (final entity in directory.listSync()) {
          if (entity is File &&
              (entity.path.toLowerCase().endsWith('.mokuro') ||
                  entity.path.toLowerCase().endsWith('mokuro.json'))) {
            yield entity;
          }
        }
      }
    }
  }

  Iterable<File> _artifactCandidates(String artifactPath) sync* {
    final type = FileSystemEntity.typeSync(artifactPath);
    final isDirectory = type == FileSystemEntityType.directory;
    if (isDirectory) {
      final directory = Directory(artifactPath);
      yield File(p.join(directory.path, '.mokuro'));
      yield File(p.join(directory.path, 'mokuro.json'));
      yield mokuroSidecarFor(directory);
      return;
    }

    yield File(p.setExtension(artifactPath, '.mokuro'));
    yield File(p.setExtension(artifactPath, '.json'));
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<double> _asDoubleList(dynamic value) {
    return (value as List? ?? const [])
        .map((item) => double.tryParse(item.toString()))
        .whereType<double>()
        .toList();
  }

  static List<List<List<double>>> _asPolygonList(dynamic value) {
    return (value as List? ?? const []).map((polygon) {
      return (polygon as List? ?? const []).map((point) {
        return _asDoubleList(point);
      }).toList();
    }).toList();
  }
}
