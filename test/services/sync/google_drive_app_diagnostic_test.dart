import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/sync/google_drive_app_diagnostic.dart';
import 'package:mangayomi/services/sync/google_drive_conditional_write_probe.dart';
import 'package:mangayomi/services/sync/google_drive_refresh_token_store.dart';

import '../../../tool/chimahon_drive_diagnostic.dart' as diagnostic_cli;

void main() {
  const refreshToken = 'private-refresh-token';
  const accessToken = 'private-access-token';

  test('runner keeps credentials inside the app-owned call chain', () async {
    final tokenStore = _MemoryTokenStore(refreshToken);
    String? refreshedWith;
    String? inspectedWith;
    final runner = GoogleDriveAppDiagnosticRunner(
      tokenStore: tokenStore,
      refreshAccessToken: (token) async {
        refreshedWith = token;
        return accessToken;
      },
      inspectAccessToken: (token) async {
        inspectedWith = token;
        return {'candidateCount': 1, 'validCandidateCount': 1};
      },
    );

    final report = await runner.inspect();

    expect(refreshedWith, refreshToken);
    expect(inspectedWith, accessToken);
    expect(report, {'candidateCount': 1, 'validCandidateCount': 1});
    final encoded = jsonEncode(report);
    expect(encoded, isNot(contains(refreshToken)));
    expect(encoded, isNot(contains(accessToken)));
    expect(tokenStore.writeCount, 0);
    expect(tokenStore.clearCount, 0);
  });

  test(
    'runner reports a missing secure credential without refreshing',
    () async {
      var refreshCalled = false;
      var inspectCalled = false;
      final runner = GoogleDriveAppDiagnosticRunner(
        tokenStore: _MemoryTokenStore(null),
        refreshAccessToken: (_) async {
          refreshCalled = true;
          return accessToken;
        },
        inspectAccessToken: (_) async {
          inspectCalled = true;
          return const {};
        },
      );

      await expectLater(
        runner.inspect(),
        throwsA(
          isA<GoogleDriveAppDiagnosticException>().having(
            (error) => error.code,
            'code',
            'notConnected',
          ),
        ),
      );
      expect(refreshCalled, isFalse);
      expect(inspectCalled, isFalse);
    },
  );

  test(
    'runner invokes the disposable probe only after token refresh',
    () async {
      final tokenStore = _MemoryTokenStore(refreshToken);
      String? probedWith;
      var inspected = false;
      final runner = GoogleDriveAppDiagnosticRunner(
        tokenStore: tokenStore,
        refreshAccessToken: (token) async {
          expect(token, refreshToken);
          return accessToken;
        },
        inspectAccessToken: (_) async {
          inspected = true;
          return const {};
        },
        probeAccessToken: (token) async {
          probedWith = token;
          return {
            'generatedFileName': 'safe-disposable-probe.tmp',
            'pairings': const [],
          };
        },
      );

      final result = await runner.conditionalWriteProbe();

      expect(probedWith, accessToken);
      expect(inspected, isFalse);
      expect(result['generatedFileName'], 'safe-disposable-probe.tmp');
      expect(tokenStore.writeCount, 0);
      expect(tokenStore.clearCount, 0);
    },
  );

  test(
    'handler posts only a redacted result without following redirects',
    () async {
      const nonce =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final callback = Uri.parse(
        'http://127.0.0.1:49152/chimahon-drive-diagnostic/$nonce',
      );
      final link = _diagnosticLink(callback);
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      });
      final runner = GoogleDriveAppDiagnosticRunner(
        tokenStore: _MemoryTokenStore(refreshToken),
        refreshAccessToken: (_) async => accessToken,
        inspectAccessToken: (_) async => {
          'accountPermissionIdSha256': 'safe-account-hash',
          'candidateCount': 1,
        },
      );
      final handler = GoogleDriveDebugDiagnosticHandler(
        runner: runner,
        client: client,
        enabled: true,
      );

      expect(await handler.handle(link), isTrue);

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url, callback);
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      expect(
        request.headers['Content-Type'],
        'application/json; charset=utf-8',
      );
      final response = jsonDecode(request.body) as Map<String, dynamic>;
      expect(response['schemaVersion'], 1);
      expect(response['operation'], 'inspect');
      expect(response['ok'], isTrue);
      expect(response['report'], {
        'accountPermissionIdSha256': 'safe-account-hash',
        'candidateCount': 1,
      });
      expect(request.body, isNot(contains(refreshToken)));
      expect(request.body, isNot(contains(accessToken)));
    },
  );

  test(
    'sync preview fetches the nonce-bound reference without redirects',
    () async {
      final callback = Uri.parse(
        'http://127.0.0.1:49161/chimahon-drive-sync-preview/${'3' * 64}',
      );
      final reference = Uint8List.fromList(const [31, 139, 8, 0, 1, 2, 3]);
      final requests = <http.Request>[];
      Uint8List? previewedReference;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response.bytes(
            reference,
            200,
            headers: const {'Content-Type': 'application/octet-stream'},
          );
        }
        return http.Response('', 204);
      });
      final handler = GoogleDriveDebugDiagnosticHandler(
        runner: GoogleDriveAppDiagnosticRunner(
          tokenStore: _MemoryTokenStore(refreshToken),
          refreshAccessToken: (_) async => accessToken,
          inspectAccessToken: (_) async => const {},
        ),
        syncPreview: (bytes) async {
          previewedReference = Uint8List.fromList(bytes);
          return const {'referencePresent': true, 'safeForFirstUpload': true};
        },
        client: client,
        enabled: true,
      );

      expect(
        await handler.handle(
          _diagnosticLink(
            callback,
            operation: GoogleDriveAppDiagnosticOperation.syncPreview,
            useReferenceTransport: true,
          ),
        ),
        isTrue,
      );

      expect(previewedReference, reference);
      expect(requests, hasLength(2));
      final get = requests.first;
      expect(get.method, 'GET');
      expect(
        get.url,
        callback.replace(
          pathSegments: [
            ...callback.pathSegments,
            GoogleDriveDebugDiagnosticHandler.referencePathSegment,
          ],
        ),
      );
      expect(get.followRedirects, isFalse);
      expect(get.maxRedirects, 0);
      expect(get.headers['Accept'], 'application/octet-stream');
      final posted = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(posted, {
        'schemaVersion': 1,
        'operation': 'sync-preview',
        'ok': true,
        'preview': {'referencePresent': true, 'safeForFirstUpload': true},
      });
      expect(requests.last.body, isNot(contains(refreshToken)));
      expect(requests.last.body, isNot(contains(accessToken)));
    },
  );

  test('sync preview cancels a reference body at the total deadline', () async {
    final callback = Uri.parse(
      'http://127.0.0.1:49164/chimahon-drive-sync-preview/${'5' * 64}',
    );
    var referenceCancelled = false;
    var previewCalled = false;
    String? postedBody;
    late final StreamController<List<int>> referenceController;
    referenceController = StreamController<List<int>>(
      onListen: () => referenceController.add(const [31, 139]),
      onCancel: () => referenceCancelled = true,
    );
    addTearDown(referenceController.close);
    final client = MockClient.streaming((request, bodyStream) async {
      final body = await bodyStream.toBytes();
      if (request.method == 'GET') {
        return http.StreamedResponse(referenceController.stream, 200);
      }
      postedBody = utf8.decode(body);
      return http.StreamedResponse(const Stream.empty(), 204);
    });
    final handler = GoogleDriveDebugDiagnosticHandler(
      runner: GoogleDriveAppDiagnosticRunner(
        tokenStore: _MemoryTokenStore(refreshToken),
        refreshAccessToken: (_) async => accessToken,
        inspectAccessToken: (_) async => const {},
      ),
      syncPreview: (_) async {
        previewCalled = true;
        return const {};
      },
      client: client,
      enabled: true,
      referenceTransferTimeout: const Duration(milliseconds: 20),
    );

    expect(
      await handler.handle(
        _diagnosticLink(
          callback,
          operation: GoogleDriveAppDiagnosticOperation.syncPreview,
          useReferenceTransport: true,
        ),
      ),
      isTrue,
    );

    expect(referenceCancelled, isTrue);
    expect(previewCalled, isFalse);
    expect(jsonDecode(postedBody!), {
      'schemaVersion': 1,
      'operation': 'sync-preview',
      'ok': false,
      'errorCode': 'referenceTransferFailed',
    });
  });

  test('handler cancels a callback body at the total deadline', () async {
    final callback = Uri.parse(
      'http://127.0.0.1:49165/chimahon-drive-diagnostic/${'6' * 64}',
    );
    var callbackCancelled = false;
    late final StreamController<List<int>> callbackController;
    callbackController = StreamController<List<int>>(
      onCancel: () => callbackCancelled = true,
    );
    addTearDown(callbackController.close);
    final client = MockClient.streaming((request, bodyStream) async {
      await bodyStream.drain<void>();
      return http.StreamedResponse(callbackController.stream, 204);
    });
    final handler = GoogleDriveDebugDiagnosticHandler(
      runner: GoogleDriveAppDiagnosticRunner(
        tokenStore: _MemoryTokenStore(refreshToken),
        refreshAccessToken: (_) async => accessToken,
        inspectAccessToken: (_) async => const {'safe': true},
      ),
      client: client,
      enabled: true,
      callbackTransferTimeout: const Duration(milliseconds: 20),
    );

    expect(await handler.handle(_diagnosticLink(callback)), isTrue);
    expect(callbackCancelled, isTrue);
  });

  test(
    'handler replaces unexpected credential errors with a fixed code',
    () async {
      const secretError = 'failure containing private-refresh-token';
      final requests = <http.Request>[];
      final handler = GoogleDriveDebugDiagnosticHandler(
        runner: GoogleDriveAppDiagnosticRunner(
          tokenStore: _MemoryTokenStore(refreshToken),
          refreshAccessToken: (_) async => throw StateError(secretError),
          inspectAccessToken: (_) async => const {},
        ),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
        enabled: true,
      );

      expect(
        await handler.handle(
          _diagnosticLink(
            Uri.parse(
              'http://127.0.0.1:49153/chimahon-drive-diagnostic/'
              '${'a' * 64}',
            ),
          ),
        ),
        isTrue,
      );

      final body = requests.single.body;
      expect(body, isNot(contains(secretError)));
      expect(body, isNot(contains(refreshToken)));
      expect(jsonDecode(body), {
        'schemaVersion': 1,
        'operation': 'inspect',
        'ok': false,
        'errorCode': 'inspectionFailed',
      });
    },
  );

  test(
    'handler maps the explicit probe host to only the probe runner',
    () async {
      final callback = Uri.parse(
        'http://127.0.0.1:49156/chimahon-drive-conditional-write-probe/'
        '${'d' * 64}',
      );
      final requests = <http.Request>[];
      var inspected = false;
      var probed = false;
      final safeProbe = <String, Object?>{
        'generatedFileName':
            '${GoogleDriveConditionalWriteProbe.probeFileNamePrefix}safe.tmp',
        'validatorAvailability': const {'v2ResourceEtag': 'strong'},
        'pairings': const [],
        'cleanup': const {
          'disposition': 'deleted',
          'requiresManualCleanup': false,
        },
      };
      final handler = GoogleDriveDebugDiagnosticHandler(
        runner: GoogleDriveAppDiagnosticRunner(
          tokenStore: _MemoryTokenStore(refreshToken),
          refreshAccessToken: (_) async => accessToken,
          inspectAccessToken: (_) async {
            inspected = true;
            return const {};
          },
          probeAccessToken: (_) async {
            probed = true;
            return safeProbe;
          },
        ),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
        enabled: true,
      );

      expect(
        await handler.handle(
          _diagnosticLink(
            callback,
            operation: GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
            allowDisposableDriveWrites: true,
          ),
        ),
        isTrue,
      );

      expect(probed, isTrue);
      expect(inspected, isFalse);
      final response = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(response, {
        'schemaVersion': 1,
        'operation': 'conditional-write-probe',
        'ok': true,
        'probe': safeProbe,
      });
      expect(requests.single.body, isNot(contains(refreshToken)));
      expect(requests.single.body, isNot(contains(accessToken)));
    },
  );

  test(
    'typed probe failures return safe pairing and cleanup details only',
    () async {
      const secretMessage =
          'secret private-access-token and raw-google-file-id';
      const generatedFileName =
          '${GoogleDriveConditionalWriteProbe.probeFileNamePrefix}failed.tmp';
      const hashedFileId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final failure = GoogleDriveConditionalWriteProbeException(
        message: secretMessage,
        statusCode: 412,
        generatedFileName: generatedFileName,
        validatorAvailability: const {
          GoogleDriveProbeValidatorSource.v2ResourceEtag:
              GoogleDriveProbeValidatorAvailability.strong,
        },
        completedPairings: const [
          GoogleDriveProbePairingResult(
            validatorSource: GoogleDriveProbeValidatorSource.v2ResourceEtag,
            endpoint: GoogleDriveProbeWriteEndpoint.v2MetadataPatch,
            matchingStatusCode: 200,
            staleStatusCode: 412,
            sentinelVerified: true,
          ),
        ],
        cleanup: const GoogleDriveProbeCleanup(
          disposition: GoogleDriveProbeCleanupDisposition.leftProbeNamedFile,
          reason: GoogleDriveProbeCleanupReason.deleteRejected,
          generatedFileName: generatedFileName,
          fileIdSha256: hashedFileId,
        ),
      );
      final requests = <http.Request>[];
      final handler = GoogleDriveDebugDiagnosticHandler(
        runner: GoogleDriveAppDiagnosticRunner(
          tokenStore: _MemoryTokenStore(refreshToken),
          refreshAccessToken: (_) async => accessToken,
          inspectAccessToken: (_) async => const {},
          probeAccessToken: (_) async => throw failure,
        ),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
        enabled: true,
      );

      await handler.handle(
        _diagnosticLink(
          Uri.parse(
            'http://127.0.0.1:49157/'
            'chimahon-drive-conditional-write-probe/${'e' * 64}',
          ),
          operation: GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
          allowDisposableDriveWrites: true,
        ),
      );

      final body = requests.single.body;
      expect(body, isNot(contains(secretMessage)));
      expect(body, isNot(contains(refreshToken)));
      expect(body, isNot(contains(accessToken)));
      expect(body, isNot(contains('raw-google-file-id')));
      final response = jsonDecode(body) as Map<String, dynamic>;
      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'conditionalWriteProbeRejected');
      final safeFailure = response['probeFailure'] as Map<String, dynamic>;
      expect(safeFailure['statusCode'], 412);
      expect(safeFailure['generatedFileName'], generatedFileName);
      expect(safeFailure['validatorAvailability'], {
        'v2ResourceEtag': 'strong',
      });
      expect(safeFailure['completedPairings'], [
        {
          'validatorSource': 'v2ResourceEtag',
          'endpoint': 'v2MetadataPatch',
          'matchingStatusCode': 200,
          'staleStatusCode': 412,
          'sentinelVerified': true,
        },
      ]);
      expect(safeFailure['cleanup'], {
        'disposition': 'leftProbeNamedFile',
        'reason': 'deleteRejected',
        'generatedFileName': generatedFileName,
        'fileIdSha256': hashedFileId,
        'requiresManualCleanup': true,
      });
    },
  );

  test('unexpected probe failures return only a fixed code', () async {
    const secretError = 'unexpected raw-google-file-id private-access-token';
    final requests = <http.Request>[];
    final handler = GoogleDriveDebugDiagnosticHandler(
      runner: GoogleDriveAppDiagnosticRunner(
        tokenStore: _MemoryTokenStore(refreshToken),
        refreshAccessToken: (_) async => accessToken,
        inspectAccessToken: (_) async => const {},
        probeAccessToken: (_) async => throw StateError(secretError),
      ),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204);
      }),
      enabled: true,
    );

    await handler.handle(
      _diagnosticLink(
        Uri.parse(
          'http://127.0.0.1:49158/'
          'chimahon-drive-conditional-write-probe/${'f' * 64}',
        ),
        operation: GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
        allowDisposableDriveWrites: true,
      ),
    );

    expect(requests.single.body, isNot(contains(secretError)));
    expect(jsonDecode(requests.single.body), {
      'schemaVersion': 1,
      'operation': 'conditional-write-probe',
      'ok': false,
      'errorCode': 'conditionalWriteProbeFailed',
    });
  });

  test('handler is inert when debug diagnostics are disabled', () async {
    final store = _MemoryTokenStore(refreshToken);
    var callbackCalled = false;
    final handler = GoogleDriveDebugDiagnosticHandler(
      runner: GoogleDriveAppDiagnosticRunner(
        tokenStore: store,
        refreshAccessToken: (_) async => accessToken,
        inspectAccessToken: (_) async => const {},
      ),
      client: MockClient((_) async {
        callbackCalled = true;
        return http.Response('', 204);
      }),
      enabled: false,
    );

    final handled = await handler.handle(
      _diagnosticLink(
        Uri.parse(
          'http://127.0.0.1:49154/chimahon-drive-diagnostic/${'b' * 64}',
        ),
      ),
    );

    expect(handled, isFalse);
    expect(store.readCount, 0);
    expect(callbackCalled, isFalse);
  });

  test('callback validation rejects non-loopback and malformed requests', () {
    final valid = Uri.parse(
      'http://127.0.0.1:49155/chimahon-drive-diagnostic/${'c' * 64}',
    );
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedCallback(
        _diagnosticLink(valid),
      ),
      valid,
    );

    for (final callback in [
      Uri.parse(
        'https://127.0.0.1:49155/chimahon-drive-diagnostic/${'c' * 64}',
      ),
      Uri.parse('http://localhost:49155/chimahon-drive-diagnostic/${'c' * 64}'),
      Uri.parse('http://192.0.2.1:49155/chimahon-drive-diagnostic/${'c' * 64}'),
      Uri.parse('http://127.0.0.1:49155/chimahon-drive-diagnostic/short'),
      Uri.parse(
        'http://127.0.0.1:49155/chimahon-drive-diagnostic/${'c' * 64}?x=1',
      ),
    ]) {
      expect(
        GoogleDriveDebugDiagnosticHandler.validatedCallback(
          _diagnosticLink(callback),
        ),
        isNull,
      );
    }
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedCallback(
        Uri.parse(
          'mangayomi://different-host?callback='
          '${Uri.encodeQueryComponent(valid.toString())}',
        ),
      ),
      isNull,
    );

    final probeCallback = Uri.parse(
      'http://127.0.0.1:49159/chimahon-drive-conditional-write-probe/'
      '${'1' * 64}',
    );
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedRequest(
        _diagnosticLink(
          probeCallback,
          operation: GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
          allowDisposableDriveWrites: true,
        ),
      )?.operation,
      GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
    );
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedRequest(
        _diagnosticLink(
          probeCallback,
          operation: GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
        ),
      ),
      isNull,
    );
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedRequest(
        _diagnosticLink(
          valid,
          operation: GoogleDriveAppDiagnosticOperation.conditionalWriteProbe,
          allowDisposableDriveWrites: true,
        ),
      ),
      isNull,
    );

    final previewCallback = Uri.parse(
      'http://127.0.0.1:49162/chimahon-drive-sync-preview/${'3' * 64}',
    );
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedRequest(
        _diagnosticLink(
          previewCallback,
          operation: GoogleDriveAppDiagnosticOperation.syncPreview,
          useReferenceTransport: true,
        ),
      )?.operation,
      GoogleDriveAppDiagnosticOperation.syncPreview,
    );
    expect(
      GoogleDriveDebugDiagnosticHandler.validatedRequest(
        _diagnosticLink(
          previewCallback,
          operation: GoogleDriveAppDiagnosticOperation.syncPreview,
        ),
      ),
      isNull,
    );
  });

  test('CLI requires both explicit disposable-write probe flags', () {
    final defaults = diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(
      const [],
    );
    expect(
      defaults.operation,
      diagnostic_cli.ChimahonDriveDiagnosticOperation.inspect,
    );
    expect(defaults.allowDisposableDriveWrites, isFalse);

    expect(
      () => diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(const [
        '--operation=conditional-write-probe',
      ]),
      throwsFormatException,
    );
    expect(
      () => diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(const [
        '--allow-disposable-drive-writes',
      ]),
      throwsFormatException,
    );

    final optedIn = diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(const [
      '--operation=conditional-write-probe',
      '--allow-disposable-drive-writes',
    ]);
    expect(
      optedIn.operation,
      diagnostic_cli.ChimahonDriveDiagnosticOperation.conditionalWriteProbe,
    );
    expect(optedIn.allowDisposableDriveWrites, isTrue);
    final callback = Uri.parse(
      'http://127.0.0.1:49160/chimahon-drive-conditional-write-probe/'
      '${'2' * 64}',
    );
    final link = optedIn.buildDeepLink(callback);
    expect(link.host, 'chimahon-drive-conditional-write-probe');
    expect(link.queryParameters['callback'], callback.toString());
    expect(link.queryParameters['allow-disposable-drive-writes'], 'true');

    expect(
      () => diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(const [
        '--operation=sync-preview',
      ]),
      throwsFormatException,
    );
    expect(
      () => diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(const [
        '--reference=/tmp/reference.tachibk',
      ]),
      throwsFormatException,
    );
    final preview = diagnostic_cli.ChimahonDriveDiagnosticOptions.parse(const [
      '--operation=sync-preview',
      '--reference=/tmp/reference.tachibk',
    ]);
    expect(
      preview.operation,
      diagnostic_cli.ChimahonDriveDiagnosticOperation.syncPreview,
    );
    expect(preview.referencePath, '/tmp/reference.tachibk');
    final previewLink = preview.buildDeepLink(
      Uri.parse(
        'http://127.0.0.1:49163/chimahon-drive-sync-preview/${'4' * 64}',
      ),
    );
    expect(previewLink.host, 'chimahon-drive-sync-preview');
    expect(previewLink.queryParameters['reference-transport'], 'loopback');
  });
}

Uri _diagnosticLink(
  Uri callback, {
  GoogleDriveAppDiagnosticOperation operation =
      GoogleDriveAppDiagnosticOperation.inspect,
  bool allowDisposableDriveWrites = false,
  bool useReferenceTransport = false,
}) => Uri(
  scheme: 'mangayomi',
  host: operation.deepLinkHost,
  queryParameters: {
    'callback': callback.toString(),
    if (allowDisposableDriveWrites)
      GoogleDriveDebugDiagnosticHandler.disposableWriteOptInParameter:
          GoogleDriveDebugDiagnosticHandler.disposableWriteOptInValue,
    if (useReferenceTransport)
      GoogleDriveDebugDiagnosticHandler.referenceTransportParameter:
          GoogleDriveDebugDiagnosticHandler.referenceTransportValue,
  },
);

class _MemoryTokenStore implements GoogleDriveRefreshTokenStore {
  _MemoryTokenStore(this.value);

  String? value;
  int readCount = 0;
  int writeCount = 0;
  int clearCount = 0;

  @override
  Future<String?> readRefreshToken() async {
    readCount++;
    return value;
  }

  @override
  Future<void> writeRefreshToken(String refreshToken) async {
    writeCount++;
    value = refreshToken;
  }

  @override
  Future<void> clearRefreshToken() async {
    clearCount++;
    value = null;
  }
}
