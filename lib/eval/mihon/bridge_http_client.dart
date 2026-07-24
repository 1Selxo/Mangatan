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

const mihonBridgeGatewayRetryDelays = [
  Duration(milliseconds: 500),
  Duration(milliseconds: 1500),
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

  final usesApkBridgeDefaultPort = _isDirectMihonBridgeHost(uri.host);
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
  List<Duration> gatewayRetryDelays = mihonBridgeGatewayRetryDelays,
  Future<void> Function(Duration) delay = Future<void>.delayed,
}) async {
  var transportRetries = 0;
  var gatewayRetries = 0;
  while (true) {
    try {
      final response = await client.post(
        uri,
        body: body,
        headers: _bridgeRequestHeaders(headers),
      );
      _validateMihonBridgeResponse(response, uri);
      return response;
    } catch (error) {
      Duration? retryDelay;
      if (retryTransientFailures &&
          isTransientBridgeTransportError(error) &&
          transportRetries < retryDelays.length) {
        retryDelay = retryDelays[transportRetries++];
      } else if (isTransientMihonBridgeGatewayError(error) &&
          gatewayRetries < gatewayRetryDelays.length) {
        retryDelay = gatewayRetryDelays[gatewayRetries++];
      } else {
        rethrow;
      }
      await delay(retryDelay);
    }
  }
}

bool isTransientBridgeTransportError(Object error) {
  return error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException;
}

bool isTransientMihonBridgeGatewayError(Object error) {
  return error is MihonBridgeResponseException &&
      const {502, 503, 504}.contains(error.statusCode);
}

void _validateMihonBridgeResponse(http.Response response, Uri uri) {
  final contentType = response.headers['content-type']?.toLowerCase() ?? '';
  final bodyStart = response.body.trimLeft().toLowerCase();
  final returnedHtml =
      contentType.contains('text/html') ||
      bodyStart.startsWith('<html') ||
      bodyStart.startsWith('<!doctype html');

  if (const {502, 503, 504}.contains(response.statusCode)) {
    final hosted = !_isDirectMihonBridgeHost(uri.host);
    throw MihonBridgeResponseException(
      hosted
          ? 'The hosted APKBridge gateway is unavailable (HTTP '
                '${response.statusCode} at $uri). The URL is valid, but its '
                'backend could not run the extension. Try again later, choose '
                'another hosted bridge, or use APKBridge on an Android device.'
          : 'APKBridge is temporarily unavailable (HTTP '
                '${response.statusCode} at $uri). Check the Android device and '
                'try again.',
      statusCode: response.statusCode,
    );
  }

  if (returnedHtml) {
    final reason = response.statusCode >= 500
        ? 'APKBridge failed while running the Mihon extension'
        : 'the configured server is not APKBridge';
    throw MihonBridgeResponseException(
      '$reason (HTTP ${response.statusCode} at $uri). Use the complete bridge '
      'URL. Direct Android-device addresses normally use port 8080, for '
      'example http://192.168.1.20:8080; hosted HTTPS bridges normally do not '
      'need an explicit port.',
      statusCode: response.statusCode,
    );
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw MihonBridgeResponseException(
      'APKBridge rejected the extension request (HTTP '
      '${response.statusCode} at $uri). Check the APKBridge log and update '
      'both APKBridge and the Mihon extension.',
      statusCode: response.statusCode,
    );
  }
}

bool _isDirectMihonBridgeHost(String host) {
  return host == 'localhost' ||
      host.endsWith('.local') ||
      host.endsWith('.lan') ||
      !host.contains('.') ||
      InternetAddress.tryParse(host) != null;
}

Map<String, String> _bridgeRequestHeaders(Map<String, String>? headers) {
  final result = <String, String>{...?headers};
  final normalizedNames = result.keys.map((key) => key.toLowerCase()).toSet();
  if (!normalizedNames.contains('content-type')) {
    result['content-type'] = 'application/json; charset=utf-8';
  }
  if (!normalizedNames.contains('accept')) {
    result['accept'] = 'application/json';
  }
  return result;
}

class MihonBridgeResponseException implements Exception {
  const MihonBridgeResponseException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
