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
  static final additionalLeftClick = ValueNotifier<bool>(false);

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
      final values = await Future.wait<dynamic>([
        MiningPreferences.getDictionaryLookupTrigger(),
        MiningPreferences.getDictionaryAdditionalLeftClick(),
      ]);
      trigger.value = values[0] as DictionaryLookupTrigger;
      additionalLeftClick.value = values[1] as bool;
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

  static Future<void> setAdditionalLeftClick(bool value) async {
    await initialize();
    additionalLeftClick.value = value;
    await MiningPreferences.setDictionaryAdditionalLeftClick(value);
  }
}

bool readerLookupTriggerMatchesPointer(
  DictionaryLookupTrigger trigger,
  int buttons, {
  bool additionalLeftClick = false,
}) {
  if (buttons == kPrimaryButton) {
    return trigger == DictionaryLookupTrigger.leftClick || additionalLeftClick;
  }
  return switch (trigger) {
    DictionaryLookupTrigger.leftClick => false,
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
