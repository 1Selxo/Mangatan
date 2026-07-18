import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mangayomi/services/sync/google_drive_refresh_token_store.dart';

void main() {
  late _MemorySecureValueStoreBackend backend;
  late SecureGoogleDriveRefreshTokenStore store;

  setUp(() {
    backend = _MemorySecureValueStoreBackend();
    store = SecureGoogleDriveRefreshTokenStore(backend: backend);
  });

  test('uses the ad-hoc-signing-compatible macOS Keychain', () {
    const secureBackend = FlutterSecureValueStoreBackend();

    expect(
      (secureBackend.storage.mOptions as MacOsOptions)
          .usesDataProtectionKeychain,
      isFalse,
    );
    expect(
      FlutterSecureValueStoreBackend.macOsItemOptions.label,
      'Mangatan Google Drive sync',
    );
    expect(
      FlutterSecureValueStoreBackend.macOsItemOptions.description,
      'Saved sign-in for Chimahon sync.',
    );
  });

  test('uses the native libsecret backend on Linux', () {
    const secureBackend = FlutterSecureValueStoreBackend();

    expect(secureBackend.storage.lOptions, isA<LinuxOptions>());
  });

  test('round-trips refresh token through secure backend', () async {
    await store.writeRefreshToken('refresh-token');

    expect(
      backend.values[SecureGoogleDriveRefreshTokenStore.defaultStorageKey],
      'refresh-token',
    );
    expect(await store.readRefreshToken(), 'refresh-token');
  });

  test('supports an injected storage key', () async {
    const storageKey = 'test.google.refresh-token';
    store = SecureGoogleDriveRefreshTokenStore(
      backend: backend,
      storageKey: storageKey,
    );

    await store.writeRefreshToken('refresh-token');

    expect(backend.values, {storageKey: 'refresh-token'});
  });

  test('migrates the legacy technical key to the friendly item once', () async {
    final legacyKey =
        SecureGoogleDriveRefreshTokenStore.defaultLegacyStorageKeys.single;
    backend.values[legacyKey] = 'legacy-refresh-token';

    expect(await store.readRefreshToken(), 'legacy-refresh-token');
    expect(
      backend.values[SecureGoogleDriveRefreshTokenStore.defaultStorageKey],
      'legacy-refresh-token',
    );
    expect(backend.values[legacyKey], 'legacy-refresh-token');

    backend.readKeys.clear();
    expect(await store.readRefreshToken(), 'legacy-refresh-token');
    expect(backend.readKeys, [
      SecureGoogleDriveRefreshTokenStore.defaultStorageKey,
    ]);
  });

  test('treats missing and legacy blank values as absent', () async {
    expect(await store.readRefreshToken(), isNull);

    backend.values[SecureGoogleDriveRefreshTokenStore.defaultStorageKey] = '  ';

    expect(await store.readRefreshToken(), isNull);
  });

  test('rejects blank token without modifying secure storage', () async {
    await store.writeRefreshToken('existing-token');

    expect(() => store.writeRefreshToken('  '), throwsA(isA<ArgumentError>()));
    expect(await store.readRefreshToken(), 'existing-token');
  });

  test('clears current and legacy refresh-token keys only', () async {
    final legacyKey =
        SecureGoogleDriveRefreshTokenStore.defaultLegacyStorageKeys.single;
    backend.values.addAll({
      SecureGoogleDriveRefreshTokenStore.defaultStorageKey: 'refresh-token',
      legacyKey: 'legacy-token',
      'unrelated-key': 'keep-me',
    });

    await store.clearRefreshToken();

    expect(await store.readRefreshToken(), isNull);
    expect(backend.values[legacyKey], isNull);
    expect(backend.values['unrelated-key'], 'keep-me');
  });
}

class _MemorySecureValueStoreBackend implements SecureValueStoreBackend {
  final values = <String, String>{};
  final readKeys = <String>[];

  @override
  Future<String?> read({required String key}) async {
    readKeys.add(key);
    return values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
