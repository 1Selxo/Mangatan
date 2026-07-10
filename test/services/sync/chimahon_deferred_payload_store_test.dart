import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';

void main() {
  test(
    'retains unwired Chimahon sections without carrying stale manga',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileChimahonDeferredPayloadStore(
        File('${directory.path}/deferred.proto.gz'),
      );
      final backup = BackupMihon(
        backupManga: [BackupManga(title: 'Do not defer')],
        backupNovels: [BackupNovel(id: 'novel', title: 'Deferred novel')],
        backupPreferences: [
          const ChimahonPreferenceCodec().encode(
            'pref_anki_profiles',
            'exact fields',
          ),
        ],
      );
      backup.unknownFields.mergeLengthDelimitedField(999, [1, 2, 3]);

      await store.save(backup);
      final restored = (await store.load())!;

      expect(restored.backupManga, isEmpty);
      expect(restored.backupNovels.single.title, 'Deferred novel');
      expect(restored.backupPreferences.single.key, 'pref_anki_profiles');
      expect(restored.unknownFields.hasField(999), isTrue);
    },
  );
}
