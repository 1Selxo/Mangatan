import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionStore.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSearchHistory.pb.dart';

void main() {
  test(
    'round-trips latest Chimahon store, memo, and search-history fields',
    () {
      final original = BackupMihon(
        backupExtensionStores: [
          BackupExtensionStore(
            indexUrl: 'https://store.example/index.min.json',
            name: 'Store',
            badgeLabel: 'Trusted',
            contactWebsite: 'https://store.example',
            signingKey: 'signing-key',
            contactDiscord: 'discord',
            isLegacy: false,
            extensionListUrl: 'https://store.example/extensions.json',
          ),
        ],
        backupManga: [
          BackupManga(
            source: Int64(42),
            url: '/title',
            title: 'Title',
            memo: [1, 2, 3],
            chapters: [
              BackupChapter(url: '/chapter', name: 'Chapter', memo: [4, 5]),
            ],
          ),
        ],
        backupSearchHistory: [
          BackupSearchHistory(
            scope: 'anime_manga',
            query: 'learning',
            lastSearchedAt: Int64(1234),
          ),
        ],
      );

      final decoded = BackupMihon.fromBuffer(original.writeToBuffer());
      expect(decoded.backupExtensionStores.single.extensionListUrl, isNotEmpty);
      expect(decoded.backupManga.single.memo, [1, 2, 3]);
      expect(decoded.backupManga.single.chapters.single.memo, [4, 5]);
      expect(decoded.backupSearchHistory.single.query, 'learning');
    },
  );

  test('decodes historical Mangatan tag-106 repository bytes as a store', () {
    final legacy = BackupExtensionRepos(
      baseUrl: 'https://legacy.example/index.json',
      name: 'Legacy',
      shortName: 'Old',
      website: 'https://legacy.example',
      signingKeyFingerprint: 'fingerprint',
    ).writeToBuffer();
    final envelope = <int>[
      ..._varint((106 << 3) | 2),
      ..._varint(legacy.length),
      ...legacy,
    ];

    final decoded = BackupMihon.fromBuffer(envelope);
    final store = decoded.backupExtensionStores.single;
    expect(store.indexUrl, 'https://legacy.example/index.json');
    expect(store.name, 'Legacy');
    expect(store.badgeLabel, 'Old');
    expect(store.contactWebsite, 'https://legacy.example');
    expect(store.signingKey, 'fingerprint');
  });
}

List<int> _varint(int value) {
  final bytes = <int>[];
  var remaining = value;
  while (remaining >= 0x80) {
    bytes.add((remaining & 0x7f) | 0x80);
    remaining >>= 7;
  }
  bytes.add(remaining);
  return bytes;
}
