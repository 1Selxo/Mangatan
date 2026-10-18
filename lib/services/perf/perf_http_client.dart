import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:mangayomi/services/perf/perf_metrics.dart';

/// Forwards every call to [inner] and, while a [PerfTrace] is running, counts
/// the time from sending the request until its body has been read as network
/// time. Outside a trace the inner response is returned untouched.
class PerfHttpClient extends http.BaseClient {
  PerfHttpClient(this.inner);

  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final end = PerfMetrics.beginNetwork();
    if (end == null) return inner.send(request);
    final http.StreamedResponse response;
    try {
      response = await inner.send(request);
    } catch (_) {
      end();
      rethrow;
    }
    final body = response.stream.transform<List<int>>(
      StreamTransformer.fromHandlers(
        handleDone: (sink) {
          end();
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          end();
          sink.addError(error, stackTrace);
        },
      ),
    );
    return http.StreamedResponse(
      http.ByteStream(body),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => inner.close();
}
