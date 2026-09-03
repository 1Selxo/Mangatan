import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/mining/screen_ai_component_manager.dart';

void main() {
  test('pins an immutable ScreenAI package and checksum', () {
    expect(ScreenAiComponentManager.version, '153.01');
    expect(
      ScreenAiComponentManager.downloadUri.path,
      contains('/screen-ai/windows-amd64/+/'),
    );
    expect(
      ScreenAiComponentManager.downloadUri.path,
      isNot(endsWith('latest')),
    );
    expect(ScreenAiComponentManager.archiveSha256, hasLength(64));
    expect(
      ScreenAiComponentManager.downloadSize,
      greaterThan(70 * 1024 * 1024),
    );
  });

  test('validates both the ScreenAI library and OCR file list', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'mangatan-screen-ai-test-',
    );
    addTearDown(() => temporary.delete(recursive: true));

    expect(
      ScreenAiComponentManager.isValidComponentDirectory(temporary),
      isFalse,
    );
    await File('${temporary.path}${Platform.pathSeparator}chrome_screen_ai.dll')
        .writeAsBytes(const [1]);
    expect(
      ScreenAiComponentManager.isValidComponentDirectory(temporary),
      isFalse,
    );
    await File('${temporary.path}${Platform.pathSeparator}files_list_ocr.txt')
        .writeAsString('model.binarypb');
    expect(
      ScreenAiComponentManager.isValidComponentDirectory(temporary),
      isFalse,
    );
    await File('${temporary.path}${Platform.pathSeparator}model.binarypb')
        .writeAsBytes(const [1]);
    expect(
      ScreenAiComponentManager.isValidComponentDirectory(temporary),
      isTrue,
    );
  });
}
