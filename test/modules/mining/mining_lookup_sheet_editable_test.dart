// Regression coverage for issue #40 ("[Feature request] Editable text").
//
// The historical userscript could not correct OCR mistakes before a lookup.
// The rewrite resolves this by seeding the recognized text into an editable
// field inside [MiningLookupSheet]: the user fixes OCR errors in place, then
// looks the corrected text up / mines it. These tests lock that capability so
// the field cannot silently regress to read-only or drop the OCR seed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mangayomi/modules/mining/widgets/mining_lookup_sheet.dart';
import 'package:mangayomi/services/mining/mining_models.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'mangatan-lookup-sheet-',
    );
    Hive.init(tempDirectory.path);
  });

  setUp(() async {
    if (Hive.isBoxOpen('mining_preferences')) {
      await Hive.box<dynamic>('mining_preferences').close();
    }
    await Hive.deleteBoxFromDisk('mining_preferences');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Widget host() => const MaterialApp(
    home: Scaffold(
      body: MiningLookupSheet(
        initialText: '茗荷',
        miningContext: MiningContext(mediaType: MiningMediaType.manga),
      ),
    ),
  );

  testWidgets('seeds the OCR text into an editable lookup field', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final fieldFinder = find.byType(TextField);
    expect(fieldFinder, findsOneWidget);

    final field = tester.widget<TextField>(fieldFinder);
    expect(field.controller, isNotNull);
    expect(field.controller!.text, '茗荷');
    // The whole point of issue #40: the OCR text must be user-correctable.
    expect(field.enabled ?? true, isTrue);
    expect(field.readOnly, isFalse);
  });

  testWidgets('accepts an OCR correction typed into the field', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    // Simulate the user fixing an OCR error before looking the word up.
    await tester.enterText(find.byType(TextField), '茗荷谷');
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '茗荷谷');
  });

  testWidgets('trims surrounding whitespace from the seeded OCR text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MiningLookupSheet(
            initialText: '  茗荷  ',
            miningContext: MiningContext(mediaType: MiningMediaType.manga),
          ),
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '茗荷');
  });
}
