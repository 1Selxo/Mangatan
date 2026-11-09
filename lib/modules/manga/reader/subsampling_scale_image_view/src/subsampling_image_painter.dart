import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'subsampling_types.dart';
import 'tiling_engine.dart';

/// A lightweight render object widget that displays the subsampled image.
/// It replaces the use of CustomPaint to eliminate ephemeral allocations of CustomPainter.
class SubsamplingImageRenderWidget extends LeafRenderObjectWidget {
  final TilingEngine tilingEngine;
  final double scale;
  final ui.Offset vTranslate;
  final int rotation;
  final int sWidth;
  final int sHeight;
  final bool showDebug;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final Size preferredSize;

  /// The whole original page in source coordinates, for [paintOverlay].
  final ui.Rect? overlaySourceRect;
  final PageOverlayPainter? paintOverlay;
  final Listenable? overlayRepaint;

  const SubsamplingImageRenderWidget({
    super.key,
    required this.tilingEngine,
    required this.scale,
    required this.vTranslate,
    required this.rotation,
    required this.sWidth,
    required this.sHeight,
    required this.showDebug,
    this.color,
    this.colorBlendMode,
    required this.filterQuality,
    required this.preferredSize,
    this.overlaySourceRect,
    this.paintOverlay,
    this.overlayRepaint,
  });

  @override
  RenderSubsamplingImage createRenderObject(BuildContext context) {
    return RenderSubsamplingImage(
        tilingEngine: tilingEngine,
        scale: scale,
        vTranslate: vTranslate,
        rotation: rotation,
        sWidth: sWidth,
        sHeight: sHeight,
        color: color,
        colorBlendMode: colorBlendMode,
        filterQuality: filterQuality,
        preferredSize: preferredSize,
      )
      ..overlaySourceRect = overlaySourceRect
      ..paintOverlay = paintOverlay
      ..overlayRepaint = overlayRepaint;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSubsamplingImage renderObject,
  ) {
    renderObject
      ..tilingEngine = tilingEngine
      ..scale = scale
      ..vTranslate = vTranslate
      ..rotation = rotation
      ..sWidth = sWidth
      ..sHeight = sHeight
      ..color = color
      ..colorBlendMode = colorBlendMode
      ..filterQuality = filterQuality
      ..preferredSize = preferredSize
      ..overlaySourceRect = overlaySourceRect
      ..paintOverlay = paintOverlay
      ..overlayRepaint = overlayRepaint;
  }
}

/// The RenderBox responsible for drawing the visible tiles on the Flutter Canvas.
/// It directly handles global transformations (translation, scale, rotation) without allocating intermediate objects at each frame.
class RenderSubsamplingImage extends RenderBox {
  RenderSubsamplingImage({
    required this._tilingEngine,
    required this._scale,
    required this._vTranslate,
    required this._rotation,
    required this._sWidth,
    required this._sHeight,
    this._color,
    this._colorBlendMode,
    required this._filterQuality,
    required this._preferredSize,
  });

  TilingEngine _tilingEngine;
  TilingEngine get tilingEngine => _tilingEngine;
  set tilingEngine(TilingEngine value) {
    if (_tilingEngine == value) return;
    _tilingEngine = value;
    markNeedsPaint();
  }

  double _scale;
  double get scale => _scale;
  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsPaint();
  }

  ui.Offset _vTranslate;
  ui.Offset get vTranslate => _vTranslate;
  set vTranslate(ui.Offset value) {
    if (_vTranslate == value) return;
    _vTranslate = value;
    markNeedsPaint();
  }

  int _rotation;
  int get rotation => _rotation;
  set rotation(int value) {
    if (_rotation == value) return;
    _rotation = value;
    markNeedsPaint();
  }

  int _sWidth;
  int get sWidth => _sWidth;
  set sWidth(int value) {
    if (_sWidth == value) return;
    _sWidth = value;
    markNeedsLayout();
  }

  int _sHeight;
  int get sHeight => _sHeight;
  set sHeight(int value) {
    if (_sHeight == value) return;
    _sHeight = value;
    markNeedsLayout();
  }

  Color? _color;
  Color? get color => _color;
  set color(Color? value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  BlendMode? _colorBlendMode;
  BlendMode? get colorBlendMode => _colorBlendMode;
  set colorBlendMode(BlendMode? value) {
    if (_colorBlendMode == value) return;
    _colorBlendMode = value;
    markNeedsPaint();
  }

  FilterQuality _filterQuality;
  FilterQuality get filterQuality => _filterQuality;
  set filterQuality(FilterQuality value) {
    if (_filterQuality == value) return;
    _filterQuality = value;
    markNeedsPaint();
  }

  Size _preferredSize;
  Size get preferredSize => _preferredSize;
  set preferredSize(Size value) {
    if (_preferredSize == value) return;
    _preferredSize = value;
    markNeedsLayout();
  }

  final Paint _paint = Paint()..isAntiAlias = true;

  ui.Rect? _overlaySourceRect;
  set overlaySourceRect(ui.Rect? value) {
    if (_overlaySourceRect == value) return;
    _overlaySourceRect = value;
    markNeedsPaint();
  }

  PageOverlayPainter? _paintOverlay;
  set paintOverlay(PageOverlayPainter? value) {
    if (_paintOverlay == value) return;
    _paintOverlay = value;
    markNeedsPaint();
  }

  Listenable? _overlayRepaint;
  set overlayRepaint(Listenable? value) {
    if (_overlayRepaint == value) return;
    if (attached) _overlayRepaint?.removeListener(markNeedsPaint);
    _overlayRepaint = value;
    if (attached) _overlayRepaint?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _overlayRepaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _overlayRepaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    size = constraints.constrain(_preferredSize);
  }

  @override
  bool hitTestSelf(ui.Offset position) => true;

  @override
  void paint(PaintingContext context, ui.Offset offset) {
    if (_sWidth == 0 || _sHeight == 0) return;

    final canvas = context.canvas;
    canvas.save();

    // Applies the offset specific to the RenderBox
    canvas.translate(offset.dx, offset.dy);

    // 1. Applies base transformations (pan & zoom)
    canvas.translate(_vTranslate.dx, _vTranslate.dy);
    canvas.scale(_scale, _scale);

    // 2. Handles the image rotation around its logical origin
    if (_rotation == 90) {
      canvas.rotate(pi / 2);
      canvas.translate(0.0, -_sHeight.toDouble());
    } else if (_rotation == 180) {
      canvas.rotate(pi);
      canvas.translate(-_sWidth.toDouble(), -_sHeight.toDouble());
    } else if (_rotation == 270) {
      canvas.rotate(-pi / 2);
      canvas.translate(-_sWidth.toDouble(), 0.0);
    }

    _paint.filterQuality = _filterQuality;

    // Applies color blending if requested
    if (_color != null) {
      _paint.colorFilter = ColorFilter.mode(
        _color!,
        _colorBlendMode ?? BlendMode.srcIn,
      );
    } else {
      _paint.colorFilter = null;
    }

    // 3. Draws all visible tiles currently loaded using cached sortedKeys
    final sortedKeys = _tilingEngine.sortedKeys;

    for (final sampleSize in sortedKeys) {
      final tiles = _tilingEngine.tileMap[sampleSize] ?? [];
      for (final tile in tiles) {
        if (tile.visible && tile.image != null) {
          final srcRect = ui.Rect.fromLTWH(
            0.0,
            0.0,
            tile.image!.width.toDouble(),
            tile.image!.height.toDouble(),
          );

          canvas.drawImageRect(tile.image!, srcRect, tile.sRect, _paint);
        }
      }
    }

    canvas.restore();
    _paintPageOverlay(canvas, offset);
  }

  void _paintPageOverlay(Canvas canvas, ui.Offset offset) {
    final overlay = _paintOverlay;
    final source = _overlaySourceRect;
    // A turned page would need its boxes turned with it.
    if (overlay == null || source == null || _rotation != 0) return;
    ui.Rect toView(ui.Rect rect) => ui.Rect.fromLTWH(
      _vTranslate.dx + rect.left * _scale,
      _vTranslate.dy + rect.top * _scale,
      rect.width * _scale,
      rect.height * _scale,
    );
    // The page shown, also where it reaches past the view when zoomed: a
    // box half on screen can still be looked up.
    final shown = toView(
      ui.Rect.fromLTWH(0, 0, _sWidth.toDouble(), _sHeight.toDouble()),
    );
    if (shown.isEmpty) return;
    overlay(canvas, offset, toView(source), shown);
  }
}
