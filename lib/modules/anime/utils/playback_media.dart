import 'dart:io';

import 'package:media_kit/media_kit.dart';

/// Creates media for the player without allowing media_kit's URI parser to
/// reinterpret a local file path.
///
/// In particular, uri_parser 3.0.2 changes a Windows UNC path from
/// `\\server\share` to `//server/share`, which libmpv cannot open on Windows.
Media playbackMedia(
  String resource, {
  required bool isLocal,
  Map<String, String>? httpHeaders,
  Duration? start,
  bool? windows,
}) {
  if (!isLocal) {
    return Media(resource, httpHeaders: httpHeaders, start: start);
  }

  return _LocalFileMedia(
    resource,
    httpHeaders: httpHeaders,
    start: start,
    windows: windows ?? Platform.isWindows,
  );
}

String localFileUri(String resource, {required bool windows}) {
  final uri = Uri.tryParse(resource);
  if (uri != null && uri.isScheme('file')) {
    return uri.toString();
  }
  return Uri.file(resource, windows: windows).toString();
}

class _LocalFileMedia extends Media {
  final String _uri;

  _LocalFileMedia(
    super.resource, {
    super.httpHeaders,
    super.start,
    required bool windows,
  }) : _uri = localFileUri(resource, windows: windows);

  @override
  String get uri => _uri;
}
