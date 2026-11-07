import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mangayomi/modules/mining/widgets/dictionary_lookup_popup.dart';

/// How long the pointer must rest on text inside the aim corridor before
/// that text is looked up anyway.
const dictionaryPopupAimDwell = Duration(milliseconds: 120);

/// Movement shorter than this is jitter and keeps the previous decision.
const dictionaryPopupAimMinStep = 4.0;

/// Whether a pointer moving from [from] to [to] is heading for [popup].
///
/// The pointer aims at the popup while [to] lies inside the region between
/// [from] and the popup: the triangle from [from] to the popup's far edges.
bool dictionaryPopupAimsAt(Offset from, Offset to, Rect popup) {
  if (popup.contains(from)) return false;
  if (popup.contains(to)) return true;
  final corners = [
    popup.topLeft,
    popup.topRight,
    popup.bottomRight,
    popup.bottomLeft,
  ];
  for (var i = 0; i < corners.length; i++) {
    for (var j = i + 1; j < corners.length; j++) {
      if (_inTriangle(to, from, corners[i], corners[j])) return true;
    }
  }
  return false;
}

bool _inTriangle(Offset p, Offset a, Offset b, Offset c) {
  double cross(Offset o, Offset u, Offset v) =>
      (u.dx - o.dx) * (v.dy - o.dy) - (u.dy - o.dy) * (v.dx - o.dx);
  final d1 = cross(a, b, p);
  final d2 = cross(b, c, p);
  final d3 = cross(c, a, p);
  final negative = d1 < 0 || d2 < 0 || d3 < 0;
  final positive = d1 > 0 || d2 > 0 || d3 > 0;
  return !(negative && positive);
}

/// Whether hover-only lookup should hold the visible popup: Shift freezes it
/// so the pointer can travel anywhere without replacing or closing it.
bool dictionaryPopupHoverFrozen() =>
    DictionaryLookupPopup.isActive && HardwareKeyboard.instance.isShiftPressed;

/// Holds hover lookups back while the pointer travels toward the popup.
///
/// A popup sits beside the text it explains, so reaching it crosses other
/// text. While the pointer keeps moving toward the popup, that text is
/// skipped. Resting on it for [dwell] looks it up after all, and moving in
/// any other direction looks text up immediately again.
class DictionaryPopupAimGuard {
  DictionaryPopupAimGuard({
    Rect? Function()? popupBounds,
    this.dwell = dictionaryPopupAimDwell,
  }) : _popupBounds = popupBounds ?? (() => DictionaryLookupPopup.bounds.value);

  final Rect? Function() _popupBounds;
  final Duration dwell;
  Offset? _apex;
  bool _aiming = false;
  Timer? _dwellTimer;

  bool get aiming => _aiming;

  /// Returns whether the hover at [position] should wait. While it waits,
  /// [onDwell] runs with the latest position once the pointer rests.
  bool defer(Offset position, void Function(Offset position) onDwell) {
    final popup = _popupBounds();
    final apex = _apex;
    if (popup == null || apex == null || popup.contains(position)) {
      reset();
      _apex = position;
      return false;
    }
    if ((position - apex).distance < dictionaryPopupAimMinStep) {
      // Jitter keeps the decision and the pending dwell timer.
      if (_aiming) _restartDwell(position, onDwell, keepRunning: true);
      return _aiming;
    }
    _apex = position;
    _aiming = dictionaryPopupAimsAt(apex, position, popup);
    if (_aiming) {
      _restartDwell(position, onDwell);
    } else {
      _dwellTimer?.cancel();
      _dwellTimer = null;
    }
    return _aiming;
  }

  Offset? _dwellPosition;
  void Function(Offset position)? _onDwell;

  void _restartDwell(
    Offset position,
    void Function(Offset position) onDwell, {
    bool keepRunning = false,
  }) {
    _dwellPosition = position;
    _onDwell = onDwell;
    if (keepRunning && _dwellTimer != null) return;
    _dwellTimer?.cancel();
    _dwellTimer = Timer(dwell, () {
      _dwellTimer = null;
      _aiming = false;
      final callback = _onDwell;
      final at = _dwellPosition;
      _onDwell = null;
      if (callback != null && at != null) callback(at);
    });
  }

  /// Forgets the pointer path, e.g. when the pointer leaves the text.
  void reset() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _onDwell = null;
    _aiming = false;
    _apex = null;
  }

  void dispose() => reset();
}
