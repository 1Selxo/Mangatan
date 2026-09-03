import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class HayaiOcrClient {
  HayaiOcrClient({required Uri endpoint, this.apiKey = '', http.Client? client})
    : endpoint = normalizeHayaiEndpoint(endpoint),
      _client = client ?? http.Client();

  final Uri endpoint;
  final String apiKey;
  final http.Client _client;

  Future<String> recognize(Uint8List cropBytes) async {
    final request = http.MultipartRequest('POST', endpoint)
      ..files.add(
        http.MultipartFile.fromBytes('image', cropBytes, filename: 'crop.png'),
      );
    if (apiKey.trim().isNotEmpty) {
      request.headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    }
    final streamed = await _client
        .send(request)
        .timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Hayai OCR failed (${response.statusCode}): ${response.body}',
      );
    }
    final payload = jsonDecode(response.body);
    final text = switch (payload) {
      {'text': final Object? value} => value?.toString() ?? '',
      {'texts': final List values} when values.isNotEmpty =>
        values.first?.toString() ?? '',
      _ => '',
    };
    return normalizeHayaiText(text);
  }

  void close() => _client.close();
}

Uri normalizeHayaiEndpoint(Uri endpoint) {
  final path = endpoint.path.replaceAll(RegExp(r'/+$'), '');
  if (path.endsWith('/v1/ocr')) return endpoint.replace(path: path);
  return endpoint.replace(path: '$path/v1/ocr');
}

String normalizeHayaiText(String value) {
  var text = value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  final betweenCjk = RegExp(
    r'([\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af])\s+'
    r'([\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af])',
  );
  while (betweenCjk.hasMatch(text)) {
    text = text.replaceAllMapped(
      betweenCjk,
      (match) => '${match[1]}${match[2]}',
    );
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
