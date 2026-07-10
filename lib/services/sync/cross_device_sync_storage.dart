import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/sync/chimahon_sync_codec.dart';

class RemoteSyncSnapshot {
  const RemoteSyncSnapshot({required this.bytes, this.revision});

  final Uint8List bytes;
  final String? revision;
}

abstract interface class CrossDeviceSyncStorage {
  ChimahonSyncWireFormat get wireFormat;

  Future<RemoteSyncSnapshot?> download();

  Future<String?> upload(Uint8List bytes, {String? expectedRevision});
}

class SyncStorageException implements Exception {
  const SyncStorageException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP status $statusCode)';
}

class SyncConflictException extends SyncStorageException {
  const SyncConflictException()
    : super('The remote sync payload changed during synchronization');
}

/// Transport implementation for SyncYomi's `/api/sync/content` protocol.
/// Authentication details are supplied by a future settings/UI layer.
class SyncYomiStorage implements CrossDeviceSyncStorage {
  SyncYomiStorage({
    required this.baseUrl,
    required this.apiToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final String apiToken;
  final http.Client _client;

  @override
  ChimahonSyncWireFormat get wireFormat => ChimahonSyncWireFormat.protobuf;

  Uri get _contentUri => baseUrl.resolve('/api/sync/content');

  Map<String, String> _headers({String? revision}) => {
    'X-API-Token': apiToken,
    if (revision != null && revision.isNotEmpty) 'If-Match': revision,
  };

  @override
  Future<RemoteSyncSnapshot?> download() async {
    final response = await _client.get(_contentUri, headers: _headers());
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncStorageException(
        'Failed to download SyncYomi data',
        statusCode: response.statusCode,
      );
    }
    return RemoteSyncSnapshot(
      bytes: response.bodyBytes,
      revision: response.headers['etag'],
    );
  }

  @override
  Future<String?> upload(Uint8List bytes, {String? expectedRevision}) async {
    final response = await _client.put(
      _contentUri,
      headers: {
        ..._headers(revision: expectedRevision),
        'Content-Type': 'application/octet-stream',
      },
      body: bytes,
    );
    if (response.statusCode == 412) throw const SyncConflictException();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncStorageException(
        'Failed to upload SyncYomi data',
        statusCode: response.statusCode,
      );
    }
    return response.headers['etag'];
  }
}
