import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_colors.dart';

void main() {
  test('reader errors contrast with light and dark backgrounds', () {
    expect(
      readerErrorForegroundColor(Colors.white),
      Colors.black.withValues(alpha: 0.7),
    );
    expect(
      readerErrorForegroundColor(Colors.black),
      Colors.white.withValues(alpha: 0.7),
    );
  });
}
