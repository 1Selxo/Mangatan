import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/reader/reader_eink_state.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:shiori/shiori.dart';

/// E-Ink mode: a plain white reader, for E-Ink displays.
class ReaderEInkSwitchRow extends StatelessWidget {
  const ReaderEInkSwitchRow({super.key});

  @override
  Widget build(BuildContext context) {
    unawaited(ReaderEInkState.initialize());
    return ValueListenableBuilder<bool>(
      valueListenable: ReaderEInkState.enabled,
      builder: (context, eInkMode, _) => ShioriSwitchRow(
        title: 'E-Ink mode',
        subtitle:
            'Uses a high-contrast white reader surface for E-Ink '
            'displays',
        value: eInkMode,
        onChanged: (value) => unawaited(ReaderEInkState.setEnabled(value)),
      ),
    );
  }
}

/// Mangatan's OCR: which engine reads the page, when it runs, and how its
/// boxes behave.
class ReaderOcrSettingsGroup extends StatelessWidget {
  const ReaderOcrSettingsGroup({super.key});

  @override
  Widget build(BuildContext context) {
    unawaited(ReaderOcrState.initialize());
    return ShioriSettingsGroup(
      title: 'OCR',
      children: [
        ValueListenableBuilder<OcrEnginePreference>(
          valueListenable: ReaderOcrState.engine,
          builder: (context, engine, _) => ShioriValueRow<OcrEnginePreference>(
            title: 'OCR engine',
            value: engine,
            options: [
              for (final option in availableOcrEngines())
                ShioriChoice(option, ocrEngineLabel(option)),
            ],
            onChanged: (value) => unawaited(ReaderOcrState.setEngine(value)),
          ),
        ),
        ValueListenableBuilder<OcrScanTrigger>(
          valueListenable: ReaderOcrState.scanTrigger,
          builder: (context, trigger, _) => ShioriValueRow<OcrScanTrigger>(
            title: 'OCR trigger',
            value: trigger,
            options: const [
              ShioriChoice(
                OcrScanTrigger.automatic,
                'Automatic',
                subtitle: 'Scans pages in the background',
              ),
              ShioriChoice(
                OcrScanTrigger.manual,
                'Manual',
                subtitle: 'Tap the OCR button to scan the current page',
              ),
            ],
            onChanged: (value) =>
                unawaited(ReaderOcrState.setScanTrigger(value)),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: ReaderOcrState.parallelOcrLimit,
          builder: (context, limit, _) => ShioriValueRow<int>(
            title: 'Parallel OCR tasks',
            value: limit,
            options: const [
              ShioriChoice(1, '1', subtitle: 'Recommended'),
              ShioriChoice(2, '2', subtitle: 'Higher battery and network use'),
              ShioriChoice(3, '3', subtitle: 'Higher battery and network use'),
              ShioriChoice(4, '4', subtitle: 'Higher battery and network use'),
            ],
            onChanged: (value) =>
                unawaited(ReaderOcrState.setParallelOcrLimit(value)),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: ReaderOcrState.outlineVisible,
          builder: (context, outlineVisible, _) => ShioriSwitchRow(
            title: 'Show OCR box outlines',
            value: outlineVisible,
            onChanged: (value) =>
                unawaited(ReaderOcrState.setOutlineVisible(value)),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: ReaderOcrState.lookupOnHover,
          builder: (context, lookupOnHover, _) => ShioriSwitchRow(
            title: 'Lookup OCR text on hover',
            value: lookupOnHover,
            onChanged: (value) =>
                unawaited(ReaderOcrState.setLookupOnHover(value)),
          ),
        ),
      ],
    );
  }
}
