import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/anime/utils/player_lifecycle.dart';

void main() {
  test('player disposal waits for every listener cancellation', () async {
    final firstCancellation = Completer<void>();
    final secondCancellation = Completer<void>();
    var disposeCalls = 0;

    final cleanup = disposePlaybackSession(
      listenerCancellations: [
        firstCancellation.future,
        secondCancellation.future,
      ],
      disposePlayer: () async {
        disposeCalls++;
      },
    );

    firstCancellation.complete();
    await Future<void>.delayed(Duration.zero);
    expect(disposeCalls, 0);

    secondCancellation.complete();
    await cleanup;
    expect(disposeCalls, 1);
  });

  test('player is still disposed when listener cancellation fails', () async {
    var disposeCalls = 0;

    await expectLater(
      disposePlaybackSession(
        listenerCancellations: [
          Future<void>.error(StateError('cancel failed')),
        ],
        disposePlayer: () async {
          disposeCalls++;
        },
      ),
      throwsStateError,
    );

    expect(disposeCalls, 1);
  });
}
