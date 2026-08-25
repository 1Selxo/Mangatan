import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/player_hotkeys.dart';

void main() {
  test('default player shortcuts have no key collisions', () {
    final defaults = PlayerHotkeyStore.defaults;

    expect(defaults, isNotEmpty);
    expect(
      defaults.map((binding) => binding.signature).toSet(),
      hasLength(defaults.length),
    );
    expect(
      defaults,
      contains(
        isA<PlayerHotkeyBinding>()
            .having(
              (binding) => binding.action,
              'action',
              PlayerHotkeyAction.playPause,
            )
            .having((binding) => binding.key, 'key', LogicalKeyboardKey.space),
      ),
    );
  });

  test('custom shortcut round-trips with modifiers', () {
    final binding = PlayerHotkeyBinding(
      action: PlayerHotkeyAction.toggleFullscreen,
      keyId: LogicalKeyboardKey.enter.keyId,
      control: true,
      shift: true,
    );

    final restored = PlayerHotkeyBinding.fromJson(binding.toJson());

    expect(restored, isNotNull);
    expect(restored!.action, PlayerHotkeyAction.toggleFullscreen);
    expect(restored.key, LogicalKeyboardKey.enter);
    expect(restored.control, isTrue);
    expect(restored.shift, isTrue);
    expect(restored.shortcutLabel, contains('Ctrl'));
    expect(restored.activator, isNotNull);
  });

  test('invalid stored shortcuts are ignored', () {
    expect(
      PlayerHotkeyBinding.fromJson({'action': 'missing', 'keyId': 1}),
      isNull,
    );
    expect(PlayerHotkeyBinding.fromJson('invalid'), isNull);
  });
}
