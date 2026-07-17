import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/mining/mokuro_extension_ocr.dart';
import 'package:mangayomi/services/mining/mokuro_sidecar.dart';
import 'package:mangayomi/services/mining/mokuro_sidecar_path.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    MokuroExtensionOcrClient.clearCache();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mangatan-mokuro-sidecar-',
    );
  });

  tearDown(() async {
    MokuroExtensionOcrClient.clearCache();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('saves the original Mokuro bytes beside a downloaded CBZ', () async {
    final bytes = utf8.encode(jsonEncode(_volumeJson));
    var requests = 0;
    final store = MokuroSidecarStore(
      client: MockClient((request) async {
        requests++;
        expect(request.headers['Referer'], MokuroExtensionOcrClient.catalogUrl);
        return http.Response.bytes(bytes, 200);
      }),
    );
    final cbz = File(p.join(temporaryDirectory.path, 'Volume 1.cbz'));
    await cbz.writeAsBytes(const [1]);

    final saved = await store.ensureDownloaded(
      sourceName: 'Mokuro',
      chapterUrl: 'series|volume',
      artifact: cbz,
    );

    final sidecar = mokuroSidecarFor(cbz);
    expect(saved, isTrue);
    expect(requests, 1);
    expect(await sidecar.readAsBytes(), bytes);
    expect(
      temporaryDirectory.listSync().where(
        (entity) => entity.path.contains('.part-'),
      ),
      isEmpty,
    );
    store.close();
  });

  test('stores folder downloads inside the chapter directory', () async {
    final store = MokuroSidecarStore(
      client: MockClient((_) async => _volumeResponse()),
    );
    final chapterDirectory = Directory(
      p.join(temporaryDirectory.path, 'Volume_1'),
    );
    await chapterDirectory.create();

    expect(
      await store.ensureDownloaded(
        sourceName: 'Mokuro',
        chapterUrl: 'series|volume',
        artifact: chapterDirectory,
      ),
      isTrue,
    );

    expect(
      await File(p.join(chapterDirectory.path, 'Volume_1.mokuro')).exists(),
      isTrue,
    );
    store.close();
  });

  test('does not fetch again when a valid sidecar already exists', () async {
    var requests = 0;
    final store = MokuroSidecarStore(
      client: MockClient((_) async {
        requests++;
        return _volumeResponse();
      }),
    );
    final cbz = File(p.join(temporaryDirectory.path, 'Volume.cbz'));
    await cbz.writeAsBytes(const [1]);
    await mokuroSidecarFor(cbz).writeAsString(jsonEncode(_volumeJson));

    expect(
      await store.ensureDownloaded(
        sourceName: 'Mokuro',
        chapterUrl: 'series|volume',
        artifact: cbz,
      ),
      isTrue,
    );
    expect(requests, 0);
    store.close();
  });

  test('leaves no sidecar or partial file for invalid data', () async {
    final store = MokuroSidecarStore(
      client: MockClient((_) async => http.Response('<html>', 200)),
    );
    final cbz = File(p.join(temporaryDirectory.path, 'Volume.cbz'));
    await cbz.writeAsBytes(const [1]);

    expect(
      await store.ensureDownloaded(
        sourceName: 'Mokuro',
        chapterUrl: 'series|volume',
        artifact: cbz,
      ),
      isFalse,
    );
    expect(await mokuroSidecarFor(cbz).exists(), isFalse);
    expect(
      temporaryDirectory.listSync().where(
        (entity) => entity.path.contains('.part-'),
      ),
      isEmpty,
    );
    store.close();
  });

  test('does nothing for chapters outside the Mokuro extension', () async {
    var requests = 0;
    final store = MokuroSidecarStore(
      client: MockClient((_) async {
        requests++;
        return _volumeResponse();
      }),
    );
    final cbz = File(p.join(temporaryDirectory.path, 'Volume.cbz'));
    await cbz.writeAsBytes(const [1]);

    expect(
      await store.ensureDownloaded(
        sourceName: 'Other',
        chapterUrl: 'series|volume',
        artifact: cbz,
      ),
      isFalse,
    );
    expect(requests, 0);
    store.close();
  });
}

const _volumeJson = {
  'title': 'Example',
  'volume': '1',
  'pages': [
    {'img_path': '001.jpg', 'img_width': 100, 'img_height': 100, 'blocks': []},
  ],
};

http.Response _volumeResponse() => http.Response.bytes(
  utf8.encode(jsonEncode(_volumeJson)),
  200,
  headers: const {'content-type': 'application/octet-stream'},
);
