import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  List<InstalledDictionary> _dictionaries = const [];
  OcrEnginePreference _engine = OcrEnginePreference.automatic;
  String _language = 'ja';
  double _opacity = 0.72;
  double _boxScale = 1;
  bool _outlineVisible = true;
  bool _overlayEnabled = true;
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<dynamic>([
      DictionaryStorage.instance.installed(),
      MiningPreferences.getOcrEngine(),
      MiningPreferences.getOcrLanguage(),
      MiningPreferences.getOcrOverlayOpacity(),
      MiningPreferences.getOcrBoxScale(),
      MiningPreferences.getOcrOutlineVisible(),
      MiningPreferences.getOcrOverlayEnabled(),
    ]);
    if (!mounted) return;
    setState(() {
      _dictionaries = values[0] as List<InstalledDictionary>;
      _engine = values[1] as OcrEnginePreference;
      _language = values[2] as String;
      _opacity = values[3] as double;
      _boxScale = values[4] as double;
      _outlineVisible = values[5] as bool;
      _overlayEnabled = values[6] as bool;
      _loading = false;
    });
  }

  Future<void> _importDictionary() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final root = await DictionaryStorage.instance.rootDirectory;
      final imported = await HoshidictsLookupBackend.instance.importDictionary(
        zipPath: path,
        outputDir: root.path,
      );
      if (!imported.success) {
        throw StateError(imported.errors.join('\n'));
      }
      await DictionaryStorage.instance.recordImport(
        name: imported.title,
        termCount: imported.termCount,
        frequencyCount: imported.freqCount,
        pitchCount: imported.pitchCount,
      );
      await HoshidictsLookupBackend.instance.reloadFromStorage();
      await _load();
      botToast(
        'Imported ${imported.title} (${imported.termCount} terms)',
        second: 4,
      );
    } catch (error) {
      botToast('Dictionary import failed: $error', second: 5);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteDictionary(InstalledDictionary dictionary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove dictionary?'),
        content: Text(dictionary.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DictionaryStorage.instance.delete(dictionary.name);
    await HoshidictsLookupBackend.instance.reloadFromStorage();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary & OCR')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader('Dictionaries'),
                ListTile(
                  leading: const Icon(Icons.archive_outlined),
                  title: const Text('Import Yomitan dictionary'),
                  subtitle: const Text('Select a Yomitan-format ZIP file'),
                  trailing: _importing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  onTap: _importing ? null : _importDictionary,
                ),
                if (_dictionaries.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.menu_book_outlined),
                    title: Text('No dictionaries installed'),
                    subtitle: Text(
                      'Import at least one term dictionary for native lookup.',
                    ),
                  )
                else
                  for (final dictionary in _dictionaries)
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(dictionary.name),
                      subtitle: Text(
                        [
                          if (dictionary.hasTerms) 'Terms',
                          if (dictionary.hasFrequencies) 'Frequency',
                          if (dictionary.hasPitch) 'Pitch',
                        ].join(' • '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove dictionary',
                        onPressed: () => _deleteDictionary(dictionary),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                const Divider(height: 24),
                const _SectionHeader('OCR overlay'),
                SwitchListTile(
                  secondary: const Icon(Icons.document_scanner_outlined),
                  title: const Text('Show OCR in reader'),
                  subtitle: const Text(
                    'Recognize pages automatically as they load',
                  ),
                  value: _overlayEnabled,
                  onChanged: (value) {
                    setState(() => _overlayEnabled = value);
                    ReaderOcrState.setEnabled(value);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<OcrEnginePreference>(
                    initialValue: _engine,
                    decoration: const InputDecoration(
                      labelText: 'OCR engine',
                      prefixIcon: Icon(Icons.document_scanner_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: OcrEnginePreference.automatic,
                        child: Text('Automatic (Mokuro, then Google Lens)'),
                      ),
                      DropdownMenuItem(
                        value: OcrEnginePreference.googleLens,
                        child: Text('Google Lens'),
                      ),
                      DropdownMenuItem(
                        value: OcrEnginePreference.mokuroOnly,
                        child: Text('Mokuro only'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _engine = value);
                      await MiningPreferences.setOcrEngine(value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: const InputDecoration(
                      labelText: 'OCR language',
                      prefixIcon: Icon(Icons.translate),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                      DropdownMenuItem(value: 'ko', child: Text('Korean')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _language = value);
                      await MiningPreferences.setOcrLanguage(value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _SliderSetting(
                  title: 'Text overlay opacity',
                  value: _opacity,
                  min: 0.1,
                  max: 1,
                  divisions: 18,
                  label: '${(_opacity * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _opacity = value);
                    MiningPreferences.setOcrOverlayOpacity(value);
                  },
                ),
                _SliderSetting(
                  title: 'OCR box scale',
                  value: _boxScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 14,
                  label: '${(_boxScale * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _boxScale = value);
                    MiningPreferences.setOcrBoxScale(value);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.border_style),
                  title: const Text('Show OCR box outlines'),
                  value: _outlineVisible,
                  onChanged: (value) {
                    setState(() => _outlineVisible = value);
                    MiningPreferences.setOcrOutlineVisible(value);
                  },
                ),
                const ListTile(
                  leading: Icon(Icons.cloud_outlined),
                  title: Text('Google Lens OCR'),
                  subtitle: Text(
                    'Uses Chromium’s Lens endpoint. Page images are sent to Google when this engine runs.',
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
      trailing: SizedBox(
        width: 48,
        child: Text(label, textAlign: TextAlign.end),
      ),
    );
  }
}
