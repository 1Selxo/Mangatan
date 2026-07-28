import 'package:flutter/material.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';

/// One label/value pair in a statistics sheet.
class StatsSheetRow {
  const StatsSheetRow(this.label, this.value);

  final String label;
  final String value;
}

/// A titled group of rows.
class StatsSheetSection {
  const StatsSheetSection({required this.title, required this.rows});

  final String title;
  final List<StatsSheetRow> rows;
}

/// Shared chrome for the in-reader statistics sheets, matching Chimahon's
/// layout: a heading with an optional pause toggle above titled sections of
/// label/value rows.
class StatsSheetLayout extends StatelessWidget {
  const StatsSheetLayout({
    super.key,
    required this.title,
    required this.sections,
    this.isTracking,
    this.onToggleTracking,
  });

  final String title;
  final List<StatsSheetSection> sections;

  /// Null hides the toggle entirely.
  final bool? isTracking;
  final VoidCallback? onToggleTracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (onToggleTracking != null)
                  IconButton(
                    onPressed: onToggleTracking,
                    tooltip: isTracking == true ? 'Pause timer' : 'Resume timer',
                    icon: Icon(
                      isTracking == true ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
              ],
            ),
            for (final section in sections)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Text(
                    section.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: context.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      for (final row in section.rows)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              row.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              row.value,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
