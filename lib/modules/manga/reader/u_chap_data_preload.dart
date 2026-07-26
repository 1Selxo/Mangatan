import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/page.dart';
import 'package:mangayomi/services/get_chapter_pages.dart';

class UChapDataPreload {
  Chapter? chapter;
  Directory? directory;
  PageUrl? pageUrl;
  bool? isLocale;
  Uint8List? archiveImage;
  int? index;
  GetChapterPagesModel? chapterUrlModel;
  int? pageIndex;
  String? localArtifactPath;
  Uint8List? cropImage;
  bool isTransitionPage;
  Chapter? nextChapter;
  String? mangaName;
  bool? isLastChapter;
  Rect? srcRect;

  /// Cached rendered dimensions (set after image first loads)
  double? loadedHeight;
  double? loadedWidth;

  /// Cached decoded image for tiled rendering.
  Image? decodedImage;

  /// Cached local file path for the subsampling image view.
  String? resolvedFilePath;

  UChapDataPreload(
    this.chapter,
    this.directory,
    this.pageUrl,
    this.isLocale,
    this.archiveImage,
    this.index,
    this.chapterUrlModel,
    this.pageIndex, {
    this.localArtifactPath,
    this.cropImage,
    this.isTransitionPage = false,
    this.nextChapter,
    this.mangaName,
    this.isLastChapter = false,
    this.srcRect,
  });

  UChapDataPreload.transition({
    required Chapter currentChapter,
    required this.nextChapter,
    required String this.mangaName,
    required int this.pageIndex,
    this.isLastChapter = false,
  }) : chapter = currentChapter,
       isTransitionPage = true,
       directory = null,
       pageUrl = null,
       isLocale = null,
       archiveImage = null,
       index = null,
       chapterUrlModel = null,
       localArtifactPath = null,
       cropImage = null,
       srcRect = null;
}
