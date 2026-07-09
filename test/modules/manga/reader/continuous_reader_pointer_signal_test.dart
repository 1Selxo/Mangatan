import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/image_view_webtoon.dart';
import 'package:mangayomi/modules/manga/reader/providers/color_filter_provider.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  for (final mode in [
    ReaderMode.verticalContinuous,
    ReaderMode.webtoon,
    ReaderMode.horizontalContinuous,
    ReaderMode.horizontalContinuousRTL,
  ]) {
    testWidgets('ctrl+scroll zooms $mode without scrolling the list', (
      tester,
    ) async {
      final photoViewController = PhotoViewController(initialScale: 1);
      final itemPositionsListener = ItemPositionsListener.create();

      await tester.pumpWidget(
        _reader(
          mode: mode,
          photoViewController: photoViewController,
          itemPositionsListener: itemPositionsListener,
        ),
      );
      final initialLeadingEdge = _leadingEdge(itemPositionsListener);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      addTearDown(
        () async => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft),
      );

      await _sendScroll(tester, const Offset(0, -120));

      expect(photoViewController.scale, greaterThan(1));
      expect(_leadingEdge(itemPositionsListener), initialLeadingEdge);
    });
  }

  testWidgets('modifier wheel zoom anchors around the pointer', (tester) async {
    final photoViewController = PhotoViewController(initialScale: 1);

    await tester.pumpWidget(
      _reader(
        mode: ReaderMode.horizontalContinuous,
        photoViewController: photoViewController,
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    addTearDown(
      () async => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft),
    );

    final readerRect = tester.getRect(find.byType(ImageViewWebtoon));
    await _sendScrollAt(
      tester,
      readerRect.centerLeft + const Offset(100, 0),
      const Offset(0, -120),
    );

    expect(photoViewController.scale, greaterThan(1));
    expect(photoViewController.position.dx, greaterThan(0));
  });

  testWidgets('cmd+scroll also zooms continuous readers', (tester) async {
    final photoViewController = PhotoViewController(initialScale: 1);

    await tester.pumpWidget(
      _reader(
        mode: ReaderMode.verticalContinuous,
        photoViewController: photoViewController,
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    addTearDown(() async => tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft));

    await _sendScroll(tester, const Offset(0, -120));

    expect(photoViewController.scale, greaterThan(1));
  });

  for (final mode in [
    ReaderMode.horizontalContinuous,
    ReaderMode.horizontalContinuousRTL,
  ]) {
    testWidgets('vertical wheel scrolls $mode by the wheel delta', (
      tester,
    ) async {
      final itemPositionsListener = ItemPositionsListener.create();

      await tester.pumpWidget(
        _reader(mode: mode, itemPositionsListener: itemPositionsListener),
      );
      final viewportWidth = tester.getSize(find.byType(ImageViewWebtoon)).width;
      final initialLeadingEdge = _leadingEdge(itemPositionsListener);

      await _sendScroll(tester, const Offset(0, 80));
      await tester.pump();
      final forwardLeadingEdge = _leadingEdge(itemPositionsListener);

      await _sendScroll(tester, const Offset(0, -40));
      await tester.pump();
      final backwardLeadingEdge = _leadingEdge(itemPositionsListener);

      expect(
        forwardLeadingEdge - initialLeadingEdge,
        closeTo(-80 / viewportWidth, 0.01),
      );
      expect(
        backwardLeadingEdge - forwardLeadingEdge,
        closeTo(40 / viewportWidth, 0.01),
      );
    });
  }
}

Widget _reader({
  required ReaderMode mode,
  PhotoViewController? photoViewController,
  ScrollOffsetController? scrollOffsetController,
  ItemPositionsListener? itemPositionsListener,
}) {
  final isHorizontal = mode.isHorizontalContinuous;

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
      home: Scaffold(
        body: ImageViewWebtoon(
          pages: List.generate(3, _page),
          itemScrollController: ItemScrollController(),
          scrollOffsetController:
              scrollOffsetController ?? ScrollOffsetController(),
          itemPositionsListener:
              itemPositionsListener ?? ItemPositionsListener.create(),
          scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
          minCacheExtent: 0,
          initialScrollIndex: 0,
          physics: const ClampingScrollPhysics(),
          onLongPressData: (_) {},
          onFailedToLoadImage: (_) {},
          backgroundColor: BackgroundColor.black,
          isDoublePageMode: false,
          pageMode: PageMode.onePage,
          isHorizontalContinuous: isHorizontal,
          readerMode: mode,
          photoViewController:
              photoViewController ?? PhotoViewController(initialScale: 1),
          photoViewScaleStateController: PhotoViewScaleStateController(),
          scalePosition: Alignment.center,
          onScaleEnd: (_) {},
          onDoubleTapDown: (_) {},
          onDoubleTap: () {},
          isScrolling: ValueNotifier(false),
          reverse: mode.isRTL,
        ),
      ),
    ),
  );
}

Future<void> _sendScroll(WidgetTester tester, Offset scrollDelta) async {
  final position = tester.getCenter(find.byType(ImageViewWebtoon));
  await _sendScrollAt(tester, position, scrollDelta);
}

Future<void> _sendScrollAt(
  WidgetTester tester,
  Offset position,
  Offset scrollDelta,
) async {
  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: position,
      scrollDelta: scrollDelta,
    ),
  );
  await tester.pump();
}

double _leadingEdge(ItemPositionsListener listener) {
  return listener.itemPositions.value
      .where((position) => position.index == 0)
      .single
      .itemLeadingEdge;
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
