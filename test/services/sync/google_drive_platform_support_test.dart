import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/services/sync/google_drive_platform_support.dart';

void main() {
  test('Google Drive Chimahon sync uses one shared desktop platform set', () {
    expect(supportsGoogleDriveChimahonSync(TargetPlatform.macOS), isTrue);
    expect(supportsGoogleDriveChimahonSync(TargetPlatform.windows), isTrue);
    expect(supportsGoogleDriveChimahonSync(TargetPlatform.linux), isTrue);
    expect(supportsGoogleDriveChimahonSync(TargetPlatform.android), isFalse);
    expect(supportsGoogleDriveChimahonSync(TargetPlatform.iOS), isFalse);
    expect(supportsGoogleDriveChimahonSync(TargetPlatform.fuchsia), isFalse);
  });

  test('captures an allowed Linux cold-start app link from argv', () {
    final uri = initialDesktopAppLinkFromArguments(const [
      '--unrelated-flag',
      'mangayomi://chimahon-drive-diagnostic?nonce=safe',
    ], platform: TargetPlatform.linux);

    expect(uri?.scheme, 'mangayomi');
    expect(uri?.host, 'chimahon-drive-diagnostic');
  });

  test('uses the same argv parser on each supported desktop', () {
    for (final platform in const [
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(
        initialDesktopAppLinkFromArguments(const [
          'mangayomi://add-repo',
        ], platform: platform)?.host,
        'add-repo',
      );
    }
  });

  test('captures the Chimahon OAuth callback scheme on Linux', () {
    final uri = initialDesktopAppLinkFromArguments(const [
      'app.chimahon.google.oauth:/oauth2redirect?code=redacted',
    ], platform: TargetPlatform.linux);

    expect(uri?.scheme, 'app.chimahon.google.oauth');
    expect(uri?.path, '/oauth2redirect');
  });

  test('ignores unknown schemes and unsupported platforms', () {
    expect(
      initialDesktopAppLinkFromArguments(const [
        'https://example.invalid/callback',
      ], platform: TargetPlatform.linux),
      isNull,
    );
    expect(
      initialDesktopAppLinkFromArguments(const [
        'mangayomi://add-repo',
      ], platform: TargetPlatform.android),
      isNull,
    );
  });
}
