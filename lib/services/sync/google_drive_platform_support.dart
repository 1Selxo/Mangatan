import 'package:flutter/foundation.dart';

/// Platforms on which Mangatan exposes Chimahon-compatible Google Drive sync.
///
/// Keep the sync implementation shared. Platform-specific code is limited to
/// OAuth callback delivery and native credential storage.
bool supportsGoogleDriveChimahonSync(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };

bool get supportsGoogleDriveChimahonSyncOnCurrentPlatform =>
    !kIsWeb && supportsGoogleDriveChimahonSync(defaultTargetPlatform);
