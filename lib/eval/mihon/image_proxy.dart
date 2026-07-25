bool isTransientMihonImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  // Older bridge versions exposed Mokuro's synthetic CBZ-entry URL directly.
  // Its fragment is meaningful only to the extension's OkHttp interceptor.
  if (uri.fragment.isNotEmpty && uri.path.toLowerCase().endsWith('.cbz')) {
    return true;
  }

  return _isLoopbackMihonImageProxyUri(uri);
}

/// Replaces the bridge server's loopback image origin with the origin the
/// client actually used to reach that bridge.
///
/// The JVM bridge registers extension-aware image requests as
/// `http://127.0.0.1:<port>/image/<token>`. That URL is correct when the app
/// and bridge share a host, but on iOS it otherwise points back to the phone.
String resolveMihonImageUrl(String bridgeBaseUrl, String imageUrl) {
  return _resolveMihonProxyUrl(bridgeBaseUrl, imageUrl, const {'image'});
}

/// Resolves any loopback media proxy URL returned by the JVM bridge.
String resolveMihonMediaUrl(String bridgeBaseUrl, String mediaUrl) {
  return _resolveMihonProxyUrl(bridgeBaseUrl, mediaUrl, const {
    'image',
    'video',
  });
}

String _resolveMihonProxyUrl(
  String bridgeBaseUrl,
  String mediaUrl,
  Set<String> routeNames,
) {
  final mediaUri = Uri.tryParse(mediaUrl);
  if (mediaUri == null || !_isLoopbackMihonProxyUri(mediaUri, routeNames)) {
    return mediaUrl;
  }

  var normalizedBridge = bridgeBaseUrl.trim();
  if (!normalizedBridge.contains('://')) {
    normalizedBridge = 'http://$normalizedBridge';
  }
  final bridgeUri = Uri.tryParse(normalizedBridge);
  if (bridgeUri == null ||
      (bridgeUri.scheme != 'http' && bridgeUri.scheme != 'https') ||
      bridgeUri.host.isEmpty) {
    return mediaUrl;
  }

  return bridgeUri
      .replace(
        path: mediaUri.path,
        query: mediaUri.hasQuery ? mediaUri.query : null,
        fragment: mediaUri.hasFragment ? mediaUri.fragment : null,
      )
      .toString();
}

bool containsTransientMihonImageUrl(Iterable<String>? urls) {
  return urls?.any(isTransientMihonImageUrl) ?? false;
}

bool canReuseCachedMihonPageUrls(Iterable<String>? urls) {
  if (urls == null || urls.isEmpty) return false;
  return !containsTransientMihonImageUrl(urls);
}

bool _isLoopbackMihonImageProxyUri(Uri uri) {
  return _isLoopbackMihonProxyUri(uri, const {'image'});
}

bool _isLoopbackMihonProxyUri(Uri uri, Set<String> routeNames) {
  if (uri.scheme != 'http') return false;
  final isLoopback =
      uri.host == '127.0.0.1' || uri.host == '::1' || uri.host == 'localhost';
  return isLoopback &&
      uri.pathSegments.length == 2 &&
      routeNames.contains(uri.pathSegments.first) &&
      uri.pathSegments.last.isNotEmpty;
}
