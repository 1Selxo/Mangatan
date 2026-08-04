import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/apple_vision_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resolves exact, base, and simplified Chinese languages', () {
    const supported = ['en-US', 'ja-JP', 'zh-Hans', 'zh-Hant'];

    expect(resolveAppleVisionLanguage('ja', supported), 'ja-JP');
    expect(resolveAppleVisionLanguage('en_US', supported), 'en-US');
    expect(resolveAppleVisionLanguage('zh', supported), 'zh-Hans');
    expect(resolveAppleVisionLanguage('ko', supported), isNull);
  });

  test('parses top-left normalized OCR blocks and rejects malformed rows', () {
    final blocks = parseAppleVisionBlocks([
      {
        'text': '日本語',
        'xmin': 0.1,
        'ymin': 0.2,
        'xmax': 0.4,
        'ymax': 0.8,
        'rotation': 0.0,
        'vertical': true,
      },
      {'text': '', 'xmin': 0.0, 'ymin': 0.0, 'xmax': 1.0, 'ymax': 1.0},
      {'text': 'missing bounds'},
    ], language: 'ja');

    expect(blocks, hasLength(1));
    expect(blocks.single.text, '日本語');
    expect(blocks.single.vertical, isTrue);
    expect(blocks.single.ymin, 0.2);
    expect(blocks.single.ymax, 0.8);
    expect(blocks.single.lineGeometries, hasLength(1));
  });

  test(
    'uses the Darwin method-channel contract for recognition',
    () async {
      const channel = MethodChannel('test.apple_vision');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'supportedLanguages') return ['en-US'];
        expect(call.method, 'recognize');
        expect(call.arguments, isA<Map<dynamic, dynamic>>());
        return {
          'imageWidth': 1,
          'imageHeight': 1,
          'blocks': [
            {
              'text': 'A',
              'xmin': 0.1,
              'ymin': 0.2,
              'xmax': 0.5,
              'ymax': 0.7,
              'rotation': 0.0,
              'vertical': false,
            },
          ],
        };
      });
      final client = AppleVisionOcrClient(channel: channel);
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

      final result = await client.recognize(png, language: 'en');

      expect(result.imageWidth, 1);
      expect(result.imageHeight, 1);
      expect(result.blocks.single.text, 'A');
    },
    skip: !AppleVisionOcrClient.isSupportedPlatform,
  );
}
