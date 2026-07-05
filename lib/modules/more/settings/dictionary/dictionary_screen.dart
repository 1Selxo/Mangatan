import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';

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
  double _boxScaleY = 1;
  bool _outlineVisible = true;
  bool _overlayEnabled = true;
  bool _loading = true;
  bool _importing = false;
  late DictionaryPopupPreferences _popupPreferences;
  AnkiMiningProfile _ankiProfile = const AnkiMiningProfile();
  Uri _ankiEndpoint = Uri.parse('http://127.0.0.1:8765');

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
      MiningPreferences.getOcrBoxScaleX(),
      MiningPreferences.getOcrBoxScaleY(),
      MiningPreferences.getOcrOutlineVisible(),
      MiningPreferences.getOcrOverlayEnabled(),
      MiningPreferences.getDictionaryPopupPreferences(),
      MiningPreferences.getAnkiProfile(),
      MiningPreferences.getAnkiEndpoint(),
    ]);
    if (!mounted) return;
    setState(() {
      _dictionaries = values[0] as List<InstalledDictionary>;
      _engine = values[1] as OcrEnginePreference;
      _language = values[2] as String;
      _opacity = values[3] as double;
      _boxScale = values[4] as double;
      _boxScaleY = values[5] as double;
      _outlineVisible = values[6] as bool;
      _overlayEnabled = values[7] as bool;
      _popupPreferences = values[8] as DictionaryPopupPreferences;
      _ankiProfile = values[9] as AnkiMiningProfile;
      _ankiEndpoint = values[10] as Uri;
      _loading = false;
    });
  }

  Future<void> _importDictionary() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: true,
    );
    final paths =
        result?.files.map((file) => file.path).nonNulls.toList() ?? [];
    if (paths.isEmpty || !mounted) return;
    setState(() => _importing = true);
    try {
      final root = await DictionaryStorage.instance.rootDirectory;
      final importedNames = <String>[];
      for (final path in paths) {
        final imported = await HoshidictsLookupBackend.instance
            .importDictionary(zipPath: path, outputDir: root.path);
        if (!imported.success) {
          throw StateError(imported.errors.join('\n'));
        }
        await DictionaryStorage.instance.recordImport(
          name: imported.title,
          termCount: imported.termCount,
          frequencyCount: imported.freqCount,
          pitchCount: imported.pitchCount,
        );
        importedNames.add(imported.title);
      }
      await HoshidictsLookupBackend.instance.reloadFromStorage();
      await _load();
      botToast('Imported ${importedNames.join(', ')}', second: 4);
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

  Future<String?> _editText({
    required String title,
    required String value,
    String? hint,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _saveAnki(AnkiMiningProfile profile) async {
    setState(() => _ankiProfile = profile);
    await MiningPreferences.setAnkiProfile(profile);
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
                const _SectionHeader('Popup appearance'),
                _SliderSetting(
                  title: 'Popup width',
                  value: _popupPreferences.width,
                  min: 280,
                  max: 720,
                  divisions: 22,
                  label: '${_popupPreferences.width.round()} px',
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        width: value,
                      );
                    });
                    MiningPreferences.setDictionaryPopupWidth(value);
                  },
                ),
                _SliderSetting(
                  title: 'Popup height',
                  value: _popupPreferences.height,
                  min: 240,
                  max: 720,
                  divisions: 24,
                  label: '${_popupPreferences.height.round()} px',
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        height: value,
                      );
                    });
                    MiningPreferences.setDictionaryPopupHeight(value);
                  },
                ),
                _SliderSetting(
                  title: 'Dictionary font size',
                  value: _popupPreferences.fontSize,
                  min: 11,
                  max: 24,
                  divisions: 13,
                  label: '${_popupPreferences.fontSize.round()} px',
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        fontSize: value,
                      );
                    });
                    MiningPreferences.setDictionaryFontSize(value);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<DictionaryThemePreference>(
                    initialValue: _popupPreferences.theme,
                    decoration: const InputDecoration(
                      labelText: 'Dictionary theme',
                      prefixIcon: Icon(Icons.contrast),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DictionaryThemePreference.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: DictionaryThemePreference.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: DictionaryThemePreference.dark,
                        child: Text('Dark'),
                      ),
                      DropdownMenuItem(
                        value: DictionaryThemePreference.black,
                        child: Text('Pure black'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _popupPreferences = _popupPreferences.copyWith(
                          theme: value,
                        );
                      });
                      MiningPreferences.setDictionaryTheme(value);
                    },
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.format_paint_outlined),
                  title: const Text('E-Ink mode'),
                  subtitle: const Text(
                    'Removes popup shadows and rounded corners',
                  ),
                  value: _popupPreferences.eInkMode,
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        eInkMode: value,
                      );
                    });
                    MiningPreferences.setDictionaryEInkMode(value);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.view_carousel_outlined),
                  title: const Text('Paginated scrolling'),
                  value: _popupPreferences.paginatedScrolling,
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        paginatedScrolling: value,
                      );
                    });
                    MiningPreferences.setDictionaryPaginatedScrolling(value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.css_outlined),
                  title: const Text('Custom CSS'),
                  subtitle: Text(
                    _popupPreferences.customCss.trim().isEmpty
                        ? 'Add CSS after dictionary styles'
                        : 'Custom CSS configured',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'Custom dictionary CSS',
                      value: _popupPreferences.customCss,
                      hint: '.gloss-sc-li { color: red; }',
                      maxLines: 12,
                    );
                    if (value == null) return;
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        customCss: value,
                      );
                    });
                    await MiningPreferences.setDictionaryCustomCss(value);
                  },
                ),
                const Divider(height: 24),
                const _SectionHeader('Dictionary display'),
                SwitchListTile(
                  title: const Text('Show harmonic frequency'),
                  value: _popupPreferences.showFrequencyHarmonic,
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        showFrequencyHarmonic: value,
                      );
                    });
                    MiningPreferences.setShowFrequencyHarmonic(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show average frequency'),
                  value: _popupPreferences.showFrequencyAverage,
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        showFrequencyAverage: value,
                      );
                    });
                    MiningPreferences.setShowFrequencyAverage(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show pitch positions'),
                  value: _popupPreferences.showPitchNumber,
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        showPitchNumber: value,
                      );
                    });
                    MiningPreferences.setShowPitchNumber(value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Show pitch transcriptions'),
                  value: _popupPreferences.showPitchText,
                  onChanged: (value) {
                    setState(() {
                      _popupPreferences = _popupPreferences.copyWith(
                        showPitchText: value,
                      );
                    });
                    MiningPreferences.setShowPitchText(value);
                  },
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
                  title: 'OCR box width',
                  value: _boxScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 14,
                  label: '${(_boxScale * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _boxScale = value);
                    MiningPreferences.setOcrBoxScaleX(value);
                  },
                ),
                _SliderSetting(
                  title: 'OCR box height',
                  value: _boxScaleY,
                  min: 0.8,
                  max: 1.5,
                  divisions: 14,
                  label: '${(_boxScaleY * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _boxScaleY = value);
                    MiningPreferences.setOcrBoxScaleY(value);
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
                const Divider(height: 24),
                const _SectionHeader('AnkiConnect'),
                SwitchListTile(
                  secondary: const Icon(Icons.note_add_outlined),
                  title: const Text('Enable Anki export'),
                  value: _ankiProfile.ankiEnabled,
                  onChanged: (value) =>
                      _saveAnki(_ankiProfile.copyWith(ankiEnabled: value)),
                ),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text('AnkiConnect address'),
                  subtitle: Text(_ankiEndpoint.toString()),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'AnkiConnect address',
                      value: _ankiEndpoint.toString(),
                      hint: 'http://127.0.0.1:8765',
                    );
                    final endpoint = value == null
                        ? null
                        : Uri.tryParse(value.trim());
                    if (endpoint == null || !endpoint.hasScheme) return;
                    setState(() => _ankiEndpoint = endpoint);
                    await MiningPreferences.setAnkiEndpoint(endpoint);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.style_outlined),
                  title: const Text('Deck'),
                  subtitle: Text(_ankiProfile.deckName),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'Anki deck',
                      value: _ankiProfile.deckName,
                    );
                    if (value?.trim().isEmpty ?? true) return;
                    await _saveAnki(
                      _ankiProfile.copyWith(deckName: value!.trim()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.view_agenda_outlined),
                  title: const Text('Note type'),
                  subtitle: Text(_ankiProfile.modelName),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'Anki note type',
                      value: _ankiProfile.modelName,
                    );
                    if (value?.trim().isEmpty ?? true) return;
                    await _saveAnki(
                      _ankiProfile.copyWith(modelName: value!.trim()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('Default tags'),
                  subtitle: Text(_ankiProfile.tags.join(' ')),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'Default tags',
                      value: _ankiProfile.tags.join(' '),
                      hint: 'mangayomi manga',
                    );
                    if (value == null) return;
                    await _saveAnki(
                      _ankiProfile.copyWith(
                        tags: value
                            .split(RegExp(r'[\s,]+'))
                            .where((tag) => tag.isNotEmpty)
                            .toList(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.data_object),
                  title: const Text('Field templates'),
                  subtitle: Text(
                    '${_ankiProfile.fieldMap.length} fields configured',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'Anki field templates (JSON)',
                      value: const JsonEncoder.withIndent(
                        '  ',
                      ).convert(_ankiProfile.fieldMap),
                      maxLines: 14,
                    );
                    if (value == null) return;
                    try {
                      final decoded = jsonDecode(value);
                      if (decoded is! Map) throw const FormatException();
                      await _saveAnki(
                        _ankiProfile.copyWith(
                          fieldMap: decoded.map(
                            (key, value) =>
                                MapEntry(key.toString(), value.toString()),
                          ),
                        ),
                      );
                    } on FormatException {
                      botToast(
                        'Field templates must be a JSON object',
                        second: 4,
                      );
                    }
                  },
                ),
                SwitchListTile(
                  title: const Text('Check for duplicates'),
                  value: _ankiProfile.duplicateCheck,
                  onChanged: (value) =>
                      _saveAnki(_ankiProfile.copyWith(duplicateCheck: value)),
                ),
                SwitchListTile(
                  title: const Text('Sync after adding a note'),
                  value: _ankiProfile.syncOnCreate,
                  onChanged: (value) =>
                      _saveAnki(_ankiProfile.copyWith(syncOnCreate: value)),
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
