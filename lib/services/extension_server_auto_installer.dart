import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mangayomi/modules/more/settings/browse/extension_server/extension_server_utils.dart';
import 'package:path/path.dart' as path;

typedef MakeExtensionServerExecutable = Future<void> Function(String filePath);
typedef FindSystemExtensionServer =
    Future<SystemExtensionServerPaths?> Function();
typedef AutoInstallExtensionServer =
    Future<SystemExtensionServerPaths> Function();

const _defaultRequestTimeout = Duration(seconds: 30);
const _defaultMaximumDownloadBytes = 256 * 1024 * 1024;
const _defaultMaximumExtractedBytes = 1024 * 1024 * 1024;
const _defaultMaximumArchiveEntries = 20000;

Future<SystemExtensionServerPaths> resolveDesktopExtensionServerPaths({
  required String configuredJrePath,
  required String configuredJarPath,
  required FindSystemExtensionServer findSystemInstall,
  required AutoInstallExtensionServer autoInstall,
}) async {
  if (configuredJrePath.isNotEmpty &&
      configuredJarPath.isNotEmpty &&
      await File(configuredJrePath).exists() &&
      await File(configuredJarPath).exists()) {
    return SystemExtensionServerPaths(
      jrePath: configuredJrePath,
      jarPath: configuredJarPath,
    );
  }
  return await findSystemInstall() ?? await autoInstall();
}

/// Installs a desktop M-Extension-Server bundle after verifying the
/// GitHub-published SHA-256 digest.
///
/// This class deliberately persists no "attempted" marker. Any network,
/// checksum, extraction, or swap failure throws, leaves the configured paths
/// unchanged, and remains eligible for another call on the next launch.
class ExtensionServerAutoInstaller {
  final http.Client client;
  final String assetName;
  final MakeExtensionServerExecutable makeExecutable;
  final Duration requestTimeout;
  final int maximumDownloadBytes;
  final int maximumExtractedBytes;
  final int maximumArchiveEntries;

  ExtensionServerAutoInstaller({
    required this.client,
    required this.assetName,
    MakeExtensionServerExecutable? makeExecutable,
    this.requestTimeout = _defaultRequestTimeout,
    this.maximumDownloadBytes = _defaultMaximumDownloadBytes,
    this.maximumExtractedBytes = _defaultMaximumExtractedBytes,
    this.maximumArchiveEntries = _defaultMaximumArchiveEntries,
  }) : makeExecutable = makeExecutable ?? _makeExecutable;

  Future<SystemExtensionServerPaths> ensureInstalled(
    Directory installDirectory,
  ) async {
    await _recoverInterruptedInstall(installDirectory);
    final existing = await _resolveInstalledPaths(installDirectory);
    if (existing != null) return existing;

    final release = await _fetchRelease();
    final staging = Directory('${installDirectory.path}.installing');
    final download = File('${installDirectory.path}.download');
    final backup = Directory('${installDirectory.path}.previous');
    var backedUpLiveInstall = false;

    try {
      await installDirectory.parent.create(recursive: true);
      await _downloadBundle(release, download);
      await staging.create(recursive: true);
      await _extractArchive(download, staging);

      final stagedPaths = await _resolveInstalledPaths(staging);
      if (stagedPaths == null) {
        throw const FormatException(
          'The Mihon proxy server bundle is missing its JRE or server JAR.',
        );
      }
      await makeExecutable(stagedPaths.jrePath);

      if (await installDirectory.exists()) {
        await installDirectory.rename(backup.path);
        backedUpLiveInstall = true;
      }
      await staging.rename(installDirectory.path);

      final installed = await _resolveInstalledPaths(installDirectory);
      if (installed == null) {
        throw const FileSystemException(
          'The installed Mihon proxy server could not be verified.',
        );
      }
      if (await backup.exists()) {
        try {
          await backup.delete(recursive: true);
        } catch (_) {
          // A later launch removes this stale backup after verifying live.
        }
      }
      return installed;
    } catch (_) {
      if (backedUpLiveInstall && await backup.exists()) {
        if (await installDirectory.exists()) {
          await installDirectory.delete(recursive: true);
        }
        await backup.rename(installDirectory.path);
      }
      rethrow;
    } finally {
      if (await download.exists()) await download.delete();
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<void> _recoverInterruptedInstall(Directory installDirectory) async {
    final download = File('${installDirectory.path}.download');
    final staging = Directory('${installDirectory.path}.installing');
    final backup = Directory('${installDirectory.path}.previous');

    if (await download.exists()) await download.delete();
    if (await staging.exists()) await staging.delete(recursive: true);
    if (!await backup.exists()) return;

    final live = await _resolveInstalledPaths(installDirectory);
    if (live != null) {
      await backup.delete(recursive: true);
      return;
    }

    final previous = await _resolveInstalledPaths(backup);
    if (previous != null || !await installDirectory.exists()) {
      if (await installDirectory.exists()) {
        await installDirectory.delete(recursive: true);
      }
      await backup.rename(installDirectory.path);
      return;
    }

    await backup.delete(recursive: true);
  }

  Future<_AutoInstallRelease> _fetchRelease() async {
    final response = await client
        .get(
          Uri.parse(extensionServerReleaseApiUrl),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to check Mihon proxy server releases '
        '(${response.statusCode}).',
        uri: Uri.parse(extensionServerReleaseApiUrl),
      );
    }

    final releases = jsonDecode(response.body) as List<dynamic>;
    for (final item in releases) {
      final release = item as Map<String, dynamic>;
      if ((release['draft'] as bool? ?? false) ||
          (release['prerelease'] as bool? ?? false)) {
        continue;
      }
      final assets = release['assets'] as List<dynamic>? ?? const [];
      for (final item in assets) {
        final asset = item as Map<String, dynamic>;
        if (asset['name'] != assetName) continue;

        final size = asset['size'] as int?;
        final digest = asset['digest'] as String?;
        final downloadUrl = asset['browser_download_url'] as String?;
        if (size == null || size <= 0 || size > maximumDownloadBytes) {
          throw FormatException('Invalid release size for $assetName.');
        }
        if (digest == null ||
            !RegExp(r'^sha256:[0-9a-fA-F]{64}$').hasMatch(digest)) {
          throw FormatException('Missing SHA-256 digest for $assetName.');
        }
        final uri = downloadUrl == null ? null : Uri.tryParse(downloadUrl);
        if (!_isTrustedReleaseUri(uri)) {
          throw FormatException('Untrusted release URL for $assetName.');
        }
        return _AutoInstallRelease(
          downloadUri: uri!,
          expectedBytes: size,
          expectedSha256: digest.substring('sha256:'.length).toLowerCase(),
        );
      }
    }
    throw StateError(
      'No stable Mihon proxy server release provides $assetName.',
    );
  }

  bool _isTrustedReleaseUri(Uri? uri) {
    if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') {
      return false;
    }
    return uri.path.startsWith('/1Selxo/M-Extension-Server/releases/download/');
  }

  Future<void> _downloadBundle(
    _AutoInstallRelease release,
    File destination,
  ) async {
    final response = await client
        .send(http.Request('GET', release.downloadUri))
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final subscription = response.stream.listen(null);
      await subscription.cancel();
      throw HttpException(
        'Failed to download the Mihon proxy server bundle '
        '(${response.statusCode}).',
        uri: release.downloadUri,
      );
    }
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength != release.expectedBytes) {
      final subscription = response.stream.listen(null);
      await subscription.cancel();
      throw const FormatException(
        'The Mihon proxy server download size did not match its release.',
      );
    }

    var received = 0;
    final output = destination.openWrite();
    try {
      await for (final chunk in response.stream.timeout(requestTimeout)) {
        received += chunk.length;
        if (received > release.expectedBytes ||
            received > maximumDownloadBytes) {
          throw const FormatException(
            'The Mihon proxy server download exceeded its release size.',
          );
        }
        output.add(chunk);
      }
    } finally {
      await output.close();
    }
    if (received != release.expectedBytes) {
      throw const FormatException(
        'The Mihon proxy server download was incomplete.',
      );
    }

    final actualDigest = await sha256.bind(destination.openRead()).first;
    if (actualDigest.toString() != release.expectedSha256) {
      throw const FormatException(
        'The Mihon proxy server download failed SHA-256 verification.',
      );
    }
  }

  Future<void> _extractArchive(File archiveFile, Directory destination) async {
    await _validateCentralDirectory(archiveFile);
    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      if (archive.length > maximumArchiveEntries) {
        throw const FormatException(
          'The Mihon proxy server bundle contains too many files.',
        );
      }
      final budget = _ExtractionBudget(maximumExtractedBytes);
      for (final entry in archive) {
        if (entry.size > budget.remaining) {
          throw const FormatException(
            'The Mihon proxy server bundle is too large when extracted.',
          );
        }
        await _extractEntry(entry, destination, budget);
      }
    } finally {
      input.closeSync();
    }
  }

  Future<void> _validateCentralDirectory(File archiveFile) async {
    final length = await archiveFile.length();
    const maximumTailLength = 65535 + 22;
    final tailLength = length < maximumTailLength ? length : maximumTailLength;
    final handle = await archiveFile.open();
    late final List<int> tail;
    try {
      await handle.setPosition(length - tailLength);
      tail = await handle.read(tailLength);
    } finally {
      await handle.close();
    }

    for (var index = tail.length - 22; index >= 0; index--) {
      if (tail[index] != 0x50 ||
          tail[index + 1] != 0x4b ||
          tail[index + 2] != 0x05 ||
          tail[index + 3] != 0x06) {
        continue;
      }
      final commentLength = _readUint16LittleEndian(tail, index + 20);
      if (index + 22 + commentLength != tail.length) continue;

      final diskNumber = _readUint16LittleEndian(tail, index + 4);
      final centralDirectoryDisk = _readUint16LittleEndian(tail, index + 6);
      final entriesOnDisk = _readUint16LittleEndian(tail, index + 8);
      final totalEntries = _readUint16LittleEndian(tail, index + 10);
      final centralDirectorySize = _readUint32LittleEndian(tail, index + 12);
      final centralDirectoryOffset = _readUint32LittleEndian(tail, index + 16);
      final hasZip64Locator =
          index >= 20 &&
          _readUint32LittleEndian(tail, index - 20) == 0x07064b50;
      if (diskNumber != 0 ||
          centralDirectoryDisk != 0 ||
          entriesOnDisk != totalEntries ||
          hasZip64Locator ||
          totalEntries == 0xffff ||
          centralDirectorySize == 0xffffffff ||
          centralDirectoryOffset == 0xffffffff) {
        throw const FormatException(
          'Unsupported ZIP structure in Mihon proxy server bundle.',
        );
      }
      if (totalEntries > maximumArchiveEntries) {
        throw const FormatException(
          'The Mihon proxy server bundle contains too many files.',
        );
      }
      final endOfCentralDirectoryOffset = length - tailLength + index;
      if (centralDirectoryOffset + centralDirectorySize !=
          endOfCentralDirectoryOffset) {
        throw const FormatException(
          'Invalid ZIP directory in Mihon proxy server bundle.',
        );
      }
      await _validateCentralDirectoryEntries(
        archiveFile,
        offset: centralDirectoryOffset,
        size: centralDirectorySize,
        expectedEntries: totalEntries,
      );
      return;
    }
    throw const FormatException(
      'Missing ZIP directory in Mihon proxy server bundle.',
    );
  }

  Future<void> _validateCentralDirectoryEntries(
    File archiveFile, {
    required int offset,
    required int size,
    required int expectedEntries,
  }) async {
    final handle = await archiveFile.open();
    var consumedBytes = 0;
    var actualEntries = 0;
    try {
      await handle.setPosition(offset);
      while (consumedBytes < size) {
        final header = await handle.read(46);
        if (header.length != 46 ||
            _readUint32LittleEndian(header, 0) != 0x02014b50) {
          throw const FormatException(
            'Invalid ZIP entry directory in Mihon proxy server bundle.',
          );
        }
        actualEntries++;
        if (actualEntries > maximumArchiveEntries) {
          throw const FormatException(
            'The Mihon proxy server bundle contains too many files.',
          );
        }

        final versionMadeBy = _readUint16LittleEndian(header, 4);
        final externalAttributes = _readUint32LittleEndian(header, 38);
        final unixMode = externalAttributes >> 16;
        if ((versionMadeBy >> 8) == 3 && (unixMode & 0xf000) == 0xa000) {
          throw const FormatException(
            'Symbolic links are not supported in Mihon proxy server bundles.',
          );
        }

        final variableLength =
            _readUint16LittleEndian(header, 28) +
            _readUint16LittleEndian(header, 30) +
            _readUint16LittleEndian(header, 32);
        consumedBytes += 46 + variableLength;
        if (consumedBytes > size) {
          throw const FormatException(
            'Invalid ZIP entry directory in Mihon proxy server bundle.',
          );
        }
        await handle.setPosition(offset + consumedBytes);
      }
    } finally {
      await handle.close();
    }
    if (consumedBytes != size || actualEntries != expectedEntries) {
      throw const FormatException(
        'Inconsistent ZIP entry count in Mihon proxy server bundle.',
      );
    }
  }

  Future<void> _extractEntry(
    ArchiveFile entry,
    Directory destination,
    _ExtractionBudget budget,
  ) async {
    final outputPath = path.normalize(path.join(destination.path, entry.name));
    if (outputPath == destination.path ||
        !path.isWithin(destination.path, outputPath)) {
      throw FormatException('Unsafe path in Mihon proxy server bundle.');
    }

    if (entry.isSymbolicLink) {
      throw const FormatException(
        'Symbolic links are not supported in Mihon proxy server bundles.',
      );
    }
    if (entry.isDirectory) {
      await Directory(outputPath).create(recursive: true);
      return;
    }

    await File(outputPath).parent.create(recursive: true);
    final boundedOutput = _BoundedOutputStream(
      OutputFileStream(outputPath),
      budget,
    );
    try {
      entry.writeContent(boundedOutput);
    } finally {
      await boundedOutput.close();
    }
  }

  Future<SystemExtensionServerPaths?> _resolveInstalledPaths(
    Directory directory,
  ) async {
    if (!await directory.exists()) return null;
    final jrePath = await findExtensionServerJavaExecutable(directory);
    final jarPath = await findExtensionServerJar(directory);
    if (jrePath == null || jarPath == null) return null;
    return SystemExtensionServerPaths(jrePath: jrePath, jarPath: jarPath);
  }

  static Future<void> _makeExecutable(String filePath) async {
    if (Platform.isWindows) return;
    final result = await Process.run('chmod', ['+x', filePath]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'chmod',
        ['+x', filePath],
        result.stderr.toString(),
        result.exitCode,
      );
    }
  }
}

class _AutoInstallRelease {
  final Uri downloadUri;
  final int expectedBytes;
  final String expectedSha256;

  const _AutoInstallRelease({
    required this.downloadUri,
    required this.expectedBytes,
    required this.expectedSha256,
  });
}

int _readUint16LittleEndian(List<int> bytes, int offset) =>
    bytes[offset] | (bytes[offset + 1] << 8);

int _readUint32LittleEndian(List<int> bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

class _ExtractionBudget {
  final int maximumBytes;
  int writtenBytes = 0;

  _ExtractionBudget(this.maximumBytes);

  int get remaining => maximumBytes - writtenBytes;

  void reserve(int byteCount) {
    if (byteCount < 0 || byteCount > remaining) {
      throw const FormatException(
        'The Mihon proxy server bundle is too large when extracted.',
      );
    }
    writtenBytes += byteCount;
  }
}

class _BoundedOutputStream extends OutputStream {
  static const _copyChunkSize = 1024 * 1024;

  final OutputStream delegate;
  final _ExtractionBudget budget;

  _BoundedOutputStream(this.delegate, this.budget)
    : super(byteOrder: delegate.byteOrder);

  @override
  int get length => delegate.length;

  @override
  bool get isOpen => delegate.isOpen;

  @override
  void open() => delegate.open();

  @override
  Future<void> close() => delegate.close();

  @override
  void closeSync() => delegate.closeSync();

  @override
  void clear() => delegate.clear();

  @override
  void flush() => delegate.flush();

  @override
  void writeByte(int value) {
    budget.reserve(1);
    delegate.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final byteCount = length ?? bytes.length;
    budget.reserve(byteCount);
    delegate.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      final chunkLength = stream.length < _copyChunkSize
          ? stream.length
          : _copyChunkSize;
      if (chunkLength <= 0) break;
      writeBytes(stream.readBytes(chunkLength).toUint8List());
    }
  }

  @override
  Uint8List subset(int start, [int? end]) => delegate.subset(start, end);
}
