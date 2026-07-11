import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/l10n/generated/app_localizations.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/image_view_paged.dart';
import 'package:mangayomi/modules/manga/reader/image_view_webtoon.dart';
import 'package:mangayomi/modules/manga/reader/image_view_vertical.dart';
import 'package:mangayomi/modules/manga/reader/providers/color_filter_provider.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/utils/reader_pointer_signals.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  testWidgets('unmodified wheel pages forward and backward', (tester) async {
    var page = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => registerPagedReaderWheelScroll(
            event,
            onPreviousPage: () => page--,
            onNextPage: () => page++,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, 40));
    expect(page, 2);
    await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, -40));
    expect(page, 1);
  });

  testWidgets('modifier wheel does not turn paged-reader pages', (
    tester,
  ) async {
    var page = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => registerPagedReaderWheelScroll(
            event,
            onPreviousPage: () => page--,
            onNextPage: () => page++,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    addTearDown(
      () async => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft),
    );

    await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, 80));
    expect(page, 1);
  });

  testWidgets('each rapid paged wheel notch turns exactly one page', (
    tester,
  ) async {
    var page = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => registerPagedReaderWheelScroll(
            event,
            onPreviousPage: () => page--,
            onNextPage: () => page++,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, 40));
    }
    expect(page, 5);
  });

  testWidgets('a large paged wheel delta still turns only one page', (
    tester,
  ) async {
    var page = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerSignal: (event) => registerPagedReaderWheelScroll(
            event,
            onPreviousPage: () => page--,
            onNextPage: () => page++,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, 400));
    expect(page, 1);
  });

  testWidgets('paged reader wins wheel signals over descendant image zoom', (
    tester,
  ) async {
    var pageTurns = 0;
    var descendantZooms = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPointerSignalInterceptor(
          onPointerSignal: (event) => registerPagedReaderWheelScroll(
            event,
            onPreviousPage: () => pageTurns--,
            onNextPage: () => pageTurns++,
          ),
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerSignal: (event) {
              GestureBinding.instance.pointerSignalResolver.register(
                event,
                (_) => descendantZooms++,
              );
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, 400));
    expect(pageTurns, 1);
    expect(descendantZooms, 0);
  });

  testWidgets('rapid paged wheel notches each jump exactly one page', (
    tester,
  ) async {
    final controller = PageController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPointerSignalInterceptor(
          onPointerSignal: (event) => registerPagedReaderWheelScroll(
            event,
            onPreviousPage: () {
              final page = controller.page!.round();
              controller.jumpToPage((page - 1).clamp(0, 9));
            },
            onNextPage: () {
              final page = controller.page!.round();
              controller.jumpToPage((page + 1).clamp(0, 9));
            },
          ),
          child: PageView.builder(
            controller: controller,
            itemCount: 10,
            itemBuilder: (_, index) => Center(child: Text('$index')),
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await _sendScrollAt(tester, const Offset(100, 100), const Offset(0, 400));
    }

    expect(controller.page, 5);
    expect(find.text('5'), findsOneWidget);
  });

  for (final mode in [
    ReaderMode.verticalContinuous,
    ReaderMode.webtoon,
    ReaderMode.horizontalContinuous,
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

    testWidgets('$mode can zoom out to half the default scale', (tester) async {
      final photoViewController = PhotoViewController(initialScale: 1);

      await tester.pumpWidget(
        _reader(mode: mode, photoViewController: photoViewController),
      );
      expect(photoViewController.scale, readerDefaultZoomScale);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      addTearDown(
        () async => tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft),
      );

      await _sendScroll(tester, const Offset(0, 1000));
      await tester.pump();
      await tester.pump();

      expect(photoViewController.scale, readerMinimumZoomScale);
    });

    for (final readingDirection
        in mode.isHorizontalContinuous
            ? ReadingDirection.values
            : [ReadingDirection.leftToRight]) {
      testWidgets(
        '$mode $readingDirection reveals adjacent pages when zoomed out',
        (tester) async {
          final photoViewController = PhotoViewController(initialScale: 1);
          final longPressedPages = <int>[];
          final itemPositionsListener = ItemPositionsListener.create();

          await tester.pumpWidget(
            _reader(
              mode: mode,
              readingDirection: readingDirection,
              pages: List.generate(5, _page),
              initialScrollIndex: 2,
              photoViewController: photoViewController,
              itemPositionsListener: itemPositionsListener,
              onLongPressData: (page) => longPressedPages.add(page.index!),
            ),
          );
          final readerRect = tester.getRect(find.byType(ImageViewWebtoon));
          final currentPage = _verticalPage(2);
          final currentPageRectAtDefaultScale = tester.getRect(currentPage);

          photoViewController.scale = readerMinimumZoomScale;
          await tester.pump();
          await tester.pump();

          final listSize = tester.getSize(
            find.byType(ScrollablePositionedList),
          );
          if (mode.isHorizontalContinuous) {
            expect(
              listSize.width,
              closeTo(readerRect.width / readerMinimumZoomScale, 0.01),
            );
            expect(listSize.height, closeTo(readerRect.height, 0.01));
          } else {
            expect(listSize.width, closeTo(readerRect.width, 0.01));
            expect(
              listSize.height,
              closeTo(readerRect.height / readerMinimumZoomScale, 0.01),
            );
          }
          expect(
            tester.getRect(currentPage),
            _scaleRectAroundCenter(
              currentPageRectAtDefaultScale,
              readerRect.center,
              readerMinimumZoomScale,
            ),
          );

          for (final pageIndex in [1, 3]) {
            final page = _verticalPage(pageIndex);
            expect(page, findsOneWidget);

            final visibleRect = tester.getRect(page).intersect(readerRect);
            expect(visibleRect.isEmpty, isFalse);

            if (!readingDirection.isRtl) {
              await tester.longPressAt(visibleRect.center);
              expect(
                longPressedPages,
                contains(pageIndex),
                reason:
                    'pageRect=${tester.getRect(page)}, '
                    'visibleRect=$visibleRect, '
                    'positions=${itemPositionsListener.itemPositions.value}',
              );
            }
          }

          photoViewController.scale = readerDefaultZoomScale;
          await tester.pump();
          await tester.pump();
          expect(tester.getRect(currentPage), currentPageRectAtDefaultScale);
        },
      );
    }
  }

  testWidgets('continuous double-page spreads stay unified when zoomed out', (
    tester,
  ) async {
    final photoViewController = PhotoViewController(initialScale: 1);

    await tester.pumpWidget(
      _reader(
        mode: ReaderMode.verticalContinuous,
        pages: List.generate(10, _page),
        initialScrollIndex: 2,
        isDoublePageMode: true,
        pageMode: PageMode.doublePage,
        photoViewController: photoViewController,
      ),
    );
    final readerRect = tester.getRect(find.byType(ImageViewWebtoon));
    final currentLeftPage = _pagedImage(4);
    final currentRightPage = _pagedImage(5);
    final currentSpreadAtDefaultScale = tester
        .getRect(currentLeftPage)
        .expandToInclude(tester.getRect(currentRightPage));

    photoViewController.scale = readerMinimumZoomScale;
    await tester.pump();
    await tester.pump();

    expect(find.byType(PhotoView), findsOneWidget);
    final imageViews = tester.widgetList<ImageViewPaged>(
      find.byType(ImageViewPaged, skipOffstage: false),
    );
    expect(imageViews, isNotEmpty);
    expect(imageViews.every((view) => !view.enableGestures), isTrue);

    final currentLeftRect = tester.getRect(currentLeftPage);
    final currentRightRect = tester.getRect(currentRightPage);
    expect(currentLeftRect.top, closeTo(currentRightRect.top, 0.01));
    expect(currentLeftRect.bottom, closeTo(currentRightRect.bottom, 0.01));
    expect(currentLeftRect.right, closeTo(currentRightRect.left, 0.01));
    expect(
      currentLeftRect.expandToInclude(currentRightRect),
      _scaleRectAroundCenter(
        currentSpreadAtDefaultScale,
        readerRect.center,
        readerMinimumZoomScale,
      ),
    );

    for (final pageIndex in [2, 3, 6, 7]) {
      expect(
        tester.getRect(_pagedImage(pageIndex)).overlaps(readerRect),
        isTrue,
      );
    }
  });

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

  for (final direction in ReadingDirection.values) {
    testWidgets('vertical wheel scrolls horizontal continuous $direction', (
      tester,
    ) async {
      final itemPositionsListener = ItemPositionsListener.create();

      await tester.pumpWidget(
        _reader(
          mode: ReaderMode.horizontalContinuous,
          readingDirection: direction,
          itemPositionsListener: itemPositionsListener,
        ),
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
  ReadingDirection readingDirection = ReadingDirection.leftToRight,
  List<UChapDataPreload>? pages,
  int initialScrollIndex = 0,
  bool isDoublePageMode = false,
  PageMode pageMode = PageMode.onePage,
  PhotoViewController? photoViewController,
  ScrollOffsetController? scrollOffsetController,
  ItemPositionsListener? itemPositionsListener,
  ValueChanged<UChapDataPreload>? onLongPressData,
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
          pages: pages ?? List.generate(3, _page),
          itemScrollController: ItemScrollController(),
          scrollOffsetController:
              scrollOffsetController ?? ScrollOffsetController(),
          itemPositionsListener:
              itemPositionsListener ?? ItemPositionsListener.create(),
          scrollDirection: isHorizontal ? Axis.horizontal : Axis.vertical,
          minCacheExtent: 0,
          initialScrollIndex: initialScrollIndex,
          physics: const ClampingScrollPhysics(),
          onLongPressData: onLongPressData ?? (_) {},
          onFailedToLoadImage: (_) {},
          backgroundColor: BackgroundColor.black,
          isDoublePageMode: isDoublePageMode,
          pageMode: pageMode,
          isHorizontalContinuous: isHorizontal,
          readerMode: mode,
          readingDirection: readingDirection,
          photoViewController:
              photoViewController ?? PhotoViewController(initialScale: 1),
          photoViewScaleStateController: PhotoViewScaleStateController(),
          scalePosition: Alignment.center,
          onDoubleTapDown: (_) {},
          onDoubleTap: () {},
          isScrolling: ValueNotifier(false),
          reverse: isHorizontal && readingDirection.isRtl,
        ),
      ),
    ),
  );
}

Finder _verticalPage(int index) => find.byWidgetPredicate(
  (widget) => widget is ImageViewVertical && widget.data.index == index,
  skipOffstage: false,
);

Finder _pagedImage(int index) => find.byWidgetPredicate(
  (widget) => widget is ImageViewPaged && widget.data.index == index,
  skipOffstage: false,
);

Rect _scaleRectAroundCenter(Rect rect, Offset center, double scale) {
  Offset scalePoint(Offset point) => center + (point - center) * scale;
  return Rect.fromPoints(
    scalePoint(rect.topLeft),
    scalePoint(rect.bottomRight),
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
