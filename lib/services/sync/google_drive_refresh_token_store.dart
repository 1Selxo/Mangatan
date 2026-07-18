import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    return backend.write(key: storageKey, value: refreshToken);
  }

  @override
  Future<void> clearRefreshToken() async {
    await backend.delete(key: storageKey);
    for (final legacyKey in legacyStorageKeys) {
      if (legacyKey != storageKey) await backend.delete(key: legacyKey);
    }
  }

  String? _usableToken(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
