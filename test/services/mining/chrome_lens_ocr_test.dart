import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/chrome_lens_ocr.dart';

void main() {
  test('decodes Chromium Lens text and normalized geometry', () {
    final response = _message((root) {
      root.message(2, (objects) {
        objects.message(3, (text) {
          text.message(1, (layout) {
            layout.message(1, (paragraph) {
              paragraph.message(2, (line) {
                line.message(1, (word) {
                  word.string(2, '日 本');
                });
                line.message(2, (geometry) {
                  geometry.message(1, (box) {
                    box.float32(1, 0.7);
                    box.float32(2, 0.5);
                    box.float32(3, 0.1);
                    box.float32(4, 0.4);
                    box.float32(5, 0);
                  });
                });
              });
            });
          });
        });
      });
    });

    final client = ChromeLensOcrClient();
    addTearDown(client.close);
    final result = client.decodeResponse(
      response,
      imageWidth: 1000,
      imageHeight: 1600,
      language: 'ja',
    );

    expect(result.blocks, hasLength(1));
    expect(result.blocks.single.text, '日本');
    expect(result.blocks.single.vertical, isTrue);
    expect(result.blocks.single.xmin, closeTo(0.65, 0.001));
    expect(result.blocks.single.ymax, closeTo(0.7, 0.001));
    expect(result.blocks.single.lineGeometries, hasLength(1));
  });
}

Uint8List _message(void Function(_TestProtoWriter writer) build) {
  final writer = _TestProtoWriter();
  build(writer);
  return writer.bytesValue();
}

class _TestProtoWriter {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void string(int field, String value) => bytes(field, utf8.encode(value));

  void float32(int field, double value) {
    _varint((field << 3) | 5);
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    _bytes.add(data.buffer.asUint8List());
  }

  void message(int field, void Function(_TestProtoWriter writer) build) {
    final writer = _TestProtoWriter();
    build(writer);
    bytes(field, writer.bytesValue());
  }

  void bytes(int field, List<int> value) {
    _varint((field << 3) | 2);
    _varint(value.length);
    _bytes.add(value);
  }

  Uint8List bytesValue() => _bytes.toBytes();

  void _varint(int value) {
    var remaining = value;
    while (remaining > 0x7f) {
      _bytes.addByte((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
    _bytes.addByte(remaining);
  }
}
