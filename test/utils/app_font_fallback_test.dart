import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/app_font_fallback.dart';

void main() {
  test('adds the bundled Japanese font to menu text styles', () {
    final theme = applyAppFontFallback(
      ThemeData(
        fontFamily: 'ABeeZee',
        textTheme: const TextTheme(
          labelLarge: TextStyle(fontFamily: 'ABeeZee'),
        ),
      ),
    );

    expect(
      theme.textTheme.labelLarge?.fontFamilyFallback,
      contains('MangatanCJK'),
    );
    expect(
      theme.primaryTextTheme.titleLarge?.fontFamilyFallback,
      contains('MangatanCJK'),
    );
  });

  test('uses a compact label size when the bottom menu is crowded', () {
    final theme = applyAppFontFallback(ThemeData());

    expect(appBottomNavigationLabelStyle(theme, 5).fontSize, 11);
    expect(appBottomNavigationLabelStyle(theme, 7).fontSize, 9.5);
    expect(
      appBottomNavigationLabelStyle(theme, 7).fontFamilyFallback,
      contains('MangatanCJK'),
    );
  });
}
