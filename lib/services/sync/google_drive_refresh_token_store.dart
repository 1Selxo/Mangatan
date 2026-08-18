import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

enum SyncCredentialAccessFailureReason { denied, locked, missing, unavailable }

/// Sanitized credential-store failure which never includes secret values or
/// platform exception details.
class SyncCredentialAccessException implements Exception {
  const SyncCredentialAccessException(this.reason);

  final SyncCredentialAccessFailureReason reason;
}

/// Persistence contract for the long-lived Google Drive credential.
///
/// OAuth and sync orchestration depend on this interface rather than a
/// platform plugin, which keeps credential storage injectable and testable.
abstract interface class GoogleDriveRefreshTokenStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String refreshToken);

  Future<void> clearRefreshToken();
}

/// Minimal secure key-value backend used by
/// [SecureGoogleDriveRefreshTokenStore].
abstract interface class SecureValueStoreBackend {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

/// Desktop-native secure storage backed by Keychain on macOS, a
/// DPAPI-encrypted file on Windows, and Secret Service through libsecret on
/// Linux.
class FlutterSecureValueStoreBackend implements SecureValueStoreBackend {
  const FlutterSecureValueStoreBackend({
    this.storage = const FlutterSecureStorage(
      // Mangatan is ad-hoc signed on macOS. The classic Keychain remains
      // encrypted by macOS without requiring a provisioning-only access group.
      mOptions: macOsQueryOptions,
      // LinuxOptions currently has no per-item label tunables; specifying it
      // documents that this backend intentionally uses the registered
      // libsecret plugin.
      lOptions: LinuxOptions(),
    ),
  });

  static const macOsQueryOptions = MacOsOptions(
    usesDataProtectionKeychain: false,
  );
  static const macOsItemOptions = MacOsOptions(
    usesDataProtectionKeychain: false,
    label: 'Mangatan Google Drive sync',
    description: 'Saved sign-in for Chimahon sync.',
  );

  final FlutterSecureStorage storage;

  @override
  Future<String?> read({required String key}) =>
      storage.read(key: key, mOptions: macOsQueryOptions);

  @override
  Future<void> write({required String key, required String value}) =>
      storage.write(key: key, value: value, mOptions: macOsItemOptions);

  @override
  Future<void> delete({required String key}) =>
      storage.delete(key: key, mOptions: macOsQueryOptions);
}

/// Stores the Google Drive refresh token outside Isar/preferences so it is
/// encrypted by the operating system's credential store.
class SecureGoogleDriveRefreshTokenStore
    implements GoogleDriveRefreshTokenStore {
  const SecureGoogleDriveRefreshTokenStore({
    this.backend = const FlutterSecureValueStoreBackend(),
    this.storageKey = defaultStorageKey,
    List<String>? legacyStorageKeys,
  }) : legacyStorageKeys =
           legacyStorageKeys ??
           (storageKey == defaultStorageKey
               ? defaultLegacyStorageKeys
               : const []);

  /// This account name is deliberately user-facing: macOS includes it in its
  /// Keychain authorization dialog.
  static const defaultStorageKey = 'Mangatan Google Drive sync';
  static const defaultLegacyStorageKeys = [
    'com.kodjodevf.mangayomi.google_drive.refresh_token.v1',
  ];

  final SecureValueStoreBackend backend;
  final String storageKey;
  final List<String> legacyStorageKeys;

  @override
  Future<String?> readRefreshToken() async {
    try {
      final current = _usableToken(await backend.read(key: storageKey));
      if (current != null) return current;
      for (final legacyKey in legacyStorageKeys) {
        if (legacyKey == storageKey) continue;
        final legacy = _usableToken(await backend.read(key: legacyKey));
        if (legacy == null) continue;
        // Create the friendly, labelled item before using it. Keep the legacy
        // item until explicit disconnect so this one-time migration cannot add
        // a second Keychain authorization prompt or lose the only credential.
        await backend.write(key: storageKey, value: legacy);
        return legacy;
      }
      return null;
    } catch (error) {
      throw _credentialAccessException(error);
    }
  }

  @override
  Future<void> writeRefreshToken(String refreshToken) {
    if (refreshToken.trim().isEmpty) {
      throw ArgumentError.value(
        refreshToken,
        'refreshToken',
        'Refresh token must not be blank',
      );
    }
    return _write(refreshToken);
  }

  Future<void> _write(String refreshToken) async {
    try {
      await backend.write(key: storageKey, value: refreshToken);
    } catch (error) {
      throw _credentialAccessException(error);
    }
  }

  @override
  Future<void> clearRefreshToken() async {
    try {
      await backend.delete(key: storageKey);
      for (final legacyKey in legacyStorageKeys) {
        if (legacyKey != storageKey) await backend.delete(key: legacyKey);
      }
    } catch (error) {
      throw _credentialAccessException(error);
    }
  }

  String? _usableToken(String? value) =>
      value == null || value.trim().isEmpty ? null : value;

  SyncCredentialAccessException _credentialAccessException(Object error) {
    if (error is SyncCredentialAccessException) return error;
    if (error is! PlatformException) {
      return const SyncCredentialAccessException(
        SyncCredentialAccessFailureReason.unavailable,
      );
    }
    final markers = <String>{error.code.trim().toLowerCase()};
    void addMarker(Object? value) {
      if (value is String || value is num) {
        markers.add(value.toString().trim().toLowerCase());
      }
    }

    final details = error.details;
    if (details is Map) {
      for (final entry in details.entries) {
        addMarker(entry.key);
        addMarker(entry.value);
      }
    } else {
      addMarker(details);
    }
    if (markers.any(
      (marker) =>
          marker == '-25293' ||
          marker == 'errsecauthfailed' ||
          marker == 'authfailed' ||
          marker == 'cssmerr_csp_operation_auth_denied' ||
          marker == 'authorization_denied',
    )) {
      return const SyncCredentialAccessException(
        SyncCredentialAccessFailureReason.denied,
      );
    }
    if (markers.any(
      (marker) =>
          marker == '-25308' ||
          marker == 'errsecinteractionnotallowed' ||
          marker == 'interactionnotallowed' ||
          marker == 'interaction_not_allowed' ||
          marker == 'keychain_locked',
    )) {
      return const SyncCredentialAccessException(
        SyncCredentialAccessFailureReason.locked,
      );
    }
    if (markers.any(
      (marker) =>
          marker == '-25300' ||
          marker == 'errsecitemnotfound' ||
          marker == 'item_not_found',
    )) {
      return const SyncCredentialAccessException(
        SyncCredentialAccessFailureReason.missing,
      );
    }
    return const SyncCredentialAccessException(
      SyncCredentialAccessFailureReason.unavailable,
    );
  }
}
