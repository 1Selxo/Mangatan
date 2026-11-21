import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/novel/tts/tts_settings_tab.dart';
import 'package:mangayomi/modules/novel/widgets/novel_reader_settings_sheet.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/platform_utils.dart';

import 'dart:io';

class NovelReaderScreen extends ConsumerWidget {
  const NovelReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsSupported = !Platform.isLinux;
    return DefaultTabController(
      length: ttsSupported ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.novel_reader),
          bottom: TabBar(
            tabs: [
              Tab(text: context.l10n.reader),
              if (ttsSupported) Tab(text: context.l10n.tts),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChildScrollView(
              padding: pageInsets(context),
              child: const ReaderSettingsTab(),
            ),
            if (ttsSupported)
              SingleChildScrollView(
                padding: pageInsets(context),
                child: const TtsSettingsTab(),
              ),
          ],
        ),
      ),
    );
  }
}
