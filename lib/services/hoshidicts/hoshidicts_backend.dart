import 'dart:typed_data';

import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:mangayomi/src/rust/api/hoshidicts/native.dart' as hoshidicts;

class HoshidictsLookupBackend {
  HoshidictsLookupBackend._();

  static final HoshidictsLookupBackend instance = HoshidictsLookupBackend._();

  hoshidicts.HoshiLookupSession? _session;

  bool get hasSession => _session != null;

  Future<HoshiImportResult> importDictionary({
    required String zipPath,
    required String outputDir,
    bool lowRam = false,
  }) {
    return hoshidicts.importDictionary(
      zipPath: zipPath,
      outputDir: outputDir,
      lowRam: lowRam,
    );
  }

  Future<void> rebuildQuery({
    required List<String> termPaths,
    List<String> freqPaths = const [],
    List<String> pitchPaths = const [],
  }) async {
    final session = await _ensureSession();
    await hoshidicts.rebuildQuery(
      session: session,
      termPaths: termPaths,
      freqPaths: freqPaths,
      pitchPaths: pitchPaths,
    );
  }

  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
  }) async {
    if (text.trim().isEmpty || maxResults <= 0 || scanLength <= 0) {
      return const [];
    }

    return hoshidicts.lookup(
      session: await _ensureSession(),
      text: text,
      maxResults: maxResults,
      scanLength: BigInt.from(scanLength),
    );
  }

  Future<List<HoshiDictionaryStyle>> getStyles() async {
    return hoshidicts.getStyles(session: await _ensureSession());
  }

  Future<Uint8List?> getMediaFile({
    required String dictName,
    required String mediaPath,
  }) async {
    if (dictName.isEmpty || mediaPath.isEmpty) return null;
    return hoshidicts.getMediaFile(
      session: await _ensureSession(),
      dictName: dictName,
      mediaPath: mediaPath,
    );
  }

  void clearSession() {
    _session = null;
  }

  Future<hoshidicts.HoshiLookupSession> _ensureSession() async {
    return _session ??= await hoshidicts.createLookupSession();
  }
}
