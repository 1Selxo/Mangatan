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
  final host = Uri.tryParse(baseUrl)?.host;
  return host == InternetAddress.loopbackIPv4.address ||
      host == InternetAddress.loopbackIPv6.address ||
      host == 'localhost';
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
      return await client.post(uri, body: body, headers: headers);
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
