import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/modules/more/settings/dictionary/dictionary_settings_section.dart';
import 'package:mangayomi/modules/more/widgets/list_tile_widget.dart';
import 'package:mangayomi/providers/l10n_providers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = l10nLocalizations(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n!.settings)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _SettingsSectionHeader('General'),
            ListTileWidget(
              title: l10n.general,
              icon: Icons.settings,
              onTap: () => context.push('/general'),
            ),
            ListTileWidget(
              title: l10n.appearance,
              icon: Icons.color_lens_rounded,
              onTap: () => context.push('/appearance'),
            ),
            if (!Platform.isLinux)
              ListTileWidget(
                title: l10n.security,
                icon: Icons.security_rounded,
                onTap: () => context.push('/security'),
              ),
            const _SettingsSectionHeader('Media'),
            ListTileWidget(
              title: l10n.reader,
              icon: Icons.chrome_reader_mode_rounded,
              onTap: () => context.push('/readerMode'),
            ),
            ListTileWidget(
              title: l10n.player,
              icon: Icons.play_circle_outline_outlined,
              onTap: () => context.push('/playerOverview'),
            ),
            ListTileWidget(
              title: 'Subtitles & Jimaku',
              subtitle: 'API key and automatic subtitle lookup',
              icon: Icons.subtitles_outlined,
              onTap: () => context.push('/playerSubtitles'),
            ),
            ListTileWidget(
              title: l10n.downloads,
              icon: Icons.download_outlined,
              onTap: () => context.push('/downloads'),
            ),
            ListTileWidget(
              title: l10n.browse,
              icon: Icons.explore_rounded,
              onTap: () => context.push('/browseS'),
            ),
            const _SettingsSectionHeader('Learning'),
            ListTileWidget(
              title: DictionarySettingsSection.dictionariesAndAudio.title,
              subtitle: DictionarySettingsSection.dictionariesAndAudio.summary,
              icon: Icons.translate,
              onTap: () => context.push('/dictionary'),
            ),
            ListTileWidget(
              title: DictionarySettingsSection.dictionaryPopup.title,
              subtitle: DictionarySettingsSection.dictionaryPopup.summary,
              icon: Icons.tab_outlined,
              onTap: () => context.push('/dictionaryPopup'),
            ),
            ListTileWidget(
              title: DictionarySettingsSection.anki.title,
              subtitle: DictionarySettingsSection.anki.summary,
              icon: Icons.style_outlined,
              onTap: () => context.push('/ankiSettings'),
            ),
            const _SettingsSectionHeader('Sync'),
            ListTileWidget(
              title: l10n.tracking,
              icon: Icons.sync_outlined,
              onTap: () => context.push('/track'),
            ),
            ListTileWidget(
              title: l10n.syncing,
              icon: Icons.cloud_sync_outlined,
              onTap: () => context.push('/sync'),
            ),
            ListTileWidget(
              title: l10n.about,
              icon: Icons.info_outline,
              onTap: () => context.push('/about'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
    );
  }
}
