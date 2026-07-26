import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/sync/mangatan_epub_sync_manifest.dart';

void main() {
  String repeat(String value, int count) => List.filled(count, value).join();

  test('manifest round trips provider-neutral EPUB entries', () {
    final manifest = MangatanEpubManifest(
      generatedAtUtc: DateTime.utc(2026, 7, 19),
      deviceId: 'device-a',
      entries: {
        'stable-b': MangatanEpubManifestEntry(
          stableNovelId: 'stable-b',
          sha256: repeat('b', 64),
          sizeBytes: 20,
          fileName: r'C:\local\path\Book.epub',
          title: 'Book',
          author: 'Author',
          lang: 'en',
          updatedAtUtc: DateTime.utc(2026, 7, 19),
        ),
        'stable-a': MangatanEpubManifestEntry(
          stableNovelId: 'stable-a',
          sha256: repeat('a', 64),
          sizeBytes: 10,
          fileName: 'Other.epub',
          title: 'Other',
          updatedAtUtc: DateTime.utc(2026, 7, 18),
        ),
      },
    );

    final encoded = manifest.encode();
    final decoded = MangatanEpubManifest.decode(encoded);

    expect(decoded.protocolVersion, mangatanEpubManifestProtocolVersion);
    expect(decoded.deviceId, 'device-a');
    expect(decoded.entries.keys, containsAll(['stable-a', 'stable-b']));
    expect(decoded.entries['stable-b']!.sha256, repeat('b', 64));

    final json = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
    final entries = json['entries'] as List;
    expect(entries.first['stableNovelId'], 'stable-a');
  });

  test('unsupported manifest protocol fails closed', () {
    expect(
      () => MangatanEpubManifest.decode(
        utf8.encode('{"protocolVersion":99,"entries":[]}'),
      ),
      throwsFormatException,
    );
  });

  test('merge keeps remote EPUB entries when local files are absent', () {
    final remoteOnly = MangatanEpubManifestEntry(
      stableNovelId: 'remote-only',
      sha256: repeat('r', 64),
      sizeBytes: 1,
      fileName: 'Remote.epub',
      title: 'Remote',
      updatedAtUtc: DateTime.utc(2026),
    );
    final local = MangatanEpubManifestEntry(
      stableNovelId: 'local',
      sha256: repeat('l', 64),
      sizeBytes: 2,
      fileName: 'Local.epub',
      title: 'Local',
      updatedAtUtc: DateTime.utc(2026),
    );
    final tombstone = MangatanEpubManifestEntry(
      stableNovelId: 'deleted',
      sha256: repeat('d', 64),
      sizeBytes: 3,
      fileName: 'Deleted.epub',
      title: 'Deleted',
      updatedAtUtc: DateTime.utc(2026),
      deleted: true,
    );

    final merged = MangatanEpubManifest(
      generatedAtUtc: DateTime.utc(2026),
      deviceId: 'old-device',
      entries: {
        remoteOnly.stableNovelId: remoteOnly,
        tombstone.stableNovelId: tombstone,
      },
    ).mergeLocalEntries(
      deviceId: 'new-device',
      localEntries: {local.stableNovelId: local},
      generatedAtUtc: DateTime.utc(2026, 7, 19),
    );

    expect(merged.entries.keys, containsAll(['remote-only', 'local', 'deleted']));
    expect(merged.entries['deleted']!.deleted, isTrue);
  });
}
