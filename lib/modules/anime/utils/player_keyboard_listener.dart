import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mangayomi/services/player_hotkeys.dart';

/// Receives desktop player keys even when a transient control owns focus.
///
/// Flutter's [Shortcuts] widget only sees events routed through its focused
/// subtree. Player controls are regularly removed after fading out, so using
/// the hardware dispatcher avoids losing shortcuts with those controls.
class PlayerHardwareKeyboardListener extends StatefulWidget {
  const PlayerHardwareKeyboardListener({
    super.key,
    required this.onKeyEvent,
    required this.child,
  });

  final bool Function(KeyEvent event) onKeyEvent;
  final Widget child;

  @override
  State<PlayerHardwareKeyboardListener> createState() =>
      _PlayerHardwareKeyboardListenerState();
}

class _PlayerHardwareKeyboardListenerState
    extends State<PlayerHardwareKeyboardListener> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  bool _handleKeyEvent(KeyEvent event) => widget.onKeyEvent(event);

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool isPlayerShortcutPress(KeyEvent event) =>
    event is KeyDownEvent || event is KeyRepeatEvent;

bool playerHotkeyMatches(
  PlayerHotkeyBinding binding,
  KeyEvent event, {
  required bool controlPressed,
  required bool altPressed,
  required bool shiftPressed,
  required bool metaPressed,
}) =>
    binding.key == event.logicalKey &&
    binding.control == controlPressed &&
    binding.alt == altPressed &&
    binding.shift == shiftPressed &&
    binding.meta == metaPressed;

String? mpvInputKeyForPlayerShortcut(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.pageUp => 'PGUP',
  LogicalKeyboardKey.pageDown => 'PGDWN',
  _ => null,
};
