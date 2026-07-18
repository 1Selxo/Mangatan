import 'package:mangayomi/models/chapter.dart';

/// Defines the boundary between Chimahon chapter data and Mangatan's
/// device-local file overlay.
///
/// New file-picker rows have an empty source URL. Older rows can contain the
/// archive path (or an equivalent `file:` URI) in both fields, so checking only
/// for an empty URL could leak a local path and let a remote chapter overwrite
/// the retained row. Source chapters downloaded for offline use remain
/// portable because their source URL differs from their archive path.
class ChimahonLocalChapterPolicy {
  const ChimahonLocalChapterPolicy();

  static const _desktopPosixRoots = <String>[
    '/Users/',
    '/Volumes/',
    '/home/',
    '/root/',
    '/mnt/',
    '/media/',
    '/run/user/',
    '/private/',
    '/tmp/',
    '/var/home/',
    '/var/mnt/',
    '/var/media/',
    '/var/tmp/',
  ];

  bool isDeviceLocal(Chapter chapter) {
    final archivePath = chapter.archivePath?.trim() ?? '';
    final url = chapter.url?.trim() ?? '';
    if (url.isEmpty) return archivePath.isNotEmpty;

    // These forms cannot be Chimahon-portable source identities. Protect them
    // even when a legacy row has lost its archivePath value.
    if (!isPortableSourceUrl(url)) return true;
    if (archivePath.isEmpty) return false;

    final normalizedArchive = _normalizeLocalFileReference(archivePath);
    final normalizedUrl = _normalizeLocalFileReference(url);
    return normalizedArchive != null && normalizedArchive == normalizedUrl;
  }

  bool hasPortableIdentity(Chapter chapter) {
    return hasPortableWireIdentity(
          url: chapter.url,
          name: chapter.name,
          chapterNumber: chapter.chapterNumber,
        ) &&
        !isDeviceLocal(chapter);
  }

  /// Whether a chapter can be represented by Chimahon without leaking a
  /// device path or relying on an identity Chimahon cannot round-trip.
  ///
  /// A missing local chapter number is representable because the exporter
  /// derives one from the chapter name. Protobuf rows expose a finite default
  /// of zero when the field is absent, so the same predicate can audit and
  /// import decoded wire rows as well.
  bool hasPortableWireIdentity({
    required String? url,
    required String? name,
    double? chapterNumber,
  }) {
    return isPortableSourceUrl(url) &&
        (name?.trim().isNotEmpty ?? false) &&
        (chapterNumber?.isFinite ?? true);
  }

  /// Whether [url] is safe to use as Chimahon's cross-device chapter key.
  ///
  /// Leading-slash source routes such as `/chapter/1` are valid and common,
  /// so an arbitrary absolute POSIX-looking URL cannot be rejected. Known
  /// desktop storage roots are different: they identify machine-local files
  /// and must remain in Mangatan's local overlay on macOS and Linux.
  bool isPortableSourceUrl(String? url) {
    final candidate = url?.trim() ?? '';
    if (candidate.isEmpty || _isUnambiguouslyLocalUrl(candidate)) {
      return false;
    }
    return !_desktopPosixRoots.any(candidate.startsWith);
  }

  /// Stable comparison key for the file owned by a device-local row.
  ///
  /// This is intentionally separate from [deviceLocalPath]: the identity is
  /// normalized across Windows and POSIX spellings, while the path preserves
  /// the platform spelling needed for actual file-system access.
  String? deviceLocalFileIdentity(Chapter chapter) {
    if (!isDeviceLocal(chapter)) return null;
    final reference = _deviceLocalReference(chapter);
    if (reference == null) return null;
    return _normalizeLocalFileReference(reference) ?? reference.trim();
  }

  /// Resolves the file-system path owned by a device-local row.
  ///
  /// [windows] is injectable so path handling can be tested on a non-Windows
  /// host. Raw paths retain their original spelling; `file:` URIs are decoded
  /// using the target platform's path rules.
  String? deviceLocalPath(Chapter chapter, {required bool windows}) {
    if (!isDeviceLocal(chapter)) return null;
    final reference = _deviceLocalReference(chapter);
    if (reference == null) return null;
    final uri = Uri.tryParse(reference);
    if (uri != null && uri.scheme.toLowerCase() == 'file') {
      try {
        return uri.toFilePath(windows: windows);
      } on UnsupportedError {
        return null;
      } on ArgumentError {
        return null;
      }
    }
    return reference;
  }

  String? _deviceLocalReference(Chapter chapter) {
    final archivePath = chapter.archivePath?.trim() ?? '';
    if (archivePath.isNotEmpty) return archivePath;
    final url = chapter.url?.trim() ?? '';
    return url.isEmpty ? null : url;
  }

  bool _isUnambiguouslyLocalUrl(String value) {
    final candidate = value.trim();
    return candidate.toLowerCase().startsWith('file:') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(candidate) ||
        candidate.startsWith(r'\\');
  }

  String? _normalizeLocalFileReference(String value) {
    var candidate = value.trim();
    if (candidate.isEmpty) return null;

    final uri = Uri.tryParse(candidate);
    if (uri != null && uri.scheme.toLowerCase() == 'file') {
      late final String decodedPath;
      try {
        decodedPath = Uri.decodeFull(uri.path);
      } on FormatException {
        return null;
      }
      candidate = uri.host.isEmpty ? decodedPath : '//${uri.host}$decodedPath';
    }

    candidate = candidate.replaceAll('\\', '/');
    final drivePath = RegExp(r'^/?[A-Za-z]:/').hasMatch(candidate);
    final uncPath = candidate.startsWith('//');
    final posixPath = candidate.startsWith('/');
    if (!drivePath && !uncPath && !posixPath) return null;

    if (drivePath && candidate.startsWith('/')) {
      candidate = candidate.substring(1);
    }
    if (uncPath) {
      candidate = '//${candidate.substring(2).replaceAll(RegExp(r'/+'), '/')}';
    } else {
      candidate = candidate.replaceAll(RegExp(r'/+'), '/');
    }
    if (candidate.length > 1 && candidate.endsWith('/')) {
      candidate = candidate.substring(0, candidate.length - 1);
    }

    // Windows drive and UNC paths are case-insensitive in the environments
    // Mangatan supports. POSIX paths retain their case-sensitive identity.
    return drivePath || uncPath ? candidate.toLowerCase() : candidate;
  }
}
