import 'dart:convert';
import 'dart:io';
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
        String htmlContent = selectEpubChapterContent(book, chapter.url);
        if (chapter.url != null && chapter.url!.isNotEmpty) {
          // Older imports can contain a stale spine id. Ask Rust directly if
          // the current manifest did not resolve it.
          if (!readerHtmlHasRenderableContent(htmlContent)) {
            htmlContent = await getChapterContent(
              epubPath: chapter.archivePath!,
              chapterPath: chapter.url!,
            );
          }
        }
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

  // Legacy single-entry imports represent the whole book as one chapter.
  return book.chapters
      .map((chapter) => chapter.content)
      .where(readerHtmlHasRenderableContent)
      .join('\n<hr/>\n');
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
