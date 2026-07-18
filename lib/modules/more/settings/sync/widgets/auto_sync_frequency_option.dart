import 'package:flutter/material.dart';

/// Radio-group deselection means the already-selected Off row was tapped.
int autoSyncFrequencyFromRadioValue(int? value) => value ?? 0;

class AutoSyncFrequencyOption extends StatelessWidget {
  const AutoSyncFrequencyOption({
    super.key,
    required this.value,
    required this.title,
  });

  final int value;
  final String title;

  @override
  Widget build(BuildContext context) => RadioListTile<int>(
    key: ValueKey('auto-sync-frequency-$value'),
    dense: true,
    contentPadding: EdgeInsets.zero,
    value: value,
    // Flutter reports null when a selected toggleable radio is tapped. Only
    // Off needs this: mapping that null back to zero records explicit intent.
    toggleable: value == 0,
    title: Text(title),
  );
}
