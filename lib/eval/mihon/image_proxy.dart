bool isTransientMihonImageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  // Older bridge versions exposed Mokuro's synthetic CBZ-entry URL directly.
  // Its fragment is meaningful only to the extension's OkHttp interceptor.
  if (uri.fragment.isNotEmpty && uri.path.toLowerCase().endsWith('.cbz')) {
    return true;
  }

  if (uri.scheme != 'http') return false;

  final isLoopback =
      uri.host == '127.0.0.1' || uri.host == '::1' || uri.host == 'localhost';
  return isLoopback &&
      uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'image' &&
      uri.pathSegments.last.isNotEmpty;
}

bool containsTransientMihonImageUrl(Iterable<String>? urls) {
  return urls?.any(isTransientMihonImageUrl) ?? false;
}

bool canReuseCachedMihonPageUrls(Iterable<String>? urls) {
  if (urls == null || urls.isEmpty) return false;
  return !containsTransientMihonImageUrl(urls);
}
