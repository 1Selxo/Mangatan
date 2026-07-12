import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/modules/more/settings/dictionary/widgets/edit_text_dialog.dart';
import 'package:mangayomi/modules/mining/reader_lookup_trigger.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_languages.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/modules/mining/widgets/reader_ocr_overlay.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/screen_ai_ocr.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  List<InstalledDictionary> _dictionaries = const [];
  List<DictionaryProfile> _profiles = const [];
  DictionaryProfile _activeProfile = const DictionaryProfile(
    id: 'mangatan-default',
    name: 'Default',
  );
  OcrEnginePreference _engine = OcrEnginePreference.automatic;
  String _language = 'ja';
  String _dictionaryLanguage = 'ja';
  double _opacity = 0.0;
  double _boxScale = 1;
  double _boxScaleY = 1;
  bool _outlineVisible = true;
  bool _lookupOnHover = false;
  DictionaryLookupTrigger _lookupTrigger = DictionaryLookupTrigger.leftClick;
  bool _overlayEnabled = true;
  bool _screenAiAvailable = false;
  bool _loading = true;
  bool _importing = false;
  late DictionaryPopupPreferences _popupPreferences;
  AnkiMiningProfile _ankiProfile = const AnkiMiningProfile();
  AnkiAudioPreferences _ankiAudioPreferences = AnkiAudioPreferences.defaults;
  Uri _ankiEndpoint = Uri.parse('http://127.0.0.1:8765');
  int? _ankiVersion;
  List<String> _ankiDecks = const [];
  List<String> _ankiModels = const [];
  List<String> _ankiFields = const [];
  String? _ankiError;
  bool _ankiRefreshing = false;

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
      MiningPreferences.getOcrLookupOnHover(),
      MiningPreferences.getOcrOverlayEnabled(),
      MiningPreferences.getDictionaryPopupPreferences(),
      MiningPreferences.getAnkiProfile(),
      MiningPreferences.getAnkiAudioPreferences(),
      MiningPreferences.getAnkiEndpoint(),
      ScreenAiOcrClient.isAvailable(),
      MiningPreferences.getDictionaryLookupTrigger(),
      MiningPreferences.getDictionaryLanguage(),
      MiningPreferences.getDictionaryProfiles(),
      MiningPreferences.getActiveDictionaryProfile(),
    ]);
    if (!mounted) return;
    setState(() {
      _profiles = values[16] as List<DictionaryProfile>;
      _activeProfile = values[17] as DictionaryProfile;
      _dictionaries = _orderDictionaries(
        values[0] as List<InstalledDictionary>,
        _activeProfile.dictionaryOrder,
      );
      _engine = values[1] as OcrEnginePreference;
      _language = values[2] as String;
      _opacity = values[3] as double;
      _boxScale = values[4] as double;
      _boxScaleY = values[5] as double;
      _outlineVisible = values[6] as bool;
      _lookupOnHover = values[7] as bool;
      _overlayEnabled = values[8] as bool;
      _popupPreferences = values[9] as DictionaryPopupPreferences;
      _ankiProfile = values[10] as AnkiMiningProfile;
      _ankiAudioPreferences = values[11] as AnkiAudioPreferences;
      _ankiEndpoint = values[12] as Uri;
      _screenAiAvailable = values[13] as bool;
      _lookupTrigger = values[14] as DictionaryLookupTrigger;
      _dictionaryLanguage = values[15] as String;
      _loading = false;
    });
    unawaited(_refreshAnki(silent: true));
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

  Future<void> _saveDictionaryOrder(
    List<InstalledDictionary> dictionaries,
  ) async {
    final previous = _dictionaries;
    setState(() => _dictionaries = dictionaries);
    try {
      await _updateActiveProfile(
        _activeProfile.copyWith(
          dictionaryOrder: dictionaries
              .map((dictionary) => dictionary.name)
              .toList(),
        ),
      );
      await HoshidictsLookupBackend.instance.reloadFromStorage();
    } catch (error) {
      if (!mounted) return;
      setState(() => _dictionaries = previous);
      botToast('Could not reorder dictionaries: $error', second: 5);
    }
  }

  void _reorderDictionaries(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final dictionaries = [..._dictionaries];
    final moved = dictionaries.removeAt(oldIndex);
    dictionaries.insert(newIndex, moved);
    unawaited(_saveDictionaryOrder(dictionaries));
  }

  Future<void> _moveDictionary(int index, int offset) async {
    final target = index + offset;
    if (target < 0 || target >= _dictionaries.length || target == index) {
      return;
    }
    final dictionaries = [..._dictionaries];
    final moved = dictionaries.removeAt(index);
    dictionaries.insert(target, moved);
    await _saveDictionaryOrder(dictionaries);
  }

  Future<String?> _editText({
    required String title,
    required String value,
    String? hint,
    int maxLines = 1,
  }) {
    return showEditTextDialog(
      context: context,
      title: title,
      initialValue: value,
      hint: hint,
      maxLines: maxLines,
    );
  }

  Future<void> _saveAnki(AnkiMiningProfile profile) async {
    setState(() {
      _ankiProfile = profile;
      _activeProfile = _activeProfile.copyWith(anki: profile);
    });
    await MiningPreferences.setAnkiProfile(profile);
  }

  List<InstalledDictionary> _orderDictionaries(
    List<InstalledDictionary> dictionaries,
    List<String> order,
  ) {
    if (order.isEmpty) return dictionaries;
    final byName = {
      for (final dictionary in dictionaries) dictionary.name: dictionary,
    };
    return [for (final name in order) ?byName.remove(name), ...byName.values];
  }

  Future<void> _updateActiveProfile(DictionaryProfile profile) async {
    await MiningPreferences.updateDictionaryProfile(profile);
    if (!mounted) return;
    setState(() {
      _activeProfile = profile;
      _profiles = [
        for (final item in _profiles) item.id == profile.id ? profile : item,
      ];
    });
  }

  Future<void> _activateProfile(DictionaryProfile profile) async {
    if (profile.id == _activeProfile.id) return;
    await MiningPreferences.setActiveDictionaryProfile(profile.id);
    HoshidictsLookupBackend.instance.clearSession();
    await _load();
  }

  Future<void> _createProfile() async {
    final name = await _editText(
      title: 'New profile',
      value: '${_activeProfile.name} copy',
      hint: 'Profile name',
    );
    if (name == null || name.trim().isEmpty) return;
    final profile = _activeProfile.copyWith(
      id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
    );
    await MiningPreferences.addDictionaryProfile(profile);
    HoshidictsLookupBackend.instance.clearSession();
    await _load();
  }

  Future<void> _renameActiveProfile() async {
    final name = await _editText(
      title: 'Rename profile',
      value: _activeProfile.name,
      hint: 'Profile name',
    );
    if (name == null || name.trim().isEmpty) return;
    await _updateActiveProfile(_activeProfile.copyWith(name: name.trim()));
  }

  Future<void> _deleteActiveProfile() async {
    if (_profiles.length <= 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text(_activeProfile.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await MiningPreferences.deleteDictionaryProfile(_activeProfile.id);
    HoshidictsLookupBackend.instance.clearSession();
    await _load();
  }

  Future<void> _toggleDictionary(String name, bool enabled) async {
    var enabledNames = _activeProfile.enabledDictionaries.isEmpty
        ? _dictionaries.map((dictionary) => dictionary.name).toSet()
        : {..._activeProfile.enabledDictionaries};
    enabled ? enabledNames.add(name) : enabledNames.remove(name);
    if (enabledNames.length == _dictionaries.length) enabledNames = {};
    await _updateActiveProfile(
      _activeProfile.copyWith(enabledDictionaries: enabledNames),
    );
    await HoshidictsLookupBackend.instance.reloadFromStorage();
  }

  Future<void> _saveAnkiAudio(AnkiAudioPreferences preferences) async {
    setState(() => _ankiAudioPreferences = preferences);
    await MiningPreferences.setAnkiAudioPreferences(preferences);
  }

  Future<void> _refreshAnki({bool silent = false}) async {
    if (_ankiRefreshing) return;
    setState(() {
      _ankiRefreshing = true;
      _ankiError = null;
    });
    try {
      final service = AnkiConnectService(endpoint: _ankiEndpoint);
      final version = await service.version();
      final decks = await service.deckNames();
      final models = await service.modelNames();
      final selectedModel = _ankiProfile.modelName.trim().isNotEmpty
          ? _ankiProfile.modelName
          : (models.isEmpty ? '' : models.first);
      final fields = selectedModel.trim().isEmpty
          ? <String>[]
          : await service.modelFieldNames(selectedModel);
      final isLapis = _isLapisLike(selectedModel, fields);
      final needsLapisMigration = isLapis && _needsLapisMigration();
      final profile =
          fields.isNotEmpty &&
              (!_fieldMapMatches(fields) || needsLapisMigration)
          ? _ankiProfile.copyWith(
              fieldMap: _autoMapFields(
                fields,
                needsLapisMigration ? const {} : _ankiProfile.fieldMap,
                isLapis: isLapis,
              ),
            )
          : _ankiProfile;
      if (!identical(profile, _ankiProfile)) {
        await MiningPreferences.setAnkiProfile(profile);
      }
      if (!mounted) return;
      setState(() {
        _ankiProfile = profile;
        _ankiVersion = version;
        _ankiDecks = decks;
        _ankiModels = models;
        _ankiFields = fields;
      });
      if (!silent) botToast('Connected to AnkiConnect v$version', second: 3);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ankiVersion = null;
        _ankiDecks = const [];
        _ankiModels = const [];
        _ankiFields = const [];
        _ankiError = error.toString();
      });
      if (!silent) botToast('AnkiConnect failed: $error', second: 5);
    } finally {
      if (mounted) setState(() => _ankiRefreshing = false);
    }
  }

  Future<void> _selectAnkiModel(String modelName) async {
    var fields = <String>[];
    try {
      fields = await AnkiConnectService(
        endpoint: _ankiEndpoint,
      ).modelFieldNames(modelName);
    } catch (error) {
      botToast('Could not fetch fields: $error', second: 5);
    }
    final isLapis = _isLapisLike(modelName, fields);
    final profile = _ankiProfile.copyWith(
      modelName: modelName,
      fieldMap: _autoMapFields(
        fields,
        isLapis ? const {} : _ankiProfile.fieldMap,
        isLapis: isLapis,
      ),
    );
    if (!mounted) return;
    setState(() => _ankiFields = fields);
    await _saveAnki(profile);
  }

  Map<String, String> _autoMapFields(
    List<String> fields,
    Map<String, String> current, {
    bool isLapis = false,
  }) {
    if (fields.isEmpty) return current;
    return {
      for (final indexed in fields.indexed)
        indexed.$2:
            current[indexed.$2] ??
            AnkiMarker.autoDetectTemplate(
              indexed.$2,
              indexed.$1,
              isLapis: isLapis,
            ) ??
            '',
    };
  }

  bool _fieldMapMatches(List<String> fields) {
    final fieldSet = fields.toSet();
    return _ankiProfile.fieldMap.keys.any(fieldSet.contains);
  }

  bool _isLapisLike(String modelName, List<String> fields) {
    final names = fields.map((field) => field.toLowerCase()).toSet();
    return modelName.toLowerCase().contains('lapis') ||
        names.containsAll({'expression', 'maindefinition', 'sentence'});
  }

  bool _needsLapisMigration() {
    final map = _ankiProfile.fieldMap;
    return map['ExpressionFurigana'] == AnkiMarker.furigana ||
        map['DefinitionPicture'] == AnkiMarker.screenshot ||
        map['IsWordAndSentenceCard'] != 'x';
  }

  Future<void> _editAnkiFieldMap() async {
    final fields = _ankiFields.isNotEmpty
        ? _ankiFields
        : _ankiProfile.fieldMap.keys.toList();
    if (fields.isEmpty) {
      botToast('Connect to Anki first to fetch note fields', second: 4);
      return;
    }
    final dictionaryTemplates =
        AnkiMarker.singleGlossaryTemplatesForDictionaries(
          _dictionaries
              .where((dictionary) => dictionary.hasTerms)
              .map((dictionary) => dictionary.name),
        );
    final isLapis = _isLapisLike(_ankiProfile.modelName, fields);
    var map = _autoMapFields(fields, _ankiProfile.fieldMap, isLapis: isLapis);
    final saved = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Anki field templates'),
              content: SizedBox(
                width: 560,
                height: 520,
                child: ListView.separated(
                  itemCount: fields.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    final value = map[field] ?? '';
                    return _AnkiFieldTemplatePicker(
                      fieldName: field,
                      value: value,
                      dynamicTemplates: dictionaryTemplates,
                      onChanged: (next) {
                        setDialogState(() => map = {...map, field: next});
                      },
                      onEditCustom: () async {
                        final next = await _editText(
                          title: field,
                          value: value,
                          hint: AnkiMarker.expression,
                          maxLines: 4,
                        );
                        if (next == null) return;
                        setDialogState(() => map = {...map, field: next});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(
                      () => map = _autoMapFields(
                        fields,
                        const {},
                        isLapis: isLapis,
                      ),
                    );
                  },
                  child: const Text('Auto map'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, map),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == null) return;
    await _saveAnki(_ankiProfile.copyWith(fieldMap: saved));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictionary & OCR')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const _SectionHeader('Profiles'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final profile in _profiles) ...[
                                ChoiceChip(
                                  label: Text(profile.name),
                                  selected: profile.id == _activeProfile.id,
                                  onSelected: (_) => _activateProfile(profile),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ActionChip(
                                avatar: const Icon(Icons.add, size: 18),
                                label: const Text('Clone'),
                                onPressed: _createProfile,
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Profile actions',
                        onSelected: (action) {
                          if (action == 'rename') _renameActiveProfile();
                          if (action == 'delete') _deleteActiveProfile();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Rename'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            enabled: _profiles.length > 1,
                            child: const ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text('Active: ${_activeProfile.name}'),
                  subtitle: const Text(
                    'Language, dictionary priority, enabled dictionaries, and Anki settings are saved per profile.',
                  ),
                ),
                const Divider(height: 24),
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
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _dictionaries.length,
                    onReorderItem: _reorderDictionaries,
                    itemBuilder: (context, index) {
                      final dictionary = _dictionaries[index];
                      return _DictionaryListTile(
                        key: ValueKey(dictionary.name),
                        dictionary: dictionary,
                        index: index,
                        canMoveUp: index > 0,
                        canMoveDown: index < _dictionaries.length - 1,
                        enabled: _activeProfile.isDictionaryEnabled(
                          dictionary.name,
                        ),
                        onEnabledChanged: (enabled) =>
                            _toggleDictionary(dictionary.name, enabled),
                        onMoveUp: () => _moveDictionary(index, -1),
                        onMoveDown: () => _moveDictionary(index, 1),
                        onDelete: () => _deleteDictionary(dictionary),
                      );
                    },
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
                const _SectionHeader('Lookup behavior'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _dictionaryLanguage,
                    decoration: const InputDecoration(
                      labelText: 'Dictionary language',
                      helperText:
                          'Controls word parsing and deinflection during lookup',
                      prefixIcon: Icon(Icons.translate),
                    ),
                    items: [
                      for (final language in dictionaryLanguages)
                        DropdownMenuItem(
                          value: language.code,
                          child: Text(language.name),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _dictionaryLanguage = value);
                      await MiningPreferences.setDictionaryLanguage(value);
                      await _updateActiveProfile(
                        _activeProfile.copyWith(languageCode: value),
                      );
                      HoshidictsLookupBackend.instance.invalidateLookups();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<DictionaryLookupTrigger>(
                    initialValue: _lookupTrigger,
                    decoration: const InputDecoration(
                      labelText: 'Lookup trigger',
                      helperText:
                          'Used in manga and EPUB readers when hover lookup is off',
                      prefixIcon: Icon(Icons.mouse_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DictionaryLookupTrigger.leftClick,
                        child: Text('Left click'),
                      ),
                      DropdownMenuItem(
                        value: DictionaryLookupTrigger.shift,
                        child: Text('Hold Shift'),
                      ),
                      DropdownMenuItem(
                        value: DictionaryLookupTrigger.middleClick,
                        child: Text('Hold middle click'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _lookupTrigger = value);
                      unawaited(ReaderLookupTriggerState.setTrigger(value));
                    },
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
                        child: Text(
                          'Automatic (Mokuro, ScreenAI, Google Lens)',
                        ),
                      ),
                      DropdownMenuItem(
                        value: OcrEnginePreference.screenAi,
                        child: Text('ScreenAI (local Chrome)'),
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
                ListTile(
                  leading: Icon(
                    _screenAiAvailable
                        ? Icons.offline_bolt_outlined
                        : Icons.download_for_offline_outlined,
                  ),
                  title: const Text('ScreenAI OCR'),
                  subtitle: Text(
                    _screenAiAvailable
                        ? 'Local Chrome ScreenAI component detected. Runs on device.'
                        : 'Local Chrome ScreenAI component was not detected.',
                  ),
                ),
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
                  min: 0,
                  max: 1,
                  divisions: 20,
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
                    unawaited(ReaderOcrState.setOutlineVisible(value));
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.mouse),
                  title: const Text('Lookup OCR text on hover'),
                  subtitle: const Text(
                    'Open dictionary popups by hovering OCR text instead of tapping it',
                  ),
                  value: _lookupOnHover,
                  onChanged: (value) {
                    setState(() => _lookupOnHover = value);
                    unawaited(ReaderOcrState.setLookupOnHover(value));
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
                const _SectionHeader('Anki audio'),
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Add word audio'),
                  subtitle: const Text(
                    'Fills {word-audio} with the first audio source match',
                  ),
                  value: _ankiAudioPreferences.enabled,
                  onChanged: (value) => _saveAnkiAudio(
                    _ankiAudioPreferences.copyWith(enabled: value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<AnkiSentenceAudioFormat>(
                    initialValue: _ankiProfile.sentenceAudioFormat,
                    decoration: const InputDecoration(
                      labelText: 'Sentence audio format',
                      prefixIcon: Icon(Icons.record_voice_over_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AnkiSentenceAudioFormat.mp3,
                        child: Text('MP3'),
                      ),
                      DropdownMenuItem(
                        value: AnkiSentenceAudioFormat.opus,
                        child: Text('Opus'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _saveAnki(
                        _ankiProfile.copyWith(sentenceAudioFormat: value),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<AnkiAudioSourceType>(
                    initialValue: _ankiAudioPreferences.sourceType,
                    decoration: const InputDecoration(
                      labelText: 'Audio source type',
                      prefixIcon: Icon(Icons.graphic_eq_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AnkiAudioSourceType.customJson,
                        child: Text('Custom URL (JSON)'),
                      ),
                      DropdownMenuItem(
                        value: AnkiAudioSourceType.customUrl,
                        child: Text('Custom URL'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _saveAnkiAudio(
                        _ankiAudioPreferences.copyWith(sourceType: value),
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.link_outlined),
                  title: const Text('Audio source URL'),
                  subtitle: Text(
                    _ankiAudioPreferences.url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () async {
                    final value = await _editText(
                      title: 'Audio source URL',
                      value: _ankiAudioPreferences.url,
                      hint: AnkiAudioPreferences.defaultUrl,
                      maxLines: 3,
                    );
                    if (value == null || value.trim().isEmpty) return;
                    await _saveAnkiAudio(
                      _ankiAudioPreferences.copyWith(url: value.trim()),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _ankiAudioPreferences.language,
                    decoration: const InputDecoration(
                      labelText: 'Audio language',
                      prefixIcon: Icon(Icons.language_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                      DropdownMenuItem(value: 'ko', child: Text('Korean')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _saveAnkiAudio(
                        _ankiAudioPreferences.copyWith(language: value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                _SliderSetting(
                  title: 'Audio timeout',
                  value: _ankiAudioPreferences.timeout.inMilliseconds
                      .toDouble(),
                  min: 1000,
                  max: 15000,
                  divisions: 14,
                  label:
                      '${(_ankiAudioPreferences.timeout.inMilliseconds / 1000).round()} s',
                  onChanged: (value) {
                    _saveAnkiAudio(
                      _ankiAudioPreferences.copyWith(
                        timeout: Duration(milliseconds: value.round()),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
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
                    await _refreshAnki();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _ankiVersion == null
                        ? Icons.cloud_off_outlined
                        : Icons.check_circle_outline,
                  ),
                  title: Text(
                    _ankiVersion == null
                        ? 'AnkiConnect not connected'
                        : 'AnkiConnect v$_ankiVersion',
                  ),
                  subtitle: Text(
                    _ankiError ??
                        (_ankiFields.isEmpty
                            ? 'Refresh to fetch decks, note types, and fields.'
                            : '${_ankiDecks.length} decks, ${_ankiModels.length} note types, ${_ankiFields.length} fields fetched.'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _ankiRefreshing
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          tooltip: 'Refresh from Anki',
                          onPressed: () => _refreshAnki(),
                          icon: const Icon(Icons.refresh),
                        ),
                ),
                if (_ankiDecks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _ankiDecks.contains(_ankiProfile.deckName)
                          ? _ankiProfile.deckName
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Deck',
                        prefixIcon: Icon(Icons.style_outlined),
                      ),
                      hint: Text(_ankiProfile.deckName),
                      items: [
                        for (final deck in _ankiDecks)
                          DropdownMenuItem(value: deck, child: Text(deck)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _saveAnki(_ankiProfile.copyWith(deckName: value));
                      },
                    ),
                  )
                else
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
                const SizedBox(height: 12),
                if (_ankiModels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _ankiModels.contains(_ankiProfile.modelName)
                          ? _ankiProfile.modelName
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Note type',
                        prefixIcon: Icon(Icons.view_agenda_outlined),
                      ),
                      hint: Text(_ankiProfile.modelName),
                      items: [
                        for (final model in _ankiModels)
                          DropdownMenuItem(value: model, child: Text(model)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        _selectAnkiModel(value);
                      },
                    ),
                  )
                else
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
                      await _refreshAnki(silent: true);
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
                      hint: 'mangatan manga',
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
                    _ankiFields.isEmpty
                        ? '${_ankiProfile.fieldMap.length} fields configured'
                        : '${_ankiFields.length} fetched fields, ${_ankiProfile.fieldMap.length} mapped',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _editAnkiFieldMap,
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

class _DictionaryListTile extends StatelessWidget {
  const _DictionaryListTile({
    super.key,
    required this.dictionary,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final InstalledDictionary dictionary;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final capabilities = [
      if (dictionary.hasTerms) 'Terms',
      if (dictionary.hasFrequencies) 'Frequency',
      if (dictionary.hasPitch) 'Pitch',
    ];
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Tooltip(
              message: 'Drag to reorder dictionary',
              child: Icon(Icons.drag_indicator),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.menu_book_outlined),
        ],
      ),
      title: Text(
        dictionary.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        capabilities.isEmpty ? 'No lookup data' : capabilities.join(' • '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: enabled, onChanged: onEnabledChanged),
          IconButton(
            tooltip: 'Move dictionary up',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: 'Move dictionary down',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          IconButton(
            tooltip: 'Remove dictionary',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _AnkiFieldTemplatePicker extends StatelessWidget {
  const _AnkiFieldTemplatePicker({
    required this.fieldName,
    required this.value,
    required this.dynamicTemplates,
    required this.onChanged,
    required this.onEditCustom,
  });

  final String fieldName;
  final String value;
  final Map<String, String> dynamicTemplates;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditCustom;

  @override
  Widget build(BuildContext context) {
    final templates = <String, String>{
      'Leave empty': '',
      ...AnkiMarker.standardTemplates,
      ...dynamicTemplates,
    };
    final isStandard = templates.containsValue(value);
    final items = <DropdownMenuItem<String>>[
      if (!isStandard && value.trim().isNotEmpty)
        DropdownMenuItem(value: value, child: Text('Custom: $value')),
      for (final entry in templates.entries)
        DropdownMenuItem(value: entry.value, child: Text(entry.key)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              fieldName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Template'),
            items: items,
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
        IconButton(
          tooltip: 'Edit custom template',
          onPressed: onEditCustom,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
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
