import 'dart:typed_data';

import 'package:mangayomi/services/sync/mangatan_epub_sync_manifest.dart';

class MangatanRemoteEpubManifest {
  const MangatanRemoteEpubManifest({
    required this.manifest,
    required this.revision,
  });

  final MangatanEpubManifest manifest;
  final String? revision;
}

abstract interface class MangatanEpubBlobStorage {
  Future<MangatanRemoteEpubManifest?> downloadEpubManifest();

  Future<String?> uploadEpubManifest(
    MangatanEpubManifest manifest, {
    String? expectedRevision,
    bool expectedAbsent = false,
  });

  Future<bool> hasEpubBlob(String sha256);

  Future<void> uploadEpubBlob({
    required String sha256,
    required int sizeBytes,
    required Stream<List<int>> bytes,
  });

  Future<Uint8List> downloadEpubBlob(String sha256);
}
