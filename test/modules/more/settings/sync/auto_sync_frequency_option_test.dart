import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/more/settings/sync/widgets/auto_sync_frequency_option.dart';

void main() {
  testWidgets('tapping selected Off still records an explicit zero', (
    tester,
  ) async {
    var selected = 0;
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) {
                setState(() {
                  selected = autoSyncFrequencyFromRadioValue(value);
                  changeCount++;
                });
              },
              child: const AutoSyncFrequencyOption(value: 0, title: 'Off'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auto-sync-frequency-0')));
    await tester.pump();

    expect(selected, 0);
    expect(changeCount, 1);
  });

  testWidgets('a selected interval remains non-toggleable', (tester) async {
    var changeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RadioGroup<int>(
            groupValue: 300,
            onChanged: (_) => changeCount++,
            child: const AutoSyncFrequencyOption(
              value: 300,
              title: '5 minutes',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('auto-sync-frequency-300')));
    await tester.pump();

    expect(changeCount, 0);
  });
}
