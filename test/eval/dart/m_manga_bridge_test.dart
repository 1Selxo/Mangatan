import 'package:d4rt/d4rt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/dart/bridge/m_manga.dart';
import 'package:mangayomi/eval/model/m_chapter.dart';

void main() {
  test('unwraps D4rt chapter instances before storing manga details', () {
    final chapter = MChapter(name: 'Chapter 1', url: '/g/123/1');
    final bridgedChapter = BridgedInstance(
      BridgedClass(nativeType: MChapter, name: 'MChapter'),
      chapter,
    );

    final chapters = unwrapBridgedList<MChapter>([bridgedChapter]);

    expect(chapters, hasLength(1));
    expect(chapters.single, same(chapter));
  });

  test('rejects an unexpected bridged chapter value immediately', () {
    expect(
      () => unwrapBridgedList<MChapter>(['not a chapter']),
      throwsStateError,
    );
  });
}
