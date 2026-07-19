import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/sync/mangatan_epub_blob_storage.dart';
import 'package:mangayomi/services/sync/mangatan_epub_sync_manifest.dart';

void main() {
  String repeat(String value, int count) => List.filled(count, value).join();

  test('fake provider deduplicates immutable blobs by sha256', () async {
    final storage = _MemoryEpubBlobStorage();
    await storage.uploadEpubBlob(
      sha256: repeat('a', 64),
      sizeBytes: 3,
      bytes: Stream.value([1, 2, 3]),
    );
    await storage.uploadEpubBlob(
      sha256: repeat('a', 64),
      sizeBytes: 3,
      bytes: Stream.value([1, 2, 3]),
    );

    expect(await storage.hasEpubBlob(repeat('a', 64)), isTrue);
    expect(storage.uploadCount, 1);
  });

  test('manifest updates are conditional', () async {
    final storage = _MemoryEpubBlobStorage();
    final first = MangatanEpubManifest.empty(deviceId: 'a');
    final revision = await storage.uploadEpubManifest(
      first,
      expectedAbsent: true,
    );

    await storage.uploadEpubManifest(
      first.copyWith(deviceId: 'b'),
      expectedRevision: revision,
    );
    await expectLater(
      storage.uploadEpubManifest(
        first.copyWith(deviceId: 'c'),
        expectedRevision: revision,
      ),
      throwsStateError,
    );
  });
}

class _MemoryEpubBlobStorage implements MangatanEpubBlobStorage {
  final blobs = <String, Uint8List>{};
  MangatanEpubManifest? manifest;
  String? revision;
  int uploadCount = 0;

  @override
  Future<MangatanRemoteEpubManifest?> downloadEpubManifest() async =>
      manifest == null
      ? null
      : MangatanRemoteEpubManifest(
          manifest: manifest!,
          revision: revision,
        );

  @override
  Future<bool> hasEpubBlob(String sha256) async => blobs.containsKey(sha256);

  @override
  Future<Uint8List> downloadEpubBlob(String sha256) async => blobs[sha256]!;

  @override
  Future<void> uploadEpubBlob({
    required String sha256,
    required int sizeBytes,
    required Stream<List<int>> bytes,
  }) async {
    if (blobs.containsKey(sha256)) return;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in bytes) {
      builder.add(chunk);
    }
    blobs[sha256] = builder.takeBytes();
    uploadCount++;
  }

  @override
  Future<String?> uploadEpubManifest(
    MangatanEpubManifest manifest, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    if (expectedAbsent && this.manifest != null) throw StateError('conflict');
    if (!expectedAbsent && expectedRevision != revision) {
      throw StateError('conflict');
    }
    this.manifest = manifest;
    revision = '${(int.tryParse(revision ?? '0') ?? 0) + 1}';
    return revision;
  }
}
