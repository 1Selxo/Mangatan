import 'package:flutter/material.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';
import 'package:mangayomi/services/mining/mining_models.dart';
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
  late String _lookupText = widget.initialText.trim();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookup() {
    final text = _controller.text.trim();
    setState(() => _lookupText = text);
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
                  DictionaryLookupResultsView(
                    key: ValueKey(_lookupText),
                    text: _lookupText,
                    miningContext: widget.miningContext.sentence.trim().isEmpty
                        ? widget.miningContext.copyWith(sentence: _lookupText)
                        : widget.miningContext,
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
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
