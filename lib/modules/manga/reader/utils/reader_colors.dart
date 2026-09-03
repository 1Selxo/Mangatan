import 'package:flutter/material.dart';

Color readerErrorForegroundColor(Color backgroundColor) {
  final isLight =
      ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.light;
  return (isLight ? Colors.black : Colors.white).withValues(alpha: 0.7);
}
