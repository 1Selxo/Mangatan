import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/src/rust/api/epub.dart';

/// Thin controller for the browser-DOM EPUB surface.
class TtsuEpubReaderController {
  InAppWebViewController? _webView;

  void attach(InAppWebViewController controller) => _webView = controller;

  void detach(InAppWebViewController controller) {
    if (identical(_webView, controller)) _webView = null;
  }

  Future<void> scrollBy(double logicalPixels) async {
    await _webView?.evaluateJavascript(
      source: 'window.mangatanReader?.scrollByPixels($logicalPixels);',
    );
  }

  Future<void> scrollPage(int direction) async {
    await _webView?.evaluateJavascript(
      source: 'window.mangatanReader?.scrollPage(${direction.sign});',
    );
  }

  Future<void> jumpToFraction(double fraction) async {
    final safeFraction = fraction.clamp(0.0, 1.0);
    await _webView?.evaluateJavascript(
      source: 'window.mangatanReader?.jumpToFraction($safeFraction);',
    );
  }
}

/// TTSU-inspired local EPUB renderer.
///
/// EPUB XHTML stays in a browser DOM instead of being expanded into thousands
/// of Flutter widgets. This keeps native text selection, ruby, tables, images,
/// and very large Japanese chapters stable while allowing Mangatan's own
/// dictionary popup to remain the lookup surface.
class TtsuEpubReader extends StatefulWidget {
  const TtsuEpubReader({
    super.key,
    required this.controller,
    required this.chapter,
    required this.html,
    required this.book,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.lineHeight,
    required this.padding,
    required this.textAlign,
    required this.initialProgress,
    required this.tapToScroll,
    required this.onProgress,
    required this.onReaderTap,
    required this.onChapterRequested,
  });

  final TtsuEpubReaderController controller;
  final Chapter chapter;
  final String html;
  final EpubNovel book;
  final String backgroundColor;
  final String textColor;
  final double fontSize;
  final double lineHeight;
  final double padding;
  final String textAlign;
  final double initialProgress;
  final bool tapToScroll;
  final void Function(double offset, double maxOffset) onProgress;
  final void Function(Offset position, Size viewport) onReaderTap;
  final void Function(int direction) onChapterRequested;

  @override
  State<TtsuEpubReader> createState() => _TtsuEpubReaderState();
}

class _TtsuEpubReaderState extends State<TtsuEpubReader> {
  final GlobalKey _webViewKey = GlobalKey();
  InAppWebViewController? _webView;
  double? _restoreAfterReload;
  late String _document = _buildDocument();

  String _buildDocument() => buildTtsuEpubDocument(
    html: widget.html,
    book: widget.book,
    title: widget.chapter.name ?? widget.book.name,
    backgroundColor: widget.backgroundColor,
    textColor: widget.textColor,
    fontSize: widget.fontSize,
    lineHeight: widget.lineHeight,
    padding: widget.padding,
    textAlign: widget.textAlign,
    initialProgress: widget.initialProgress,
    tapToScroll: widget.tapToScroll,
  );

  @override
  void didUpdateWidget(covariant TtsuEpubReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html == widget.html &&
        identical(oldWidget.book, widget.book) &&
        oldWidget.backgroundColor == widget.backgroundColor &&
        oldWidget.textColor == widget.textColor &&
        oldWidget.fontSize == widget.fontSize &&
        oldWidget.lineHeight == widget.lineHeight &&
        oldWidget.padding == widget.padding &&
        oldWidget.textAlign == widget.textAlign &&
        oldWidget.tapToScroll == widget.tapToScroll) {
      return;
    }
    unawaited(_reloadAtCurrentPosition());
  }

  Future<void> _reloadAtCurrentPosition() async {
    final controller = _webView;
    if (controller == null) return;
    final value = await controller.evaluateJavascript(
      source: 'window.mangatanReader?.fraction() ?? 0;',
    );
    _restoreAfterReload = (value as num?)?.toDouble() ?? widget.initialProgress;
    _document = _buildDocument();
    await controller.loadData(
      data: _document,
      baseUrl: WebUri('https://mangatan-reader.local/'),
    );
  }

  @override
  void dispose() {
    final controller = _webView;
    if (controller != null) widget.controller.detach(controller);
    super.dispose();
  }

  void _registerHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'readerProgress',
      callback: (arguments) {
        final data = _firstMap(arguments);
        final offset = (data?['offset'] as num?)?.toDouble() ?? 0;
        final maxOffset = (data?['max'] as num?)?.toDouble() ?? 0;
        widget.onProgress(offset, maxOffset);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'readerTap',
      callback: (arguments) {
        final data = _firstMap(arguments);
        if (data == null) return;
        widget.onReaderTap(
          Offset(
            (data['x'] as num?)?.toDouble() ?? 0,
            (data['y'] as num?)?.toDouble() ?? 0,
          ),
          Size(
            (data['width'] as num?)?.toDouble() ?? 0,
            (data['height'] as num?)?.toDouble() ?? 0,
          ),
        );
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'readerChapter',
      callback: (arguments) {
        final direction = (arguments.firstOrNull as num?)?.toInt() ?? 0;
        if (direction != 0) widget.onChapterRequested(direction);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'readerDictionary',
      callback: (arguments) async {
        final data = _firstMap(arguments);
        if (data == null) return;
        await _showDictionary(data);
      },
    );
  }

  Map<dynamic, dynamic>? _firstMap(List<dynamic> arguments) {
    final first = arguments.firstOrNull;
    return first is Map ? first : null;
  }

  Future<void> _showDictionary(Map<dynamic, dynamic> data) async {
    final text = data['text']?.toString().trim() ?? '';
    if (text.isEmpty || !mounted) return;

    final box = _webViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localAnchor = Offset(
      (data['left'] as num?)?.toDouble() ?? box.size.width / 2,
      (data['bottom'] as num?)?.toDouble() ?? box.size.height / 2,
    );
    final anchor = box.localToGlobal(localAnchor);

    await DictionaryLookupPopup.show(
      context: context,
      anchor: Rect.fromCenter(center: anchor, width: 1, height: 1),
      text: text,
      miningContext: MiningContext(
        mediaType: MiningMediaType.novel,
        sourceTitle: widget.chapter.manga.value?.name ?? widget.book.name,
        chapterTitle: widget.chapter.name ?? '',
        sentence: text,
        sourceUri: Uri.tryParse(widget.chapter.archivePath ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _color(widget.backgroundColor, const Color(0xFF292832)),
      child: InAppWebView(
        key: _webViewKey,
        webViewEnvironment: webViewEnvironment,
        initialData: InAppWebViewInitialData(
          data: _document,
          baseUrl: WebUri('https://mangatan-reader.local/'),
        ),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          supportZoom: false,
          horizontalScrollBarEnabled: false,
          verticalScrollBarEnabled: true,
          disableHorizontalScroll: true,
          isInspectable: kDebugMode,
        ),
        onWebViewCreated: (controller) {
          _webView = controller;
          widget.controller.attach(controller);
          _registerHandlers(controller);
        },
        onLoadStop: (controller, _) async {
          final restore = _restoreAfterReload;
          _restoreAfterReload = null;
          if (restore != null) await widget.controller.jumpToFraction(restore);
        },
      ),
    );
  }
}

Color _color(String value, Color fallback) {
  final normalized = value.trim().replaceFirst('#', '');
  final parsed = int.tryParse(
    normalized.length == 6 ? 'FF$normalized' : normalized,
    radix: 16,
  );
  return parsed == null ? fallback : Color(parsed);
}

/// Builds a self-contained, script-sanitized reader document.
@visibleForTesting
String buildTtsuEpubDocument({
  required String html,
  required EpubNovel book,
  required String title,
  required String backgroundColor,
  required String textColor,
  required double fontSize,
  required double lineHeight,
  required double padding,
  required String textAlign,
  required double initialProgress,
  required bool tapToScroll,
}) {
  final document = html_parser.parse(html);
  document
      .querySelectorAll('script, iframe, object, embed')
      .forEach((element) => element.remove());
  for (final image in document.querySelectorAll('img')) {
    final source = image.attributes['src'];
    if (source == null ||
        source.startsWith('data:') ||
        source.startsWith('http://') ||
        source.startsWith('https://')) {
      continue;
    }
    final resource = _findImage(book.images, source);
    if (resource == null) continue;
    image.attributes['src'] =
        'data:${_mimeType(resource.name)};base64,${base64Encode(resource.content)}';
  }

  final content = document.body?.innerHtml ?? html;
  final safeTitle = const HtmlEscape().convert(title);
  final background = _safeCssColor(backgroundColor, '#292832');
  final foreground = _safeCssColor(textColor, '#ffffff');
  final align = const {'left', 'right', 'center', 'justify'}.contains(textAlign)
      ? textAlign
      : 'left';
  final progress = initialProgress.clamp(0.0, 1.0);
  final tapZones = tapToScroll ? 'true' : 'false';

  return '''<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>$safeTitle</title>
  <style>
    :root { color-scheme: light dark; --reader-bg: $background; --reader-fg: $foreground; }
    html, body { margin: 0; min-height: 100%; background: var(--reader-bg); color: var(--reader-fg); }
    html { scroll-behavior: smooth; overflow-x: hidden; }
    body {
      box-sizing: border-box;
      padding: ${padding}px;
      font-family: "Yu Mincho", "Noto Serif CJK JP", "Meiryo", serif;
      font-size: ${fontSize}px;
      line-height: $lineHeight;
      text-align: $align;
      overflow-wrap: anywhere;
      -webkit-text-size-adjust: 100%;
      user-select: text;
    }
    #reader-content { max-width: 72rem; min-height: 100vh; margin: 0 auto; }
    #reader-content p { margin: 0 0 0.8em; }
    #reader-content ruby { ruby-position: over; }
    #reader-content rt { font-size: 0.55em; }
    #reader-content img, #reader-content svg { display: block; max-width: 100%; height: auto; margin: 1em auto; }
    #reader-content table { max-width: 100%; border-collapse: collapse; overflow-wrap: normal; }
    #reader-content td, #reader-content th { border: 1px solid color-mix(in srgb, var(--reader-fg) 35%, transparent); padding: 0.4em; }
    #reader-content a { color: #64a8ff; }
    #dictionary-action {
      position: fixed; z-index: 2147483647; display: none; transform: translate(-50%, -100%);
      border: 0; border-radius: 999px; padding: 8px 14px; color: white; background: #1769c2;
      font: 600 13px system-ui, sans-serif; box-shadow: 0 4px 16px rgba(0,0,0,.35); cursor: pointer;
    }
  </style>
</head>
<body>
  <main id="reader-content">$content</main>
  <button id="dictionary-action" type="button">Dictionary</button>
  <script>
    (() => {
      const initialProgress = $progress;
      const tapZones = $tapZones;
      const action = document.getElementById('dictionary-action');
      let progressFrame = 0;
      let selected = null;

      const call = (name, payload) => {
        if (window.flutter_inappwebview?.callHandler) {
          window.flutter_inappwebview.callHandler(name, payload);
        }
      };
      const metrics = () => {
        const root = document.documentElement;
        const max = Math.max(0, root.scrollHeight - window.innerHeight);
        return { offset: window.scrollY || root.scrollTop || 0, max };
      };
      const report = () => {
        progressFrame = 0;
        call('readerProgress', metrics());
      };
      const queueReport = () => {
        if (!progressFrame) progressFrame = requestAnimationFrame(report);
      };
      const fraction = () => {
        const value = metrics();
        return value.max > 0 ? value.offset / value.max : 0;
      };
      const jumpToFraction = (value) => {
        const max = metrics().max;
        window.scrollTo({ top: Math.max(0, Math.min(1, Number(value) || 0)) * max, behavior: 'auto' });
        queueReport();
      };
      const scrollByPixels = (value) => window.scrollBy({ top: Number(value) || 0, behavior: 'smooth' });
      const scrollPage = (direction) => scrollByPixels((Number(direction) || 0) * window.innerHeight * 0.88);
      window.mangatanReader = { fraction, jumpToFraction, scrollByPixels, scrollPage };

      window.addEventListener('scroll', queueReport, { passive: true });
      window.addEventListener('resize', queueReport, { passive: true });
      new ResizeObserver(queueReport).observe(document.getElementById('reader-content'));

      const hideAction = () => { action.style.display = 'none'; selected = null; };
      const updateSelection = () => {
        const selection = window.getSelection();
        const text = selection ? selection.toString().trim() : '';
        if (!text || !selection.rangeCount) { hideAction(); return; }
        const rect = selection.getRangeAt(0).getBoundingClientRect();
        if (!rect || (!rect.width && !rect.height)) { hideAction(); return; }
        selected = { text, left: rect.left, top: rect.top, right: rect.right, bottom: rect.bottom };
        action.style.left = Math.max(56, Math.min(window.innerWidth - 56, rect.left + rect.width / 2)) + 'px';
        action.style.top = Math.max(42, rect.top - 8) + 'px';
        action.style.display = 'block';
      };
      document.addEventListener('selectionchange', () => setTimeout(updateSelection, 0));
      document.addEventListener('mouseup', () => setTimeout(updateSelection, 0));
      document.addEventListener('touchend', () => setTimeout(updateSelection, 0), { passive: true });
      action.addEventListener('click', (event) => {
        event.preventDefault(); event.stopPropagation();
        if (selected) call('readerDictionary', selected);
      });
      document.addEventListener('click', (event) => {
        if (event.target === action) return;
        const selection = window.getSelection();
        if (selection && selection.toString().trim()) return;
        hideAction();
        call('readerTap', { x: event.clientX, y: event.clientY, width: window.innerWidth, height: window.innerHeight, tapZones });
      });
      document.addEventListener('keydown', (event) => {
        if (event.key === 'PageDown') { event.preventDefault(); scrollPage(1); }
        if (event.key === 'PageUp') { event.preventDefault(); scrollPage(-1); }
        if (event.key.toLowerCase() === 'n') call('readerChapter', 1);
        if (event.key.toLowerCase() === 'm') call('readerChapter', -1);
      });

      const imagesReady = Promise.all(Array.from(document.images).map((image) => image.complete
        ? Promise.resolve()
        : new Promise((resolve) => { image.addEventListener('load', resolve, { once: true }); image.addEventListener('error', resolve, { once: true }); })));
      Promise.race([imagesReady, new Promise((resolve) => setTimeout(resolve, 2000))])
        .then(() => document.fonts?.ready)
        .then(() => requestAnimationFrame(() => requestAnimationFrame(() => jumpToFraction(initialProgress))));
    })();
  </script>
</body>
</html>''';
}

EpubResource? _findImage(List<EpubResource> images, String source) {
  final normalized = Uri.decodeComponent(
    source.split('#').first.split('?').first.replaceAll('\\', '/'),
  );
  final fileName = normalized.split('/').last.toLowerCase();
  for (final image in images) {
    final name = image.name.replaceAll('\\', '/').toLowerCase();
    if (name.endsWith('/$fileName') || name == fileName) return image;
  }
  return null;
}

String _safeCssColor(String value, String fallback) =>
    RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value.trim())
    ? value.trim()
    : fallback;

String _mimeType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.svg')) return 'image/svg+xml';
  return 'image/jpeg';
}
