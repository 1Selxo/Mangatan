import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/sync/google_drive_conditional_write_probe.dart';
import 'package:mangayomi/services/sync/google_drive_sync_storage.dart';

void main() {
  group('GoogleDriveConditionalWriteProbe', () {
    test(
      'proves the resource ETag and only reports response-header ETags',
      () async {
        const accessToken = 'probe-access-token-that-must-not-be-reported';
        final api = _FakeDriveV2ProbeApi();
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: accessToken,
          client: MockClient(api.handle),
        );

        final result = await probe.run();

        expect(
          result.generatedFileName,
          startsWith(GoogleDriveConditionalWriteProbe.probeFileNamePrefix),
        );
        expect(
          result.generatedFileName,
          isNot(GoogleDriveSyncStorage.chimahonRemoteFileName),
        );
        expect(
          result.validatorAvailability.values,
          everyElement(GoogleDriveProbeValidatorAvailability.strong),
        );
        expect(result.pairings, hasLength(2));
        for (final endpoint in GoogleDriveProbeWriteEndpoint.values) {
          expect(
            result.pairingProven(
              GoogleDriveProbeValidatorSource.v2ResourceEtag,
              endpoint,
            ),
            isTrue,
          );
          expect(
            result.pairingProven(
              GoogleDriveProbeValidatorSource.v2MetadataResponseHeaderEtag,
              endpoint,
            ),
            isFalse,
          );
          expect(
            result.pairingProven(
              GoogleDriveProbeValidatorSource.v2MediaResponseHeaderEtag,
              endpoint,
            ),
            isFalse,
          );
        }
        expect(
          result.pairings.map((pairing) => pairing.staleStatusCode),
          everyElement(412),
        );
        expect(
          result.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.deleted,
        );
        expect(result.cleanup.requiresManualCleanup, isFalse);
        expect(api.deleted, isTrue);
        expect(api.staleRequestCount, 2);
        expect(
          api.requests.map((request) => request.headers['authorization']),
          everyElement('Bearer $accessToken'),
        );

        final createRequests = api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.url.path == '/upload/drive/v2/files',
        );
        expect(createRequests, hasLength(1));
        expect(
          api.requests.where((request) => request.method == 'DELETE'),
          hasLength(1),
        );
        expect(
          api.requests.where((request) => request.method == 'PATCH'),
          hasLength(2),
        );
        expect(
          api.requests.where((request) => request.method == 'PUT'),
          hasLength(2),
        );
        expect(
          api.requests.where(
            (request) => request.url.path == '/drive/v2/files',
          ),
          isEmpty,
        );
        for (final request in api.requests) {
          expect(
            request.url.toString(),
            isNot(contains(GoogleDriveSyncStorage.chimahonRemoteFileName)),
          );
          expect(
            utf8.decode(request.bodyBytes, allowMalformed: true),
            isNot(contains(GoogleDriveSyncStorage.chimahonRemoteFileName)),
          );
          if (request.method == 'PATCH' ||
              request.method == 'PUT' ||
              request.method == 'DELETE') {
            expect(request.url.path, contains(_FakeDriveV2ProbeApi.fileId));
            expect(request.headers['If-Match'], startsWith('"resource-'));
          }
        }

        final safeOutput = jsonEncode(result.toSafeJson());
        for (final privateValue in [
          accessToken,
          _FakeDriveV2ProbeApi.fileId,
          api.marker,
          api.resourceEtag,
          api.metadataHeaderEtag,
          api.mediaHeaderEtag,
        ]) {
          expect(safeOutput, isNot(contains(privateValue)));
        }
      },
    );

    test(
      'records absent response ETags and still tests the v2 resource ETag',
      () async {
        final api = _FakeDriveV2ProbeApi(
          includeMetadataHeaderEtag: false,
          includeMediaHeaderEtag: false,
        );
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        final result = await probe.run();

        expect(
          result.validatorAvailability[GoogleDriveProbeValidatorSource
              .v2ResourceEtag],
          GoogleDriveProbeValidatorAvailability.strong,
        );
        expect(
          result.validatorAvailability[GoogleDriveProbeValidatorSource
              .v2MetadataResponseHeaderEtag],
          GoogleDriveProbeValidatorAvailability.absent,
        );
        expect(
          result.validatorAvailability[GoogleDriveProbeValidatorSource
              .v2MediaResponseHeaderEtag],
          GoogleDriveProbeValidatorAvailability.absent,
        );
        expect(result.pairings, hasLength(2));
        expect(
          result.pairings.map((pairing) => pairing.validatorSource).toSet(),
          {GoogleDriveProbeValidatorSource.v2ResourceEtag},
        );
        expect(
          result.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.deleted,
        );
      },
    );

    test('requires the documented v2 resource ETag', () async {
      final api = _FakeDriveV2ProbeApi(includeResourceEtag: false);
      final probe = GoogleDriveConditionalWriteProbe(
        accessToken: 'token',
        client: MockClient(api.handle),
      );

      late GoogleDriveConditionalWriteProbeException failure;
      try {
        await probe.run();
        fail('The probe unexpectedly accepted a missing resource ETag');
      } on GoogleDriveConditionalWriteProbeException catch (error) {
        failure = error;
      }

      expect(
        failure.message,
        contains('did not return a strong resource ETag'),
      );
      expect(
        failure.validatorAvailability[GoogleDriveProbeValidatorSource
            .v2ResourceEtag],
        GoogleDriveProbeValidatorAvailability.absent,
      );
      expect(failure.completedPairings, isEmpty);
      expect(
        failure.cleanup.disposition,
        GoogleDriveProbeCleanupDisposition.leftProbeNamedFile,
      );
      expect(
        failure.cleanup.reason,
        GoogleDriveProbeCleanupReason.noStrongCleanupEtag,
      );
      expect(api.deleted, isFalse);
    });

    for (final malformed in ['"contains space"', '"embedded"quote"']) {
      test('rejects malformed resource ETag $malformed', () async {
        final api = _FakeDriveV2ProbeApi(resourceEtagOverride: malformed);
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        late GoogleDriveConditionalWriteProbeException failure;
        try {
          await probe.run();
          fail('The probe unexpectedly accepted a malformed resource ETag');
        } on GoogleDriveConditionalWriteProbeException catch (error) {
          failure = error;
        }

        expect(
          failure.validatorAvailability[GoogleDriveProbeValidatorSource
              .v2ResourceEtag],
          GoogleDriveProbeValidatorAvailability.weakOrInvalid,
        );
        expect(failure.completedPairings, isEmpty);
        expect(
          failure.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.leftProbeNamedFile,
        );
        expect(
          failure.cleanup.reason,
          GoogleDriveProbeCleanupReason.noStrongCleanupEtag,
        );
      });
    }

    test(
      'rejects a server that does not return 412 for a stale write',
      () async {
        final api = _FakeDriveV2ProbeApi(staleStatusCode: 200);
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        late GoogleDriveConditionalWriteProbeException failure;
        try {
          await probe.run();
          fail('The probe unexpectedly accepted a stale write');
        } on GoogleDriveConditionalWriteProbeException catch (error) {
          failure = error;
        }

        expect(failure.message, contains('did not return 412'));
        expect(failure.statusCode, 200);
        expect(failure.completedPairings, isEmpty);
        expect(
          failure.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.deleted,
        );
        expect(api.deleted, isTrue);
      },
    );

    test(
      'rejects a server that applies a stale sentinel despite returning 412',
      () async {
        final api = _FakeDriveV2ProbeApi(applyStaleWrite: true);
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        late GoogleDriveConditionalWriteProbeException failure;
        try {
          await probe.run();
          fail('The probe unexpectedly accepted an applied stale sentinel');
        } on GoogleDriveConditionalWriteProbeException catch (error) {
          failure = error;
        }

        expect(
          failure.message,
          contains('stale metadata sentinel was applied'),
        );
        expect(
          failure.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.deleted,
        );
        expect(api.deleted, isTrue);
      },
    );

    test(
      'leaves the probe-named file untouched when the cleanup guard changes',
      () async {
        final api = _FakeDriveV2ProbeApi(tamperOwnershipBeforeCleanup: true);
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        final result = await probe.run();

        expect(
          result.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.leftUnverifiedFileUntouched,
        );
        expect(
          result.cleanup.reason,
          GoogleDriveProbeCleanupReason.ownershipGuardFailed,
        );
        expect(result.cleanup.requiresManualCleanup, isTrue);
        expect(
          result.cleanup.generatedFileName,
          startsWith(GoogleDriveConditionalWriteProbe.probeFileNamePrefix),
        );
        expect(api.deleted, isFalse);
        expect(
          api.requests.where((request) => request.method == 'DELETE'),
          isEmpty,
        );
      },
    );

    test(
      'reports a guarded delete rejection and leaves the probe file',
      () async {
        final api = _FakeDriveV2ProbeApi(deleteStatusCode: 503);
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        final result = await probe.run();

        expect(
          result.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.leftProbeNamedFile,
        );
        expect(
          result.cleanup.reason,
          GoogleDriveProbeCleanupReason.deleteRejected,
        );
        expect(result.cleanup.requiresManualCleanup, isTrue);
        expect(api.deleted, isFalse);
        expect(
          api.requests.where((request) => request.method == 'DELETE'),
          hasLength(1),
        );
      },
    );

    test(
      'reports an unknown creation outcome instead of searching for a file',
      () async {
        final api = _FakeDriveV2ProbeApi(omitCreatedFileId: true);
        final probe = GoogleDriveConditionalWriteProbe(
          accessToken: 'token',
          client: MockClient(api.handle),
        );

        late GoogleDriveConditionalWriteProbeException failure;
        try {
          await probe.run();
          fail(
            'The probe unexpectedly accepted a create response without an ID',
          );
        } on GoogleDriveConditionalWriteProbeException catch (error) {
          failure = error;
        }

        expect(
          failure.cleanup.disposition,
          GoogleDriveProbeCleanupDisposition.unknownCreationOutcome,
        );
        expect(
          failure.cleanup.reason,
          GoogleDriveProbeCleanupReason.noReturnedFileId,
        );
        expect(failure.cleanup.requiresManualCleanup, isTrue);
        expect(
          failure.generatedFileName,
          startsWith(GoogleDriveConditionalWriteProbe.probeFileNamePrefix),
        );
        expect(api.requests, hasLength(1));
        expect(api.requests.single.method, 'POST');
        expect(
          api.requests.where((request) => request.method == 'GET'),
          isEmpty,
        );
        expect(
          api.requests.where((request) => request.method == 'DELETE'),
          isEmpty,
        );
      },
    );
  });
}

class _FakeDriveV2ProbeApi {
  _FakeDriveV2ProbeApi({
    this.includeResourceEtag = true,
    this.includeMetadataHeaderEtag = true,
    this.includeMediaHeaderEtag = true,
    this.staleStatusCode = 412,
    this.applyStaleWrite = false,
    this.tamperOwnershipBeforeCleanup = false,
    this.omitCreatedFileId = false,
    this.deleteStatusCode = 204,
    this.resourceEtagOverride,
  });

  static const fileId = 'newly-created-probe-file-id';

  final bool includeResourceEtag;
  final bool includeMetadataHeaderEtag;
  final bool includeMediaHeaderEtag;
  final int staleStatusCode;
  final bool applyStaleWrite;
  final bool tamperOwnershipBeforeCleanup;
  final bool omitCreatedFileId;
  final int deleteStatusCode;
  final String? resourceEtagOverride;

  final requests = <http.Request>[];
  String fileName = '';
  String marker = '';
  String description = '';
  Uint8List mediaBytes = Uint8List(0);
  int version = 0;
  int conditionalMutationCount = 0;
  int staleRequestCount = 0;
  bool deleted = false;
  bool _finalPairingVerificationFinished = false;
  bool _ownershipTampered = false;

  int get expectedPairingCount => GoogleDriveProbeWriteEndpoint.values.length;

  String get resourceEtag => resourceEtagOverride ?? '"resource-$version"';
  String get metadataHeaderEtag => '"metadata-header-$version"';
  String get mediaHeaderEtag => '"media-header-$version"';

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    return _handleWithoutTokenAssertion(request);
  }

  http.Response _handleWithoutTokenAssertion(http.Request request) {
    // Most tests use a short token. Authorization itself is still mandatory;
    // only the happy-path test checks the exact private value separately.
    if (request.headers['authorization'] == null) {
      return http.Response('', 401);
    }

    if (request.method == 'POST' &&
        request.url.path == '/upload/drive/v2/files') {
      return _create(request);
    }
    if (request.url.path != '/drive/v2/files/$fileId' &&
        request.url.path != '/upload/drive/v2/files/$fileId') {
      return http.Response('', 404);
    }
    if (deleted) return http.Response('', 404);

    if (request.method == 'GET') {
      if (request.url.queryParameters['alt'] == 'media') {
        if (conditionalMutationCount == expectedPairingCount * 2) {
          _finalPairingVerificationFinished = true;
        }
        return http.Response.bytes(
          mediaBytes,
          200,
          headers: {if (includeMediaHeaderEtag) 'etag': mediaHeaderEtag},
        );
      }
      if (tamperOwnershipBeforeCleanup &&
          _finalPairingVerificationFinished &&
          !_ownershipTampered) {
        marker = 'externally-changed-marker';
        _ownershipTampered = true;
      }
      return _metadataResponse();
    }

    if (request.method == 'PATCH' || request.method == 'PUT') {
      return _conditionalMutation(request);
    }
    if (request.method == 'DELETE') {
      if (!_currentValidators.contains(request.headers['If-Match'])) {
        return http.Response('', 412);
      }
      if (deleteStatusCode < 200 || deleteStatusCode >= 300) {
        return http.Response('', deleteStatusCode);
      }
      deleted = true;
      return http.Response('', deleteStatusCode);
    }
    return http.Response('', 405);
  }

  http.Response _create(http.Request request) {
    expect(request.url.queryParameters['uploadType'], 'multipart');
    final payload = _parseMultipart(request);
    fileName = payload.metadata['title']?.toString() ?? '';
    description = payload.metadata['description']?.toString() ?? '';
    mediaBytes = payload.bytes;
    expect(
      fileName,
      startsWith(GoogleDriveConditionalWriteProbe.probeFileNamePrefix),
    );
    expect(fileName, isNot(GoogleDriveSyncStorage.chimahonRemoteFileName));
    final parents = payload.metadata['parents'] as List;
    expect((parents.single as Map)['id'], 'appDataFolder');
    final properties = payload.metadata['properties'] as List;
    final ownership = properties.cast<Map>().singleWhere(
      (property) =>
          property['key'] ==
          GoogleDriveConditionalWriteProbe.ownershipPropertyKey,
    );
    expect(ownership['visibility'], 'PRIVATE');
    marker = ownership['value']!.toString();
    version = 1;
    final metadata = _metadataJson();
    if (omitCreatedFileId) metadata.remove('id');
    return http.Response(jsonEncode(metadata), 200);
  }

  http.Response _conditionalMutation(http.Request request) {
    conditionalMutationCount++;
    final validator = request.headers['If-Match'];
    final isCurrent = _currentValidators.contains(validator);
    late final Map<String, dynamic> metadata;
    late final Uint8List? newMedia;
    if (request.url.path.startsWith('/upload/')) {
      final payload = _parseMultipart(request);
      metadata = payload.metadata;
      newMedia = payload.bytes;
    } else {
      metadata = jsonDecode(request.body) as Map<String, dynamic>;
      newMedia = null;
    }

    if (!isCurrent) {
      staleRequestCount++;
      if (applyStaleWrite || staleStatusCode >= 200 && staleStatusCode < 300) {
        _apply(metadata, newMedia);
      }
      return http.Response('', staleStatusCode);
    }

    _apply(metadata, newMedia);
    return _metadataResponse();
  }

  void _apply(Map<String, dynamic> metadata, Uint8List? newMedia) {
    description = metadata['description']?.toString() ?? description;
    if (newMedia != null) mediaBytes = newMedia;
    version++;
  }

  Set<String> get _currentValidators => {if (includeResourceEtag) resourceEtag};

  http.Response _metadataResponse() => http.Response(
    jsonEncode(_metadataJson()),
    200,
    headers: {if (includeMetadataHeaderEtag) 'etag': metadataHeaderEtag},
  );

  Map<String, dynamic> _metadataJson() => {
    'id': fileId,
    'title': fileName,
    'description': description,
    'mimeType': 'application/octet-stream',
    if (includeResourceEtag) 'etag': resourceEtag,
    'version': '$version',
    'appDataContents': true,
    'properties': [
      {
        'key': GoogleDriveConditionalWriteProbe.ownershipPropertyKey,
        'value': marker,
        'visibility': 'PRIVATE',
      },
    ],
    'labels': {'trashed': false},
  };
}

class _MultipartPayload {
  const _MultipartPayload({required this.metadata, required this.bytes});

  final Map<String, dynamic> metadata;
  final Uint8List bytes;
}

_MultipartPayload _parseMultipart(http.Request request) {
  final contentType = request.headers['content-type']!;
  final boundary = RegExp(
    r'boundary=([^;]+)',
  ).firstMatch(contentType)!.group(1)!;
  final text = utf8.decode(request.bodyBytes);
  final parts = text.split('--$boundary');
  expect(parts, hasLength(4));
  final metadataPart = parts[1];
  final mediaPart = parts[2];
  final metadataBody = metadataPart
      .substring(metadataPart.indexOf('\r\n\r\n') + 4)
      .replaceFirst(RegExp(r'\r\n$'), '');
  final mediaBody = mediaPart
      .substring(mediaPart.indexOf('\r\n\r\n') + 4)
      .replaceFirst(RegExp(r'\r\n$'), '');
  return _MultipartPayload(
    metadata: jsonDecode(metadataBody) as Map<String, dynamic>,
    bytes: Uint8List.fromList(utf8.encode(mediaBody)),
  );
}
