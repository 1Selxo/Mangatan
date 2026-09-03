import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/modules/manga/detail/resume_chapter.dart';

void main() {
  test('a new manga resumes at its earliest unread chapter', () {
    final first = _chapter(1, isRead: false);
    final second = _chapter(2, isRead: false);

    expect(selectResumeChapter([first, second]), same(first));
  });

  test('a partially read history chapter remains the resume target', () {
    final first = _chapter(1, isRead: true);
    final second = _chapter(2, isRead: false);
    final third = _chapter(3, isRead: false);

    expect(
      selectResumeChapter([first, second, third], historyChapter: second),
      same(second),
    );
  });

  test('a completed history chapter advances to the next unread chapter', () {
    final first = _chapter(1, isRead: true);
    final second = _chapter(2, isRead: false);

    expect(
      selectResumeChapter([first, second], historyChapter: first),
      same(second),
    );
  });
}

Chapter _chapter(int id, {required bool isRead}) {
  return Chapter(id: id, mangaId: 1, name: 'Chapter $id', isRead: isRead);
}
