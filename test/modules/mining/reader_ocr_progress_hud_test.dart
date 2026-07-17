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
    expect(find.text('OCR 1/3'), findsOneWidget);

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

  testWidgets('shows a compact label while website Mokuro data loads', (
    tester,
  ) async {
    ReaderOcrState.progress.value = const ReaderOcrProgress(
      completed: 0,
      total: 12,
      stage: ReaderOcrProgressStage.loadingMokuro,
    );
    addTearDown(() => ReaderOcrState.progress.value = null);

    await tester.pumpWidget(
      const MaterialApp(home: Stack(children: [ReaderOcrProgressHud()])),
    );

    expect(find.text('Loading Mokuro'), findsOneWidget);
    expect(find.text('OCR 0/12'), findsNothing);
  });

  testWidgets('keeps Mokuro distinct during cached page preparation', (
    tester,
  ) async {
    ReaderOcrState.progress.value = const ReaderOcrProgress(
      completed: 4,
      total: 12,
      stage: ReaderOcrProgressStage.mokuro,
    );
    addTearDown(() => ReaderOcrState.progress.value = null);

    await tester.pumpWidget(
      const MaterialApp(home: Stack(children: [ReaderOcrProgressHud()])),
    );

    expect(find.text('Mokuro 4/12'), findsOneWidget);
    expect(find.text('OCR 4/12'), findsNothing);
  });
}
