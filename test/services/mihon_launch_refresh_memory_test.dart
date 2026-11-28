import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/services/mihon_launch_refresh_memory.dart';

/// The launch refresh asked the bridge about every installed source on each
/// launch, uploading every APK, for the same answers as last time. It now
/// skips an extension when nothing it depends on changed in the last day.
void main() {
  late Directory directory;
  var now = DateTime(2026, 11, 28, 9);

  setUp(() => directory = Directory.systemTemp.createTempSync('launch-mem'));
  tearDown(() => directory.deleteSync(recursive: true));

  List<Source> group({String prefs = '[]', String version = '1.6.4'}) => [
    for (final id in [2, 1])
      Source(
        id: id,
        version: version,
        sourceCodeUrl: 'https://repo.example/mangadex.apk',
        sourceCode: 'A' * 9000,
        preferenceList: prefs,
      ),
  ];

  Future<MihonLaunchRefreshMemory> load() =>
      MihonLaunchRefreshMemory.load(directory, now: () => now);

  test('an unchanged extension is skipped on the next launch', () async {
    final memory = await load();
    expect(memory.isUnchanged('mangadex', group(), 'server.jar'), isFalse);
    memory.remember('mangadex', group(), 'server.jar');
    await memory.save();

    final next = await load();
    expect(next.isUnchanged('mangadex', group(), 'server.jar'), isTrue);
  });

  test('a change to what the answers depend on refreshes it', () async {
    final memory = await load();
    memory.remember('mangadex', group(), 'server.jar');
    await memory.save();
    final next = await load();

    expect(
      next.isUnchanged('mangadex', group(prefs: '[1]'), 'server.jar'),
      isFalse,
    );
    expect(
      next.isUnchanged('mangadex', group(version: '1.6.5'), 'server.jar'),
      isFalse,
    );
    expect(
      next.isUnchanged('mangadex', group().sublist(1), 'server.jar'),
      isFalse,
    );
    expect(next.isUnchanged('mangadex', group(), 'other.jar'), isFalse);
  });

  test('it is refreshed at least once a day, and after a failure', () async {
    final memory = await load();
    memory.remember('mangadex', group(), 'server.jar');
    now = now.add(const Duration(hours: 25));
    expect(memory.isUnchanged('mangadex', group(), 'server.jar'), isFalse);

    now = now.add(const Duration(minutes: 1));
    memory.remember('mangadex', group(), 'server.jar');
    memory.forget('mangadex');
    expect(memory.isUnchanged('mangadex', group(), 'server.jar'), isFalse);
  });

  test('an unreadable memory means refreshing everything', () async {
    File('${directory.path}/${MihonLaunchRefreshMemory.fileName}')
        .writeAsStringSync('not json');
    final memory = await load();
    expect(memory.isUnchanged('mangadex', group(), 'server.jar'), isFalse);
  });
}
