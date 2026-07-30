import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/mining_models.dart';

void main() {
  test('enforces one preparation job per player', () {
    final controller = AnkiExportJobController();
    final first = controller.beginPreparing();

    expect(controller.state, AnkiExportJobState.preparing);
    expect(
      controller.beginPreparing,
      throwsA(isA<AnkiExportJobBusyException>()),
    );

    first.finish();
    expect(controller.state, AnkiExportJobState.idle);
    controller.beginPreparing().finish();
  });

  test('cancellation wins while preparing but not while committing', () {
    final controller = AnkiExportJobController();
    final cancelled = controller.beginPreparing();
    cancelled.registerCancel(() {});
    controller.cancel();

    expect(cancelled.isCancelled, isTrue);
    expect(
      cancelled.beginCommitting,
      throwsA(isA<AnkiExportCancelledException>()),
    );
    cancelled.finish();

    final committing = controller.beginPreparing();
    committing.registerCancel(() {});
    committing.beginCommitting();
    controller.cancel();

    expect(controller.state, AnkiExportJobState.committing);
    expect(committing.isCancelled, isFalse);
    committing.finish();
    expect(controller.state, AnkiExportJobState.idle);
  });
}
