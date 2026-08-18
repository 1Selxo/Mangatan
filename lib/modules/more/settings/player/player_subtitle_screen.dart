import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/anime/providers/state_provider.dart';
import 'package:mangayomi/modules/anime/widgets/subtitle_view.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

class PlayerSubtitleScreen extends ConsumerStatefulWidget {
  const PlayerSubtitleScreen({super.key});

  @override
  ConsumerState<PlayerSubtitleScreen> createState() =>
      _PlayerSubtitleScreenState();
}

class _PlayerSubtitleScreenState extends ConsumerState<PlayerSubtitleScreen> {
  final _apiKeyController = TextEditingController();
  bool _autoJimaku = true;
  bool _obscureKey = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<dynamic>([
      MiningPreferences.getJimakuApiKey(),
      MiningPreferences.getAutoJimakuEnabled(),
    ]);
    if (!mounted) return;
    _apiKeyController.text = values[0] as String;
    setState(() {
      _autoJimaku = values[1] as bool;
      _loading = false;
    });
  }

  Future<void> _saveKey() async {
    await MiningPreferences.setJimakuApiKey(_apiKeyController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Jimaku API key saved')));
  }

  void _updateAppearance(
    void Function(PlayerSubtitleSettings settings) update,
  ) {
    final settings = ref.read(subtitleSettingsStateProvider);
    update(settings);
    ref.read(subtitleSettingsStateProvider.notifier).set(settings, true);
    setState(() {});
  }

  void _resetAppearance() {
    ref
        .read(subtitleSettingsStateProvider.notifier)
        .set(PlayerSubtitleSettings(), true);
    setState(() {});
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitleSettings = ref.watch(subtitleSettingsStateProvider);
    final fontSize = (subtitleSettings.fontSize ?? 45).clamp(12, 96);
    final fontWeight =
        subtitleSettings.fontWeight ??
        ((subtitleSettings.useBold ?? true) ? 700 : 400);
    final outlineThickness = effectiveSubtitleOutlineThickness(
      subtitleSettings,
    ).clamp(0, 8);
    final shadowThickness = (subtitleSettings.shadowThickness ?? 0).clamp(
      0,
      12,
    );
    final backgroundOpacity = (subtitleSettings.backgroundColorA ?? 0) / 255;
    return Scaffold(
      appBar: AppBar(title: const Text('Subtitles & Jimaku')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                const _SettingsHeader('Subtitle appearance'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 112),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SubtitleAppearancePreview(
                      settings: subtitleSettings,
                    ),
                  ),
                ),
                _AppearanceSlider(
                  title: 'Font size',
                  value: fontSize.toDouble(),
                  min: 12,
                  max: 96,
                  divisions: 84,
                  valueLabel: '${fontSize}px',
                  onChanged: (value) => _updateAppearance(
                    (settings) => settings.fontSize = value.round(),
                  ),
                ),
                _AppearanceSlider(
                  title: 'Font thickness',
                  subtitle: '100 is thin; 900 is extra bold',
                  value: fontWeight.toDouble(),
                  min: 100,
                  max: 900,
                  divisions: 8,
                  valueLabel: '$fontWeight',
                  onChanged: (value) => _updateAppearance((settings) {
                    settings.fontWeight = value.round();
                    settings.useBold = value >= 600;
                  }),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Automatic outline thickness'),
                  subtitle: const Text('Scales the outline with the font size'),
                  value: subtitleSettings.outlineThickness == null,
                  onChanged: (automatic) => _updateAppearance(
                    (settings) => settings.outlineThickness = automatic
                        ? null
                        : effectiveSubtitleOutlineThickness(settings),
                  ),
                ),
                if (subtitleSettings.outlineThickness != null)
                  _AppearanceSlider(
                    title: 'Outline thickness',
                    value: outlineThickness.toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 32,
                    valueLabel: '${outlineThickness.toStringAsFixed(2)}px',
                    onChanged: (value) => _updateAppearance(
                      (settings) => settings.outlineThickness = value,
                    ),
                  ),
                _AppearanceSlider(
                  title: 'Shadow thickness',
                  subtitle: 'Adds a soft shadow around the subtitle text',
                  value: shadowThickness.toDouble(),
                  min: 0,
                  max: 12,
                  divisions: 48,
                  valueLabel: '${shadowThickness.toStringAsFixed(2)}px',
                  onChanged: (value) => _updateAppearance(
                    (settings) => settings.shadowThickness = value,
                  ),
                ),
                _AppearanceSlider(
                  title: 'Background opacity',
                  value: backgroundOpacity,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  valueLabel: '${(backgroundOpacity * 100).round()}%',
                  onChanged: (value) => _updateAppearance(
                    (settings) =>
                        settings.backgroundColorA = (value * 255).round(),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.format_italic),
                  title: const Text('Italic subtitles'),
                  value: subtitleSettings.useItalic ?? false,
                  onChanged: (value) => _updateAppearance(
                    (settings) => settings.useItalic = value,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _resetAppearance,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset appearance'),
                    ),
                  ),
                ),
                const Divider(),
                const _SettingsHeader('Jimaku'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Jimaku API key',
                      helperText:
                          'Required to search and download Jimaku subtitles',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        tooltip: _obscureKey ? 'Show API key' : 'Hide API key',
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _saveKey(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saveKey,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.subtitles_outlined),
                  title: const Text('Load Jimaku subtitles automatically'),
                  subtitle: const Text(
                    'Search for matching subtitles when media opens',
                  ),
                  value: _autoJimaku,
                  onChanged: (value) {
                    setState(() => _autoJimaku = value);
                    MiningPreferences.setAutoJimakuEnabled(value);
                  },
                ),
              ],
            ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _AppearanceSlider extends StatelessWidget {
  const _AppearanceSlider({
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Row(
      children: [
        Expanded(child: Text(title)),
        Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtitle != null) Text(subtitle!),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
