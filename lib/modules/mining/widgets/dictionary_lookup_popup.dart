import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_glossary.dart';
import 'package:mangayomi/modules/mining/widgets/hoshi_dictionary_popup.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';

class DictionaryPopupHandle {
  const DictionaryPopupHandle({required this.dismiss, required this.dismissed});

  final VoidCallback dismiss;
  final Future<void> dismissed;
}

final _dictionaryPopupHost = _DictionaryPopupHostController();

class _DictionaryPopupHostController {
  final key = GlobalKey<_DictionaryPopupOverlayHostState>();
  OverlayEntry? _entry;
  Future<void>? _initializing;

  Future<void> prewarm(BuildContext context) => _ensure(context);

  bool dismissActive() {
    final state = key.currentState;
    if (state == null || !state.isVisible) return false;
    state.dismiss();
    return true;
  }

  Future<void> _ensure(BuildContext context) {
    if (_entry != null) return Future.value();
    return _initializing ??= _initialize(context);
  }

  Future<void> _initialize(BuildContext context) async {
    final preferences = await MiningPreferences.getDictionaryPopupPreferences();
    if (!context.mounted || _entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) =>
          _DictionaryPopupOverlayHost(key: key, preferences: preferences),
    );
    overlay.insert(_entry!);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<DictionaryPopupHandle?> show({
    required BuildContext context,
    required Rect anchor,
    required String text,
    required FutureOr<MiningContext> miningContext,
    required Future<List<HoshiLookupResult>> initialResults,
    bool dismissOnOutsideTap = true,
    ValueChanged<int>? onMatchChanged,
    ValueChanged<bool>? onHoverChanged,
  }) async {
    final resolvedMiningContext = Future<MiningContext>.value(miningContext);
    await _ensure(context);
    if (!context.mounted) return null;
    return key.currentState?.present(
      screen: MediaQuery.sizeOf(context),
      anchor: anchor,
      text: text,
      miningContext: resolvedMiningContext,
      initialResults: initialResults,
      dismissOnOutsideTap: dismissOnOutsideTap,
      onMatchChanged: onMatchChanged,
      onHoverChanged: onHoverChanged,
    );
  }
}

class _DictionaryPopupRequest {
  const _DictionaryPopupRequest({
    required this.text,
    required this.miningContext,
    required this.initialResults,
    required this.onMatchChanged,
    required this.onHoverChanged,
  });

  final String text;
  final Future<MiningContext> miningContext;
  final Future<List<HoshiLookupResult>> initialResults;
  final ValueChanged<int>? onMatchChanged;
  final ValueChanged<bool>? onHoverChanged;
}

class _DictionaryPopupOverlayHost extends StatefulWidget {
  const _DictionaryPopupOverlayHost({super.key, required this.preferences});

  final DictionaryPopupPreferences preferences;

  @override
  State<_DictionaryPopupOverlayHost> createState() =>
      _DictionaryPopupOverlayHostState();
}

class _DictionaryPopupOverlayHostState
    extends State<_DictionaryPopupOverlayHost> {
  _DictionaryPopupRequest? _request;
  Completer<void>? _dismissed;
  bool _visible = false;
  late double _left;
  double _top = 0;
  late double _width;
  late double _height;
  bool _dismissOnOutsideTap = true;

  bool get isVisible => _visible;

  @override
  void initState() {
    super.initState();
    _width = widget.preferences.width;
    _height = widget.preferences.height;
    _left = -_width - 100;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointer);
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  Rect get _popupBounds => Rect.fromLTWH(_left, _top, _width, _height);

  void _handleGlobalPointer(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    if (!dictionaryPopupShouldDismissForPointer(
      visible: _visible,
      dismissOnOutsideTap: _dismissOnOutsideTap,
      popupBounds: _popupBounds,
      position: event.position,
      buttons: event.buttons,
    )) {
      return;
    }
    // This global route observes without joining the hit-test path, so the
    // same click continues to the reader and can immediately replace the
    // lookup instead of being consumed by a modal barrier.
    dismiss();
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (!_visible || event is! KeyDownEvent) return false;
    if (!dictionaryPopupIsDismissKey(event.logicalKey)) return false;
    dismiss();
    return true;
  }

  DictionaryPopupHandle present({
    required Size screen,
    required Rect anchor,
    required String text,
    required Future<MiningContext> miningContext,
    required Future<List<HoshiLookupResult>> initialResults,
    required bool dismissOnOutsideTap,
    ValueChanged<int>? onMatchChanged,
    ValueChanged<bool>? onHoverChanged,
  }) {
    _completeDismissal();
    final width = math.min(widget.preferences.width, screen.width - 24);
    final height = math.min(widget.preferences.height, screen.height - 24);
    final left = (anchor.center.dx - width / 2)
        .clamp(12.0, math.max(12.0, screen.width - width - 12))
        .toDouble();
    final below = anchor.bottom + 8;
    final top = below + height <= screen.height - 12
        ? below
        : math.max(12.0, anchor.top - height - 8);
    final completer = Completer<void>();
    setState(() {
      _request = _DictionaryPopupRequest(
        text: text,
        miningContext: miningContext,
        initialResults: initialResults,
        onMatchChanged: onMatchChanged,
        onHoverChanged: onHoverChanged,
      );
      _dismissed = completer;
      _visible = true;
      _dismissOnOutsideTap = dismissOnOutsideTap;
      _left = left;
      _top = top;
      _width = width;
      _height = height;
    });
    return DictionaryPopupHandle(dismiss: dismiss, dismissed: completer.future);
  }

  void dismiss() {
    if (!_visible) {
      _completeDismissal();
      return;
    }
    setState(() {
      _visible = false;
      _request = null;
      _dismissOnOutsideTap = true;
      _left = -_width - 100;
      _top = 0;
    });
    _completeDismissal();
  }

  void _completeDismissal() {
    final completer = _dismissed;
    _dismissed = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final popupTheme = _popupTheme(Theme.of(context), widget.preferences.theme);
    return Stack(
      children: [
        if (_visible && request != null)
          Positioned(
            left: _left,
            top: _top,
            width: _width,
            height: _height,
            child: IgnorePointer(
              ignoring: !_visible,
              child: MouseRegion(
                onEnter: (_) => request.onHoverChanged?.call(true),
                onExit: (_) => request.onHoverChanged?.call(false),
                child: Theme(
                  data: popupTheme.copyWith(
                    textTheme: popupTheme.textTheme.apply(
                      fontSizeFactor: widget.preferences.fontSize / 14,
                    ),
                  ),
                  child: Material(
                    elevation: _visible && !widget.preferences.eInkMode
                        ? 12
                        : 0,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(
                      widget.preferences.eInkMode ? 0 : 8,
                    ),
                    color: popupTheme.colorScheme.surface,
                    child: HoshiDictionaryPopup(
                      text: request.text,
                      miningContext: request.miningContext,
                      initialResults: request.initialResults,
                      preferences: widget.preferences,
                      onMatchChanged: (count) =>
                          _request?.onMatchChanged?.call(count),
                      onDismiss: dismiss,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(
      _handleGlobalPointer,
    );
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _completeDismissal();
    super.dispose();
  }
}

class DictionaryLookupPopup extends StatelessWidget {
  const DictionaryLookupPopup({
    super.key,
    required this.text,
    required this.miningContext,
    required this.onMatchChanged,
    required this.onClose,
    required this.preferences,
  });

  final String text;
  final MiningContext miningContext;
  final ValueChanged<int> onMatchChanged;
  final VoidCallback onClose;
  final DictionaryPopupPreferences preferences;

  static Future<DictionaryPopupHandle?> show({
    required BuildContext context,
    required Rect anchor,
    required String text,
    required FutureOr<MiningContext> miningContext,
    Future<List<HoshiLookupResult>>? initialResults,
    bool dismissOnOutsideTap = true,
    ValueChanged<int>? onMatchChanged,
    ValueChanged<bool>? onHoverChanged,
  }) async {
    final lookupText = text.trim();
    if (lookupText.isEmpty) return null;
    return _dictionaryPopupHost.show(
      context: context,
      anchor: anchor,
      text: lookupText,
      miningContext: miningContext,
      initialResults: initialResults ?? lookup(lookupText),
      dismissOnOutsideTap: dismissOnOutsideTap,
      onMatchChanged: onMatchChanged,
      onHoverChanged: onHoverChanged,
    );
  }

  static Future<void> prewarm(BuildContext context) =>
      _dictionaryPopupHost.prewarm(context);

  /// Dismisses the active popup without affecting the current app route.
  /// Returns whether a popup consumed the back action.
  static bool dismissActive() => _dictionaryPopupHost.dismissActive();

  static Future<List<HoshiLookupResult>> lookup(String text) {
    final query = text.trim();
    if (query.isEmpty) return Future.value(const []);
    return HoshidictsLookupBackend.instance.lookup(
      query,
      maxResults: hoshiPopupMaxResults,
      scanLength: hoshiPopupScanLength,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final popupTheme = _popupTheme(baseTheme, preferences.theme);
    return Theme(
      data: popupTheme.copyWith(
        textTheme: popupTheme.textTheme.apply(
          fontSizeFactor: preferences.fontSize / 14,
        ),
      ),
      child: Material(
        elevation: preferences.eInkMode ? 0 : 12,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(preferences.eInkMode ? 0 : 8),
        color: popupTheme.colorScheme.surface,
        child: HoshiDictionaryPopup(
          text: text,
          miningContext: miningContext,
          preferences: preferences,
          onMatchChanged: onMatchChanged,
          onDismiss: onClose,
        ),
      ),
    );
  }
}

@visibleForTesting
bool dictionaryPopupIsDismissKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.escape ||
    key == LogicalKeyboardKey.backspace ||
    key == LogicalKeyboardKey.browserBack;

@visibleForTesting
bool dictionaryPopupShouldDismissForPointer({
  required bool visible,
  required bool dismissOnOutsideTap,
  required Rect popupBounds,
  required Offset position,
  required int buttons,
}) {
  if (!visible || !dismissOnOutsideTap) return false;
  // Mouse navigation buttons are handled by the app-level back listener so
  // it can consume the route pop when a dictionary popup is active.
  if (buttons & (kBackMouseButton | kForwardMouseButton) != 0) return false;
  return !popupBounds.contains(position);
}

class DictionaryLookupResultsView extends StatefulWidget {
  const DictionaryLookupResultsView({
    super.key,
    required this.text,
    required this.miningContext,
    this.preferences,
    this.onMatchChanged,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.compact = false,
    this.showAnkiButton = true,
    this.shrinkWrap = false,
    this.maxResults = 10,
    this.scanLength = hoshiPopupScanLength,
  });

  final String text;
  final MiningContext miningContext;
  final DictionaryPopupPreferences? preferences;
  final ValueChanged<int>? onMatchChanged;
  final ScrollPhysics? physics;
  final EdgeInsets padding;
  final bool compact;
  final bool showAnkiButton;
  final bool shrinkWrap;
  final int maxResults;
  final int scanLength;

  @override
  State<DictionaryLookupResultsView> createState() =>
      _DictionaryLookupResultsViewState();
}

class _DictionaryLookupResultsViewState
    extends State<DictionaryLookupResultsView> {
  late Future<_LookupPayload> _future = _lookup();
  bool _exporting = false;

  @override
  void didUpdateWidget(covariant DictionaryLookupResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxResults != widget.maxResults ||
        oldWidget.scanLength != widget.scanLength ||
        oldWidget.preferences != widget.preferences) {
      _future = _lookup();
    }
  }

  Future<_LookupPayload> _lookup() async {
    final lookupText = widget.text.trim();
    if (lookupText.isEmpty) {
      return _LookupPayload.empty(
        widget.preferences ??
            await MiningPreferences.getDictionaryPopupPreferences(),
      );
    }
    final values = await Future.wait<dynamic>([
      HoshidictsLookupBackend.instance.lookup(
        lookupText,
        maxResults: widget.maxResults,
        scanLength: widget.scanLength,
      ),
      HoshidictsLookupBackend.instance.getStyles().catchError(
        (_) => <HoshiDictionaryStyle>[],
      ),
      if (widget.preferences == null)
        MiningPreferences.getDictionaryPopupPreferences()
      else
        Future<DictionaryPopupPreferences>.value(widget.preferences),
    ]);
    final results = values[0] as List<HoshiLookupResult>;
    if (results.isNotEmpty) {
      widget.onMatchChanged?.call(results.first.matched.length);
    }
    final styles = values[1] as List<HoshiDictionaryStyle>;
    return _LookupPayload(
      results: results,
      styles: {for (final style in styles) style.dictName: style.styles},
      preferences: values[2] as DictionaryPopupPreferences,
    );
  }

  Future<void> _export(HoshiLookupResult result) async {
    setState(() => _exporting = true);
    try {
      final profile = await MiningPreferences.getAnkiProfile();
      if (!profile.ankiEnabled) {
        botToast('Anki export is disabled in Dictionary settings', second: 4);
        return;
      }
      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: widget.miningContext,
        profile: profile,
      );
      final noteId =
          await AnkiConnectService(
            endpoint: await MiningPreferences.getAnkiEndpoint(),
          ).exportDraft(
            draft,
            duplicateCheck: profile.duplicateCheck,
            syncOnCreate: profile.syncOnCreate,
          );
      botToast('Added to Anki (#$noteId)', second: 3);
    } catch (error) {
      botToast('Anki export failed: $error', second: 5);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LookupPayload>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EmptyLookupState(text: 'Lookup failed: ${snapshot.error}');
        }
        final payload = snapshot.data;
        final results = payload?.results ?? const [];
        if (widget.text.trim().isEmpty) {
          return const _EmptyLookupState(text: 'Enter text to look up.');
        }
        if (results.isEmpty) {
          return const _EmptyLookupState(text: 'No dictionary results found.');
        }
        return ListView.separated(
          physics: widget.shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : widget.physics,
          primary: widget.shrinkWrap ? false : null,
          shrinkWrap: widget.shrinkWrap,
          padding: widget.padding,
          itemCount: results.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: Theme.of(context).dividerColor),
          itemBuilder: (context, index) {
            final result = results[index];
            return _LookupResultTile(
              result: result,
              preferences: payload!.preferences,
              styles: payload.styles,
              exporting: _exporting,
              showAnkiButton: widget.showAnkiButton,
              compact: widget.compact,
              onExport: () => _export(result),
            );
          },
        );
      },
    );
  }
}

class _LookupResultTile extends StatelessWidget {
  const _LookupResultTile({
    required this.result,
    required this.preferences,
    required this.styles,
    required this.exporting,
    required this.showAnkiButton,
    required this.compact,
    required this.onExport,
  });

  final HoshiLookupResult result;
  final DictionaryPopupPreferences preferences;
  final Map<String, String> styles;
  final bool exporting;
  final bool showAnkiButton;
  final bool compact;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final term = result.term;
    final glossaryGroups = _groupGlossariesByDictionary(term.glossaries);
    final senseTermTags = _uniqueTags(
      term.glossaries.expand((entry) => _splitTags(entry.termTags)),
    ).toSet();
    final rules = _splitTags(term.rules);
    final globalRules = [
      for (final rule in rules)
        if (!senseTermTags.contains(rule)) rule,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(10, compact ? 8 : 12, 6, compact ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LookupEntryMarker(result: result),
              const SizedBox(width: 6),
              Expanded(
                child: _TermHeading(
                  term: term,
                  result: result,
                  compact: compact,
                ),
              ),
              if (showAnkiButton)
                IconButton(
                  tooltip: 'Add to Anki',
                  onPressed: exporting ? null : onExport,
                  visualDensity: VisualDensity.compact,
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.note_add_outlined, size: 20),
                ),
            ],
          ),
          if (globalRules.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final rule in globalRules)
                    _LookupChip(label: rule, kind: _ChipKind.rule),
                ],
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DeinflectionTrace(result: result),
                SizedBox(height: compact ? 5 : 8),
                if (term.frequencies.isNotEmpty || term.pitches.isNotEmpty) ...[
                  _FrequencyAndPitchBlock(term: term, preferences: preferences),
                  SizedBox(height: compact ? 6 : 9),
                ],
                for (final group in glossaryGroups)
                  _DictionaryGlossaryGroup(
                    group: group,
                    styles: styles,
                    preferences: preferences,
                    compact: compact,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DictionaryGlossaryGroup extends StatefulWidget {
  const _DictionaryGlossaryGroup({
    required this.group,
    required this.styles,
    required this.preferences,
    required this.compact,
  });

  final _GlossaryGroup group;
  final Map<String, String> styles;
  final DictionaryPopupPreferences preferences;
  final bool compact;

  @override
  State<_DictionaryGlossaryGroup> createState() =>
      _DictionaryGlossaryGroupState();
}

class _DictionaryGlossaryGroupState extends State<_DictionaryGlossaryGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final group = widget.group;
    final termTags = _uniqueTags(
      group.entries.expand((entry) => _splitTags(entry.termTags)),
    );
    final hasMultipleSenses = group.entries.length > 1;
    final dictionaryName = group.dictionaryName.trim().isEmpty
        ? 'Dictionary'
        : group.dictionaryName.trim();

    return Container(
      margin: EdgeInsets.only(bottom: widget.compact ? 6 : 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.72),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 4),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.arrow_drop_down : Icons.arrow_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      dictionaryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                widget.compact ? 9 : 11,
                2,
                widget.compact ? 9 : 11,
                widget.compact ? 7 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (termTags.isNotEmpty) ...[
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in termTags)
                          _LookupChip(label: tag, kind: _ChipKind.tag),
                      ],
                    ),
                    const SizedBox(height: 5),
                  ],
                  for (final indexed in group.entries.indexed)
                    _GlossarySense(
                      index: indexed.$1 + 1,
                      showIndex: hasMultipleSenses,
                      glossary: indexed.$2,
                      styles: widget.styles,
                      preferences: widget.preferences,
                      compact: widget.compact,
                      hiddenTermTags: termTags.toSet(),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LookupEntryMarker extends StatelessWidget {
  const _LookupEntryMarker({required this.result});

  final HoshiLookupResult result;

  @override
  Widget build(BuildContext context) {
    final hasTransform =
        result.trace.isNotEmpty ||
        (result.matched.trim().isNotEmpty &&
            result.deinflected.trim().isNotEmpty &&
            result.matched.trim() != result.deinflected.trim());
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Icon(
        hasTransform ? Icons.arrow_right : Icons.circle,
        size: hasTransform ? 18 : 6,
        color: hasTransform
            ? Theme.of(context).colorScheme.primary
            : Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      ),
    );
  }
}

class _TermHeading extends StatelessWidget {
  const _TermHeading({
    required this.term,
    required this.result,
    required this.compact,
  });

  final HoshiTermResult term;
  final HoshiLookupResult result;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final reading = term.reading.trim();
    final showReading = reading.isNotEmpty && reading != term.expression;
    final titleStyle = compact
        ? Theme.of(context).textTheme.headlineSmall
        : Theme.of(context).textTheme.headlineMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showReading)
          Text(
            reading,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              height: 1,
            ),
          ),
        Text(
          term.expression,
          style: titleStyle?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _DeinflectionTrace extends StatelessWidget {
  const _DeinflectionTrace({required this.result});

  final HoshiLookupResult result;

  @override
  Widget build(BuildContext context) {
    final deinflected = result.deinflected.trim();
    final matched = result.matched.trim();
    final hasProcess =
        deinflected.isNotEmpty && matched.isNotEmpty && deinflected != matched;
    if (!hasProcess && result.trace.isEmpty && result.preprocessorSteps == 0) {
      return const SizedBox.shrink();
    }
    final processText = hasProcess ? '$matched -> $deinflected' : '';
    final traceLabels = [
      for (final group in result.trace)
        if (group.name.trim().isNotEmpty) group.name.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Tooltip(
        message: [
          if (processText.isNotEmpty) processText,
          for (final group in result.trace)
            if (group.description.trim().isNotEmpty)
              '${group.name}: ${group.description}',
        ].join('\n'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 15,
              color: Colors.lightGreenAccent.shade400,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  if (traceLabels.isEmpty && processText.isNotEmpty)
                    _LookupChip(label: processText, kind: _ChipKind.trace),
                  for (final label in traceLabels)
                    _LookupChip(label: label, kind: _ChipKind.trace),
                  if (result.preprocessorSteps > 0)
                    _LookupChip(
                      label: '${result.preprocessorSteps} preprocess',
                      kind: _ChipKind.trace,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlossarySense extends StatelessWidget {
  const _GlossarySense({
    required this.index,
    required this.showIndex,
    required this.glossary,
    required this.styles,
    required this.preferences,
    required this.compact,
    required this.hiddenTermTags,
  });

  final int index;
  final bool showIndex;
  final HoshiGlossaryEntry glossary;
  final Map<String, String> styles;
  final DictionaryPopupPreferences preferences;
  final bool compact;
  final Set<String> hiddenTermTags;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{...hiddenTermTags};
    final termTags = _splitTags(
      glossary.termTags,
    ).where((tag) => seen.add(tag)).toList();
    final definitionTags = _splitTags(
      glossary.definitionTags,
    ).where((tag) => tag != index.toString() && seen.add(tag)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: showIndex ? 30 : 12,
            child: showIndex
                ? Text(
                    '$index.',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final tag in termTags)
                      _LookupChip(label: tag, kind: _ChipKind.tag),
                    for (final tag in definitionTags)
                      _LookupChip(label: tag, kind: _ChipKind.definition),
                  ],
                ),
                if (termTags.isNotEmpty || definitionTags.isNotEmpty)
                  const SizedBox(height: 4),
                DictionaryGlossary(
                  rawGlossary: glossary.glossary,
                  dictionaryName: glossary.dictName,
                  dictionaryCss: styles[glossary.dictName] ?? '',
                  customCss: preferences.customCss,
                  fontSize: preferences.fontSize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencyAndPitchBlock extends StatelessWidget {
  const _FrequencyAndPitchBlock({
    required this.term,
    required this.preferences,
  });

  final HoshiTermResult term;
  final DictionaryPopupPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        if (preferences.showFrequencyHarmonic && term.frequencies.isNotEmpty)
          _LookupChip(
            label:
                'harmonic ${_frequencyHarmonic(term.frequencies).toStringAsFixed(1)}',
            kind: _ChipKind.frequency,
          ),
        if (preferences.showFrequencyAverage && term.frequencies.isNotEmpty)
          _LookupChip(
            label:
                'average ${_frequencyAverage(term.frequencies).toStringAsFixed(1)}',
            kind: _ChipKind.frequency,
          ),
        for (final frequency in term.frequencies.take(6))
          _LookupChip(
            label: _frequencyEntryText(frequency),
            kind: _ChipKind.frequency,
          ),
        if (preferences.showPitchNumber || preferences.showPitchText)
          for (final pitch in term.pitches)
            _LookupChip(
              label: [
                pitch.dictName,
                if (preferences.showPitchNumber)
                  pitch.pitchPositions.join(', '),
                if (preferences.showPitchText) pitch.transcriptions.join(', '),
              ].where((value) => value.trim().isNotEmpty).join(' - '),
              kind: _ChipKind.pitch,
            ),
      ],
    );
  }
}

class _LookupChip extends StatelessWidget {
  const _LookupChip({required this.label, required this.kind});

  final String label;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = _chipColors(context, kind);
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.$2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyLookupState extends StatelessWidget {
  const _EmptyLookupState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

class _LookupPayload {
  const _LookupPayload({
    required this.results,
    required this.styles,
    required this.preferences,
  });

  factory _LookupPayload.empty(DictionaryPopupPreferences preferences) {
    return _LookupPayload(
      results: const [],
      styles: const {},
      preferences: preferences,
    );
  }

  final List<HoshiLookupResult> results;
  final Map<String, String> styles;
  final DictionaryPopupPreferences preferences;
}

class _GlossaryGroup {
  const _GlossaryGroup({required this.dictionaryName, required this.entries});

  final String dictionaryName;
  final List<HoshiGlossaryEntry> entries;
}

List<_GlossaryGroup> _groupGlossariesByDictionary(
  List<HoshiGlossaryEntry> glossaries,
) {
  final grouped = <String, List<HoshiGlossaryEntry>>{};
  for (final glossary in glossaries) {
    grouped.putIfAbsent(glossary.dictName, () => []).add(glossary);
  }
  return [
    for (final entry in grouped.entries)
      _GlossaryGroup(dictionaryName: entry.key, entries: entry.value),
  ];
}

enum _ChipKind { tag, rule, definition, dictionary, trace, frequency, pitch }

ThemeData _popupTheme(
  ThemeData baseTheme,
  DictionaryThemePreference preference,
) {
  final baseScheme = baseTheme.colorScheme;
  final light = ThemeData.light().copyWith(
    colorScheme: ColorScheme.light(
      primary: baseScheme.primary,
      primaryContainer: baseScheme.primaryContainer,
      onPrimaryContainer: baseScheme.onPrimaryContainer,
      secondaryContainer: baseScheme.secondaryContainer,
      onSecondaryContainer: baseScheme.onSecondaryContainer,
      tertiaryContainer: baseScheme.tertiaryContainer,
      onTertiaryContainer: baseScheme.onTertiaryContainer,
      errorContainer: baseScheme.errorContainer,
      onErrorContainer: baseScheme.onErrorContainer,
    ),
  );
  final dark = ThemeData.dark().copyWith(
    colorScheme: ColorScheme.dark(
      surface: const Color(0xff1f1f1f),
      surfaceContainerHighest: const Color(0xff303134),
      onSurface: const Color(0xfff1f3f4),
      onSurfaceVariant: const Color(0xffbdc1c6),
      primary: baseScheme.primary,
      primaryContainer: baseScheme.primaryContainer,
      onPrimaryContainer: baseScheme.onPrimaryContainer,
      secondaryContainer: baseScheme.secondaryContainer,
      onSecondaryContainer: baseScheme.onSecondaryContainer,
      tertiaryContainer: baseScheme.tertiaryContainer,
      onTertiaryContainer: baseScheme.onTertiaryContainer,
      errorContainer: baseScheme.errorContainer,
      onErrorContainer: baseScheme.onErrorContainer,
    ),
    dividerColor: const Color(0xff343536),
    scaffoldBackgroundColor: const Color(0xff1f1f1f),
  );
  return switch (preference) {
    DictionaryThemePreference.light =>
      baseTheme.brightness == Brightness.light ? baseTheme : light,
    DictionaryThemePreference.dark => dark,
    DictionaryThemePreference.black => dark.copyWith(
      colorScheme: dark.colorScheme.copyWith(surface: Colors.black),
      scaffoldBackgroundColor: Colors.black,
    ),
    DictionaryThemePreference.system => baseTheme,
  };
}

(Color, Color) _chipColors(BuildContext context, _ChipKind kind) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (kind) {
    _ChipKind.dictionary => (const Color(0xff9c59d1), Colors.white),
    _ChipKind.tag => (const Color(0xff2f8fbd), Colors.white),
    _ChipKind.rule => (
      dark ? const Color(0xff5f6368) : scheme.secondaryContainer,
      dark ? Colors.white : scheme.onSecondaryContainer,
    ),
    _ChipKind.definition => (
      dark ? const Color(0xff5f6368) : scheme.tertiaryContainer,
      dark ? Colors.white : scheme.onTertiaryContainer,
    ),
    _ChipKind.trace => (
      dark ? const Color(0xff3c4043) : scheme.surfaceContainerHighest,
      dark ? const Color(0xffe8eaed) : scheme.onSurfaceVariant,
    ),
    _ChipKind.frequency => (
      dark ? const Color(0xff3c4043) : scheme.primaryContainer,
      dark ? const Color(0xffe8eaed) : scheme.onPrimaryContainer,
    ),
    _ChipKind.pitch => (scheme.errorContainer, scheme.onErrorContainer),
  };
}

List<String> _splitTags(String value) {
  return _uniqueTags(
    value
        .split(RegExp(r'[\s,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty),
  );
}

List<String> _uniqueTags(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final value in values) {
    if (seen.add(value)) result.add(value);
  }
  return result;
}

String _frequencyEntryText(HoshiFrequencyEntry entry) {
  final values = entry.frequencies
      .map((frequency) {
        return frequency.displayValue.trim().isEmpty
            ? frequency.value.toString()
            : frequency.displayValue;
      })
      .where((value) => value.trim().isNotEmpty)
      .join(', ');
  if (values.isEmpty) return entry.dictName;
  return '${entry.dictName}: $values';
}

List<int> _frequencyValues(List<HoshiFrequencyEntry> entries) => entries
    .expand((entry) => entry.frequencies)
    .map((frequency) => frequency.value)
    .where((value) => value > 0)
    .toSet()
    .toList();

double _frequencyHarmonic(List<HoshiFrequencyEntry> entries) {
  final values = _frequencyValues(entries);
  if (values.isEmpty) return 0;
  return values.length /
      values.fold<double>(0, (sum, value) => sum + 1 / value);
}

double _frequencyAverage(List<HoshiFrequencyEntry> entries) {
  final values = _frequencyValues(entries);
  if (values.isEmpty) return 0;
  return values.reduce((a, b) => a + b) / values.length;
}
