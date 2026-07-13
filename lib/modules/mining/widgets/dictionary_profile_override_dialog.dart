import 'package:flutter/material.dart';
import 'package:mangayomi/services/mining/dictionary_profile.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

class _ProfileOverrideChoice {
  const _ProfileOverrideChoice(this.profileId);

  final String? profileId;
}

/// Shows Chimahon's profile override selector for a single cascade level.
///
/// [autoProfile] must be resolved with the level represented by [overrideKey]
/// omitted, so the Auto label previews the profile the cascade will select.
Future<bool> showDictionaryProfileOverrideDialog({
  required BuildContext context,
  required String overrideKey,
  required Future<DictionaryProfile> autoProfile,
  String title = 'Set dictionary profile',
}) async {
  final values = await Future.wait<dynamic>([
    MiningPreferences.getDictionaryProfiles(),
    MiningPreferences.getDictionaryProfileOverride(overrideKey),
    autoProfile,
  ]);
  if (!context.mounted) return false;

  final profiles = values[0] as List<DictionaryProfile>;
  final currentId = values[1] as String;
  final resolvedAutoProfile = values[2] as DictionaryProfile;
  var selectedId = profiles.any((profile) => profile.id == currentId)
      ? currentId
      : '';
  final choice = await showDialog<_ProfileOverrideChoice>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                _ProfileChoiceTile(
                  label: 'Auto (${resolvedAutoProfile.name})',
                  selected: selectedId.isEmpty,
                  onTap: () => setDialogState(() => selectedId = ''),
                ),
                for (final profile in profiles)
                  _ProfileChoiceTile(
                    label: profile.name,
                    selected: selectedId == profile.id,
                    onTap: () => setDialogState(() => selectedId = profile.id),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              _ProfileOverrideChoice(selectedId.isEmpty ? null : selectedId),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return false;
  await MiningPreferences.setDictionaryProfileOverride(
    overrideKey,
    choice.profileId,
  );
  return true;
}

class _ProfileChoiceTile extends StatelessWidget {
  const _ProfileChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
