import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/modules/mining/widgets/hoshi_dictionary_popup.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/services/hoshidicts/dictionary_storage.dart';
import 'package:mangayomi/services/mining/anki_markers.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

@visibleForTesting
bool dictionaryLookupUsesNativeRenderer(TargetPlatform platform) =>
    platform == TargetPlatform.linux;

class DictionaryLookupScreen extends StatefulWidget {
  const DictionaryLookupScreen({super.key, this.dataLoader});

  @visibleForTesting
  final Future<DictionaryLookupData> Function()? dataLoader;

  @override
  State<DictionaryLookupScreen> createState() => _DictionaryLookupScreenState();
}

class _DictionaryLookupScreenState extends State<DictionaryLookupScreen> {
  static const _searchDebounce = Duration(milliseconds: 275);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _popupController = HoshiDictionaryPopupController();

  late Future<DictionaryLookupData> _data;
  Timer? _debounce;
  String _lookupText = '';
  int _lookupRevision = 0;
  bool _loading = false;
  HoshiDictionaryNavigationState _navigation =
      HoshiDictionaryNavigationState.empty;

  static Future<DictionaryLookupData> _loadDefaultData() async {
    final values = await Future.wait<dynamic>([
      DictionaryStorage.instance.installed(),
      MiningPreferences.getDictionaryPopupPreferences(),
      MiningPreferences.getAnkiProfile(),
    ]);
    return DictionaryLookupData(
      dictionaries: values[0] as List<InstalledDictionary>,
      preferences: values[1] as DictionaryPopupPreferences,
      ankiProfile: values[2] as AnkiMiningProfile,
    );
  }

  Future<DictionaryLookupData> _loadData() =>
      widget.dataLoader?.call() ?? _loadDefaultData();

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () => _commitLookup(value));
  }

  void _submitLookup([String? value]) {
    _debounce?.cancel();
    _commitLookup(value ?? _controller.text, force: true);
  }

  void _commitLookup(String value, {bool force = false}) {
    final query = value.trim();
    if (!mounted || (query == _lookupText && !force)) return;
    setState(() {
      _lookupText = query;
      if (force) _lookupRevision++;
      _loading = query.isNotEmpty && !_usesNativeRenderer;
      _navigation = HoshiDictionaryNavigationState.empty;
    });
  }

  bool get _usesNativeRenderer =>
      dictionaryLookupUsesNativeRenderer(defaultTargetPlatform);

  void _clearLookup() {
    _debounce?.cancel();
    _controller.clear();
    _commitLookup('');
    _focusNode.requestFocus();
  }

  Future<void> _openDictionarySettings() async {
    await context.push('/dictionary');
    if (!mounted) return;
    setState(() => _data = _loadData());
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dictionary_lookup),
        actions: [
          IconButton(
            tooltip: l10n.dictionary_settings,
            onPressed: _openDictionarySettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _DictionarySearchField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onQueryChanged,
                    onSubmitted: _submitLookup,
                    onClear: _clearLookup,
                  ),
                  Expanded(
                    child: FutureBuilder<DictionaryLookupData>(
                      future: _data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return _DictionaryMessage(
                            icon: Icons.error_outline,
                            title: l10n.dictionary_load_failed,
                            description: snapshot.error.toString(),
                            actionLabel: l10n.retry,
                            onAction: () => setState(() => _data = _loadData()),
                          );
                        }

                        final data = snapshot.data!;
                        if (!data.dictionaries.any(
                          (dictionary) => dictionary.hasTerms,
                        )) {
                          return _DictionaryMessage(
                            icon: Icons.menu_book_outlined,
                            title: l10n.no_dictionaries_title,
                            description: l10n.no_dictionaries_description,
                            actionLabel: l10n.manage_dictionaries,
                            onAction: _openDictionarySettings,
                          );
                        }

                        return Column(
                          children: [
                            _DictionaryContextBar(
                              dictionaryCount: data.dictionaries.length,
                              ankiProfile: data.ankiProfile,
                              navigation: _navigation,
                              showNavigation: !_usesNativeRenderer,
                              onBack: _popupController.goBack,
                              onForward: _popupController.goForward,
                            ),
                            if (_loading)
                              const LinearProgressIndicator(minHeight: 2)
                            else
                              const SizedBox(height: 2),
                            Expanded(
                              child: _lookupText.isEmpty
                                  ? _DictionaryMessage(
                                      icon: Icons.translate,
                                      title: l10n.dictionary_empty_title,
                                      description:
                                          l10n.dictionary_empty_description,
                                    )
                                  : Material(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      clipBehavior: Clip.antiAlias,
                                      child: _usesNativeRenderer
                                          ? DictionaryLookupResultsView(
                                              key: ValueKey((
                                                data.preferences,
                                                _lookupRevision,
                                              )),
                                              text: _lookupText,
                                              miningContext: MiningContext(
                                                sentence: _lookupText,
                                              ),
                                              preferences: data.preferences,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              showAnkiButton:
                                                  data.ankiProfile.ankiEnabled,
                                            )
                                          : HoshiDictionaryPopup(
                                              key: ValueKey((
                                                data.preferences,
                                                _lookupRevision,
                                              )),
                                              text: _lookupText,
                                              miningContext: MiningContext(
                                                sentence: _lookupText,
                                              ),
                                              controller: _popupController,
                                              preferences: data.preferences,
                                              onMatchChanged: (_) {},
                                              onDismiss: _clearLookup,
                                              onLoadingChanged: (loading) {
                                                if (!mounted ||
                                                    _loading == loading) {
                                                  return;
                                                }
                                                setState(
                                                  () => _loading = loading,
                                                );
                                              },
                                              onNavigationChanged:
                                                  (navigation) {
                                                    if (!mounted) return;
                                                    setState(
                                                      () => _navigation =
                                                          navigation,
                                                    );
                                                  },
                                            ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DictionarySearchField extends StatelessWidget {
  const _DictionarySearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: l10n.dictionary_search_label,
            hintText: l10n.dictionary_search_hint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clear_search,
                    onPressed: onClear,
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}

class _DictionaryContextBar extends StatelessWidget {
  const _DictionaryContextBar({
    required this.dictionaryCount,
    required this.ankiProfile,
    required this.navigation,
    required this.showNavigation,
    required this.onBack,
    required this.onForward,
  });

  final int dictionaryCount;
  final AnkiMiningProfile ankiProfile;
  final HoshiDictionaryNavigationState navigation;
  final bool showNavigation;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: l10n.dictionary_count(dictionaryCount)),
                  if (ankiProfile.ankiEnabled) ...[
                    const TextSpan(text: '  •  '),
                    TextSpan(
                      text: l10n.dictionary_anki_deck(ankiProfile.deckName),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
          if (showNavigation) ...[
            IconButton(
              tooltip: l10n.previous_lookup,
              visualDensity: VisualDensity.compact,
              onPressed: navigation.canGoBack ? onBack : null,
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            IconButton(
              tooltip: l10n.next_lookup,
              visualDensity: VisualDensity.compact,
              onPressed: navigation.canGoForward ? onForward : null,
              icon: const Icon(Icons.arrow_forward, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _DictionaryMessage extends StatelessWidget {
  const _DictionaryMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: colors.primary),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
class DictionaryLookupData {
  const DictionaryLookupData({
    required this.dictionaries,
    required this.preferences,
    required this.ankiProfile,
  });

  final List<InstalledDictionary> dictionaries;
  final DictionaryPopupPreferences preferences;
  final AnkiMiningProfile ankiProfile;
}
