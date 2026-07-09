import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/image_view_paged.dart';
import 'package:mangayomi/modules/manga/reader/providers/color_filter_provider.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/widgets/double_page_view.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';

void main() {
  testWidgets('double page spreads disable per-page zoom gestures', (
    tester,
  ) async {
    await tester.pumpWidget(
      _reader(
        DoublePageView.vertical(
          pages: [_page(0), _page(1)],
          backgroundColor: BackgroundColor.black,
        ),
      ),
    );

    final imageViews = tester.widgetList<ImageViewPaged>(
      find.byType(ImageViewPaged),
    );

    expect(imageViews, hasLength(2));
    expect(imageViews.every((widget) => !widget.enableGestures), isTrue);
  });
}

Widget _reader(Widget child) {
  return ProviderScope(
    overrides: [
      cropBordersStateProvider.overrideWithValue(false),
      scaleTypeStateProvider.overrideWithValue(ScaleType.fitScreen),
      customColorFilterStateProvider.overrideWithValue(null),
      colorFilterBlendModeStateProvider.overrideWithValue(
        ColorFilterBlendMode.none,
      ),
      invertColorsStateProvider.overrideWithValue(false),
      grayscaleStateProvider.overrideWithValue(false),
      readerBrightnessStateProvider.overrideWithValue(0),
      readerContrastStateProvider.overrideWithValue(1),
      readerSaturationStateProvider.overrideWithValue(1),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

UChapDataPreload _page(int index) {
  return UChapDataPreload(
    null,
    null,
    null,
    true,
    _transparentImage,
    index,
    null,
    index,
  );
}

final Uint8List _transparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l83bEwAAAABJRU5ErkJggg==',
);
