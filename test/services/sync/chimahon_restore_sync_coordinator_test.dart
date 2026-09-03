import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/sync/chimahon_restore_sync_coordinator.dart';

void main() {
  test(
    'sync waits until a manual restore leaves its critical section',
    () async {
      final coordinator = ChimahonRestoreSyncCoordinator();
      final restoreStarted = Completer<void>();
      final releaseRestore = Completer<void>();
      final events = <String>[];

      final restore = coordinator.duringManualRestore(() async {
        events.add('restore-start');
        restoreStarted.complete();
        await releaseRestore.future;
        events.add('restore-end');
      });
      await restoreStarted.future;

      final sync = coordinator.duringSync(() async {
        events.add('sync');
      });
      await Future<void>.delayed(Duration.zero);
      expect(events, ['restore-start']);

      releaseRestore.complete();
      await Future.wait([restore, sync]);
      expect(events, ['restore-start', 'restore-end', 'sync']);
    },
  );

  test('a failed operation releases the next queued operation', () async {
    final coordinator = ChimahonRestoreSyncCoordinator();
    final firstStarted = Completer<void>();
    final failFirst = Completer<void>();
    var secondRan = false;

    final first = coordinator.duringSync<void>(() async {
      firstStarted.complete();
      await failFirst.future;
      throw StateError('expected failure');
    });
    await firstStarted.future;
    final second = coordinator.duringManualRestore(() async {
      secondRan = true;
    });

    failFirst.complete();
    await expectLater(first, throwsStateError);
    await second;
    expect(secondRan, isTrue);
  });

  test('read-only preview does not inspect state during a restore', () async {
    final coordinator = ChimahonRestoreSyncCoordinator();
    final restoreStarted = Completer<void>();
    final releaseRestore = Completer<void>();
    var previewOpenedState = false;

    final restore = coordinator.duringManualRestore(() async {
      restoreStarted.complete();
      await releaseRestore.future;
    });
    await restoreStarted.future;

    final preview = coordinator.duringReadOnlyPreview(() async {
      previewOpenedState = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(previewOpenedState, isFalse);

    releaseRestore.complete();
    await Future.wait([restore, preview]);
    expect(previewOpenedState, isTrue);
  });

  test('Drive disconnect waits for an in-flight credential commit', () async {
    final coordinator = ChimahonRestoreSyncCoordinator();
    final connectStarted = Completer<void>();
    final releaseConnect = Completer<void>();
    final events = <String>[];

    final connect = coordinator.duringSync(() async {
      events.add('commit-start');
      connectStarted.complete();
      await releaseConnect.future;
      events.add('commit-end');
    });
    await connectStarted.future;

    final disconnect = coordinator.duringSync(() async {
      events.add('clear-token');
      events.add('mark-disconnected');
    });
    await Future<void>.delayed(Duration.zero);
    expect(events, ['commit-start']);

    releaseConnect.complete();
    await Future.wait([connect, disconnect]);
    expect(events, [
      'commit-start',
      'commit-end',
      'clear-token',
      'mark-disconnected',
    ]);
  });
}
