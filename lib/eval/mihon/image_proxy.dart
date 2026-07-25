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
  final imageUri = Uri.tryParse(imageUrl);
  if (imageUri == null || !_isLoopbackMihonImageProxyUri(imageUri)) {
    return imageUrl;
  }

  var normalizedBridge = bridgeBaseUrl.trim();
  if (!normalizedBridge.contains('://')) {
    normalizedBridge = 'http://$normalizedBridge';
  }
  final bridgeUri = Uri.tryParse(normalizedBridge);
  if (bridgeUri == null ||
      (bridgeUri.scheme != 'http' && bridgeUri.scheme != 'https') ||
      bridgeUri.host.isEmpty) {
    return imageUrl;
  }

  return bridgeUri
      .replace(
        path: imageUri.path,
        query: imageUri.hasQuery ? imageUri.query : null,
        fragment: imageUri.hasFragment ? imageUri.fragment : null,
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
  if (uri.scheme != 'http') return false;
  final isLoopback =
      uri.host == '127.0.0.1' || uri.host == '::1' || uri.host == 'localhost';
  return isLoopback &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'image' &&
      uri.pathSegments.last.isNotEmpty;
}
