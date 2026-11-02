import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

void restoreSystemUI() => SystemChrome.setEnabledSystemUIMode(
  SystemUiMode.manual,
  overlays: SystemUiOverlay.values,
);

bool _restoreMaximizedAfterFullscreen = false;

/// Toggles desktop fullscreen, restoring a maximized window on exit.
Future<bool> setFullScreen({bool? value}) async {
  final current = await windowManager.isFullScreen();
  final target = value ?? !current;
  if (target == current) return current;

  if (target) {
    _restoreMaximizedAfterFullscreen = await windowManager.isMaximized();
    if (_restoreMaximizedAfterFullscreen) {
      await windowManager.unmaximize();
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await windowManager.setFullScreen(true);
  } else {
    await windowManager.setFullScreen(false);
    if (_restoreMaximizedAfterFullscreen) {
      await windowManager.maximize();
    }
    _restoreMaximizedAfterFullscreen = false;
  }
  return target;
}
