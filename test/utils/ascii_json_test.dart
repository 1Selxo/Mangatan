import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/utils/ascii_json.dart';

void main() {
  test('reads back to the same value, ASCII only', () {
    final value = {
      'name': '年代 Ünïcödé',
      'emoji': '📚 manga',
      'nested': [
        {'title': 'Ελληνικά', 'n': 1},
        'плохо',
      ],
      'plain': 'ascii "quoted" \ backslash',
    };
    final escaped = asciiJson(jsonEncode(value));

    expect(escaped.codeUnits.every((c) => c < 128), isTrue);
    expect(jsonDecode(escaped), value);
  });

  test('leaves ASCII JSON alone', () {
    const json = '[{"key":"quality","value":1}]';
    expect(identical(asciiJson(json), json), isTrue);
  });

  test('an absent value stays absent', () {
    expect(asciiJsonOrNull(null), isNull);
  });
}
