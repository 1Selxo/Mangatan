import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/epub_reader_asset_server.dart';

void main() {
  late Directory root;
  EpubReaderAssetServer? server;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ридер epub ');
  });

  tearDown(() async {
    await server?.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('serves reader assets from a non-ASCII filesystem path', () async {
    final image = File('${root.path}/item/image/章 title.jpg');
    await image.parent.create(recursive: true);
    await image.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
    server = await EpubReaderAssetServer.start(root);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final uri = server!.uriFor(image, queryParameters: {'revision': '1'});
    final response = await (await client.getUrl(uri)).close();
    final bytes = await response.fold<List<int>>(
      <int>[],
      (result, chunk) => result..addAll(chunk),
    );

    expect(server!.owns(uri), isTrue);
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, 'image/jpeg');
    expect(bytes, [0xff, 0xd8, 0xff, 0xd9]);
  });

  test('does not expose files outside the reader session', () async {
    final outside = File('${root.parent.path}/outside-reader.txt');
    await outside.writeAsString('private');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });
    server = await EpubReaderAssetServer.start(root);

    expect(() => server!.uriFor(outside), throwsArgumentError);
  });
}
