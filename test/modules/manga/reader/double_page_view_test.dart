import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/image_view_paged.dart';
import 'package:mangayomi/modules/manga/reader/providers/color_filter_provider.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_pointer_signals.dart';
import 'package:mangayomi/modules/manga/reader/widgets/double_page_view.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:photo_view/photo_view.dart';

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

  testWidgets('double page spreads follow the selected reading direction', (
    tester,
  ) async {
    for (final (direction, expectedOrder) in [
      (ReadingDirection.leftToRight, [0, 1]),
      (ReadingDirection.rightToLeft, [1, 0]),
    ]) {
      await tester.pumpWidget(
        _reader(
          DoublePageView.vertical(
            pages: [_page(0), _page(1)],
            backgroundColor: BackgroundColor.black,
            readingDirection: direction,
          ),
        ),
      );

      final actualOrder = tester
          .widgetList<ImageViewPaged>(find.byType(ImageViewPaged))
          .map((widget) => widget.data.index)
          .toList();
      expect(actualOrder, expectedOrder);
    }
  });

  testWidgets('paged readers can zoom out to half the default scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _reader(
        DoublePageView.paged(
          pages: [_page(0), _page(1)],
          backgroundColor: BackgroundColor.black,
        ),
      ),
    );

    final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
    final imageViews = tester.widgetList<ImageViewPaged>(
      find.byType(ImageViewPaged),
    );
    expect(find.byType(PhotoView), findsOneWidget);
    expect(imageViews, hasLength(2));
    expect(imageViews.every((view) => !view.enableGestures), isTrue);
    expect(photoView.minScale, readerMinimumZoomScale);
    expect(photoView.controller!.scale, readerDefaultZoomScale);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    addTearDown(
      () async => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: tester.getCenter(find.byType(DoublePageView)),
        scrollDelta: const Offset(0, 1000),
      ),
    );
    await tester.pump();

    expect(photoView.controller!.scale, readerMinimumZoomScale);
    final leftPageRect = tester.getRect(find.byType(ImageViewPaged).at(0));
    final rightPageRect = tester.getRect(find.byType(ImageViewPaged).at(1));
    expect(leftPageRect.top, closeTo(rightPageRect.top, 0.01));
    expect(leftPageRect.bottom, closeTo(rightPageRect.bottom, 0.01));
    expect(leftPageRect.right, closeTo(rightPageRect.left, 0.01));
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
