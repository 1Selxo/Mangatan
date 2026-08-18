import 'package:flutter/foundation.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

class ReaderEInkState {
  ReaderEInkState._();

  static final enabled = ValueNotifier<bool>(false);
  static bool _initialized = false;
  static Future<void>? _initializing;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing;
    final operation = _load();
    _initializing = operation;
    try {
      await operation;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> _load() async {
    enabled.value = await MiningPreferences.getReaderEInkMode();
    _initialized = true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    _initialized = true;
    await MiningPreferences.setReaderEInkMode(value);
  }
}
