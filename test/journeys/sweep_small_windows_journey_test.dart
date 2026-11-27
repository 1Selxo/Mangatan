// Part of the screen sweep: see sweep_support.dart.
import 'harness/journey.dart';
import 'sweep_support.dart';

void main() {
  sweepWindows([
    ('phone', phoneWindow, false),
    // 640×480 overflows the library itself (S8), which would fail every
    // screen; this size is just above it.
    ('small window', const Size(700, 540), false),
  ]);
}
