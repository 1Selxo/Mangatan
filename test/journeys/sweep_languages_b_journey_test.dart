// Part of the screen sweep: see sweep_support.dart.
import 'dart:ui' show Locale;

import 'sweep_support.dart';

void main() {
  sweepTranslations(const [
    Locale('ru'),
    Locale('ja'),
    Locale('zh'),
    Locale('ar'),
  ]);
}
