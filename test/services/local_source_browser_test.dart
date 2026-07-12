import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/local_source_browser.dart';

void main() {
  test('keeps a number-prefixed Japanese title in local browse results', () {
    final entries = <String>[
      for (var i = 0; i < 55; i++) '作品${i.toString().padLeft(3, '0')}',
      '100回まわって愛を啼け',
    ].reversed;

    final firstPage = buildLocalSourcePage(entries, page: 1);
    final secondPage = buildLocalSourcePage(entries, page: 2);
    final names = [
      ...firstPage.list.map((entry) => entry.name),
      ...secondPage.list.map((entry) => entry.name),
    ];

    expect(firstPage.list.first.name, '100回まわって愛を啼け');
    expect(names, contains('100回まわって愛を啼け'));
    expect(names.toSet(), hasLength(56));
    expect(firstPage.hasNextPage, isTrue);
    expect(secondPage.hasNextPage, isFalse);
  });

  test('searches number-prefixed local titles without stripping digits', () {
    final result = buildLocalSourcePage(
      ['100回まわって愛を啼け', '回まわって愛を啼け'],
      page: 1,
      query: '100回',
    );

    expect(result.list.map((entry) => entry.name), ['100回まわって愛を啼け']);
    expect(result.hasNextPage, isFalse);
  });
}
