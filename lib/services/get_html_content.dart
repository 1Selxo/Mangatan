import 'dart:convert';
import 'dart:io';
import 'package:html/dom.dart' as dom;
import 'package:mangayomi/src/rust/api/epub.dart';
import 'package:path/path.dart' as p;
import 'package:html/parser.dart';
import 'package:mangayomi/eval/lib.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/modules/more/settings/browse/providers/browse_state_provider.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'get_html_content.g.dart';

@riverpod
Future<(String, EpubNovel?)> getHtmlContent(
  Ref ref, {
  required Chapter chapter,
}) async {
  final keepAlive = ref.keepAlive();
  (String, EpubNovel?)? result;
  try {
    if (!chapter.manga.isLoaded) {
      chapter.manga.loadSync();
    }
    if (chapter.archivePath != null && chapter.archivePath!.isNotEmpty) {
      try {
        final book = await parseEpubFromPath(
          epubPath: chapter.archivePath!,
          fullData: true,
        );
        // A local EPUB is always one continuous reader document. `Chapter`
        // rows are TOC shortcuts only and must never select a physical XHTML
        // file as the reader's state owner.
        final htmlContent = selectEpubChapterContent(book, null);
        if (!readerHtmlHasRenderableContent(htmlContent)) {
          throw const FormatException(
            'The EPUB contains no readable chapter content.',
          );
        }
        // Keep the original EPUB XHTML for the browser reader. It needs the
        // document head and relative URLs to resolve publisher CSS, images,
        // footnotes, and SVG resources from the materialized EPUB session.
        // The compatibility Flutter renderer still sanitizes this through
        // buildReaderHtml when it is used as a fallback.
        result = (htmlContent, book);
      } catch (error) {
        final message = const HtmlEscape().convert(error.toString());
        result = (
          buildReaderHtml(
            '<p><strong>Unable to open this EPUB chapter.</strong></p>'
            '<p>$message</p>',
          ),
          null,
        );
      }
    }
    if (result == null) {
      final storageProvider = StorageProvider();
      final mangaMainDirectory = await storageProvider.getMangaMainDirectory(
        chapter,
      );
      final chapterDirectory = (await storageProvider.getMangaChapterDirectory(
        chapter,
        mangaMainDirectory: mangaMainDirectory,
      ))!;

      final htmlPath = p.join(chapterDirectory.path, "${chapter.name}.html");

      final htmlFile = File(htmlPath);
      String? htmlContent;
      if (await htmlFile.exists()) {
        htmlContent = await htmlFile.readAsString();
      }
      final source = getSource(
        chapter.manga.value!.lang!,
        chapter.manga.value!.source!,
        chapter.manga.value!.sourceId,
      );
      final proxyServer = ref.read(androidProxyServerStateProvider);
      final html = await withExtensionService(source!, proxyServer, (
        service,
      ) async {
        if (htmlContent != null) {
          return await service.cleanHtmlContent(htmlContent);
        } else {
          return await service.getHtmlContent(
            chapter.manga.value!.name!,
            chapter.url!,
          );
        }
      });
      result = (buildReaderHtml(html.substring(1, html.length - 1)), null);
    }

    keepAlive.close();
    return result;
  } catch (e) {
    keepAlive.close();
    rethrow;
  }
}

String selectEpubChapterContent(EpubNovel book, String? chapterPath) {
  if (chapterPath != null && chapterPath.isNotEmpty) {
    for (final subChapter in book.chapters) {
      if (subChapter.path == chapterPath ||
          _normalizedEpubReference(subChapter.href) ==
              _normalizedEpubReference(chapterPath)) {
        return subChapter.content;
      }
    }
    return '';
  }

  return buildContinuousEpubContent(book);
}

String epubSpineMarkerId(int spineIndex) => 'mangatan-spine-$spineIndex';

String buildContinuousEpubContent(EpubNovel book) {
  final byHref = <String, EpubChapter>{
    for (final chapter in book.chapters)
      _normalizedEpubReference(chapter.href): chapter,
  };
  final stylesheetLinks = <String>{};
  final logicalSections = <String>[];
  final physicalSections = <String>[];
  int? logicalNavigationSpine;
  var hasPhysicalSection = false;
  var characterStart = 0;
  var linearChapterIndex = 0;

  void finishLogicalSection() {
    if (physicalSections.isEmpty) return;
    logicalSections.add(
      '<article class="mangatan-logical-section" '
      'data-mangatan-navigation-spine="${logicalNavigationSpine ?? -1}">'
      '<i class="mangatan-logical-marker" aria-hidden="true"></i>'
      '${physicalSections.join()}'
      '</article>',
    );
    physicalSections.clear();
  }

  for (final chapter in book.chapters) {
    if (!readerHtmlHasRenderableContent(chapter.content) && !chapter.isLinear) {
      continue;
    }
    if (chapter.isNavigationEntry && physicalSections.isNotEmpty) {
      finishLogicalSection();
      logicalNavigationSpine = null;
    }
    if (chapter.isNavigationEntry) {
      logicalNavigationSpine = chapter.spineIndex;
    }
    final document = parse(chapter.content);
    final idPrefix = 'mangatan-s${chapter.spineIndex}-';

    for (final element in document.querySelectorAll('[id], [name]')) {
      final id = element.id;
      if (id.isNotEmpty) element.id = '$idPrefix$id';
      final name = element.attributes['name'];
      if (name != null && name.isNotEmpty) {
        element.attributes['name'] = '$idPrefix$name';
      }
    }

    for (final element in document.querySelectorAll('[src], [poster], image')) {
      for (final attribute in const ['src', 'poster', 'href']) {
        final value = element.attributes[attribute];
        if (value == null || _isExternalEpubReference(value)) continue;
        element.attributes[attribute] = _resolveEpubReference(
          chapter.href,
          value,
        );
      }
      for (final attribute
          in element.attributes.keys
              .whereType<dom.AttributeName>()
              .where((attribute) => attribute.name == 'href')
              .toList(growable: false)) {
        final value = element.attributes[attribute];
        if (value == null || _isExternalEpubReference(value)) continue;
        element.attributes[attribute] = _resolveEpubReference(
          chapter.href,
          value,
        );
      }
    }

    for (final link in document.querySelectorAll('link[rel][href]')) {
      final rel = link.attributes['rel']?.toLowerCase() ?? '';
      final href = link.attributes['href'];
      if (!rel.contains('stylesheet') || href == null) continue;
      link.attributes['href'] = _resolveEpubReference(chapter.href, href);
      stylesheetLinks.add(link.outerHtml);
    }

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty || _isExternalEpubReference(href)) {
        continue;
      }
      final parts = href.split('#');
      final targetPath = parts.first.isEmpty
          ? _normalizedEpubReference(chapter.href)
          : _normalizedEpubReference(
              _resolveEpubReference(chapter.href, parts.first),
            );
      final target = byHref[targetPath];
      if (target == null) continue;
      final fragment = parts.length > 1 && parts[1].isNotEmpty
          ? '-${parts.sublist(1).join('#')}'
          : '';
      anchor.attributes['href'] = fragment.isEmpty
          ? '#${epubSpineMarkerId(target.spineIndex)}'
          : '#mangatan-s${target.spineIndex}$fragment';
    }

    final body = document.body;
    final textLength = chapter.isLinear
        ? chimahonChapterCharacterCount(chapter.content)
        : 0;
    final chapterIndexAttribute = chapter.isLinear
        ? 'data-mangatan-chapter-index="$linearChapterIndex" '
        : '';
    physicalSections.add(
      '${hasPhysicalSection ? '<hr data-mangatan-spine-separator>' : ''}'
      '<section id="${epubSpineMarkerId(chapter.spineIndex)}" '
      'data-mangatan-spine-index="${chapter.spineIndex}" '
      '$chapterIndexAttribute'
      'data-mangatan-navigation="${chapter.isNavigationEntry}" '
      'data-mangatan-character-start="$characterStart" '
      'data-mangatan-character-count="$textLength">'
      '${body?.innerHtml ?? chapter.content}'
      '</section>',
    );
    hasPhysicalSection = true;
    if (chapter.isLinear) {
      characterStart += textLength;
      linearChapterIndex++;
    }
  }
  finishLogicalSection();

  return '<!doctype html><html><head>${stylesheetLinks.join()}</head>'
      '<body>${logicalSections.join()}</body></html>';
}

/// Counts EPUB chapter characters exactly like Chimahon's
/// `NovelReaderCharacterCountPolicy` so its bookmark `characterCount` can be
/// restored or synced without conversion.
int chimahonChapterCharacterCount(String? content) {
  if (content == null) return 0;
  final body = RegExp(
    r'<body.*?</body>',
    dotAll: true,
  ).firstMatch(content)?.group(0);
  var text = body ?? content;
  text = text.replaceAll(RegExp(r'<rt>.*?</rt>', dotAll: true), '');
  text = text.replaceAll(
    RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true),
    '',
  );
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  var count = 0;
  for (final codePoint in text.runes) {
    if (_isChimahonCountedCharacter(codePoint)) count++;
  }
  return count;
}

bool _isChimahonCountedCharacter(int codePoint) {
  bool between(int first, int last) => codePoint >= first && codePoint <= last;
  return between(0x30, 0x39) ||
      between(0x41, 0x5a) ||
      between(0x61, 0x7a) ||
      codePoint == 0x25cb ||
      codePoint == 0x25ef ||
      between(0x3005, 0x3007) ||
      codePoint == 0x303b ||
      between(0x3041, 0x3096) ||
      between(0x309d, 0x309e) ||
      between(0x30a1, 0x30fa) ||
      codePoint == 0x30fc ||
      between(0xff10, 0xff19) ||
      between(0xff21, 0xff3a) ||
      between(0xff41, 0xff5a) ||
      between(0xff66, 0xff9d) ||
      between(0x3400, 0x4dbf) ||
      between(0x4e00, 0x9fff) ||
      between(0xf900, 0xfaff) ||
      between(0x20000, 0x2a6df) ||
      between(0x2a700, 0x2b73f) ||
      between(0x2b740, 0x2b81f) ||
      between(0x2b820, 0x2ceaf) ||
      between(0x2ceb0, 0x2ebef) ||
      between(0x30000, 0x3134f) ||
      between(0x31350, 0x323af) ||
      between(0x1100, 0x11ff) ||
      between(0x3130, 0x318f) ||
      between(0xa960, 0xa97f) ||
      between(0xac00, 0xd7af) ||
      between(0xd7b0, 0xd7ff);
}

bool _isExternalEpubReference(String value) {
  final lower = value.trimLeft().toLowerCase();
  return lower.startsWith('http:') ||
      lower.startsWith('https:') ||
      lower.startsWith('data:') ||
      lower.startsWith('javascript:') ||
      lower.startsWith('//');
}

String _resolveEpubReference(String baseHref, String reference) {
  if (reference.startsWith('#')) return reference;
  final withoutSuffix = reference.split('#').first.split('?').first;
  return p.posix.normalize(
    p.posix.join(
      p.posix.dirname(baseHref),
      withoutSuffix.replaceAll('\\', '/'),
    ),
  );
}

String _normalizedEpubReference(String value) {
  final withoutFragment = value.split('#').first.split('?').first;
  try {
    return p.posix
        .normalize(Uri.decodeComponent(withoutFragment).replaceAll('\\', '/'))
        .replaceFirst(RegExp(r'^\./'), '');
  } catch (_) {
    return p.posix
        .normalize(withoutFragment.replaceAll('\\', '/'))
        .replaceFirst(RegExp(r'^\./'), '');
  }
}

bool readerHtmlHasRenderableContent(String input) {
  if (input.trim().isEmpty) return false;
  final document = parse(input);
  final text = document.body?.text.trim() ?? '';
  return text.isNotEmpty ||
      document.querySelector('img, svg, image, video, audio') != null;
}

String buildReaderHtml(String input) {
  // Decode basic escapes
  String cleaned = input
      .replaceAll("\\n", "")
      .replaceAll("\\t", "")
      .replaceAll("\\\"", "\"")
      .replaceAll("\\'", "'")
      .replaceAll("\\&quot;", "\"")
      .replaceAll("&quot;", "\"");

  // Parse HTML to clean it
  final document = parse(cleaned);

  // Remove unwanted elements (ads, tracking, etc.)
  document.querySelectorAll('iframe').forEach((el) => el.remove());
  document.querySelectorAll('script').forEach((el) => el.remove());
  document.querySelectorAll('[data-aa]').forEach((el) => el.remove());

  // Improve styles for EPUB tables
  document.querySelectorAll('table').forEach((table) {
    table.attributes['style'] =
        '${table.attributes['style'] ?? ''} border-collapse: collapse; width: 100%; margin: 10px 0;';
  });

  document.querySelectorAll('td, th').forEach((cell) {
    cell.attributes['style'] =
        '${cell.attributes['style'] ?? ''} border: 1px solid #ddd; padding: 8px;';
  });

  // Improve citations/blockquotes
  document.querySelectorAll('blockquote').forEach((quote) {
    quote.attributes['style'] =
        '${quote.attributes['style'] ?? ''} border-left: 4px solid #ccc; padding-left: 15px; margin: 10px 0; font-style: italic;';
  });

  // Keep entities encoded here. flutter_html parses this fragment again and
  // performs the correct entity decode; decoding `<` at this point would turn
  // literal book text into markup and make it disappear.
  final htmlContent = document.body?.innerHtml ?? cleaned;

  return '''<div id="readerViewContent">$htmlContent</div>''';
}
