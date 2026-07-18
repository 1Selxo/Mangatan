import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import './protocol.dart';

typedef LinuxProtocolProcessRunner =
    ProcessResult Function(String executable, List<String> arguments);

/// Registers a custom URL scheme for the current Linux user.
///
/// The generated desktop entry contains no credentials or OAuth state. It is
/// installed below XDG_DATA_HOME and activated with `xdg-mime`, both without
/// root access. An unrelated existing default is never replaced. Registration
/// intentionally remains installed after a temporary lease ends: freedesktop
/// has no ownership-safe "unset default" operation, and retaining the owned
/// entry is what permits a later callback to cold-start Mangatan.
class LinuxProtocolHandler extends ProtocolHandler {
  LinuxProtocolHandler({
    Map<String, String>? environment,
    String? resolvedExecutable,
    LinuxProtocolProcessRunner? processRunner,
    bool? enabled,
  }) : _environment = environment ?? Platform.environment,
       _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable,
       _processRunner = processRunner ?? _runProcess,
       _enabled = enabled ?? Platform.isLinux;

  static const persistentOwnerValue = 'com.kodjodevf.mangayomi/persistent/v1';
  static const _ownerKey = 'X-Mangatan-Protocol-Owner';
  static const _schemeKey = 'X-Mangatan-Protocol-Scheme';
  static const _schemesKey = 'X-Mangatan-Protocol-Schemes';
  static const _appScheme = 'mangayomi';
  static const _chimahonOAuthScheme = 'app.chimahon.google.oauth';
  static const _packagedDesktopIds = {
    'mangayomi.desktop',
    'com.kodjodevf.mangayomi.desktop',
  };
  static final Map<String, _LinuxProtocolRegistration> _registrations = {};

  final Map<String, String> _environment;
  final String _resolvedExecutable;
  final LinuxProtocolProcessRunner _processRunner;
  final bool _enabled;

  @override
  void register(String scheme, {String? executable, List<String>? arguments}) {
    if (!_enabled) return;
    final normalizedScheme = normalizeScheme(scheme);
    final resolvedArguments = getArguments(arguments);
    final resolvedPath = executable ?? _defaultExecutable;
    final command = buildExecCommand(resolvedPath, resolvedArguments);
    final registrationKey = _registrationKey(normalizedScheme);
    final active = _registrations[registrationKey];
    if (active != null) {
      if (active.command != command) {
        throw StateError(
          'The URL protocol is already leased by this Mangatan process with '
          'a different command.',
        );
      }
      active.depth++;
      return;
    }

    _install(
      scheme: normalizedScheme,
      executable: resolvedPath,
      arguments: resolvedArguments,
    );
    _registrations[registrationKey] = _LinuxProtocolRegistration(command);
  }

  @override
  void registerPersistent(
    String scheme, {
    String? executable,
    List<String>? arguments,
  }) {
    if (!_enabled) return;
    _install(
      scheme: normalizeScheme(scheme),
      executable: executable ?? _defaultExecutable,
      arguments: getArguments(arguments),
    );
  }

  @override
  void unregister(String scheme) {
    if (!_enabled) return;
    final registrationKey = _registrationKey(normalizeScheme(scheme));
    final registration = _registrations[registrationKey];
    if (registration == null) return;
    registration.depth--;
    if (registration.depth <= 0) {
      _registrations.remove(registrationKey);
    }

    // Do not remove the desktop file or MIME default here. xdg-mime provides
    // no atomic, ownership-aware way to clear a default. Leaving our narrowly
    // marked per-user entry in place also supports a cold-started callback.
  }

  void _install({
    required String scheme,
    required String executable,
    required List<String> arguments,
  }) {
    final mimeType = mimeTypeForScheme(scheme);
    final desktopId = desktopIdForScheme(scheme);
    final applications = _applicationsDirectory;
    final desktopFile = File(p.join(applications.path, desktopId));
    final expectedContent = buildDesktopEntry(
      scheme: scheme,
      executable: executable,
      arguments: arguments,
    );
    final currentDefault = _queryDefault(mimeType);

    if (currentDefault != null && currentDefault != desktopId) {
      final existingEntry = _readDesktopEntry(currentDefault);
      if (existingEntry == null ||
          !isOwnedPackagedDesktopEntry(
            desktopId: currentDefault,
            content: existingEntry,
            scheme: scheme,
          )) {
        throw StateError(
          'The $scheme URL protocol is already registered by another '
          'application; Mangatan will not overwrite it.',
        );
      }
      // An owned packaged desktop entry already handles this scheme. Keep its
      // package-managed command and association intact.
      return;
    }

    final existingType = FileSystemEntity.typeSync(
      desktopFile.path,
      followLinks: false,
    );
    if (existingType != FileSystemEntityType.notFound) {
      if (existingType != FileSystemEntityType.file) {
        throw StateError(
          'Mangatan will not replace a non-file Linux protocol entry.',
        );
      }
      final existingContent = desktopFile.readAsStringSync();
      if (!isOwnedDesktopEntry(existingContent, scheme: scheme)) {
        throw StateError(
          'The $scheme Linux protocol entry is not owned by Mangatan; it '
          'will not be replaced.',
        );
      }
    }

    applications.createSync(recursive: true);
    _writeOwnedDesktopEntry(
      desktopFile,
      expectedContent,
      replacingOwnedFile: existingType == FileSystemEntityType.file,
    );
    _refreshDesktopDatabase(applications.path);

    // Re-check immediately before setting the default so a newly visible
    // unrelated association is not knowingly overwritten.
    final latestDefault = _queryDefault(mimeType);
    if (latestDefault != null && latestDefault != desktopId) {
      final existingEntry = _readDesktopEntry(latestDefault);
      if (existingEntry == null ||
          !isOwnedPackagedDesktopEntry(
            desktopId: latestDefault,
            content: existingEntry,
            scheme: scheme,
          )) {
        throw StateError(
          'The $scheme URL protocol was claimed by another application; '
          'Mangatan will not overwrite it.',
        );
      }
      return;
    }

    if (latestDefault != desktopId) {
      _runXdgMime(['default', desktopId, mimeType]);
    }
    if (_queryDefault(mimeType) != desktopId) {
      throw StateError(
        'The desktop did not activate Mangatan for the $scheme URL protocol.',
      );
    }
  }

  void _writeOwnedDesktopEntry(
    File target,
    String content, {
    required bool replacingOwnedFile,
  }) {
    if (!replacingOwnedFile) {
      try {
        target.createSync(exclusive: true);
        final sink = target.openSync(mode: FileMode.writeOnly);
        try {
          sink.writeStringSync(content);
          sink.flushSync();
        } finally {
          sink.closeSync();
        }
        return;
      } on FileSystemException {
        // A competing creator won the race. Inspect it before deciding if an
        // ownership-safe update is possible.
        final type = FileSystemEntity.typeSync(target.path, followLinks: false);
        if (type != FileSystemEntityType.file ||
            !isOwnedDesktopEntry(
              target.readAsStringSync(),
              scheme: _schemeFromContent(content),
            )) {
          rethrow;
        }
      }
    }

    final temporary = File(
      '${target.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    temporary.createSync(exclusive: true);
    final sink = temporary.openSync(mode: FileMode.writeOnly);
    try {
      sink.writeStringSync(content);
      sink.flushSync();
      sink.closeSync();
      final currentType = FileSystemEntity.typeSync(
        target.path,
        followLinks: false,
      );
      if (currentType != FileSystemEntityType.file ||
          !isOwnedDesktopEntry(
            target.readAsStringSync(),
            scheme: _schemeFromContent(content),
          )) {
        throw StateError(
          'The Linux protocol entry changed ownership while it was updated.',
        );
      }
      temporary.renameSync(target.path);
    } finally {
      try {
        sink.closeSync();
      } catch (_) {}
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
    }
  }

  String? _queryDefault(String mimeType) {
    final result = _runXdgMime(['query', 'default', mimeType]);
    final value = result.stdout.toString().trim();
    if (value.isEmpty) return null;
    if (!RegExp(r'^[A-Za-z0-9_.+-]+\.desktop$').hasMatch(value)) {
      throw StateError('xdg-mime returned an invalid desktop entry id.');
    }
    return value;
  }

  ProcessResult _runXdgMime(List<String> arguments) {
    late final ProcessResult result;
    try {
      result = _processRunner('xdg-mime', arguments);
    } on ProcessException {
      throw StateError(
        'Linux URL protocol registration requires xdg-utils (xdg-mime).',
      );
    }
    if (result.exitCode != 0) {
      throw StateError('xdg-mime could not update the current-user handler.');
    }
    return result;
  }

  void _refreshDesktopDatabase(String applicationsPath) {
    try {
      // This cache helper is optional; xdg-mime remains the authority and is
      // checked immediately after registration.
      _processRunner('update-desktop-database', [applicationsPath]);
    } on ProcessException {
      // Minimal desktops often omit this utility.
    }
  }

  String? _readDesktopEntry(String desktopId) {
    for (final directory in _desktopSearchDirectories) {
      final candidate = File(p.join(directory, desktopId));
      final type = FileSystemEntity.typeSync(
        candidate.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.file) {
        return candidate.readAsStringSync();
      }
    }
    return null;
  }

  Directory get _applicationsDirectory {
    final configured = _environment['XDG_DATA_HOME']?.trim();
    if (configured != null && configured.isNotEmpty) {
      if (!p.isAbsolute(configured) || configured.contains('\u0000')) {
        throw StateError('XDG_DATA_HOME must be an absolute path.');
      }
      return Directory(p.join(configured, 'applications'));
    }
    final userHome = _environment['HOME']?.trim();
    if (userHome == null ||
        userHome.isEmpty ||
        !p.isAbsolute(userHome) ||
        userHome.contains('\u0000')) {
      throw StateError(
        'Linux URL protocol registration could not locate the user data '
        'directory.',
      );
    }
    return Directory(p.join(userHome, '.local', 'share', 'applications'));
  }

  String get _defaultExecutable {
    final appImage = _environment['APPIMAGE']?.trim();
    if (appImage != null &&
        appImage.isNotEmpty &&
        p.isAbsolute(appImage) &&
        !appImage.contains('\u0000')) {
      final type = FileSystemEntity.typeSync(appImage, followLinks: false);
      if (type == FileSystemEntityType.file &&
          File(appImage).statSync().mode & 0x49 != 0) {
        // Platform.resolvedExecutable points inside AppImage's ephemeral
        // /tmp/.mount_* tree. APPIMAGE is the stable outer file which must be
        // stored in a persistent protocol entry.
        return appImage;
      }
    }
    return _resolvedExecutable;
  }

  Iterable<String> get _desktopSearchDirectories sync* {
    yield _applicationsDirectory.path;
    final configured = _environment['XDG_DATA_DIRS']?.trim();
    final directories = configured == null || configured.isEmpty
        ? const ['/usr/local/share', '/usr/share']
        : configured.split(':');
    for (final directory in directories) {
      if (p.isAbsolute(directory) && !directory.contains('\u0000')) {
        yield p.join(directory, 'applications');
      }
    }
  }

  String _registrationKey(String scheme) =>
      '${_applicationsDirectory.path}\u0000$scheme';

  @visibleForTesting
  static String normalizeScheme(String scheme) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$').hasMatch(scheme)) {
      throw ArgumentError.value(scheme, 'scheme', 'Must be a valid URI scheme');
    }
    return scheme.toLowerCase();
  }

  @visibleForTesting
  static String mimeTypeForScheme(String scheme) =>
      'x-scheme-handler/${normalizeScheme(scheme)}';

  @visibleForTesting
  static String desktopIdForScheme(String scheme) =>
      'com.kodjodevf.mangayomi.protocol.${normalizeScheme(scheme)}.desktop';

  @visibleForTesting
  static String buildDesktopEntry({
    required String scheme,
    required String executable,
    Iterable<String> arguments = const ['%s'],
  }) {
    final normalizedScheme = normalizeScheme(scheme);
    final command = buildExecCommand(executable, arguments);
    return '''[Desktop Entry]
Version=1.5
Type=Application
Name=Mangatan URL Handler
NoDisplay=true
Terminal=false
$_ownerKey=$persistentOwnerValue
$_schemeKey=$normalizedScheme
Exec=$command
MimeType=${mimeTypeForScheme(normalizedScheme)};
''';
  }

  @visibleForTesting
  static String buildExecCommand(
    String executable,
    Iterable<String> arguments,
  ) {
    if (executable.isEmpty || executable.contains('=')) {
      throw ArgumentError.value(
        executable,
        'executable',
        'Must be a non-empty desktop Exec program without an equals sign',
      );
    }
    final values = arguments.toList(growable: false);
    final placeholderCount = values.where((value) => value == '%s').length;
    if (placeholderCount != 1 ||
        values.any((value) => value != '%s' && value.contains('%s'))) {
      throw ArgumentError(
        'Linux protocol arguments require exactly one standalone "%s".',
      );
    }
    return [
      _quoteExecArgument(executable),
      for (final argument in values)
        if (argument == '%s') '%u' else _quoteExecArgument(argument),
    ].join(' ');
  }

  @visibleForTesting
  static bool isOwnedDesktopEntry(String content, {required String scheme}) {
    final normalizedScheme = normalizeScheme(scheme);
    final values = _desktopEntryValues(content);
    final mimeTypes = (values['MimeType'] ?? '')
        .split(';')
        .where((value) => value.isNotEmpty)
        .toSet();
    final ownedSchemes = (values[_schemesKey] ?? '')
        .split(';')
        .where((value) => value.isNotEmpty)
        .map(normalizeScheme)
        .toSet();
    return values[_ownerKey] == persistentOwnerValue &&
        (values[_schemeKey] == normalizedScheme ||
            ownedSchemes.contains(normalizedScheme)) &&
        mimeTypes.contains(mimeTypeForScheme(normalizedScheme)) &&
        _hasStandaloneUrlFieldCode(values['Exec']);
  }

  /// Recognizes only Mangatan's package-managed desktop ids and launch shape.
  ///
  /// Some packagers regenerate the desktop file and discard extension keys.
  /// The marker path is preferred, while this narrow legacy shape prevents an
  /// arbitrary scheme claimant from being mistaken for Mangatan.
  @visibleForTesting
  static bool isOwnedPackagedDesktopEntry({
    required String desktopId,
    required String content,
    required String scheme,
  }) {
    final normalizedScheme = normalizeScheme(scheme);
    if (!_packagedDesktopIds.contains(desktopId) ||
        (normalizedScheme != _appScheme &&
            normalizedScheme != _chimahonOAuthScheme)) {
      return false;
    }
    final values = _desktopEntryValues(content);
    final mimeTypes = (values['MimeType'] ?? '')
        .split(';')
        .where((value) => value.isNotEmpty)
        .toSet();
    final executable = _desktopExecProgram(values['Exec']);
    final executableName = executable == null
        ? null
        : p.basename(executable).toLowerCase();
    final hasOwnedMarkers = isOwnedDesktopEntry(
      content,
      scheme: normalizedScheme,
    );
    return values['Type'] == 'Application' &&
        values['Name'] == 'Mangatan' &&
        (executableName == 'mangayomi' || executableName == 'mangatan') &&
        _hasStandaloneUrlFieldCode(values['Exec']) &&
        mimeTypes.contains(mimeTypeForScheme(_appScheme)) &&
        mimeTypes.contains(mimeTypeForScheme(_chimahonOAuthScheme)) &&
        (hasOwnedMarkers || !values.containsKey(_ownerKey));
  }

  static bool _hasStandaloneUrlFieldCode(String? command) {
    if (command == null) return false;
    final tokens = command.trim().split(RegExp(r'\s+'));
    return tokens.where((token) => token == '%u' || token == '%U').length == 1;
  }

  static String? _desktopExecProgram(String? command) {
    if (command == null) return null;
    final trimmed = command.trimLeft();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('"')) {
      final tokens = trimmed.split(RegExp(r'\s+'));
      // Fastforge's AppImage template prefixes Mangatan with this one exact
      // bundle-relative library assignment. Do not generalize this to other
      // environment assignments or shell syntax.
      if (tokens.length >= 2 && tokens.first == 'LD_LIBRARY_PATH=usr/lib') {
        return tokens[1];
      }
      return tokens.first;
    }
    final closingQuote = trimmed.indexOf('"', 1);
    if (closingQuote <= 1) return null;
    return trimmed.substring(1, closingQuote);
  }

  static Map<String, String> _desktopEntryValues(String content) {
    final values = <String, String>{};
    var inDesktopEntry = false;
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        inDesktopEntry = line == '[Desktop Entry]';
        continue;
      }
      if (!inDesktopEntry) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      values[line.substring(0, separator)] = line.substring(separator + 1);
    }
    return values;
  }

  static String _schemeFromContent(String content) {
    final scheme = _desktopEntryValues(content)[_schemeKey];
    if (scheme == null) {
      throw StateError('The generated Linux protocol entry has no scheme.');
    }
    return scheme;
  }

  static String _quoteExecArgument(String value) {
    if (value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      throw ArgumentError.value(
        value,
        'desktop Exec argument',
        'Control characters are not allowed',
      );
    }
    final escaped = StringBuffer('"');
    for (final rune in value.runes) {
      switch (rune) {
        case 0x5c: // Backslash: two escaping layers in a desktop Exec value.
          escaped.write(r'\\\\');
        case 0x22: // Double quote.
          escaped.write(r'\\\"');
        case 0x24: // Dollar sign.
          escaped.write(r'\\$');
        case 0x60: // Backtick.
          escaped.write(r'\\`');
        case 0x25: // Literal percent; field codes are expanded separately.
          escaped.write('%%');
        default:
          escaped.writeCharCode(rune);
      }
    }
    escaped.write('"');
    return escaped.toString();
  }

  static ProcessResult _runProcess(String executable, List<String> arguments) {
    return Process.runSync(executable, arguments, runInShell: false);
  }
}

class _LinuxProtocolRegistration {
  _LinuxProtocolRegistration(this.command);

  final String command;
  int depth = 1;
}
