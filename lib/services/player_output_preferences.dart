import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Player output choices that the player needs synchronously when it starts,
/// so they are loaded once at startup and cached.
class PlayerOutputPreferences {
  static const _boxName = 'player_output_preferences';
  static const _windowsGpuOutputKey = 'windows_gpu_output';

  static bool _storageReady = false;

  /// Whether Windows draws video through a GPU texture instead of the
  /// crash-safe pixel buffer. Off by default: Flutter's Windows engine can
  /// lose its graphics context while that texture is painted and close the
  /// app, but mpv's shaders only run on the GPU output.
  static final ValueNotifier<bool> windowsGpuOutput = ValueNotifier(false);

  /// Called once Hive is initialised; loads the cached values.
  static Future<void> load() async {
    _storageReady = true;
    final box = await _box();
    windowsGpuOutput.value =
        box?.get(_windowsGpuOutputKey, defaultValue: false) as bool? ?? false;
  }

  static Future<void> setWindowsGpuOutput(bool value) async {
    windowsGpuOutput.value = value;
    await (await _box())?.put(_windowsGpuOutputKey, value);
  }

  static Future<Box<dynamic>?> _box() async {
    if (!_storageReady) return null;
    try {
      if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
      return await Hive.openBox<dynamic>(_boxName);
    } catch (_) {
      return null;
    }
  }
}
