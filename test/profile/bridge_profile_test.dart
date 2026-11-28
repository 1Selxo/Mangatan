// Startup's Mihon source refresh and a global search, against a real
// extension server started for the test (isolated data folder), with the
// Dart CPU sampler on this side and Java Flight Recorder on the other.
//
//   MANGATAN_PROFILE_DB=<folder with a copy of mangayomiDb.isar>
//   MANGATAN_PROFILE_JDK=<JDK 21 home>   (needs java and jcmd)
//   MANGATAN_PROFILE_JAR=<MExtensionServer jar>
//     flutter test --enable-vmservice test/profile/bridge_profile_test.dart
//
// The search part sends one real query to every ENABLED, non-NSFW manga
// source's website, as the app's global search would. Set
// MANGATAN_PROFILE_QUERY to change the word, or to an empty string to skip.
// Source names are never written out.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/main.dart' as app;
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/models/manga.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/services/fetch_gate.dart';
import 'package:mangayomi/services/http/m_client.dart' as m_client;
import 'package:mangayomi/services/reconcile_mihon_sources.dart';
import 'package:mangayomi/services/search.dart';

import '../journeys/harness/plugins.dart';
import 'profiler.dart';
import 'real_data.dart';

final _env = Platform.environment;
final _jdk = _env['MANGATAN_PROFILE_JDK'];
final _jar = _env['MANGATAN_PROFILE_JAR'];
final _query = _env['MANGATAN_PROFILE_QUERY'] ?? 'love';

/// The longest stretches the main isolate could not run its event loop: what
/// a person sees as a frozen window.
class _Stalls {
  _Stalls() {
    var last = _clock.elapsedMicroseconds;
    _timer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      final now = _clock.elapsedMicroseconds;
      final gap = (now - last) / 1000 - 5;
      last = now;
      if (gap > 16) _gaps.add(gap);
    });
  }

  final _clock = Stopwatch()..start();
  final _gaps = <double>[];
  late final Timer _timer;

  Map<String, Object?> stop() {
    _timer.cancel();
    return {
      'stallsOver16ms': _gaps.length,
      'stallsOver100ms': _gaps.where((g) => g > 100).length,
      'stalledMsTotal': _gaps.fold<double>(0, (a, b) => a + b).round(),
      'worstStallMs': _gaps.isEmpty
          ? 0
          : _gaps.reduce((a, b) => a > b ? a : b).round(),
    };
  }
}

void main() {
  final skip = realDatabaseDir == null || _jdk == null || _jar == null;

  test(
    'startup refresh and global search through the bridge',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = null;
      stubPlatformPlugins();
      final work = Directory.systemTemp.createTempSync('mangatan-bridge-prof-');
      platformDirectory = work.path;
      Hive.init(work.path);
      final jvmTmp = Directory('${work.path}/jvmtmp')..createSync();

      final exe = Platform.isWindows ? '.exe' : '';
      final log = File('${profileOut.path}/bridge-server.log').openWrite();
      late Process jvm;
      late String base;

      /// Starts the server on the same data folder each time, as each app
      /// launch does, and waits until it answers.
      Future<void> launch() async {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        final launched = Stopwatch()..start();
        jvm = await Process.start('$_jdk/bin/java$exe', [
          '-XX:FlightRecorderOptions=stackdepth=192',
          '-Djava.io.tmpdir=${jvmTmp.path}',
          '-Dsuwayomi.tachidesk.config.server.rootDir=${work.path}/bridge-data',
          '-jar',
          _jar!,
          '$port',
        ]);
        jvm.stdout.listen(log.add);
        jvm.stderr.listen(log.add);
        base = 'http://127.0.0.1:$port';
        while (true) {
          try {
            final request = await HttpClient().getUrl(
              Uri.parse('$base/capabilities'),
            );
            final response = await request.close();
            await response.drain<void>();
            if (response.statusCode == 200) break;
          } catch (_) {
            if (launched.elapsed > const Duration(seconds: 60)) rethrow;
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        print('bridge answered after ${launched.elapsedMilliseconds} ms');
      }

      Future<void> jcmd(List<String> args) async {
        final r = await Process.run('$_jdk/bin/jcmd$exe', [
          '${jvm.pid}',
          ...args,
        ]);
        if (r.exitCode != 0) {
          print('jcmd ${args.first}: ${r.stdout}${r.stderr}');
        }
      }

      Future<void> record(String name) =>
          jcmd(['JFR.start', 'name=$name', 'settings=profile']);
      Future<void> dump(String name) => jcmd([
        'JFR.stop',
        'name=$name',
        'filename=${profileOut.absolute.path}/$name.jfr',
      ]);

      final profiler = await Profiler.connect();
      try {
        await launch();
        final db = await openRealDatabaseCopy(Directory('${work.path}/db'));
        app.isar = db;
        m_client.cfPort = 1; // No WebView host headlessly.
        Future<ProviderContainer> pointAtServer() async {
          final settings = (await db.settings.get(227))!;
          await db.writeTxn(
            () => db.settings.put(settings..androidProxyServer = base),
          );
          return ProviderContainer(retry: (_, _) => null);
        }

        var container = await pointAtServer();
        Future<void> phase(
          String name,
          Future<Map<String, Object?>> Function() action,
        ) async {
          await record(name);
          await profiler.start();
          final drain = Timer.periodic(
            const Duration(seconds: 2),
            (_) => unawaited(profiler.drain().catchError((_) {})),
          );
          var writes = 0;
          final watch = db.sources.watchLazy().listen((_) => writes++);
          final stalls = _Stalls();
          final wall = Stopwatch()..start();
          final facts = await action();
          wall.stop();
          final stalled = stalls.stop();
          drain.cancel();
          await watch.cancel();
          await profiler.stop(name, {
            'wallMs': wall.elapsedMilliseconds,
            ...stalled,
            'sourceTableChanges': writes,
            ...facts,
          });
          await dump(name);
        }

        Future<Map<String, Object?>> refresh() async {
          final result = await container.read(
            refreshInstalledMihonFactorySourcesProvider.future,
          );
          return {
            'groups': result.groupsReconciled,
            'unresolved': result.unresolvedGroups,
          };
        }

        await phase('bridge-01-refresh-first-launch', refresh);
        container.invalidate(refreshInstalledMihonFactorySourcesProvider);
        await phase('bridge-02-refresh-again', refresh);
        // A relaunch: a new server process on the same data folder, and an
        // app that has forgotten every extension handle (a new port).
        container.dispose();
        jvm.kill();
        await jvm.exitCode;
        await launch();
        container = await pointAtServer();
        await phase('bridge-03-refresh-relaunch', refresh);

        if (_query.isNotEmpty) {
          final sources = await db.sources
              .filter()
              .isAddedEqualTo(true)
              .itemTypeEqualTo(ItemType.manga)
              .isActiveEqualTo(true)
              .findAll();
          sources.removeWhere((s) => s.isNsfw ?? false);
          await phase('bridge-04-global-search', () async {
            final gate = FetchGate(3); // As the global search screen does.
            final clock = Stopwatch()..start();
            final latencies = <int>[];
            var ok = 0, empty = 0, failed = 0;
            int? firstResult;
            await Future.wait([
              for (final source in sources)
                () async {
                  await gate.acquire();
                  final w = Stopwatch()..start();
                  final provider = searchProvider(
                    source: source,
                    query: _query,
                    page: 1,
                    filterList: const [],
                  );
                  final sub = container.listen(provider, (_, _) {});
                  try {
                    final pages = await container
                        .read(provider.future)
                        .timeout(const Duration(seconds: 60));
                    if (pages?.list.isEmpty ?? true) {
                      empty++;
                    } else {
                      ok++;
                      firstResult ??= clock.elapsedMilliseconds;
                    }
                  } catch (_) {
                    failed++;
                  } finally {
                    latencies.add(w.elapsedMilliseconds);
                    sub.close();
                    gate.release();
                  }
                }(),
            ]);
            return {
              'sources': sources.length,
              'withResults': ok,
              'empty': empty,
              'failed': failed,
              'firstResultMs': firstResult,
              'perSourceMs': summary(latencies),
              'latenciesMs': latencies,
            };
          });
        }
        container.dispose();
        await db.close();
      } finally {
        await profiler.dispose();
        jvm.kill();
        await jvm.exitCode;
        await log.close();
        try {
          work.deleteSync(recursive: true);
        } on FileSystemException {
          // The JVM can hold its jars a moment longer.
        }
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
