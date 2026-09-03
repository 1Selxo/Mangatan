// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupChapter.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupManga.pb.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupMihon.pb.dart';
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';
import 'package:mangayomi/services/sync/chimahon_media_sync_selection.dart';
import 'package:mangayomi/services/sync/cross_device_sync_engine.dart';
import 'package:mangayomi/services/sync/cross_device_sync_metrics.dart';
import 'package:mangayomi/services/sync/cross_device_sync_storage.dart';

const _mangaCount = 300;
const _chaptersPerManga = 100;
const _warmupRuns = 2;
const _measuredRuns = 7;

void main() {
  test('large in-memory Chimahon synchronization benchmark', _benchmark);
}

Future<void> _benchmark() async {
  final changed = _representativeBackup();
  await _benchmarkScenario(
    name: 'changed upload',
    local: changed,
    remote: changed,
    isCompleteRecovery: false,
  );
  final unchanged = const ChimahonMediaSyncSelection().withBackedPreferences(
    _representativeBackup(),
  );
  await _benchmarkScenario(
    name: 'unchanged no-op',
    local: unchanged,
    remote: unchanged,
    isCompleteRecovery: true,
  );
}

Future<void> _benchmarkScenario({
  required String name,
  required BackupMihon local,
  required BackupMihon remote,
  required bool isCompleteRecovery,
}) async {
  const codec = ChimahonSyncCodec();
  final remoteBytes = codec.encode(
    remote,
    format: ChimahonSyncWireFormat.gzipProtobuf,
  );
  final samples = <int>[];
  CrossDeviceSyncMetrics? lastMetrics;

  for (var run = 0; run < _warmupRuns + _measuredRuns; run++) {
    final stopwatch = Stopwatch()..start();
    final result = await CrossDeviceSyncEngine(
      storage: _BenchmarkStorage(
        remoteBytes,
        isCompleteRecovery: isCompleteRecovery,
      ),
      exportLocal: () async => local.deepCopy(),
      importMerged: (_) async {},
    ).uploadPreservingRemote();
    lastMetrics = result.metrics;
    stopwatch.stop();
    if (run >= _warmupRuns) samples.add(stopwatch.elapsedMicroseconds);
  }

  samples.sort();
  final total = samples.fold<int>(0, (sum, sample) => sum + sample);
  final average = total / samples.length / Duration.microsecondsPerMillisecond;
  final median =
      samples[samples.length ~/ 2] / Duration.microsecondsPerMillisecond;
  final minimum = samples.first / Duration.microsecondsPerMillisecond;
  final maximum = samples.last / Duration.microsecondsPerMillisecond;
  print(
    'Chimahon sync benchmark ($name): '
    '$_mangaCount manga, ${_mangaCount * _chaptersPerManga} chapters, '
    '${remoteBytes.length} compressed bytes',
  );
  print(
    'runs=$_measuredRuns avg=${average.toStringAsFixed(2)}ms '
    'median=${median.toStringAsFixed(2)}ms min=${minimum.toStringAsFixed(2)}ms '
    'max=${maximum.toStringAsFixed(2)}ms',
  );
  print('last run phases: ${lastMetrics!.toLogMessage()}');
}

BackupMihon _representativeBackup() => BackupMihon(
  backupManga: [
    for (var mangaIndex = 0; mangaIndex < _mangaCount; mangaIndex++)
      BackupManga(
        source: Int64(1000 + mangaIndex % 12),
        url: '/manga/$mangaIndex',
        title: 'Benchmark manga $mangaIndex',
        author: 'Author ${mangaIndex % 40}',
        description: 'Representative synchronization payload $mangaIndex',
        favorite: true,
        version: Int64(10),
        lastModifiedAt: Int64(10000 + mangaIndex),
        chapters: [
          for (
            var chapterIndex = 0;
            chapterIndex < _chaptersPerManga;
            chapterIndex++
          )
            BackupChapter(
              url: '/manga/$mangaIndex/chapter/$chapterIndex',
              name: 'Chapter $chapterIndex',
              chapterNumber: chapterIndex.toDouble(),
              read: chapterIndex.isEven,
              lastPageRead: Int64(chapterIndex % 12),
              version: Int64(5),
              lastModifiedAt: Int64(20000 + chapterIndex),
            ),
        ],
      ),
  ],
);

class _BenchmarkStorage implements CrossDeviceSyncStorage {
  const _BenchmarkStorage(this.bytes, {this.isCompleteRecovery = false});

  final Uint8List bytes;
  final bool isCompleteRecovery;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.gzipProtobuf;

  @override
  Future<RemoteSyncSnapshot> download() async => RemoteSyncSnapshot(
    bytes: bytes,
    revision: 'benchmark-revision',
    isCompleteRecovery: isCompleteRecovery,
  );

  @override
  Future<String> upload(
    Uint8List bytes, {
    String? expectedRevision,
    bool expectedAbsent = false,
  }) async => 'benchmark-next-revision';
}
