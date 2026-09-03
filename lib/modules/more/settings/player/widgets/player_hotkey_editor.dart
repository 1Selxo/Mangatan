import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mangayomi/services/player_hotkeys.dart';

Future<void> showPlayerHotkeyEditor(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const Dialog.fullscreen(child: PlayerHotkeyEditor()),
);

class PlayerHotkeyEditor extends StatefulWidget {
  const PlayerHotkeyEditor({super.key});

  @override
  State<PlayerHotkeyEditor> createState() => _PlayerHotkeyEditorState();
}

class _PlayerHotkeyEditorState extends State<PlayerHotkeyEditor> {
  List<PlayerHotkeyBinding>? _bindings;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final bindings = await PlayerHotkeyStore.load();
      if (mounted) setState(() => _bindings = bindings);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not load hotkeys: $error');
    }
  }

  Future<void> _edit({int? index}) async {
    final bindings = _bindings;
    if (bindings == null) return;
    final replacement = await showDialog<PlayerHotkeyBinding>(
      context: context,
      builder: (_) =>
          _RecordHotkeyDialog(initial: index == null ? null : bindings[index]),
    );
    if (replacement == null || !mounted) return;
    final duplicate = bindings.indexWhere(
      (binding) => binding.signature == replacement.signature,
    );
    if (duplicate != -1 && duplicate != index) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${replacement.shortcutLabel} is already assigned to ${bindings[duplicate].action.label}',
          ),
        ),
      );
      return;
    }
    final updated = bindings.toList();
    if (index == null) {
      updated.add(replacement);
    } else {
      updated[index] = replacement;
    }
    await _save(updated);
  }

  Future<void> _delete(int index) async {
    final updated = _bindings!.toList()..removeAt(index);
    await _save(updated);
  }

  Future<void> _save(List<PlayerHotkeyBinding> bindings) async {
    await PlayerHotkeyStore.save(bindings);
    if (mounted) setState(() => _bindings = bindings);
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore default hotkeys?'),
        content: const Text('All custom player hotkeys will be replaced.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final bindings = await PlayerHotkeyStore.restoreDefaults();
    if (mounted) setState(() => _bindings = bindings);
  }

  @override
  Widget build(BuildContext context) {
    final bindings = _bindings;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Player hotkeys'),
        actions: [
          IconButton(
            tooltip: 'Restore defaults',
            onPressed: bindings == null ? null : _restoreDefaults,
            icon: const Icon(Icons.restore),
          ),
        ],
      ),
      floatingActionButton: bindings == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Add hotkey'),
            ),
      body: switch ((bindings, _error)) {
        (_, final String error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final List<PlayerHotkeyBinding> items, _) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Tap a binding to change its action or shortcut. Changes apply when a player is opened.',
                ),
              );
            }
            final bindingIndex = index - 1;
            final binding = items[bindingIndex];
            return ListTile(
              leading: const Icon(Icons.keyboard_outlined),
              title: Text(binding.action.label),
              subtitle: Text(binding.shortcutLabel),
              onTap: () => _edit(index: bindingIndex),
              trailing: IconButton(
                tooltip: 'Remove hotkey',
                onPressed: () => _delete(bindingIndex),
                icon: const Icon(Icons.delete_outline),
              ),
            );
          },
        ),
      },
    );
  }
}

class _RecordHotkeyDialog extends StatefulWidget {
  const _RecordHotkeyDialog({this.initial});

  final PlayerHotkeyBinding? initial;

  @override
  State<_RecordHotkeyDialog> createState() => _RecordHotkeyDialogState();
}

class _RecordHotkeyDialogState extends State<_RecordHotkeyDialog> {
  final _focusNode = FocusNode();
  late PlayerHotkeyAction _action =
      widget.initial?.action ?? PlayerHotkeyAction.playPause;
  PlayerHotkeyBinding? _binding;

  @override
  void initState() {
    super.initState();
    _binding = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _record(KeyEvent event) {
    if (event is! KeyDownEvent || isModifierKey(event.logicalKey)) return;
    final keyboard = HardwareKeyboard.instance;
    setState(() {
      _binding = PlayerHotkeyBinding(
        action: _action,
        keyId: event.logicalKey.keyId,
        control: keyboard.isControlPressed,
        alt: keyboard.isAltPressed,
        shift: keyboard.isShiftPressed,
        meta: keyboard.isMetaPressed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final binding = _binding;
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _record,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'Add hotkey' : 'Change hotkey'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PlayerHotkeyAction>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'Action'),
                items: [
                  for (final action in PlayerHotkeyAction.values)
                    DropdownMenuItem(value: action, child: Text(action.label)),
                ],
                onChanged: (action) {
                  if (action == null) return;
                  setState(() {
                    _action = action;
                    if (_binding case final existing?) {
                      _binding = PlayerHotkeyBinding(
                        action: action,
                        keyId: existing.keyId,
                        control: existing.control,
                        alt: existing.alt,
                        shift: existing.shift,
                        meta: existing.meta,
                      );
                    }
                  });
                  _focusNode.requestFocus();
                },
              ),
              const SizedBox(height: 24),
              Text(
                binding?.shortcutLabel ?? 'Press the new key combination',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Modifier keys can be combined with one other key.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: binding == null
                ? null
                : () => Navigator.pop(context, binding),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
