import 'package:flutter/material.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

class PlayerSubtitleScreen extends StatefulWidget {
  const PlayerSubtitleScreen({super.key});

  @override
  State<PlayerSubtitleScreen> createState() => _PlayerSubtitleScreenState();
}

class _PlayerSubtitleScreenState extends State<PlayerSubtitleScreen> {
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

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subtitles & Jimaku')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
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
