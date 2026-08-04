import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/extension_repository_catalog.dart';

void main() {
  test('decodes a gzip-compressed Mihon v2 protobuf index', () async {
    final source = _message([
      _varintField(1, -42, signed64: true),
      _stringField(2, 'Example Source'),
      _stringField(3, 'en'),
      _stringField(4, 'https://reader.example'),
    ]);
    final resources = _message([
      _stringField(1, 'apk/example.apk'),
      _stringField(2, 'icons/example.png'),
    ]);
    final extension = _message([
      _stringField(1, 'Tachiyomi: Example'),
      _stringField(2, 'eu.kanade.tachiyomi.extension.en.example'),
      _messageField(3, resources),
      _stringField(4, '1.4'),
      _varintField(5, 17),
      _stringField(6, '1.4.17'),
      _varintField(7, 2),
      _messageField(8, source),
    ]);
    final extensionList = _message([_messageField(1, extension)]);
    final contact = _message([
      _stringField(1, 'https://repo.example'),
      _stringField(2, 'https://discord.example'),
    ]);
    final index = _message([
      _stringField(1, 'Example repository'),
      _stringField(2, 'Example'),
      _stringField(3, 'sha256-key'),
      _messageField(4, contact),
      _messageField(101, extensionList),
    ]);

    final catalog = await loadExtensionRepositoryCatalog(
      Uri.parse('https://repo.example/catalog/index.pb'),
      (_) async => Uint8List.fromList(gzip.encode(index)),
    );

    expect(catalog.name, 'Example repository');
    expect(catalog.website, 'https://repo.example');
    expect(catalog.entries, hasLength(1));
    final entry = catalog.entries.single;
    expect(entry['version'], '1.4.17');
    expect(entry['code'], 17);
    expect(entry['lang'], 'en');
    expect(entry['nsfw'], 1);
    expect(entry['_apkUrl'], 'https://repo.example/catalog/apk/example.apk');
    expect(entry['_iconUrl'], 'https://repo.example/catalog/icons/example.png');
    expect(entry['sources'], [
      {
        'id': '-42',
        'name': 'Example Source',
        'lang': 'en',
        'baseUrl': 'https://reader.example',
      },
    ]);
  });

  test('follows a Mihon repo.json pointer to a protobuf index', () async {
    final extensionList = _message([]);
    final index = _message([
      _stringField(1, 'Pointer target'),
      _stringField(2, 'Target'),
      _stringField(3, 'key'),
      _messageField(4, _message([_stringField(1, 'https://example.test')])),
      _messageField(101, extensionList),
    ]);
    final requested = <Uri>[];

    final catalog = await loadExtensionRepositoryCatalog(
      Uri.parse('https://example.test/repo.json'),
      (uri) async {
        requested.add(uri);
        if (uri.path.endsWith('repo.json')) {
          return Uint8List.fromList(
            utf8.encode('{"index_v2":"index.pb","meta":{}}'),
          );
        }
        return Uint8List.fromList(index);
      },
    );

    expect(requested.map((uri) => uri.toString()), [
      'https://example.test/repo.json',
      'https://example.test/index.pb',
    ]);
    expect(catalog.name, 'Pointer target');
  });

  test('keeps legacy JSON indexes compatible', () async {
    final legacy = utf8.encode(
      '[{"name":"Legacy","pkg":"pkg","version":"1.0",'
      '"code":1,"lang":"en","nsfw":0,"sources":[],"apk":"x.apk"}]',
    );
    final catalog = await loadExtensionRepositoryCatalog(
      Uri.parse('https://example.test/index.min.json'),
      (_) async => Uint8List.fromList(legacy),
    );

    expect(catalog.entries.single['name'], 'Legacy');
  });
}

List<int> _message(List<List<int>> fields) => [
  for (final field in fields) ...field,
];

List<int> _stringField(int number, String value) =>
    _messageField(number, utf8.encode(value));

List<int> _messageField(int number, List<int> value) => [
  ..._varint((number << 3) | 2),
  ..._varint(value.length),
  ...value,
];

List<int> _varintField(int number, int value, {bool signed64 = false}) => [
  ..._varint(number << 3),
  ...(signed64 && value < 0 ? _negativeInt64Varint(value) : _varint(value)),
];

List<int> _negativeInt64Varint(int value) {
  final result = <int>[];
  for (var index = 0; index < 9; index++) {
    result.add((value & 0x7f) | 0x80);
    value >>= 7;
  }
  result.add(1);
  return result;
}

List<int> _varint(int value) {
  final result = <int>[];
  do {
    var byte = value & 0x7f;
    value >>= 7;
    if (value != 0) byte |= 0x80;
    result.add(byte);
  } while (value != 0);
  return result;
}
