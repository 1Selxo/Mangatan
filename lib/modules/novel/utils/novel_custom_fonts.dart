import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:path/path.dart' as p;

/// Stored-setting prefix that marks a user-imported font. The remainder is
/// the file name inside [StorageProvider.getFontsDirectory].
const novelCustomFontKeyPrefix = 'custom:';

const _supportedExtensions = {'.ttf', '.otf', '.ttc', '.otc'};

class NovelCustomFont {
  const NovelCustomFont(this.file);

  final File file;

  String get fileName => p.basename(file.path);
  String get key => '$novelCustomFontKeyPrefix$fileName';
  String get label => p.basenameWithoutExtension(file.path);
  String get familyName => novelCustomFontFamilyName(fileName);
}

bool isNovelCustomFontKey(String? key) =>
    key != null && key.startsWith(novelCustomFontKeyPrefix);

String? novelCustomFontFileName(String? key) => isNovelCustomFontKey(key)
    ? key!.substring(novelCustomFontKeyPrefix.length)
    : null;

/// Deterministic Flutter/CSS family name for an imported file, so a renderer
/// can reference the family before the asynchronous load has finished.
String novelCustomFontFamilyName(String fileName) =>
    'MangatanUserFont_${fileName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}';

Future<List<NovelCustomFont>> listNovelCustomFonts() async {
  final dir = await StorageProvider().getFontsDirectory();
  final fonts = <NovelCustomFont>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is File &&
        _supportedExtensions.contains(p.extension(entity.path).toLowerCase())) {
      fonts.add(NovelCustomFont(entity));
    }
  }
  fonts.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return fonts;
}

Future<File?> novelCustomFontFile(String? key) async {
  final fileName = novelCustomFontFileName(key);
  if (fileName == null || p.basename(fileName) != fileName) return null;
  final dir = await StorageProvider().getFontsDirectory();
  final file = File(p.join(dir.path, fileName));
  return await file.exists() ? file : null;
}

class NovelFontImportException implements Exception {
  const NovelFontImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Lets the user pick a font file and copies it into app storage.
/// Returns null when the picker was cancelled.
Future<NovelCustomFont?> importNovelCustomFont() async {
  // Android's MIME table does not know every font extension, and an unknown
  // custom extension makes the picker fail outright, so filter afterwards.
  final result = await FilePicker.pickFiles(
    type: Platform.isAndroid ? FileType.any : FileType.custom,
    allowedExtensions: Platform.isAndroid
        ? null
        : _supportedExtensions.map((e) => e.substring(1)).toList(),
  );
  final picked = result.singleOrNull;
  if (picked == null) return null;

  final extension = p.extension(picked.name).toLowerCase();
  if (!_supportedExtensions.contains(extension)) {
    throw const NovelFontImportException(
      'Unsupported font file. Use a .ttf, .otf or .ttc font.',
    );
  }

  final Uint8List bytes;
  try {
    bytes = await picked.readAsBytes();
  } catch (_) {
    throw const NovelFontImportException('Could not read the font file.');
  }
  if (!_looksLikeFont(bytes)) {
    throw const NovelFontImportException('The file is not a valid font.');
  }

  final dir = await StorageProvider().getFontsDirectory();
  final base = _safeBaseName(p.basenameWithoutExtension(picked.name));
  var target = File(p.join(dir.path, '$base$extension'));
  for (var i = 2; await target.exists(); i++) {
    target = File(p.join(dir.path, '$base ($i)$extension'));
  }
  await target.writeAsBytes(bytes, flush: true);
  final font = NovelCustomFont(target);
  await ensureNovelCustomFontLoaded(font.key);
  return font;
}

Future<void> deleteNovelCustomFont(NovelCustomFont font) async {
  if (await font.file.exists()) await font.file.delete();
}

final _loads = <String, Future<String?>>{};

/// Registers an imported font with the Flutter engine once per session and
/// returns its family name, or null when the file is missing or invalid.
/// Text laid out with the family re-lays out automatically when it loads.
Future<String?> ensureNovelCustomFontLoaded(String? key) {
  final fileName = novelCustomFontFileName(key);
  if (fileName == null) return Future.value(null);
  return _loads
      .putIfAbsent(fileName, () async {
        try {
          final file = await novelCustomFontFile(key);
          if (file == null) return null;
          final bytes = await file.readAsBytes();
          final family = novelCustomFontFamilyName(fileName);
          final loader = FontLoader(family)
            ..addFont(Future.value(ByteData.sublistView(bytes)));
          await loader.load();
          return family;
        } catch (_) {
          return null;
        }
      })
      .then((family) {
        // Allow a retry later (e.g. the file was re-imported under the same name).
        if (family == null) _loads.remove(fileName);
        return family;
      });
}

bool _looksLikeFont(Uint8List bytes) {
  if (bytes.length < 12) return false;
  final tag = String.fromCharCodes(bytes.sublist(0, 4));
  return tag == 'OTTO' ||
      tag == 'true' ||
      tag == 'ttcf' ||
      (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0);
}

String _safeBaseName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  return cleaned.isEmpty ? 'font' : cleaned;
}
