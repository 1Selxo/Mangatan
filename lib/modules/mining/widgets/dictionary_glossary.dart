import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';

class DictionaryGlossary extends StatefulWidget {
  const DictionaryGlossary({
    super.key,
    required this.rawGlossary,
    required this.dictionaryName,
    this.dictionaryCss = '',
    this.customCss = '',
    this.fontSize = 14,
  });

  final String rawGlossary;
  final String dictionaryName;
  final String dictionaryCss;
  final String customCss;
  final double fontSize;

  @override
  State<DictionaryGlossary> createState() => _DictionaryGlossaryState();
}

class _DictionaryGlossaryState extends State<DictionaryGlossary> {
  Map<String, String> _media = const {};

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void didUpdateWidget(covariant DictionaryGlossary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawGlossary != widget.rawGlossary ||
        oldWidget.dictionaryName != widget.dictionaryName) {
      _media = const {};
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    final paths = yomitanGlossaryMediaPaths(widget.rawGlossary);
    if (paths.isEmpty) return;
    final loaded = <String, String>{};
    for (final path in paths) {
      final bytes = await HoshidictsLookupBackend.instance.getMediaFile(
        dictName: widget.dictionaryName,
        mediaPath: path,
      );
      if (bytes != null) {
        loaded[path] = 'data:${_mimeType(path)};base64,${base64Encode(bytes)}';
      }
    }
    if (mounted) setState(() => _media = loaded);
  }

  @override
  Widget build(BuildContext context) {
    return Html(
      data: yomitanGlossaryToHtml(
        widget.rawGlossary,
        dictionaryCss: widget.dictionaryCss,
        customCss: widget.customCss,
        mediaDataUris: _media,
      ),
      shrinkWrap: true,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: FontSize(widget.fontSize),
        ),
        '.dictionary-glossary': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        '.glossary-item': Style(margin: Margins.only(bottom: 5)),
      },
    );
  }
}

String yomitanGlossaryToHtml(
  String rawGlossary, {
  String dictionaryCss = '',
  String customCss = '',
  Map<String, String> mediaDataUris = const {},
}) {
  final decoded = _decodeGlossary(rawGlossary);
  final content = _renderGlossaryValue(decoded, mediaDataUris);
  final css = dictionaryCss.replaceAll(
    RegExp(r'</style', caseSensitive: false),
    '',
  );
  final userCss = customCss.replaceAll(
    RegExp(r'</style', caseSensitive: false),
    '',
  );
  return '''
<style>
.dictionary-glossary { margin: 0; padding: 0; }
.glossary-item { margin: 0 0 .35em 0; }
.structured-content { white-space: normal; }
.gloss-sc-table-container { overflow-x: auto; }
.gloss-sc-table { border-collapse: collapse; }
.gloss-sc-td, .gloss-sc-th { padding: .2em .4em; }
.gloss-image { max-width: 100%; height: auto; }
$css
$userCss
</style>
<div class="dictionary-glossary">$content</div>
''';
}

Set<String> yomitanGlossaryMediaPaths(String rawGlossary) {
  final paths = <String>{};
  void walk(Object? value) {
    if (value is List) {
      for (final item in value) {
        walk(item);
      }
    } else if (value is Map) {
      final type = value['type'];
      final tag = value['tag'];
      if (type == 'image' || tag == 'img') {
        final path = value['path'];
        if (path is String && path.isNotEmpty) paths.add(path);
      }
      for (final item in value.values) {
        walk(item);
      }
    }
  }

  walk(_decodeGlossary(rawGlossary));
  return paths;
}

Object? _decodeGlossary(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  if (!text.startsWith('[') && !text.startsWith('{') && !text.startsWith('"')) {
    return raw;
  }
  try {
    return jsonDecode(text);
  } on FormatException {
    return raw;
  }
}

String _renderGlossaryValue(Object? value, Map<String, String> media) {
  if (value is List) {
    return value
        .map(
          (item) =>
              '<div class="glossary-item">${_renderDefinition(item, media)}</div>',
        )
        .join();
  }
  return '<div class="glossary-item">${_renderDefinition(value, media)}</div>';
}

String _renderDefinition(Object? value, Map<String, String> media) {
  if (value is String) return _escapeText(value);
  if (value is List) {
    return '<ul class="glossary-list">${value.map((item) => '<li>${_renderDefinition(item, media)}</li>').join()}</ul>';
  }
  if (value is! Map) return _escapeText(value?.toString() ?? '');
  switch (value['type']) {
    case 'text':
      return _escapeText(value['text']?.toString() ?? '');
    case 'structured-content':
      return '<span class="structured-content">${_renderNode(value['content'], media)}</span>';
    case 'image':
      return _renderImage(value, media);
  }
  return _renderNode(value, media);
}

String _renderNode(Object? value, Map<String, String> media) {
  if (value is String) return _escapeText(value);
  if (value is List) {
    return value.map((item) => _renderNode(item, media)).join();
  }
  if (value is! Map) return '';

  final tag = value['tag']?.toString() ?? '';
  const allowed = {
    'br',
    'ruby',
    'rt',
    'rp',
    'table',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'td',
    'th',
    'span',
    'div',
    'ol',
    'ul',
    'li',
    'details',
    'summary',
    'img',
    'a',
  };
  if (!allowed.contains(tag)) return _renderNode(value['content'], media);
  if (tag == 'img') return _renderImage(value, media);

  final attributes = <String>['class="gloss-sc-$tag"'];
  final data = value['data'];
  if (data is Map) {
    for (final entry in data.entries) {
      if (entry.key.toString().isEmpty || entry.value is! String) continue;
      attributes.add(
        'data-sc-${_kebabCase(entry.key.toString())}="${_escapeAttribute(entry.value.toString())}"',
      );
    }
  }
  for (final name in const ['lang', 'title', 'href']) {
    final attribute = value[name];
    if (attribute is String && attribute.isNotEmpty) {
      attributes.add('$name="${_escapeAttribute(attribute)}"');
    }
  }
  for (final name in const ['colSpan', 'rowSpan']) {
    final attribute = value[name];
    if (attribute is num) {
      attributes.add('${_kebabCase(name)}="${attribute.toInt()}"');
    }
  }
  if (value['open'] == true) attributes.add('open');
  final inlineStyle = _inlineStyle(value['style']);
  if (inlineStyle.isNotEmpty) {
    attributes.add('style="${_escapeAttribute(inlineStyle)}"');
  }
  final child = tag == 'br' ? '' : _renderNode(value['content'], media);
  final element = '<$tag ${attributes.join(' ')}>$child</$tag>';
  return tag == 'table'
      ? '<div class="gloss-sc-table-container">$element</div>'
      : element;
}

String _renderImage(Map value, Map<String, String> media) {
  final path = value['path']?.toString() ?? '';
  final source = media[path];
  if (source == null) {
    return '<span class="gloss-image-unavailable">${_escapeText(value['alt']?.toString() ?? value['description']?.toString() ?? '')}</span>';
  }
  final attributes = <String>[
    'class="gloss-image"',
    'src="${_escapeAttribute(source)}"',
  ];
  for (final name in const ['alt', 'title']) {
    final attribute = value[name];
    if (attribute is String) {
      attributes.add('$name="${_escapeAttribute(attribute)}"');
    }
  }
  final style = <String>[];
  final units = value['sizeUnits'] == 'em' ? 'em' : 'px';
  if (value['width'] is num) style.add('width:${value['width']}$units');
  if (value['height'] is num) style.add('height:${value['height']}$units');
  if (value['imageRendering'] is String) {
    style.add('image-rendering:${value['imageRendering']}');
  }
  if (style.isNotEmpty) attributes.add('style="${style.join(';')}"');
  return '<img ${attributes.join(' ')}>';
}

String _inlineStyle(Object? value) {
  if (value is! Map) return '';
  final styles = <String>[];
  for (final entry in value.entries) {
    var name = _kebabCase(entry.key.toString());
    Object? styleValue = entry.value;
    if (name == 'text-decoration-line') name = 'text-decoration';
    if (styleValue is List) styleValue = styleValue.join(' ');
    if (styleValue is num && name.startsWith('margin-')) {
      styleValue = '${styleValue}em';
    }
    if (styleValue is String || styleValue is num) {
      styles.add('$name:$styleValue');
    }
  }
  return styles.join(';');
}

String _kebabCase(String value) => value.replaceAllMapped(
  RegExp(r'([a-z0-9])([A-Z])'),
  (match) => '${match[1]}-${match[2]!.toLowerCase()}',
);

String _escapeText(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);

String _escapeAttribute(String value) =>
    const HtmlEscape(HtmlEscapeMode.attribute).convert(value);

String _mimeType(String path) {
  return switch (path.split('.').last.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'svg' => 'image/svg+xml',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
}
