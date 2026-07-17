import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/mining/mokuro_extension_ocr.dart';
import 'package:mangayomi/services/mining/mokuro_parser.dart';
import 'package:mangayomi/services/mining/mokuro_sidecar_path.dart';
import 'package:path/path.dart' as p;

class MokuroSidecarStore {
  MokuroSidecarStore({http.Client? client})
    : _client = MokuroExtensionOcrClient(client: client);

  static final Map<String, Future<bool>> _writes = {};

  final MokuroExtensionOcrClient _client;

  Future<bool> ensureDownloaded({
    required String sourceName,
    required String chapterUrl,
    required FileSystemEntity artifact,
  }) {
    if (MokuroExtensionOcrClient.volumeUri(
          sourceName: sourceName,
          chapterUrl: chapterUrl,
        ) ==
        null) {
      return Future.value(false);
    }

    final destination = mokuroSidecarFor(artifact);
    final path = p.normalize(destination.absolute.path);
    final pending = _writes[path];
    if (pending != null) return pending;

    final write = _ensureDownloaded(
      sourceName: sourceName,
      chapterUrl: chapterUrl,
      destination: destination,
    );
    _writes[path] = write;
    return write.whenComplete(() {
      if (identical(_writes[path], write)) _writes.remove(path);
    });
  }

  Future<bool> _ensureDownloaded({
    required String sourceName,
    required String chapterUrl,
    required File destination,
  }) async {
    if (await _isValid(destination)) return true;

    final document = await _client.fetchDocument(
      sourceName: sourceName,
      chapterUrl: chapterUrl,
    );
    if (document == null) return false;

    File? temporary;
    try {
      await destination.parent.create(recursive: true);
      temporary = File(
        '${destination.path}.part-$pid-${DateTime.now().microsecondsSinceEpoch}',
      );
      await temporary.writeAsBytes(document.bytes, flush: true);

      // A different process may have completed the same sidecar while the
      // request was in flight. Preserve its valid result if so.
      if (await _isValid(destination)) {
        await temporary.delete();
        return true;
      }
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
      return true;
    } catch (_) {
      if (temporary != null && await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
      return false;
    }
  }

  static Future<bool> _isValid(File file) async {
    if (!await file.exists()) return false;
    try {
      final volume = const MokuroParser().parse(
        utf8.decode(await file.readAsBytes()),
      );
      return volume.pages.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}
