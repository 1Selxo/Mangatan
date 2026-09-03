import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

enum PlayerHotkeyAction {
  playPause,
  play,
  pause,
  seekBackward5,
  seekForward5,
  seekBackward10,
  seekForward10,
  skipIntro,
  toggleFullscreen,
  volumeUp,
  volumeDown,
  nextMedia,
  previousMedia,
}

extension PlayerHotkeyActionLabel on PlayerHotkeyAction {
  String get label => switch (this) {
    PlayerHotkeyAction.playPause => 'Play / pause',
    PlayerHotkeyAction.play => 'Play',
    PlayerHotkeyAction.pause => 'Pause',
    PlayerHotkeyAction.seekBackward5 => 'Seek backward 5 seconds',
    PlayerHotkeyAction.seekForward5 => 'Seek forward 5 seconds',
    PlayerHotkeyAction.seekBackward10 => 'Seek backward 10 seconds',
    PlayerHotkeyAction.seekForward10 => 'Seek forward 10 seconds',
    PlayerHotkeyAction.skipIntro => 'Skip intro',
    PlayerHotkeyAction.toggleFullscreen => 'Toggle fullscreen',
    PlayerHotkeyAction.volumeUp => 'Volume up',
    PlayerHotkeyAction.volumeDown => 'Volume down',
    PlayerHotkeyAction.nextMedia => 'Next item',
    PlayerHotkeyAction.previousMedia => 'Previous item',
  };
}

class PlayerHotkeyBinding {
  const PlayerHotkeyBinding({
    required this.action,
    required this.keyId,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  final PlayerHotkeyAction action;
  final int keyId;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  LogicalKeyboardKey? get key => LogicalKeyboardKey.findKeyByKeyId(keyId);

  SingleActivator? get activator {
    final logicalKey = key;
    if (logicalKey == null) return null;
    return SingleActivator(
      logicalKey,
      control: control,
      alt: alt,
      shift: shift,
      meta: meta,
    );
  }

  String get shortcutLabel {
    final logicalKey = key;
    final keyLabel = logicalKey?.keyLabel.trim();
    final parts = <String>[
      if (control) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (meta) 'Meta',
      if (keyLabel != null && keyLabel.isNotEmpty)
        keyLabel
      else
        logicalKey?.debugName ?? 'Unknown key',
    ];
    return parts.join(' + ');
  }

  String get signature => '$keyId:$control:$alt:$shift:$meta';

  Map<String, Object> toJson() => {
    'action': action.name,
    'keyId': keyId,
    'control': control,
    'alt': alt,
    'shift': shift,
    'meta': meta,
  };

  static PlayerHotkeyBinding? fromJson(Object? value) {
    if (value is! Map) return null;
    final actionName = value['action'];
    final keyId = value['keyId'];
    if (actionName is! String || keyId is! int) return null;
    final action = PlayerHotkeyAction.values
        .where((candidate) => candidate.name == actionName)
        .firstOrNull;
    if (action == null || LogicalKeyboardKey.findKeyByKeyId(keyId) == null) {
      return null;
    }
    return PlayerHotkeyBinding(
      action: action,
      keyId: keyId,
      control: value['control'] == true,
      alt: value['alt'] == true,
      shift: value['shift'] == true,
      meta: value['meta'] == true,
    );
  }
}

class PlayerHotkeyStore {
  static const _boxName = 'player_hotkeys';
  static const _bindingsKey = 'bindings';

  static List<PlayerHotkeyBinding> get defaults => [
    _binding(PlayerHotkeyAction.playPause, LogicalKeyboardKey.space),
    _binding(PlayerHotkeyAction.play, LogicalKeyboardKey.mediaPlay),
    _binding(PlayerHotkeyAction.pause, LogicalKeyboardKey.mediaPause),
    _binding(PlayerHotkeyAction.playPause, LogicalKeyboardKey.mediaPlayPause),
    _binding(
      PlayerHotkeyAction.previousMedia,
      LogicalKeyboardKey.mediaTrackPrevious,
    ),
    _binding(PlayerHotkeyAction.nextMedia, LogicalKeyboardKey.mediaTrackNext),
    _binding(PlayerHotkeyAction.seekBackward10, LogicalKeyboardKey.keyJ),
    _binding(PlayerHotkeyAction.seekForward10, LogicalKeyboardKey.keyL),
    _binding(PlayerHotkeyAction.skipIntro, LogicalKeyboardKey.enter),
    _binding(PlayerHotkeyAction.skipIntro, LogicalKeyboardKey.keyS),
    _binding(PlayerHotkeyAction.seekBackward5, LogicalKeyboardKey.arrowLeft),
    _binding(PlayerHotkeyAction.seekForward5, LogicalKeyboardKey.arrowRight),
    _binding(PlayerHotkeyAction.volumeUp, LogicalKeyboardKey.arrowUp),
    _binding(PlayerHotkeyAction.volumeDown, LogicalKeyboardKey.arrowDown),
    _binding(PlayerHotkeyAction.toggleFullscreen, LogicalKeyboardKey.keyF),
  ];

  static Future<List<PlayerHotkeyBinding>> load() async {
    final box = await _box();
    final stored = box.get(_bindingsKey);
    if (stored is! List) return defaults;
    return stored
        .map(PlayerHotkeyBinding.fromJson)
        .whereType<PlayerHotkeyBinding>()
        .toList(growable: false);
  }

  static Future<void> save(List<PlayerHotkeyBinding> bindings) async {
    final box = await _box();
    await box.put(
      _bindingsKey,
      bindings.map((binding) => binding.toJson()).toList(growable: false),
    );
  }

  static Future<List<PlayerHotkeyBinding>> restoreDefaults() async {
    final restored = defaults;
    await save(restored);
    return restored;
  }

  static Future<Box<dynamic>> _box() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  static PlayerHotkeyBinding _binding(
    PlayerHotkeyAction action,
    LogicalKeyboardKey key,
  ) => PlayerHotkeyBinding(action: action, keyId: key.keyId);
}

bool isModifierKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.controlLeft ||
    key == LogicalKeyboardKey.controlRight ||
    key == LogicalKeyboardKey.altLeft ||
    key == LogicalKeyboardKey.altRight ||
    key == LogicalKeyboardKey.shiftLeft ||
    key == LogicalKeyboardKey.shiftRight ||
    key == LogicalKeyboardKey.metaLeft ||
    key == LogicalKeyboardKey.metaRight;
