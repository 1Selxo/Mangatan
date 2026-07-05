import 'package:flutter/material.dart';
import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/services/hoshidicts/hoshidicts_backend.dart';
import 'package:mangayomi/services/mining/anki_card_builder.dart';
import 'package:mangayomi/services/mining/anki_connect_service.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';

class MiningLookupSheet extends StatefulWidget {
  final String initialText;
  final MiningContext miningContext;

  const MiningLookupSheet({
    super.key,
    required this.initialText,
    required this.miningContext,
  });

  static Future<void> show({
    required BuildContext context,
    required String text,
    MiningContext miningContext = const MiningContext(),
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: context.width(1)),
      builder: (_) => MiningLookupSheet(
        initialText: text,
        miningContext: miningContext.sentence.trim().isEmpty
            ? miningContext.copyWith(sentence: text)
            : miningContext,
      ),
    );
  }

  @override
  State<MiningLookupSheet> createState() => _MiningLookupSheetState();
}

class _MiningLookupSheetState extends State<MiningLookupSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText.trim(),
  );
  Future<List<HoshiLookupResult>>? _lookupFuture;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    if (_controller.text.trim().isNotEmpty) _lookup();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookup() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _lookupFuture = HoshidictsLookupBackend.instance.lookup(
        text,
        maxResults: 20,
        scanLength: 80,
      );
    });
  }

  Future<void> _export(HoshiLookupResult result) async {
    setState(() => _exporting = true);
    try {
      final profile = await MiningPreferences.getAnkiProfile();
      if (!profile.ankiEnabled) {
        botToast('Anki export is disabled in Dictionary settings', second: 4);
        return;
      }
      final endpoint = await MiningPreferences.getAnkiEndpoint();
      final context = widget.miningContext.sentence.trim().isEmpty
          ? widget.miningContext.copyWith(sentence: _controller.text)
          : widget.miningContext;
      final draft = await const AnkiCardBuilder().build(
        result: result,
        context: context,
        profile: profile,
      );
      final noteId = await AnkiConnectService(endpoint: endpoint).exportDraft(
        draft,
        duplicateCheck: profile.duplicateCheck,
        syncOnCreate: profile.syncOnCreate,
      );
      botToast('Added to Anki (#$noteId)', second: 3);
    } catch (e) {
      botToast('Anki export failed: $e', second: 5);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: context.themeData.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.35,
            maxChildSize: 0.94,
            builder: (context, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  Center(
                    child: Container(
                      height: 7,
                      width: 35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: context.secondaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _lookup(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.manage_search),
                            labelText: 'Lookup',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Lookup',
                        onPressed: _lookup,
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (widget.miningContext.locationLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.miningContext.locationLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  FutureBuilder<List<HoshiLookupResult>>(
                    future: _lookupFuture,
                    builder: (context, snapshot) {
                      if (_lookupFuture == null) {
                        return const _EmptyLookupState(
                          text: 'Enter text to look up.',
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return _EmptyLookupState(
                          text: 'Lookup failed: ${snapshot.error}',
                        );
                      }
                      final results = snapshot.data ?? const [];
                      if (results.isEmpty) {
                        return const _EmptyLookupState(
                          text: 'No dictionary results found.',
                        );
                      }
                      return Column(
                        children: [
                          for (final result in results)
                            _LookupResultTile(
                              result: result,
                              exporting: _exporting,
                              onExport: () => _export(result),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LookupResultTile extends StatelessWidget {
  final HoshiLookupResult result;
  final bool exporting;
  final VoidCallback onExport;

  const _LookupResultTile({
    required this.result,
    required this.exporting,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final term = result.term;
    final subtitle = [
      if (term.reading.trim().isNotEmpty) term.reading,
      if (result.deinflected.trim().isNotEmpty &&
          result.deinflected != term.expression)
        result.deinflected,
    ].join(' - ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        term.expression,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add to Anki',
                  onPressed: exporting ? null : onExport,
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.note_add_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final glossary in term.glossaries.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  glossary.glossary,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (term.frequencies.isNotEmpty || term.pitches.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final frequency in term.frequencies.take(3))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${frequency.dictName}: ${frequency.frequencies.map((e) => e.displayValue.isEmpty ? e.value : e.displayValue).join(', ')}',
                      ),
                    ),
                  for (final pitch in term.pitches.take(3))
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${pitch.dictName}: ${pitch.pitchPositions.join(', ')}',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLookupState extends StatelessWidget {
  final String text;

  const _EmptyLookupState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}
