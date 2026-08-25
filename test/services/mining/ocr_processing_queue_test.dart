import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/ocr_processing_queue.dart';

void main() {
  late OcrProcessingQueueController controller;

  setUp(() {
    controller = OcrProcessingQueueController(
      delay: (_) => Future<void>.value(),
    );
  });

  tearDown(() {
    controller.reset();
    controller.entries.dispose();
  });

  test('automatically retries a failed chapter three times', () async {
    var attempts = 0;
    controller.enqueue([
      OcrQueueRequest(
        id: 'chapter:1',
        title: 'Title',
        subtitle: 'Chapter 1',
        operation: (onProgress) async {
          attempts++;
          if (attempts < 3) throw StateError('temporary OCR failure');
          onProgress(4, 4);
        },
      ),
    ]);

    await controller.waitUntilIdle();

    expect(attempts, 3);
    expect(controller.entries.value.single.status, OcrQueueStatus.completed);
    expect(controller.entries.value.single.attempt, 3);
    expect(controller.entries.value.single.completed, 4);
  });

  test('terminal failure remains available for an explicit retry', () async {
    var attempts = 0;
    var shouldFail = true;
    controller.enqueue([
      OcrQueueRequest(
        id: 'chapter:2',
        title: 'Title',
        subtitle: 'Chapter 2',
        operation: (_) async {
          attempts++;
          if (shouldFail) throw StateError('OCR model unavailable');
        },
      ),
    ]);

    await controller.waitUntilIdle();
    expect(attempts, 3);
    expect(controller.entries.value.single.status, OcrQueueStatus.error);
    expect(
      controller.entries.value.single.error,
      contains('model unavailable'),
    );

    shouldFail = false;
    expect(controller.retry('chapter:2'), isTrue);
    await controller.waitUntilIdle();

    expect(attempts, 4);
    expect(controller.entries.value.single.status, OcrQueueStatus.completed);
  });

  test('an active duplicate is not enqueued twice', () async {
    final blocker = Completer<void>();
    var attempts = 0;
    final request = OcrQueueRequest(
      id: 'chapter:3',
      title: 'Title',
      subtitle: 'Chapter 3',
      operation: (_) async {
        attempts++;
        await blocker.future;
      },
    );

    controller.enqueue([request]);
    controller.enqueue([request]);
    expect(controller.entries.value, hasLength(1));
    blocker.complete();
    await controller.waitUntilIdle();
    expect(attempts, 1);
  });
}
