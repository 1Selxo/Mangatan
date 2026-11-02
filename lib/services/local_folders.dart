import 'dart:io';

import 'package:mangayomi/eval/model/m_bridge.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/providers/storage_provider.dart';
import 'package:mangayomi/repositories/settings_repository.dart';
import 'package:mangayomi/utils/localized_message.dart';
import 'package:path/path.dart' as p;
import 'package:shiori/shiori.dart';

/// Returns the `/local` directory inside the app's default storage.
Future<Directory?> getLocalLibrary() async {
  try {
    final dir = await StorageProvider().getDefaultDirectory();
    return dir == null ? null : Directory(p.join(dir.path, 'local'));
  } catch (e) {
    botToast(
      localizedMessage((l10n) => l10n.error_getting_local_library(e)),
      tone: ShioriToastTone.error,
      second: 4,
    );
    return null;
  }
}

/// The user's extra local folders, as stored absolute paths.
///
/// Mangatan keeps local folders as plain paths and stores archive paths
/// absolutely, so no virtual folder names need resolving.
List<String> getAllLocalFolders({Settings? settings}) {
  settings ??= settingsRepository.current;
  return [
    for (final path in settings.localFolders ?? const <String>[])
      if (path.trim().isNotEmpty) path.trim(),
  ];
}

/// Resolves a stored local archive path to a readable file path.
Future<String> resolveLocalArchivePath(String archivePath) async => archivePath;
