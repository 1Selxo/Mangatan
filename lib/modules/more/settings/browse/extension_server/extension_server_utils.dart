import 'dart:ffi';
import 'dart:io';

import 'package:mangayomi/utils/extensions/string_extensions.dart';
import 'package:path/path.dart' as path;

const extensionServerFallbackVersion = '1.0.0';
const extensionServerJarPrefix = 'MExtensionServer-';
const extensionServerReleaseApiUrl =
    'https://api.github.com/repos/1Selxo/M-Extension-Server/releases?page=1&per_page=10';
const apkBridgeReleaseUrl =
    'https://github.com/Schnitzel5/ApkBridge/releases/latest';

/// Distro-managed install locations for the extension server, newest layout
/// first. A Linux package (for example the `mangatan-extension-server` AUR
/// package) drops `MExtensionServer-<version>.jar` plus a `jre/jre/bin/java`
/// symlink to the system JRE here, so the bridge works without the user
/// pointing the file picker at anything.
///
/// These directories are owned by the package manager. Never extract into or
/// delete them; see [isManagedExtensionServerDirectory].
const extensionServerSystemDirectories = <String>[
  '/usr/share/mangatan/extension_server',
  '/usr/lib/mangatan/extension_server',
];

/// Locations where release packaging embeds Mangatan's own Mihon server.
///
/// Linux and Windows keep the bundle beside the executable. macOS executables
/// live in `Contents/MacOS`, while bundled data belongs in
/// `Contents/Resources`.
List<String> bundledExtensionServerDirectories({
  required String resolvedExecutable,
  required bool macos,
}) {
  final executableDirectory = path.dirname(resolvedExecutable);
  final bundleRoot = macos
      ? path.normalize(path.join(executableDirectory, '..', 'Resources'))
      : executableDirectory;
  return [path.join(bundleRoot, _bundledExtensionServerDirectoryName)];
}

/// Whether [directory] is a location the in-app installer must not write to or
/// wipe: a distro-managed install, or the server bundled inside this very
/// Mangatan installation.
///
/// Matches an ancestor of a managed directory as well as the directory itself,
/// because the installer wipes its target with `delete(recursive: true)`. The
/// folder picker resolves the JAR recursively, so selecting `/usr/share/mangatan`
/// — or `/usr` — yields a working configuration whose next in-app update would
/// recursively delete everything beneath it. Subdirectories are covered too,
/// since they are equally package-owned.
///
/// Pass [bundledDirectories] to test the bundle rule without depending on the
/// test runner's own executable location.
bool isManagedExtensionServerDirectory(
  String directory, {
  List<String>? bundledDirectories,
}) {
  if (directory.isEmpty) return false;
  // The app's own bundled server is as unwritable as a pacman-owned tree: the
  // installer clears its target first, so an update aimed at the bundle would
  // delete the shipped JRE, JAR and license notices out of the running
  // installation (and invalidate the macOS code signature).
  final managedDirectories = [
    ...extensionServerSystemDirectories,
    ...(bundledDirectories ?? _currentBundledExtensionServerDirectories()),
  ];
  // path.equals/isWithin canonicalize both sides, so a trailing separator or a
  // `..` segment cannot slip a package-owned path past this check.
  return managedDirectories.any(
    (managed) =>
        path.equals(managed, directory) ||
        path.isWithin(directory, managed) ||
        path.isWithin(managed, directory),
  );
}

/// Whether the configured paths name a `mihon_server` bundle that is *not* this
/// installation's own.
///
/// Release bundles live at a path derived from the executable, so their absolute
/// paths change whenever the app is moved or a new version is unpacked
/// side-by-side. Such a path can still exist on disk while belonging to a
/// different (usually older) Mangatan, so it must be re-resolved rather than
/// launched. A path outside any `mihon_server` bundle is a user or distro
/// choice and is left alone.
bool isStaleBundledExtensionServerPath({
  required String jrePath,
  required String serverJarPath,
  List<String>? bundledDirectories,
}) {
  final current =
      bundledDirectories ?? _currentBundledExtensionServerDirectories();
  if (current.isEmpty) return false;
  bool isForeignBundlePath(String candidate) {
    if (candidate.isEmpty) return false;
    if (path.basename(candidate) != _bundledExtensionServerDirectoryName &&
        !_isWithinBundleDirectoryName(candidate)) {
      return false;
    }
    return !current.any(
      (bundle) =>
          path.equals(bundle, candidate) || path.isWithin(bundle, candidate),
    );
  }

  return isForeignBundlePath(jrePath) || isForeignBundlePath(serverJarPath);
}

bool _isWithinBundleDirectoryName(String candidate) {
  return path.split(candidate).contains(_bundledExtensionServerDirectoryName);
}

const _bundledExtensionServerDirectoryName = 'mihon_server';

List<String> _currentBundledExtensionServerDirectories() {
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return const [];
  }
  return bundledExtensionServerDirectories(
    resolvedExecutable: Platform.resolvedExecutable,
    macos: Platform.isMacOS,
  );
}

/// Finds a package-managed extension server install, or null when none is
/// usable. Linux-only: no other platform ships a distro package.
///
/// A candidate only counts when it provides *both* a `java` executable and a
/// `MExtensionServer-*.jar`, so a partially removed package is skipped rather
/// than persisted as a broken configuration.
///
/// [directories] exists so tests can point at a temporary tree instead of the
/// real `/usr` paths; production callers use the default.
Future<SystemExtensionServerPaths?> findSystemExtensionServer({
  List<String> directories = extensionServerSystemDirectories,
}) async {
  if (!Platform.isLinux) return null;
  return _findExtensionServerInDirectories(directories);
}

/// Finds the JRE and server JAR shipped inside the Mangatan desktop bundle.
///
/// Release artifacts include these files, so a fresh install works offline and
/// does not require a separately downloaded M-Extension-Server package.
Future<SystemExtensionServerPaths?> findBundledExtensionServer({
  List<String>? directories,
}) async {
  if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) {
    return null;
  }
  final candidates =
      directories ??
      bundledExtensionServerDirectories(
        resolvedExecutable: Platform.resolvedExecutable,
        macos: Platform.isMacOS,
      );
  return _findExtensionServerInDirectories(candidates);
}

Future<SystemExtensionServerPaths?> _findExtensionServerInDirectories(
  List<String> directories,
) async {
  for (final candidate in directories) {
    final root = Directory(candidate);
    if (!await root.exists()) continue;
    // Reuses the same resolution the folder picker performs. Note the packaged
    // `java` must sit at `<root>/jre/jre/bin/java`: that preferred path is
    // probed with File.exists(), which follows symlinks, whereas the recursive
    // fallback lists with followLinks: false and would skip a symlink.
    final jrePath = await findExtensionServerJavaExecutable(root);
    if (jrePath == null) continue;
    final jarPath = await findExtensionServerJar(root);
    if (jarPath == null) continue;
    return SystemExtensionServerPaths(jrePath: jrePath, jarPath: jarPath);
  }
  return null;
}

/// A resolved pair of paths from a package-managed extension server install.
class SystemExtensionServerPaths {
  final String jrePath;
  final String jarPath;

  const SystemExtensionServerPaths({
    required this.jrePath,
    required this.jarPath,
  });
}

String? extensionServerDirectoryFromPaths({
  required String jrePath,
  required String extensionServerPath,
}) {
  if (extensionServerPath.isNotEmpty) {
    return path.dirname(extensionServerPath);
  }
  if (jrePath.isNotEmpty) {
    return path.dirname(jrePath);
  }
  return null;
}

Future<String?> findExtensionServerJavaExecutable(Directory root) async {
  final executableName = Platform.isWindows ? 'java.exe' : 'java';
  final preferredPath = path.join(
    root.path,
    'jre',
    'jre',
    'bin',
    executableName,
  );
  if (await File(preferredPath).exists()) {
    return preferredPath;
  }
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File &&
        path.basename(entity.path).toLowerCase() == executableName) {
      return entity.path;
    }
  }
  return null;
}

Future<String?> findExtensionServerJar(Directory root) async {
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    final fileName = path.basename(entity.path);
    if (entity is File &&
        fileName.startsWith(extensionServerJarPrefix) &&
        fileName.endsWith('.jar')) {
      return entity.path;
    }
  }
  return null;
}

String? extensionServerAssetNameForCurrentPlatform() {
  final abi = Abi.current();
  if (Platform.isIOS) {
    return abi == Abi.iosArm64 ? 'macOS-arm64-bundle.zip' : null;
  }
  if (Platform.isWindows) {
    return abi == Abi.windowsX64 ? 'windows-x64-bundle.zip' : null;
  }
  if (Platform.isLinux) {
    return abi == Abi.linuxX64 ? 'linux-x64-bundle.zip' : null;
  }
  if (Platform.isMacOS) {
    return switch (abi) {
      Abi.macosArm64 => 'macOS-arm64-bundle.zip',
      Abi.macosX64 => 'macOS-x64-bundle.zip',
      _ => null,
    };
  }
  return null;
}

String resolveInstalledExtensionServerVersion(String extensionServerPath) {
  if (extensionServerPath.isEmpty) return '';
  return extractExtensionServerVersion(path.basename(extensionServerPath)) ??
      extensionServerFallbackVersion;
}

String resolveExtensionServerReleaseVersion(Map<String, dynamic> release) {
  final versionSource =
      release['tag_name']?.toString() ??
      release['name']?.toString() ??
      extensionServerFallbackVersion;
  return extractExtensionServerVersion(versionSource) ??
      versionSource.substringAfter('v').substringBefore('-');
}

String? extractExtensionServerVersion(String value) {
  final match = RegExp(r'v?(\d+(?:\.\d+)+)').firstMatch(value);
  return match?.group(1);
}
