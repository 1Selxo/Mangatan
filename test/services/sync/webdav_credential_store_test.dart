import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/sync/google_drive_refresh_token_store.dart';
import 'package:mangayomi/services/sync/webdav_credential_store.dart';

void main() {
  late _MemorySecureValueStoreBackend backend;
  late SecureWebDavCredentialStore store;

  setUp(() {
    backend = _MemorySecureValueStoreBackend();
    store = SecureWebDavCredentialStore(backend: backend);
  });

  test('round-trips WebDAV credentials through secure storage', () async {
    await store.writeCredentials(
      const WebDavCredentials(username: 'reader', password: 'secret'),
    );

    final raw = backend.values[SecureWebDavCredentialStore.defaultStorageKey];
    expect(raw, contains('reader'));
    expect(raw, contains('secret'));
    final credentials = await store.readCredentials();
    expect(credentials?.username, 'reader');
    expect(credentials?.password, 'secret');
  });

  test('rejects blank credentials without changing secure storage', () async {
    await store.writeCredentials(
      const WebDavCredentials(username: 'reader', password: 'secret'),
    );

    await expectLater(
      store.writeCredentials(
        const WebDavCredentials(username: ' ', password: ''),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect((await store.readCredentials())?.username, 'reader');
  });

  test('clears only the WebDAV secure item', () async {
    backend.values.addAll({
      SecureWebDavCredentialStore.defaultStorageKey:
          '{"username":"reader","password":"secret"}',
      'unrelated': 'keep',
    });

    await store.clearCredentials();

    expect(await store.readCredentials(), isNull);
    expect(backend.values['unrelated'], 'keep');
  });
}

class _MemorySecureValueStoreBackend implements SecureValueStoreBackend {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
