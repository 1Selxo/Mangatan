import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/external_browser.dart';

/// A tracker login on desktop: the authorize page opens in the browser, the
/// tracker redirects to http://localhost:<port>/?code=..., and the app reads
/// the code off that redirect. On Windows this used to go through
/// flutter_web_auth_2's WebView window, which never recognised the redirect
/// (it compared the URI's scheme with "http://localhost:43824"), so no login
/// on Windows could finish.
void main() {
  tearDown(() => ExternalBrowser.openForTest = null);

  test(
    'the login returns the redirect with its code, past a favicon request',
    () async {
      const port = 43899;
      String? opened;
      ExternalBrowser.openForTest = (url) async {
        opened = url;
        // The browser, after the person clicks Authorize.
        Future<void>(() async {
          final client = HttpClient();
          for (final path in ['/favicon.ico', '/success?code=abc123']) {
            final request = await client.getUrl(
              Uri.parse('http://localhost:$port$path'),
            );
            await (await request.close()).drain<void>();
          }
          client.close();
        });
        return true;
      };

      final uri = await ExternalBrowser.openOAuth(
        'https://anilist.co/api/v2/oauth/authorize?client_id=1',
        port: port,
        callbackUrlScheme: 'http://localhost:$port',
      ).timeout(const Duration(seconds: 10));

      expect(opened, startsWith('https://anilist.co/'));
      expect(uri?.queryParameters['code'], 'abc123');
    },
    skip: !(Platform.isWindows || Platform.isLinux),
  );
}
