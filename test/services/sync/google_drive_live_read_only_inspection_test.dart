import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/sync/google_drive_oauth.dart';
import 'package:mangayomi/services/sync/google_drive_read_only_inspector.dart';
import 'package:mangayomi/services/sync/google_drive_refresh_token_store.dart';

// Opt-in macOS diagnostic. It reads the refresh token directly into this test
// process, refreshes it in memory, and makes only Drive GET requests through
// GoogleDriveReadOnlyInspector. Neither credential is printed or persisted.
//
// CHIMAHON_LIVE_DRIVE_INSPECT=1 \
// CHIMAHON_REFERENCE_BACKUP=/path/to/reference.tachibk \
// flutter test \
//   test/services/sync/google_drive_live_read_only_inspection_test.dart
void main() {
  final enabled =
      Platform.environment['CHIMAHON_LIVE_DRIVE_INSPECT']?.trim() == '1';
  final referencePath = Platform.environment['CHIMAHON_REFERENCE_BACKUP']
      ?.trim();
  final skipReason = !enabled
      ? 'Set CHIMAHON_LIVE_DRIVE_INSPECT=1 to authorize live Drive reads.'
      : !Platform.isMacOS
      ? 'The credential-loading harness currently targets macOS Keychain.'
      : referencePath == null || referencePath.isEmpty
      ? 'Set CHIMAHON_REFERENCE_BACKUP to the local comparison backup.'
      : false;

  test(
    'inspects Chimahon appDataFolder without making Drive writes',
    () async {
      final keychainResult = await Process.run(
        '/usr/bin/security',
        [
          'find-generic-password',
          '-a',
          SecureGoogleDriveRefreshTokenStore.defaultStorageKey,
          '-w',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (keychainResult.exitCode != 0) {
        throw StateError('The Google Drive refresh token is not in Keychain.');
      }
      final refreshToken = (keychainResult.stdout as String).trim();
      if (refreshToken.isEmpty) {
        throw StateError(
          'The Google Drive refresh token in Keychain is blank.',
        );
      }

      final oauth = GoogleDriveOAuthClient();
      try {
        final tokens = await oauth.refresh(refreshToken);
        final inspector = GoogleDriveReadOnlyInspector(
          accessToken: tokens.accessToken,
        );
        try {
          final report = await inspector.inspect(
            referenceBytes: await File(referencePath!).readAsBytes(),
          );
          debugPrint(
            const JsonEncoder.withIndent('  ').convert(report.toSafeJson()),
          );
          expect(report.files, isNotEmpty);
          expect(
            report.files.where((file) => file.fingerprint != null),
            isNotEmpty,
          );
        } finally {
          inspector.close();
        }
      } finally {
        oauth.close();
      }
    },
    skip: skipReason,
  );
}
