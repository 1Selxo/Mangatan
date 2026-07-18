import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

import './protocol.dart';

const _hive = HKEY_CURRENT_USER;

class WindowsProtocolHandler extends ProtocolHandler {
  static final Map<String, _OwnedProtocolRegistration> _registrations = {};
  static const _ownerValueName = 'Mangatan Protocol Owner';
  static const _temporaryOwnerValue = 'com.kodjodevf.mangayomi/temporary/v1';
  static const _persistentOwnerValue = 'com.kodjodevf.mangayomi/persistent/v1';

  @override
  void register(String scheme, {String? executable, List<String>? arguments}) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;

    final normalizedScheme = normalizeScheme(scheme);
    final prefix = _regPrefix(normalizedScheme);
    final capitalized =
        normalizedScheme[0].toUpperCase() + normalizedScheme.substring(1);
    final cmd = buildCommand(
      executable ?? Platform.resolvedExecutable,
      getArguments(arguments),
    );
    final active = _registrations[normalizedScheme];
    if (active != null) {
      if (active.command != cmd) {
        throw StateError(
          'The URL protocol is already leased by this Mangatan process with '
          'a different command.',
        );
      }
      active.depth++;
      return;
    }

    final keyAlreadyExisted = _registryKeyExists(prefix);
    if (keyAlreadyExisted) {
      final existingCommand = _readRegistryString(
        '$prefix\\shell\\open\\command',
        '',
      );
      final urlProtocol = _readRegistryString(prefix, 'URL Protocol');
      final ownsAbandonedTemporaryRegistration = isOwnedTemporaryRegistration(
        owner: _readRegistryString(prefix, _ownerValueName),
      );
      if ((existingCommand != cmd || urlProtocol == null) &&
          !ownsAbandonedTemporaryRegistration) {
        throw StateError(
          'The $normalizedScheme URL protocol is already registered by '
          'another application; Mangatan will not overwrite it.',
        );
      }
      if (ownsAbandonedTemporaryRegistration) {
        _writeProtocolRegistration(
          prefix: prefix,
          capitalizedScheme: capitalized,
          command: cmd,
          ownerValue: _temporaryOwnerValue,
        );
      }
      _registrations[normalizedScheme] = _OwnedProtocolRegistration(
        command: cmd,
        deleteOnRelease: ownsAbandonedTemporaryRegistration,
      );
      return;
    }

    try {
      _writeProtocolRegistration(
        prefix: prefix,
        capitalizedScheme: capitalized,
        command: cmd,
        ownerValue: _temporaryOwnerValue,
      );
    } catch (_) {
      // The root did not exist before this call, so removing a partially
      // created tree cannot damage another application's registration.
      _deleteRegistryTree(prefix, ignoreMissing: true);
      rethrow;
    }
    _registrations[normalizedScheme] = _OwnedProtocolRegistration(
      command: cmd,
      deleteOnRelease: true,
    );
  }

  @override
  void registerPersistent(
    String scheme, {
    String? executable,
    List<String>? arguments,
  }) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;

    final normalizedScheme = normalizeScheme(scheme);
    final prefix = _regPrefix(normalizedScheme);
    final capitalized =
        normalizedScheme[0].toUpperCase() + normalizedScheme.substring(1);
    final command = buildCommand(
      executable ?? Platform.resolvedExecutable,
      getArguments(arguments),
    );
    final keyAlreadyExisted = _registryKeyExists(prefix);
    if (keyAlreadyExisted) {
      final existingOwner = _readRegistryString(prefix, _ownerValueName);
      if (existingOwner != _persistentOwnerValue &&
          !isLegacyMangatanRegistration(
            scheme: normalizedScheme,
            description: _readRegistryString(prefix, ''),
            urlProtocol: _readRegistryString(prefix, 'URL Protocol'),
            command: _readRegistryString('$prefix\\shell\\open\\command', ''),
          )) {
        throw StateError(
          'The $normalizedScheme URL protocol is already registered by '
          'another application; Mangatan will not overwrite it.',
        );
      }
    }

    try {
      _writeProtocolRegistration(
        prefix: prefix,
        capitalizedScheme: capitalized,
        command: command,
        ownerValue: _persistentOwnerValue,
      );
    } catch (_) {
      if (!keyAlreadyExisted) {
        _deleteRegistryTree(prefix, ignoreMissing: true);
      }
      rethrow;
    }
  }

  @override
  void unregister(String scheme) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    final normalizedScheme = normalizeScheme(scheme);
    final registration = _registrations[normalizedScheme];
    if (registration == null) return;
    registration.depth--;
    if (registration.depth > 0) return;
    _registrations.remove(normalizedScheme);

    // A matching handler which predated this OAuth attempt belongs to its
    // owner and must remain. If another process replaced our temporary entry,
    // leave that newer registration untouched as well.
    if (!registration.deleteOnRelease) return;
    final prefix = _regPrefix(normalizedScheme);
    final currentCommand = _readRegistryString(
      '$prefix\\shell\\open\\command',
      '',
    );
    final stillOwnsTemporaryRegistration = isOwnedTemporaryRegistration(
      owner: _readRegistryString(prefix, _ownerValueName),
    );
    if (currentCommand == registration.command &&
        stillOwnsTemporaryRegistration) {
      _deleteRegistryTree(prefix, ignoreMissing: true);
    }
  }

  String _regPrefix(String scheme) => 'SOFTWARE\\Classes\\$scheme';

  @visibleForTesting
  static String buildCommand(String executable, Iterable<String> arguments) {
    if (executable.isEmpty) {
      throw ArgumentError.value(executable, 'executable', 'Must not be empty');
    }
    final command = <String>[
      _quoteCommandLineArgument(executable),
      ...arguments.map(
        (argument) =>
            _quoteCommandLineArgument(argument.replaceAll(r'%s', '%1')),
      ),
    ];
    return command.join(' ');
  }

  @visibleForTesting
  static String normalizeScheme(String scheme) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*$').hasMatch(scheme)) {
      throw ArgumentError.value(scheme, 'scheme', 'Must be a valid URI scheme');
    }
    return scheme.toLowerCase();
  }

  /// Recognizes registrations written by Mangayomi/Mangatan versions which
  /// predate the explicit ownership marker. Keep this deliberately narrow: a
  /// different scheme, description, URL marker, executable, or missing callback
  /// placeholder must never be claimed.
  @visibleForTesting
  static bool isLegacyMangatanRegistration({
    required String scheme,
    required String? description,
    required String? urlProtocol,
    required String? command,
  }) {
    if (scheme.toLowerCase() != 'mangayomi' ||
        description?.toLowerCase() != 'url:mangayomi' ||
        urlProtocol != '' ||
        command == null ||
        !command.contains('%1')) {
      return false;
    }
    final trimmed = command.trimLeft();
    late final String executable;
    if (trimmed.startsWith('"')) {
      final closingQuote = trimmed.indexOf('"', 1);
      if (closingQuote < 0) return false;
      executable = trimmed.substring(1, closingQuote);
    } else {
      // Old Mangayomi builds did not quote the executable, even when its path
      // contained spaces. Stop at the first executable suffix so a shell such
      // as `cmd.exe /c ...` cannot be mistaken for an owned registration.
      final executableEnd = RegExp(
        r'\.exe(?=\s|$)',
        caseSensitive: false,
      ).firstMatch(trimmed)?.end;
      if (executableEnd == null) return false;
      executable = trimmed.substring(0, executableEnd);
    }
    final normalizedExecutable = executable.replaceAll('/', r'\');
    final basename = normalizedExecutable
        .substring(normalizedExecutable.lastIndexOf(r'\') + 1)
        .toLowerCase();
    return basename == 'mangayomi.exe';
  }

  @visibleForTesting
  static bool isOwnedTemporaryRegistration({required String? owner}) =>
      owner == _temporaryOwnerValue;

  void _writeProtocolRegistration({
    required String prefix,
    required String capitalizedScheme,
    required String command,
    required String ownerValue,
  }) {
    // Write the ownership marker first. If the process terminates between
    // registry writes, the next Mangatan process can safely repair this tree.
    _regCreateStringKeyOrThrow(_hive, prefix, _ownerValueName, ownerValue);
    _regCreateStringKeyOrThrow(_hive, prefix, '', 'URL:$capitalizedScheme');
    _regCreateStringKeyOrThrow(_hive, prefix, 'URL Protocol', '');
    _regCreateStringKeyOrThrow(
      _hive,
      '$prefix\\shell\\open\\command',
      '',
      command,
    );
  }

  int _regCreateStringKey(int hKey, String key, String valueName, String data) {
    final txtKey = TEXT(key);
    final txtValue = TEXT(valueName);
    final txtData = TEXT(data);
    try {
      return RegSetKeyValue(
        hKey,
        txtKey,
        txtValue,
        REG_SZ,
        txtData,
        txtData.length * 2 + 2,
      );
    } finally {
      free(txtKey);
      free(txtValue);
      free(txtData);
    }
  }

  void _regCreateStringKeyOrThrow(
    int hKey,
    String key,
    String valueName,
    String data,
  ) {
    final result = _regCreateStringKey(hKey, key, valueName, data);
    if (result != ERROR_SUCCESS) {
      throw WindowsException(
        result,
        message:
            'Could not register the URL protocol in the current-user '
            'registry key $key',
      );
    }
  }

  bool _registryKeyExists(String key) {
    final txtKey = TEXT(key);
    final openedKey = calloc<HKEY>();
    try {
      final result = RegOpenKeyEx(_hive, txtKey, 0, KEY_READ, openedKey);
      if (result == ERROR_FILE_NOT_FOUND) return false;
      if (result != ERROR_SUCCESS) {
        throw WindowsException(
          result,
          message: 'Could not inspect current-user registry key $key',
        );
      }
      RegCloseKey(openedKey.value);
      return true;
    } finally {
      free(txtKey);
      free(openedKey);
    }
  }

  String? _readRegistryString(String key, String valueName) {
    final txtKey = TEXT(key);
    final txtValue = TEXT(valueName);
    final dataType = calloc<DWORD>();
    final dataSize = calloc<DWORD>();
    Pointer<Uint8>? data;
    try {
      var result = RegGetValue(
        _hive,
        txtKey,
        txtValue,
        RRF_RT_REG_SZ,
        dataType,
        nullptr,
        dataSize,
      );
      if (result == ERROR_FILE_NOT_FOUND) return null;
      if (result != ERROR_SUCCESS) {
        throw WindowsException(
          result,
          message: 'Could not inspect current-user registry value $key',
        );
      }
      data = calloc<Uint8>(dataSize.value);
      result = RegGetValue(
        _hive,
        txtKey,
        txtValue,
        RRF_RT_REG_SZ,
        dataType,
        data,
        dataSize,
      );
      if (result != ERROR_SUCCESS) {
        throw WindowsException(
          result,
          message: 'Could not read current-user registry value $key',
        );
      }
      return data.cast<Utf16>().toDartString();
    } finally {
      free(txtKey);
      free(txtValue);
      free(dataType);
      free(dataSize);
      if (data != null) free(data);
    }
  }

  void _deleteRegistryTree(String key, {required bool ignoreMissing}) {
    final txtKey = TEXT(key);
    try {
      final result = RegDeleteTree(_hive, txtKey);
      if (result != ERROR_SUCCESS &&
          !(ignoreMissing && result == ERROR_FILE_NOT_FOUND)) {
        throw WindowsException(
          result,
          message: 'Could not remove current-user registry key $key',
        );
      }
    } finally {
      free(txtKey);
    }
  }

  static String _quoteCommandLineArgument(String value) {
    final quoted = StringBuffer('"');
    var backslashes = 0;
    for (final codeUnit in value.codeUnits) {
      if (codeUnit == 0x5c) {
        backslashes++;
        continue;
      }
      if (codeUnit == 0x22) {
        _writeBackslashes(quoted, backslashes * 2 + 1);
        quoted.writeCharCode(codeUnit);
      } else {
        _writeBackslashes(quoted, backslashes);
        quoted.writeCharCode(codeUnit);
      }
      backslashes = 0;
    }
    // Backslashes immediately before the closing quote must be doubled.
    _writeBackslashes(quoted, backslashes * 2);
    quoted.write('"');
    return quoted.toString();
  }

  static void _writeBackslashes(StringBuffer target, int count) {
    for (var index = 0; index < count; index++) {
      target.writeCharCode(0x5c);
    }
  }
}

class _OwnedProtocolRegistration {
  _OwnedProtocolRegistration({
    required this.command,
    required this.deleteOnRelease,
  });

  final String command;
  final bool deleteOnRelease;
  int depth = 1;
}
