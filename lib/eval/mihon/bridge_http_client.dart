import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

const mihonBridgeRetryDelays = [
  Duration(milliseconds: 250),
  Duration(milliseconds: 750),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 8),
];

bool isLoopbackMihonBridge(String baseUrl) {
  final host = Uri.tryParse(normalizeMihonBridgeBaseUrl(baseUrl))?.host;
  return host == InternetAddress.loopbackIPv4.address ||
      host == InternetAddress.loopbackIPv6.address ||
      host == 'localhost';
}

String normalizeMihonBridgeBaseUrl(String value) {
  var address = value.trim();
  if (address.isEmpty) {
    throw const FormatException('Enter the address shown in APKBridge.');
  }
  if (!address.contains('://')) {
    address = 'http://$address';
  }

  final uri = Uri.tryParse(address);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw FormatException('Invalid APKBridge address: $value');
  }

  final usesApkBridgeDefaultPort =
      uri.host == 'localhost' ||
      uri.host.endsWith('.local') ||
      !uri.host.contains('.') ||
      InternetAddress.tryParse(uri.host) != null;
  final port = uri.hasPort
      ? uri.port
      : usesApkBridgeDefaultPort
      ? 8080
      : null;

  return Uri(scheme: uri.scheme, host: uri.host, port: port).toString();
}

Uri mihonBridgeDalvikUri(String baseUrl) {
  final baseUri = Uri.parse(normalizeMihonBridgeBaseUrl(baseUrl));
  return baseUri.replace(path: '/dalvik');
}

Future<http.Response> postMihonBridge(
  http.Client client,
  Uri uri, {
  Object? body,
  Map<String, String>? headers,
  bool retryTransientFailures = false,
  List<Duration> retryDelays = mihonBridgeRetryDelays,
  Future<void> Function(Duration) delay = Future<void>.delayed,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
    try {
      final response = await client.post(uri, body: body, headers: headers);
      _validateMihonBridgeResponse(response, uri);
      return response;
    } catch (error, stackTrace) {
      if (!retryTransientFailures || !isTransientBridgeTransportError(error)) {
        rethrow;
      }
      lastError = error;
      lastStackTrace = stackTrace;
      if (attempt < retryDelays.length) {
        await delay(retryDelays[attempt]);
      }
    }
  }

  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}

bool isTransientBridgeTransportError(Object error) {
  return error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;
}

void _validateMihonBridgeResponse(http.Response response, Uri uri) {
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  final bodyStart = response.body.trimLeft().toLowerCase();
  final returnedHtml =
      contentType.contains('text/html') ||
      bodyStart.startsWith('<html') ||
      bodyStart.startsWith('<!doctype html');

  if (returnedHtml) {
    final reason = response.statusCode >= 500
        ? 'APKBridge failed while running the Mihon extension'
        : 'the configured server is not APKBridge';
    throw MihonBridgeResponseException(
      '$reason (HTTP ${response.statusCode} at $uri). Use the complete bridge '
      'URL. Direct Android-device addresses normally use port 8080, for '
      'example http://192.168.1.20:8080; hosted HTTPS bridges normally do not '
      'need an explicit port.',
    );
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw MihonBridgeResponseException(
      'APKBridge rejected the extension request (HTTP '
      '${response.statusCode} at $uri). Check the APKBridge log and update '
      'both APKBridge and the Mihon extension.',
    );
  }
}

class MihonBridgeResponseException implements Exception {
  const MihonBridgeResponseException(this.message);

  final String message;

  @override
  String toString() => message;
}
