import 'package:flutter/material.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

class DictionaryLookupHistorySheet extends StatefulWidget {
  const DictionaryLookupHistorySheet({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DictionaryLookupHistorySheet(onSelected: onSelected),
    );
  }

  @override
  State<DictionaryLookupHistorySheet> createState() =>
      _DictionaryLookupHistorySheetState();
}

class _DictionaryLookupHistorySheetState
    extends State<DictionaryLookupHistorySheet> {
  late Future<List<String>> _history = _load();

  Future<List<String>> _load() =>
      MiningPreferences.getDictionaryLookupHistory();

  Future<void> _clear() async {
    await MiningPreferences.clearDictionaryLookupHistory();
    if (mounted) setState(() => _history = Future.value(const []));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Lookup history'),
              trailing: TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _history,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final history = snapshot.data!;
                  if (history.isEmpty) {
                    return const Center(
                      child: Text('Words looked up while reading appear here.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final query = history[index];
                      return ListTile(
                        leading: const Icon(Icons.manage_search),
                        title: Text(query),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onSelected(query);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
