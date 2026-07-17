import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:mangayomi/modules/manga/archive_reader/models/models.dart';
import 'package:mangayomi/src/rust/api/epub.dart';
import 'package:path/path.dart' as p;

/// A deliberately conservative EPUB library recommendation.
///
/// The result is only a hint. Ambiguous books and any user override should be
/// imported into the library explicitly chosen by the user.
enum EpubContentKind { imageBased, textBased, ambiguous }

class EpubContentAnalysis {
  const EpubContentAnalysis({
    required this.kind,
    required this.spineItemCount,
    required this.imageReferenceCount,
    required this.imageOnlySpineItemCount,
    required this.textHeavySpineItemCount,
    required this.visibleTextCharacters,
  });

  final EpubContentKind kind;
  final int spineItemCount;
  final int imageReferenceCount;
  final int imageOnlySpineItemCount;
  final int textHeavySpineItemCount;
  final int visibleTextCharacters;
}

/// Classifies an EPUB from its authored spine content, not its total assets.
///
/// Ordinary novels often contain covers, ornaments, and illustrations, so an
/// image count alone is not useful. Image-based is returned only when at least
/// four images are referenced by overwhelmingly image-only spine items.
/// Text-based likewise requires substantial prose. Mixed and short books stay
/// ambiguous and follow the library where the user initiated the import.
EpubContentAnalysis analyzeEpubContent(EpubNovel book) {
  var spineItemCount = 0;
  var imageReferenceCount = 0;
  var imageOnlySpineItemCount = 0;
  var textHeavySpineItemCount = 0;
  var visibleTextCharacters = 0;
  final textCharactersBySpineItem = <int>[];

  for (final chapter in book.chapters.where((chapter) => chapter.isLinear)) {
    final document = html_parser.parse(chapter.content);
    final references = _imageReferences(document, chapter.href);
    final textCharacters = _visibleTextCharacterCount(document);

    if (references.isEmpty && textCharacters == 0) continue;
    spineItemCount++;
    imageReferenceCount += references.length;
    visibleTextCharacters += textCharacters;
    textCharactersBySpineItem.add(textCharacters);
    if (references.isNotEmpty && textCharacters <= 80) {
      imageOnlySpineItemCount++;
    }
    if (textCharacters >= 200) textHeavySpineItemCount++;
  }

  textCharactersBySpineItem.sort();
  final medianTextCharacters = textCharactersBySpineItem.isEmpty
      ? 0
      : textCharactersBySpineItem[textCharactersBySpineItem.length ~/ 2];
  final imageOnlyRatio = spineItemCount == 0
      ? 0.0
      : imageOnlySpineItemCount / spineItemCount;
  final looksImageBased =
      spineItemCount >= 4 &&
      imageReferenceCount >= 4 &&
      imageOnlyRatio >= 0.85 &&
      medianTextCharacters <= 30;

  final textHeavyRatio = spineItemCount == 0
      ? 0.0
      : textHeavySpineItemCount / spineItemCount;
  final looksTextBased =
      visibleTextCharacters >= 2000 &&
      textHeavyRatio >= 0.5 &&
      imageOnlyRatio < 0.8;

  final kind = looksImageBased
      ? EpubContentKind.imageBased
      : looksTextBased
      ? EpubContentKind.textBased
      : EpubContentKind.ambiguous;

  return EpubContentAnalysis(
    kind: kind,
    spineItemCount: spineItemCount,
    imageReferenceCount: imageReferenceCount,
    imageOnlySpineItemCount: imageOnlySpineItemCount,
    textHeavySpineItemCount: textHeavySpineItemCount,
    visibleTextCharacters: visibleTextCharacters,
  );
}

/// Returns only images referenced by linear EPUB spine documents, preserving
/// spine and document order. This adapts Chimahon/Mihon's EPUB page loading and
/// avoids treating unused covers, thumbnails, and ornaments as manga pages.
List<LocalImage> epubMangaPageImages(EpubNovel book) {
  final resources = <String, EpubResource>{};
  final caseInsensitiveResources = <String, EpubResource>{};
  for (final resource in book.images) {
    final normalized = normalizeEpubResourcePath(resource.name);
    resources[normalized] = resource;
    caseInsensitiveResources.putIfAbsent(
      normalized.toLowerCase(),
      () => resource,
    );
  }

  final pages = <LocalImage>[];
  final chapters = book.chapters.where((chapter) => chapter.isLinear).toList()
    ..sort((left, right) => left.spineIndex.compareTo(right.spineIndex));
  for (final chapter in chapters) {
    final document = html_parser.parse(chapter.content);
    for (final reference in _imageReferences(document, chapter.href)) {
      _appendResolvedPage(
        pages,
        reference,
        resources,
        caseInsensitiveResources,
      );
    }
  }
  return pages;
}

void _appendResolvedPage(
  List<LocalImage> pages,
  String reference,
  Map<String, EpubResource> resources,
  Map<String, EpubResource> caseInsensitiveResources,
) {
  final resource =
      resources[reference] ?? caseInsensitiveResources[reference.toLowerCase()];
  if (resource == null) return;

  if (_isRasterImagePath(resource.name)) {
    pages.add(
      LocalImage()
        ..name = p.posix.basename(resource.name)
        ..image = resource.content,
    );
    return;
  }

  // Some EPUBs reference an SVG wrapper from XHTML. Mangatan's archive image
  // reader handles raster pages, so unwrap linked raster images when possible.
  if (!_isSvgPath(resource.name)) return;
  final svg = html_parser.parse(
    utf8.decode(resource.content, allowMalformed: true),
  );
  for (final nested in _imageReferences(svg, resource.name)) {
    final nestedResource =
        resources[nested] ?? caseInsensitiveResources[nested.toLowerCase()];
    if (nestedResource == null || !_isRasterImagePath(nestedResource.name)) {
      continue;
    }
    pages.add(
      LocalImage()
        ..name = p.posix.basename(nestedResource.name)
        ..image = nestedResource.content,
    );
  }
}

List<String> _imageReferences(dom.Document document, String documentPath) {
  final references = <String>[];
  for (final element in document.querySelectorAll('img, image')) {
    final raw = element.localName == 'img'
        ? _attributeValue(element, const {'src'})
        : _attributeValue(element, const {'xlink:href', 'href'});
    final resolved = resolveEpubResourceReference(documentPath, raw);
    if (resolved != null) references.add(resolved);
  }
  return references;
}

String? _attributeValue(dom.Element element, Set<String> names) {
  for (final attribute in element.attributes.entries) {
    if (names.contains(attribute.key.toString().toLowerCase())) {
      return attribute.value;
    }
  }
  return null;
}

int _visibleTextCharacterCount(dom.Document source) {
  final document = source.clone(true);
  for (final element in document.querySelectorAll(
    'script, style, noscript, nav, rt, [hidden], [aria-hidden="true"]',
  )) {
    element.remove();
  }
  final text = document.body?.text ?? document.documentElement?.text ?? '';
  return text.replaceAll(RegExp(r'\s+', unicode: true), '').runes.length;
}

String? resolveEpubResourceReference(String documentPath, String? reference) {
  if (reference == null || reference.trim().isEmpty) return null;
  final trimmed = reference.trim();
  if (RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:').hasMatch(trimmed)) return null;

  final cleanReference = trimmed.split(RegExp(r'[?#]')).first;
  if (cleanReference.isEmpty) return null;
  if (cleanReference.startsWith('/')) {
    return normalizeEpubResourcePath(cleanReference);
  }
  final directory = p.posix.dirname(normalizeEpubResourcePath(documentPath));
  return normalizeEpubResourcePath(p.posix.join(directory, cleanReference));
}

String normalizeEpubResourcePath(String value) {
  var normalized = value.replaceAll('\\', '/').split(RegExp(r'[?#]')).first;
  try {
    normalized = Uri.decodeFull(normalized);
  } on FormatException {
    // Keep malformed percent escapes verbatim; an exact archive match may
    // still be possible.
  }
  normalized = p.posix.normalize(normalized);
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  while (normalized.startsWith('./')) {
    normalized = normalized.substring(2);
  }
  return normalized;
}

bool _isRasterImagePath(String value) {
  final extension = p.posix.extension(value).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.gif', '.webp'}.contains(extension);
}

bool _isSvgPath(String value) =>
    p.posix.extension(value).toLowerCase() == '.svg';
