import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:mangayomi/services/mining/mining_preferences.dart';

/// Shared lookup-trigger state for desktop readers and dictionary settings.
class ReaderLookupTriggerState {
  ReaderLookupTriggerState._();

  static final trigger = ValueNotifier<DictionaryLookupTrigger>(
    DictionaryLookupTrigger.leftClick,
  );

  static bool _initialized = false;
  static Future<void>? _initializing;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing;
    final future = _load();
    _initializing = future;
    return future;
  }

  static Future<void> _load() async {
    try {
      trigger.value = await MiningPreferences.getDictionaryLookupTrigger();
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> setTrigger(DictionaryLookupTrigger value) async {
    await initialize();
    trigger.value = value;
    await MiningPreferences.setDictionaryLookupTrigger(value);
  }
}

bool readerLookupTriggerMatchesPointer(
  DictionaryLookupTrigger trigger,
  int buttons,
) {
  return switch (trigger) {
    DictionaryLookupTrigger.leftClick => buttons == kPrimaryButton,
    DictionaryLookupTrigger.middleClick => buttons == kMiddleMouseButton,
    DictionaryLookupTrigger.shift => false,
  };
}

bool readerLookupTriggerMatchesKey(
  DictionaryLookupTrigger trigger,
  KeyEvent event,
) {
  if (trigger != DictionaryLookupTrigger.shift || event is KeyRepeatEvent) {
    return false;
  }
  final isShift =
      event.logicalKey == LogicalKeyboardKey.shiftLeft ||
      event.logicalKey == LogicalKeyboardKey.shiftRight;
  return isShift && (event is KeyDownEvent || event is KeyUpEvent);
}
