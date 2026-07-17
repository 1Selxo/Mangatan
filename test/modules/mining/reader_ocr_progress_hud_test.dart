import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';

void main() {
  testWidgets('OCR progress follows the reader menu in both directions', (
    tester,
  ) async {
    ReaderOcrState.progress.value = const ReaderOcrProgress(
      completed: 1,
      total: 3,
    );
    addTearDown(() => ReaderOcrState.progress.value = null);

    var top = 12.0;
    late StateSetter setHarnessState;

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            StatefulBuilder(
              builder: (context, setState) {
                setHarnessState = setState;
                return ReaderOcrProgressHud(
                  key: const ValueKey('ocr-progress'),
                  top: top,
                );
              },
            ),
          ],
        ),
      ),
    );

    final hud = find.byKey(const ValueKey('ocr-progress'));
    expect(tester.getTopLeft(hud).dy, 12);

    setHarnessState(() => top = 92);
    await tester.pump();
    expect(tester.getTopLeft(hud).dy, 12);

    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(hud).dy, inExclusiveRange(12, 92));

    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getTopLeft(hud).dy, 92);

    setHarnessState(() => top = 12);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(hud).dy, 12);
  });
}
