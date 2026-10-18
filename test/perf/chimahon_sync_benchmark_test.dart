// Benchmarks the Chimahon-compatible sync pipeline on a large library.
//
// Skipped unless MANGATAN_PERF is set:
//
//   MANGATAN_PERF=1 flutter test test/perf/chimahon_sync_benchmark_test.dart
//
// MANGATAN_PERF_RUNS sets the measured runs (default 12, after 3 warm-up
// runs) and MANGATAN_PERF_OUT=<file> writes the results as JSON.
//
// Everything runs through the production classes on a real Isar database:
// the local projection, revision capture, codec, merger, pre-upload safety
// gate, download plan, importer and the provider-neutral engine. Only the
// transport is replaced by an in-memory store, so no Google Drive, WebDAV or
// SyncYomi server is contacted.
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/download.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/services/sync/chimahon_deferred_payload_store.dart';
import 'package:mangayomi/services/sync/chimahon_download_plan.dart';
import 'package:mangayomi/services/sync/chimahon_local_revision.dart';
import 'package:mangayomi/services/sync/chimahon_local_sync_projection_service.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/chimahon_pre_upload_safety_gate.dart';
import 'package:mangayomi/services/sync/chimahon_remote_recovery_store.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_sync_importer.dart';
import 'package:mangayomi/services/sync/chimahon_sync_merger.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_metrics.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

import '../test_utils/isar_library.dart';
import 'chimahon_sync_fixture.dart';

final _enabled = Platform.environment['MANGATAN_PERF'] != null;
final _iterations =
    int.tryParse(Platform.environment['MANGATAN_PERF_RUNS'] ?? '') ?? 12;
const _warmup = 3;
const _entries = 400;
const _chaptersPerEntry = 150;
const _animeEntries = 40;

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final n = sorted.length;
  return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
}

double _p90(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[min(sorted.length - 1, (sorted.length * 0.9).floor())];
}

Map<String, Object> _stat(List<double> values) => {
  'median': double.parse(_median(values).toStringAsFixed(2)),
  'p90': double.parse(_p90(values).toStringAsFixed(2)),
};

/// Longest gap between ticks of a 1 ms timer on this isolate, which is how
/// long the isolate was busy without yielding. No threshold is applied.
class _StallProbe {
  final _clock = Stopwatch();
  int _last = 0;
  int longest = 0;
  Timer? _timer;

  void start() {
    longest = 0;
    _clock
      ..reset()
      ..start();
    _last = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 1), (_) => _tick());
  }

  void _tick() {
    final now = _clock.elapsedMicroseconds;
    longest = max(longest, now - _last);
    _last = now;
  }

  int stop() {
    _timer?.cancel();
    _tick();
    return longest;
  }
}

final _results = <String, Object?>{};

/// Runs [run] warm-up plus measured times. [run] returns the measured
/// milliseconds so per-run setup stays outside the measurement; the stall
/// probe covers only the measured part through [measure].
Future<void> _bench(
  String name,
  Future<void> Function(Future<T> Function<T>(Future<T> Function()) measure)
  run, {
  int? iterations,
  void Function(Map<String, Object?> result)? extra,
}) async {
  final runs = iterations ?? _iterations;
  final totals = <double>[];
  final stalls = <double>[];
  for (var i = 0; i < _warmup + runs; i++) {
    var micros = 0;
    var stall = 0;
    await run(<T>(Future<T> Function() body) async {
      final probe = _StallProbe()..start();
      final clock = Stopwatch()..start();
      try {
        return await body();
      } finally {
        clock.stop();
        micros += clock.elapsedMicroseconds;
        stall = max(stall, probe.stop());
      }
    });
    if (i < _warmup) continue;
    totals.add(micros / 1000);
    stalls.add(stall / 1000);
  }
  final result = <String, Object?>{
    'runs': runs,
    'totalMs': _stat(totals),
    'longestMainIsolateStallMs': _stat(stalls),
  };
  extra?.call(result);
  _results[name] = result;
  // ignore: avoid_print
  print('BENCH $name ${jsonEncode(result)}');
}

class _MemoryStorage implements CrossDeviceSyncStorage {
  _MemoryStorage(this.bytes);

  Uint8List? bytes;
  int revision = 1;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.gzipProtobuf;

  @override
  Future<RemoteSyncSnapshot?> download() async => bytes == null
      ? null
      : RemoteSyncSnapshot(
          bytes: bytes!,
          revision: '$revision',
          isCompleteRecovery: true,
        );

  @override
  Future<String?> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async {
    if (expectedRevision != '$revision') throw const SyncConflictException();
    this.bytes = bytes;
    return '${++revision}';
  }
}

void main() {
  late Directory root;
  late Isar database;
  late String pristinePath;
  late BackupMihon localBackup;
  late BackupMihon remoteBackup;
  late Uint8List remoteBytes;
  var openCount = 0;

  ChimahonLocalSyncProjectionService projectionFor(Isar db) =>
      ChimahonLocalSyncProjectionService(
        database: db,
        dictionaryStorage: EmptyDictionaryStorage(),
        mediaSelection: const ChimahonMediaSyncSelection(),
        mediaSelectionInitialized: true,
      );

  /// A fresh copy of the seeded database, so writes never leak between runs.
  Future<Isar> openCopy() async {
    final name = 'chimahon_sync_run_${openCount++}';
    await File(pristinePath).copy('${root.path}/$name.isar');
    return Isar.open(
      chimahonSyncBenchmarkSchemas,
      directory: root.path,
      name: name,
    );
  }

  ({CrossDeviceSyncEngine engine, _MemoryStorage storage}) engineFor(
    Isar db,
    Directory sidecars,
    Uint8List? remote, {
    void Function(CrossDeviceSyncMetrics metrics)? onMetrics,
  }) {
    final projection = projectionFor(db);
    late ChimahonLocalSyncProjectionSnapshot snapshot;
    final storage = _MemoryStorage(remote);
    final engine = CrossDeviceSyncEngine(
      storage: storage,
      deferredPayloadStore: FileChimahonDeferredPayloadStore(
        File('${sidecars.path}/chimahon_deferred.tachibk'),
      ),
      exportLocal: () async {
        snapshot = await projection.createSnapshot();
        return snapshot.backup;
      },
      localUnrepresentablePreferenceKeys: () =>
          snapshot.unrepresentablePreferenceKeys,
      localMediaSelection: const ChimahonMediaSyncSelection(),
      localMediaSelectionInitialized: true,
      importMerged: (backup) async =>
          const ChimahonSyncImporter().apply(database: db, backup: backup),
      preUpload: ChimahonPreUploadSafetyGate(
        recoveryStore: FileChimahonRemoteRecoveryStore(
          Directory('${sidecars.path}/recovery'),
        ),
      ).check,
      onMetrics: onMetrics,
    );
    return (engine: engine, storage: storage);
  }

  setUpAll(() async {
    if (!_enabled) return;
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): await isarTestLibraryPath()},
    );
    root = Directory.systemTemp.createTempSync('mangatan_chimahon_sync_perf');
    Hive.init('${root.path}/hive');
    MiningPreferences.configureStorageDirectory('${root.path}/hive');
    final seed = await Isar.open(
      chimahonSyncBenchmarkSchemas,
      directory: root.path,
      name: 'pristine',
    );
    seedChimahonSyncLibrary(
      seed,
      entries: _entries,
      chaptersPerEntry: _chaptersPerEntry,
      animeEntries: _animeEntries,
    );
    await seed.close();
    pristinePath = '${root.path}/pristine.isar';
    // The other device starts from the same library and makes its edits.
    final remoteDevice = await openCopy();
    applyRemoteDeviceEdits(remoteDevice, chaptersPerEntry: _chaptersPerEntry);
    remoteBackup = (await projectionFor(
      remoteDevice,
    ).createSnapshot()).backup.deepCopy();
    await remoteDevice.close(deleteFromDisk: true);
    // Meanwhile this device read further in other entries, so a sync has to
    // both import and upload.
    final local = await Isar.open(
      chimahonSyncBenchmarkSchemas,
      directory: root.path,
      name: 'pristine',
    );
    applyLocalDeviceEdits(local);
    await local.close();
    database = await openCopy();
    localBackup = (await projectionFor(database).createSnapshot()).backup;
    remoteBytes = const ChimahonSyncCodec().encode(
      remoteBackup,
      format: ChimahonSyncWireFormat.gzipProtobuf,
    );
    // ignore: avoid_print
    print(
      'BENCH setup ${jsonEncode({'entries': localBackup.backupManga.length, 'anime': localBackup.backupAnime.length, 'remoteEntries': remoteBackup.backupManga.length, 'protobufBytes': localBackup.writeToBuffer().length, 'remoteGzipBytes': remoteBytes.length})}',
    );
  });

  tearDownAll(() async {
    if (!_enabled) return;
    final out = Platform.environment['MANGATAN_PERF_OUT'];
    if (out != null) {
      File(
        out,
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(_results));
    }
    await database.close();
    await Hive.close();
    root.deleteSync(recursive: true);
  });

  test('local projection snapshot', skip: !_enabled, () async {
    final projection = projectionFor(database);
    await _bench('local_projection', (measure) async {
      await measure(projection.createSnapshot);
    });
  });

  test('local revision capture', skip: !_enabled, () async {
    await _bench('local_revision', (measure) async {
      await measure(() => ChimahonLocalRevision.capture(database, localBackup));
    });
  });

  test('codec decode remote (gzip)', skip: !_enabled, () async {
    await _bench('codec_decode', (measure) async {
      await measure(() async => const ChimahonSyncCodec().decode(remoteBytes));
    });
  });

  test('merge local and remote', skip: !_enabled, () async {
    await _bench('merge', (measure) async {
      await measure(
        () async => const ChimahonSyncMerger().merge(
          local: localBackup,
          remote: remoteBackup,
          remoteWinsProjectionTies: true,
        ),
      );
    });
  });

  test('two-way preview and pre-upload safety gate', skip: !_enabled, () async {
    final sidecars = root.createTempSync('preview_');
    final (:engine, storage: _) = engineFor(database, sidecars, remoteBytes);
    final gate = ChimahonPreUploadSafetyGate(
      recoveryStore: FileChimahonRemoteRecoveryStore(
        Directory('${sidecars.path}/recovery'),
      ),
    );
    await _bench('two_way_preview', (measure) async {
      await measure(engine.preview);
    });
    final preview = await engine.preview();
    await _bench('pre_upload_safety_gate', (measure) async {
      await measure(() => gate.check(preview));
    });
  });

  test('download-only plan', skip: !_enabled, () async {
    await _bench('download_plan', (measure) async {
      await measure(
        () async => ChimahonDownloadPlan(
          backup: remoteBackup,
          selection: const ChimahonMediaSyncSelection(),
          localProjection: localBackup,
          localMangas: database.mangas.where().findAllSync(),
          localChapters: database.chapters.where().findAllSync(),
          localSources: database.sources.where().findAllSync(),
          downloadedChapterIds: database.downloads
              .where()
              .findAllSync()
              .map((download) => download.id)
              .nonNulls
              .toSet(),
        ),
      );
    });
  });

  test('import merged payload', skip: !_enabled, () async {
    final merged = const ChimahonSyncMerger().merge(
      local: localBackup,
      remote: remoteBackup,
      remoteWinsProjectionTies: true,
    );
    await _bench('import_merged', (measure) async {
      final db = await openCopy();
      try {
        await measure(
          () async =>
              const ChimahonSyncImporter().apply(database: db, backup: merged),
        );
      } finally {
        await db.close(deleteFromDisk: true);
      }
    });
  });

  test('download-only import (authoritative)', skip: !_enabled, () async {
    await _bench('import_authoritative', (measure) async {
      final db = await openCopy();
      try {
        await measure(
          () async => const ChimahonSyncImporter().apply(
            database: db,
            backup: remoteBackup,
            authoritativeSelection: const ChimahonMediaSyncSelection(),
          ),
        );
      } finally {
        await db.close(deleteFromDisk: true);
      }
    });
  });

  test('two-way sync with remote changes', skip: !_enabled, () async {
    final phases = <CrossDeviceSyncPhase, List<double>>{};
    await _bench(
      'two_way_sync',
      (measure) async {
        final db = await openCopy();
        final sidecars = root.createTempSync('sync_');
        CrossDeviceSyncMetrics? last;
        try {
          final (:engine, :storage) = engineFor(
            db,
            sidecars,
            remoteBytes,
            onMetrics: (metrics) => last = metrics,
          );
          final result = await measure(engine.synchronize);
          expect(result.requiresRetry, isFalse);
          expect(storage.revision, 2);
          for (final entry in last!.phases.entries) {
            phases
                .putIfAbsent(entry.key, () => [])
                .add(entry.value.inMicroseconds / 1000);
          }
        } finally {
          await db.close(deleteFromDisk: true);
          sidecars.deleteSync(recursive: true);
        }
      },
      extra: (result) => result['phasesMs'] = {
        for (final entry in phases.entries)
          entry.key.name: _stat(entry.value.skip(_warmup).toList()),
      },
    );
  });

  test('two-way sync with nothing to change', skip: !_enabled, () async {
    final db = await openCopy();
    final sidecars = root.createTempSync('steady_');
    final phases = <CrossDeviceSyncPhase, List<double>>{};
    CrossDeviceSyncMetrics? last;
    final (:engine, :storage) = engineFor(
      db,
      sidecars,
      remoteBytes,
      onMetrics: (metrics) => last = metrics,
    );
    // Converge once; later syncs find nothing to upload or import.
    await engine.synchronize();
    try {
      await _bench(
        'steady_sync',
        (measure) async {
          await measure(engine.synchronize);
          for (final entry in last!.phases.entries) {
            phases
                .putIfAbsent(entry.key, () => [])
                .add(entry.value.inMicroseconds / 1000);
          }
        },
        extra: (result) => result['phasesMs'] = {
          for (final entry in phases.entries)
            entry.key.name: _stat(entry.value.skip(_warmup).toList()),
        },
      );
    } finally {
      await db.close(deleteFromDisk: true);
    }
  });
}
