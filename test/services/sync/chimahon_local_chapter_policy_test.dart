import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/services/sync/chimahon_local_chapter_policy.dart';

void main() {
  const policy = ChimahonLocalChapterPolicy();

  Chapter chapter({
    String? url = '',
    String? name = 'Chapter 1',
    String? archivePath = '',
    double? number,
  }) => Chapter(
    mangaId: 1,
    name: name,
    url: url,
    archivePath: archivePath,
    chapterNumber: number,
  );

  test('keeps desktop file identities in the device-local overlay', () {
    for (final path in <String>[
      '/Users/reader/Books/chapter.cbz',
      '/Volumes/Books/chapter.cbz',
      '/home/reader/Books/chapter.cbz',
      '/run/user/1000/doc/chapter.cbz',
      '/var/home/reader/Books/chapter.cbz',
      r'C:\Users\reader\Books\chapter.cbz',
      r'\\server\Books\chapter.cbz',
      'file:///home/reader/Books/chapter.cbz',
    ]) {
      final local = chapter(url: path);
      expect(policy.isDeviceLocal(local), isTrue, reason: path);
      expect(policy.hasPortableIdentity(local), isFalse, reason: path);
    }
  });

  test('keeps source chapters portable when their cache is device-local', () {
    final downloaded = chapter(
      url: '/source/chapter/1',
      archivePath: '/home/reader/Downloads/chapter.cbz',
      number: 1,
    );

    expect(policy.isDeviceLocal(downloaded), isFalse);
    expect(policy.hasPortableIdentity(downloaded), isTrue);
  });

  test('uses the same complete predicate for local and wire identities', () {
    expect(
      policy.hasPortableWireIdentity(
        url: '/source/chapter/1',
        name: 'Chapter 1',
        chapterNumber: 1,
      ),
      isTrue,
    );
    expect(
      policy.hasPortableWireIdentity(
        url: '/Users/reader/Books/chapter.cbz',
        name: 'Chapter 1',
        chapterNumber: 1,
      ),
      isFalse,
    );
    expect(
      policy.hasPortableWireIdentity(
        url: '/source/chapter/1',
        name: '   ',
        chapterNumber: 1,
      ),
      isFalse,
    );
    expect(
      policy.hasPortableWireIdentity(
        url: '/source/chapter/1',
        name: 'Chapter 1',
        chapterNumber: double.nan,
      ),
      isFalse,
    );

    // A missing local number is exported as a finite number derived from the
    // name, and therefore remains representable.
    expect(
      policy.hasPortableIdentity(chapter(url: '/source/chapter/2')),
      isTrue,
    );
  });
}
