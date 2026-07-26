import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupNovel.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupPreference.pb.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

void main() {
  test('default store uses the application support sync directory', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));

    final store = await defaultChimahonDeferredPayloadStore(
      scopeKey: 'google-drive|secret-refresh-token',
      applicationSupportDirectory: directory,
    );
    await store.save(BackupMihon());

    expect(
      store.file.path,
      '${directory.path}${Platform.pathSeparator}sync'
      '${Platform.pathSeparator}chimahon'
      '${Platform.pathSeparator}'
      '8592749aea9ac7d34a8df995e36de35f924c44611bca12c67d95daf6c918ea1f'
      '${Platform.pathSeparator}chimahon_deferred.tachibk',
    );
    expect(store.file.path, isNot(contains('secret-refresh-token')));
    expect(await store.file.exists(), isTrue);
  });

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

  test(
    'pending manual restore retains complete media and clears once',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
      );
      final backup = BackupMihon(
        backupManga: [BackupManga(title: 'Restored title')],
        backupNovels: [BackupNovel(id: 'novel', title: 'Restored novel')],
      );
      backup.backupManga.single.unknownFields.mergeVarintField(998, Int64(42));

      await store.save(backup);
      final restored = (await store.load())!;

      expect(restored.backupManga.single.title, 'Restored title');
      expect(restored.backupManga.single.unknownFields.hasField(998), isTrue);
      expect(restored.backupNovels.single.title, 'Restored novel');
      expect(
        store.file.path,
        '${directory.path}${Platform.pathSeparator}sync'
        '${Platform.pathSeparator}chimahon'
        '${Platform.pathSeparator}manual_restore'
        '${Platform.pathSeparator}chimahon_pending_restore.tachibk',
      );

      final projected = const ChimahonPreferenceCodec().encode(
        'restored-setting',
        'projected',
      );
      await store.saveLocalPreferenceBaseline([projected]);
      await store.saveLocalSourcePreferenceBaseline([
        BackupSourcePreferences(sourceKey: '42', prefs: [projected]),
      ]);
      expect(await store.loadLocalPreferenceBaseline(), isNotNull);
      expect(await store.loadLocalSourcePreferenceBaseline(), isNotNull);

      // Replacing the exact restore invalidates evidence from the older one.
      await store.save(backup);
      expect(await store.loadLocalPreferenceBaseline(), isNull);
      expect(await store.loadLocalSourcePreferenceBaseline(), isNull);

      await store.saveLocalPreferenceBaseline([projected]);
      await store.saveLocalSourcePreferenceBaseline([
        BackupSourcePreferences(sourceKey: '42', prefs: [projected]),
      ]);

      await store.clear();
      expect(await store.load(), isNull);
      expect(await store.loadLocalPreferenceBaseline(), isNull);
      expect(await store.loadLocalSourcePreferenceBaseline(), isNull);
    },
  );

  test(
    'corrupt pending manual restore blocks sync instead of vanishing',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
      );
      await store.file.parent.create(recursive: true);
      await store.file.writeAsBytes([1, 2, 3], flush: true);

      await expectLater(
        store.load(),
        throwsA(
          isA<ChimahonDeferredPayloadCorruptionException>().having(
            (error) => error.corruptPaths.single,
            'corrupt path',
            store.file.path,
          ),
        ),
      );
      // A strict pending store must keep blocking subsequent attempts. Moving
      // the only copy aside would turn the next load into a silent cache miss.
      await expectLater(
        store.load(),
        throwsA(isA<ChimahonDeferredPayloadCorruptionException>()),
      );
      expect(await store.file.exists(), isTrue);
      expect(
        store.file.parent.listSync().where(
          (entry) => entry.path.contains('.corrupt_'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'strict current corruption is not masked by a valid previous payload',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
      );
      await store.save(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'old', title: 'Valid previous')],
        ),
      );
      final previous = File('${store.file.path}.previous');
      await store.file.copy(previous.path);
      await store.file.writeAsBytes([1, 2, 3], flush: true);

      await expectLater(
        store.load(),
        throwsA(
          isA<ChimahonDeferredPayloadCorruptionException>().having(
            (error) => error.corruptPaths,
            'corrupt paths',
            [store.file.path],
          ),
        ),
      );
      expect(await store.file.exists(), isTrue);
      expect(await previous.exists(), isTrue);

      // A previous payload is recovery data only when the current path is
      // absent, as it can be during an interrupted Windows replacement.
      await store.file.delete();
      expect((await store.load())!.backupNovels.single.title, 'Valid previous');
    },
  );

  test(
    'recoverable cache quarantines corrupt current and loads valid previous',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileChimahonDeferredPayloadStore(
        File('${directory.path}/account/deferred.proto.gz'),
      );
      await store.save(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'old', title: 'Valid previous')],
        ),
      );
      final previous = File('${store.file.path}.previous');
      await store.file.copy(previous.path);
      await store.file.writeAsBytes([1, 2, 3], flush: true);

      expect((await store.load())!.backupNovels.single.title, 'Valid previous');
      expect(await store.file.exists(), isFalse);
      expect(await previous.exists(), isTrue);
      expect(
        store.file.parent.listSync().where(
          (entry) => entry.path.contains('.corrupt_'),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'read-only cache uses valid previous without moving corrupt current',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/account/deferred.proto.gz');
      final writable = FileChimahonDeferredPayloadStore(file);
      await writable.save(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'old', title: 'Valid previous')],
        ),
      );
      final previous = File('${file.path}.previous');
      await file.copy(previous.path);
      const corruptBytes = [1, 2, 3];
      await file.writeAsBytes(corruptBytes, flush: true);
      final readOnly = FileChimahonDeferredPayloadStore(file, readOnly: true);

      expect(
        (await readOnly.load())!.backupNovels.single.title,
        'Valid previous',
      );
      expect(await file.readAsBytes(), corruptBytes);
      expect(await previous.exists(), isTrue);
      expect(
        file.parent.listSync().where(
          (entry) => entry.path.contains('.corrupt_'),
        ),
        isEmpty,
      );
    },
  );

  test(
    'strict current baseline corruption is not masked by valid previous data',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
      );
      final preference = const ChimahonPreferenceCodec().encode(
        'restored-setting',
        'valid previous',
      );
      await store.saveLocalPreferenceBaseline([preference]);
      await store.saveLocalSourcePreferenceBaseline([
        BackupSourcePreferences(sourceKey: '42', prefs: [preference]),
      ]);
      final currentFiles = [
        store.localPreferenceBaselineFile,
        store.localSourcePreferenceBaselineFile,
      ];
      for (final current in currentFiles) {
        await current.copy('${current.path}.previous');
        await current.writeAsBytes([1, 2, 3], flush: true);
      }

      await expectLater(
        store.loadLocalPreferenceBaseline(),
        throwsA(
          isA<ChimahonDeferredPayloadCorruptionException>().having(
            (error) => error.corruptPaths,
            'corrupt paths',
            [store.localPreferenceBaselineFile.path],
          ),
        ),
      );
      await expectLater(
        store.loadLocalSourcePreferenceBaseline(),
        throwsA(
          isA<ChimahonDeferredPayloadCorruptionException>().having(
            (error) => error.corruptPaths,
            'corrupt paths',
            [store.localSourcePreferenceBaselineFile.path],
          ),
        ),
      );

      for (final current in currentFiles) {
        expect(await current.exists(), isTrue);
        expect(await File('${current.path}.previous').exists(), isTrue);
        await current.delete();
      }
      expect(await store.loadLocalPreferenceBaseline(), hasLength(1));
      expect(await store.loadLocalSourcePreferenceBaseline(), hasLength(1));
    },
  );

  test(
    'clear removes previous before a current-file deletion failure',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileChimahonDeferredPayloadStore(
        File('${directory.path}/manual/pending.proto.gz'),
        retainMediaRecords: true,
        failOnCorruption: true,
      );
      await store.save(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'old', title: 'Old intent')],
        ),
      );
      final previous = File('${store.file.path}.previous');
      await store.file.copy(previous.path);
      await store.file.delete();
      final obstructingDirectory = Directory(store.file.path);
      await obstructingDirectory.create();
      await File('${obstructingDirectory.path}/child').writeAsString('block');

      await expectLater(store.clear(), throwsA(isA<FileSystemException>()));

      expect(await previous.exists(), isFalse);
      expect(await obstructingDirectory.exists(), isTrue);
      expect(await store.load(), isNull);
    },
  );

  test(
    'restore invalidation removes previous before baseline deletion failure',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final baseline = File('${directory.path}/manual/preferences.proto.gz');
      final store = FileChimahonDeferredPayloadStore(
        File('${directory.path}/manual/pending.proto.gz'),
        localPreferenceBaselineFile: baseline,
        retainMediaRecords: true,
        failOnCorruption: true,
      );
      await store.save(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'old', title: 'Old intent')],
        ),
      );
      final preference = const ChimahonPreferenceCodec().encode(
        'restored-setting',
        'old projection',
      );
      await store.saveLocalPreferenceBaseline([preference]);
      final previous = File('${baseline.path}.previous');
      await baseline.copy(previous.path);
      await baseline.delete();
      final obstructingDirectory = Directory(baseline.path);
      await obstructingDirectory.create();
      await File('${obstructingDirectory.path}/child').writeAsString('block');

      await expectLater(
        store.save(
          BackupMihon(
            backupNovels: [BackupNovel(id: 'new', title: 'New intent')],
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(await previous.exists(), isFalse);
      expect(await obstructingDirectory.exists(), isTrue);
      expect((await store.load())!.backupNovels.single.id, 'old');
      expect(await store.loadLocalPreferenceBaseline(), isNull);
    },
  );

  test(
    'layered store keeps remote baseline separate from pending local intent',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final primary = FileChimahonDeferredPayloadStore(
        File('${directory.path}/account/deferred.proto.gz'),
      );
      final pending = FileChimahonDeferredPayloadStore(
        File('${directory.path}/manual/pending.proto.gz'),
        retainMediaRecords: true,
      );
      await primary.save(
        BackupMihon(
          backupNovels: [BackupNovel(id: 'old', title: 'Old deferred')],
        ),
      );
      await pending.save(
        BackupMihon(
          backupManga: [BackupManga(title: 'Pending media')],
          backupNovels: [BackupNovel(id: 'pending', title: 'Pending novel')],
        ),
      );
      final projectedPreference = const ChimahonPreferenceCodec().encode(
        'restored-setting',
        'projection',
      );
      await pending.saveLocalPreferenceBaseline([projectedPreference]);
      await pending.saveLocalSourcePreferenceBaseline([
        BackupSourcePreferences(sourceKey: '42', prefs: [projectedPreference]),
      ]);
      final layered = LayeredChimahonDeferredPayloadStore(
        primary: primary,
        pendingManualRestore: pending,
      );

      final baseline = (await layered.load())!;
      final pendingLocal = (await layered.loadPendingLocalPayload())!;
      expect(baseline.backupManga, isEmpty);
      expect(baseline.backupNovels.single.title, 'Old deferred');
      expect(pendingLocal.backupManga.single.title, 'Pending media');
      expect(pendingLocal.backupNovels.single.title, 'Pending novel');
      expect(await layered.loadPendingLocalPreferenceBaseline(), isNotNull);
      expect(
        await layered.loadPendingLocalSourcePreferenceBaseline(),
        isNotNull,
      );
      expect(await pending.file.exists(), isTrue);

      await layered.save(pendingLocal);
      expect(await pending.file.exists(), isFalse);
      expect(await layered.loadPendingLocalPreferenceBaseline(), isNull);
      expect(await layered.loadPendingLocalSourcePreferenceBaseline(), isNull);
      expect((await primary.load())!.backupManga, isEmpty);
      expect(
        (await primary.load())!.backupNovels.single.title,
        'Pending novel',
      );
    },
  );

  test('atomically replaces an existing cache payload', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileChimahonDeferredPayloadStore(
      File('${directory.path}/deferred.proto.gz'),
    );

    await store.save(
      BackupMihon(
        backupNovels: [BackupNovel(id: 'old', title: 'Old')],
      ),
    );
    await store.save(
      BackupMihon(
        backupNovels: [BackupNovel(id: 'new', title: 'New')],
      ),
    );

    final restored = (await store.load())!;
    expect(restored.backupNovels.map((novel) => novel.id), ['new']);
    expect(
      directory.listSync().where((entry) => entry.path.contains('.tmp_')),
      isEmpty,
    );
  });

  test(
    'uses separate cache paths for different providers or accounts',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final first = await defaultChimahonDeferredPayloadStore(
        scopeKey: 'google-drive|account-one',
        applicationSupportDirectory: directory,
      );
      final second = await defaultChimahonDeferredPayloadStore(
        scopeKey: 'syncyomi|https://sync.example|token',
        applicationSupportDirectory: directory,
      );

      expect(first.file.path, isNot(second.file.path));
    },
  );

  test('quarantines a corrupt cache so remote recovery can continue', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/deferred.proto.gz');
    final store = FileChimahonDeferredPayloadStore(file);
    await file.writeAsBytes([1, 2, 3], flush: true);

    expect(await store.load(), isNull);
    expect(await file.exists(), isFalse);
    expect(
      directory.listSync().where((entry) => entry.path.contains('.corrupt_')),
      hasLength(1),
    );
  });

  test(
    'read-only loads leave corrupt payloads and baselines untouched',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/account/deferred.proto.gz');
      final preferenceBaseline = File(
        '${directory.path}/account/preferences.proto.gz',
      );
      final sourcePreferenceBaseline = File(
        '${directory.path}/account/source_preferences.proto.gz',
      );
      final store = FileChimahonDeferredPayloadStore(
        file,
        localPreferenceBaselineFile: preferenceBaseline,
        localSourcePreferenceBaselineFile: sourcePreferenceBaseline,
        readOnly: true,
      );
      final corruptFiles = <File, List<int>>{
        file: [1, 2, 3],
        File('${file.path}.previous'): [4, 5, 6],
        preferenceBaseline: [7, 8, 9],
        File('${preferenceBaseline.path}.previous'): [10, 11, 12],
        sourcePreferenceBaseline: [13, 14, 15],
        File('${sourcePreferenceBaseline.path}.previous'): [16, 17, 18],
      };
      await file.parent.create(recursive: true);
      for (final entry in corruptFiles.entries) {
        await entry.key.writeAsBytes(entry.value, flush: true);
      }
      final pathsBefore = directory
          .listSync(recursive: true)
          .map((entry) => entry.path)
          .toSet();

      expect(await store.load(), isNull);
      expect(await store.loadLocalPreferenceBaseline(), isNull);
      expect(await store.loadLocalSourcePreferenceBaseline(), isNull);

      expect(
        directory.listSync(recursive: true).map((entry) => entry.path).toSet(),
        pathsBefore,
      );
      for (final entry in corruptFiles.entries) {
        expect(await entry.key.readAsBytes(), entry.value);
      }
    },
  );

  test(
    'read-only missing state does not create files or directories',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/missing/account/deferred.proto.gz');
      final store = FileChimahonDeferredPayloadStore(file, readOnly: true);

      expect(await store.load(), isNull);
      expect(await store.loadLocalPreferenceBaseline(), isNull);
      expect(await store.loadLocalSourcePreferenceBaseline(), isNull);
      expect(await file.parent.exists(), isFalse);
      expect(directory.listSync(), isEmpty);
    },
  );

  test(
    'read-only pending restore still fails closed without moving corruption',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
        readOnly: true,
      );
      final previous = File('${store.file.path}.previous');
      const currentBytes = [1, 2, 3];
      const previousBytes = [4, 5, 6];
      await store.file.parent.create(recursive: true);
      await store.file.writeAsBytes(currentBytes, flush: true);
      await previous.writeAsBytes(previousBytes, flush: true);
      final pathsBefore = store.file.parent
          .listSync()
          .map((entry) => entry.path)
          .toSet();

      await expectLater(
        store.load(),
        throwsA(
          isA<ChimahonDeferredPayloadCorruptionException>().having(
            (error) => error.corruptPaths,
            'corrupt paths',
            [store.file.path],
          ),
        ),
      );

      expect(
        store.file.parent.listSync().map((entry) => entry.path).toSet(),
        pathsBefore,
      );
      expect(await store.file.readAsBytes(), currentBytes);
      expect(await previous.readAsBytes(), previousBytes);
    },
  );

  test('read-only stores reject mutation before creating state', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/missing/account/deferred.proto.gz');
    final store = FileChimahonDeferredPayloadStore(file, readOnly: true);

    await expectLater(store.save(BackupMihon()), throwsUnsupportedError);
    await expectLater(store.clear(), throwsUnsupportedError);
    await expectLater(
      store.saveLocalPreferenceBaseline(const []),
      throwsUnsupportedError,
    );
    await expectLater(
      store.saveLocalSourcePreferenceBaseline(const []),
      throwsUnsupportedError,
    );
    expect(await file.parent.exists(), isFalse);
    expect(directory.listSync(), isEmpty);
  });

  test(
    'stores the local preference projection in a separate sidecar',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileChimahonDeferredPayloadStore(
        File('${directory.path}/deferred.proto.gz'),
      );
      final preference = const ChimahonPreferenceCodec().encode(
        'paired_setting',
        'local projection',
      );

      await store.saveLocalPreferenceBaseline([preference]);
      final restored = await store.loadLocalPreferenceBaseline();

      expect(restored, hasLength(1));
      expect(restored!.single.writeToBuffer(), preference.writeToBuffer());
      expect(await store.file.exists(), isFalse);
      expect(await store.localPreferenceBaselineFile.exists(), isTrue);
    },
  );

  test(
    'stores the local source preference projection in a separate sidecar',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = FileChimahonDeferredPayloadStore(
        File('${directory.path}/deferred.proto.gz'),
      );
      final sourcePreferences = BackupSourcePreferences(
        sourceKey: 'source_1',
        prefs: [
          const ChimahonPreferenceCodec().encode(
            'source_setting',
            'local projection',
          ),
        ],
      );

      await store.saveLocalSourcePreferenceBaseline([sourcePreferences]);
      final restored = await store.loadLocalSourcePreferenceBaseline();

      expect(restored, hasLength(1));
      expect(
        restored!.single.writeToBuffer(),
        sourcePreferences.writeToBuffer(),
      );
      expect(await store.file.exists(), isFalse);
      expect(await store.localSourcePreferenceBaselineFile.exists(), isTrue);
    },
  );

  test(
    'pending restore stays blocked until both baselines are durable',
    () async {
      final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final store = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
      );
      final backup = BackupMihon(
        backupManga: [BackupManga(title: 'Selected restore')],
      );

      await store.beginPreparing(backup);
      expect(
        await store.loadRestorePhase(),
        ChimahonPendingManualRestorePhase.preparing,
      );
      await expectLater(
        store.ensureReadyForSync(),
        throwsA(isA<ChimahonPendingManualRestoreIncompleteException>()),
      );
      await expectLater(
        store.load(),
        throwsA(isA<ChimahonPendingManualRestoreIncompleteException>()),
      );

      await store.saveLocalPreferenceBaseline(const []);
      await expectLater(
        store.markReady(),
        throwsA(isA<ChimahonPendingManualRestoreIncompleteException>()),
      );
      await store.saveLocalSourcePreferenceBaseline(const []);
      await store.markReady();

      final reopened = await defaultChimahonPendingManualRestoreStore(
        applicationSupportDirectory: directory,
      );
      expect(
        await reopened.loadRestorePhase(),
        ChimahonPendingManualRestorePhase.ready,
      );
      await reopened.ensureReadyForSync();
      expect(
        (await reopened.load())!.backupManga.single.title,
        'Selected restore',
      );
      await reopened.clear();
      expect(
        await reopened.loadRestorePhase(),
        ChimahonPendingManualRestorePhase.absent,
      );
      expect(await reopened.stateFile.exists(), isFalse);
    },
  );

  test('preparing phase survives restart and fails closed', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final first = await defaultChimahonPendingManualRestoreStore(
      applicationSupportDirectory: directory,
    );
    await first.beginPreparing(
      BackupMihon(
        backupNovels: [BackupNovel(id: 'n', title: 'Novel')],
      ),
    );

    final reopened = await defaultChimahonPendingManualRestoreStore(
      applicationSupportDirectory: directory,
    );
    expect(
      await reopened.loadRestorePhase(),
      ChimahonPendingManualRestorePhase.preparing,
    );
    await expectLater(
      reopened.ensureReadyForSync(),
      throwsA(isA<ChimahonPendingManualRestoreIncompleteException>()),
    );
  });

  test('marker-less pre-upgrade pending payload remains ready', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final store = await defaultChimahonPendingManualRestoreStore(
      applicationSupportDirectory: directory,
    );
    await store.file.parent.create(recursive: true);
    await store.file.writeAsBytes(
      const ChimahonSyncCodec().encode(
        BackupMihon(backupManga: [BackupManga(title: 'Legacy')]),
        format: ChimahonSyncWireFormat.gzipProtobuf,
      ),
      flush: true,
    );

    expect(
      await store.loadRestorePhase(),
      ChimahonPendingManualRestorePhase.ready,
    );
    await store.ensureReadyForSync();
    expect((await store.load())!.backupManga.single.title, 'Legacy');
    expect(await store.stateFile.exists(), isFalse);
  });

  test('ready marker without its baselines fails closed', () async {
    final directory = await Directory.systemTemp.createTemp('chimahon-sync-');
    addTearDown(() => directory.delete(recursive: true));
    final store = await defaultChimahonPendingManualRestoreStore(
      applicationSupportDirectory: directory,
    );
    await store.beginPreparing(BackupMihon());
    await store.saveLocalPreferenceBaseline(const []);
    await store.saveLocalSourcePreferenceBaseline(const []);
    await store.markReady();
    await store.localSourcePreferenceBaselineFile.delete();

    await expectLater(
      store.ensureReadyForSync(),
      throwsA(isA<ChimahonPendingManualRestoreIncompleteException>()),
    );
  });
}
