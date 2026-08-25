import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/ocr_processing_queue_sheet.dart';
import 'package:mangayomi/services/mining/ocr_processing_queue.dart';

void main() {
  testWidgets('tapping a failed chapter retries it', (tester) async {
    var shouldFail = true;
    final controller = OcrProcessingQueueController(
      maxAutomaticAttempts: 1,
      delay: (_) => Future<void>.value(),
    );
    addTearDown(() {
      controller.reset();
      controller.entries.dispose();
    });
    controller.enqueue([
      OcrQueueRequest(
        id: 'chapter:1',
        title: 'Test manga',
        subtitle: 'Chapter 1',
        operation: (_) async {
          if (shouldFail) throw StateError('recognition failed');
        },
      ),
    ]);
    await controller.waitUntilIdle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OcrProcessingQueueSheet(controller: controller)),
      ),
    );
    expect(find.textContaining('tap to retry'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Test manga'));
    await tester.pump();
    await controller.waitUntilIdle();
    await tester.pump();

    expect(find.text('OCR ready'), findsOneWidget);
  });
}
