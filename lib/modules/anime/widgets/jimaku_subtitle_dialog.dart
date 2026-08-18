import 'package:flutter/material.dart';

enum JimakuSubtitleDialogAction { search, openSettings }

class JimakuSubtitleDialog extends StatelessWidget {
  const JimakuSubtitleDialog({
    super.key,
    required this.apiKeyConfigured,
    required this.titleController,
    required this.titleHint,
    required this.cancelLabel,
    this.apiKeyController,
  });

  final bool apiKeyConfigured;
  final TextEditingController titleController;
  final String titleHint;
  final String cancelLabel;
  final TextEditingController? apiKeyController;

  bool get _managesApiKey => apiKeyController != null;

  @override
  Widget build(BuildContext context) {
    final needsApiKeySetup = !_managesApiKey && !apiKeyConfigured;

    return AlertDialog(
      title: const Text('Jimaku subtitles'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_managesApiKey) ...[
            TextFormField(
              controller: apiKeyController,
              decoration: const InputDecoration(labelText: 'Jimaku API key'),
            ),
            const SizedBox(height: 12),
          ],
          if (needsApiKeySetup) ...[
            const Text(
              'Add a Jimaku API key in Settings before searching for '
              'subtitles.',
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Title override',
              hintText: titleHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel),
        ),
        if (needsApiKeySetup)
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(context, JimakuSubtitleDialogAction.openSettings),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Set API key in Settings'),
          )
        else
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, JimakuSubtitleDialogAction.search),
            child: const Text('Search'),
          ),
      ],
    );
  }
}
