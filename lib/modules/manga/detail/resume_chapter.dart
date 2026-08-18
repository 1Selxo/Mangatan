import 'package:mangayomi/models/chapter.dart';

Chapter? selectResumeChapter(
  Iterable<Chapter> chaptersInReadingOrder, {
  Chapter? historyChapter,
}) {
  final chapters = chaptersInReadingOrder.toList();
  var startIndex = 0;

  if (historyChapter != null) {
    final historyIndex = chapters.indexWhere(
      (chapter) =>
          identical(chapter, historyChapter) ||
          (chapter.id != null && chapter.id == historyChapter.id),
    );
    if (historyIndex >= 0) startIndex = historyIndex;
  }

  for (var index = startIndex; index < chapters.length; index++) {
    if (!(chapters[index].isRead ?? false)) return chapters[index];
  }
  for (var index = 0; index < startIndex; index++) {
    if (!(chapters[index].isRead ?? false)) return chapters[index];
  }
  return null;
}
