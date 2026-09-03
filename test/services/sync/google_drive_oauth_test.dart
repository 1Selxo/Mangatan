import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mangayomi/services/sync/google_drive_oauth.dart';

void main() {
  group('shared desktop custom-protocol browser', () {
    test(
      'subscribes and registers before launch, then filters scheme and path',
      () async {
        final links = StreamController<Uri>.broadcast(sync: true);
        final events = <String>[];
        final expectedRedirect = Uri.parse(
          'app.chimahon.google.oauth:/oauth2redirect',
        );
        final browser = DesktopGoogleOAuthBrowser(
          expectedRedirectUri: expectedRedirect,
          registerProtocol: (scheme) {
            expect(links.hasListener, isTrue);
            expect(scheme, 'app.chimahon.google.oauth');
            events.add('registered');
          },
          unregisterProtocol: (scheme) {
            expect(links.hasListener, isFalse);
            expect(scheme, 'app.chimahon.google.oauth');
            events.add('unregistered');
          },
          linkStream: () => links.stream,
          launchExternal: (authorizationUri) async {
            expect(events, ['registered']);
            events.add('launched');
            links
              ..add(Uri.parse('mangayomi:/oauth2redirect?code=wrong-scheme'))
              ..add(
                Uri.parse(
                  'app.chimahon.google.oauth://unexpected/oauth2redirect'
                  '?code=wrong-host',
                ),
              )
              ..add(
                Uri.parse(
                  'app.chimahon.google.oauth:/wrong-path?code=wrong-path',
                ),
              )
              ..add(
                Uri.parse(
                  'app.chimahon.google.oauth:///oauth2redirect'
                  '?code=wrong-authority',
                ),
              )
              ..add(
                Uri.parse(
                  'app.chimahon.google.oauth:/oauth2redirect'
                  '?code=wrong-state&state=unexpected',
                ),
              )
              ..add(
                Uri.parse(
                  'app.chimahon.google.oauth:/oauth2redirect'
                  '?code=right&state=expected',
                ),
              );
            return true;
          },
        );

        final callback = await browser.authenticate(
          Uri.parse('https://accounts.google.com/o/oauth2/auth?state=expected'),
        );

        expect(events, ['registered', 'launched', 'unregistered']);
        expect(Uri.parse(callback).queryParameters['code'], 'right');
        expect(links.hasListener, isFalse);
        await links.close();
      },
    );

    test('reports a browser launch failure and removes its listener', () async {
      final links = StreamController<Uri>.broadcast(sync: true);
      var unregistered = false;
      final browser = DesktopGoogleOAuthBrowser(
        expectedRedirectUri: Uri.parse(
          'app.chimahon.google.oauth:/oauth2redirect',
        ),
        registerProtocol: (_) {},
        unregisterProtocol: (_) => unregistered = true,
        linkStream: () => links.stream,
        launchExternal: (_) async => false,
      );

      await expectLater(
        browser.authenticate(Uri.parse('https://accounts.google.com')),
        throwsA(
          isA<GoogleDriveOAuthException>().having(
            (error) => error.code,
            'code',
            'browser_launch_failed',
          ),
        ),
      );
      expect(links.hasListener, isFalse);
      expect(unregistered, isTrue);
      await links.close();
    });

    test('does not unregister when protocol registration fails', () async {
      final links = StreamController<Uri>.broadcast(sync: true);
      var unregisterCalls = 0;
      final browser = DesktopGoogleOAuthBrowser(
        expectedRedirectUri: Uri.parse(
          'app.chimahon.google.oauth:/oauth2redirect',
        ),
        registerProtocol: (_) => throw StateError('registry unavailable'),
        unregisterProtocol: (_) => unregisterCalls++,
        linkStream: () => links.stream,
        launchExternal: (_) async => fail('browser must not launch'),
      );

      await expectLater(
        browser.authenticate(Uri.parse('https://accounts.google.com')),
        throwsStateError,
      );
      expect(links.hasListener, isFalse);
      expect(unregisterCalls, 0);
      await links.close();
    });

    test('keeps a successful callback when registry cleanup fails', () async {
      final links = StreamController<Uri>.broadcast(sync: true);
      final browser = DesktopGoogleOAuthBrowser(
        expectedRedirectUri: Uri.parse(
          'app.chimahon.google.oauth:/oauth2redirect',
        ),
        registerProtocol: (_) {},
        unregisterProtocol: (_) => throw StateError('registry key is busy'),
        linkStream: () => links.stream,
        launchExternal: (_) async {
          links.add(
            Uri.parse(
              'app.chimahon.google.oauth:/oauth2redirect'
              '?code=right&state=expected',
            ),
          );
          return true;
        },
      );

      final callback = await browser.authenticate(
        Uri.parse('https://accounts.google.com/o/oauth2/auth?state=expected'),
      );

      expect(Uri.parse(callback).queryParameters['code'], 'right');
      expect(links.hasListener, isFalse);
      await links.close();
    });
  });

  test('uses Chimahon identity, redirect, scopes, state, and PKCE', () async {
    Uri? authorizationUri;
    http.Request? tokenRequest;
    final now = DateTime.utc(2026, 7, 17, 20);
    final oauth = GoogleDriveOAuthClient(
      client: MockClient((request) async {
        tokenRequest = request;
        return http.Response(
          jsonEncode({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'scope': [
              ChimahonGoogleOAuthConfig.driveFileScope,
              ChimahonGoogleOAuthConfig.driveAppDataScope,
            ].join(' '),
          }),
          200,
        );
      }),
      browser: (uri, callbackUrlScheme) async {
        authorizationUri = uri;
        expect(callbackUrlScheme, 'app.chimahon.google.oauth');
        return Uri.parse(ChimahonGoogleOAuthConfig.current.redirectUri)
            .replace(
              queryParameters: {
                'code': 'authorization-code',
                'state': uri.queryParameters['state'],
              },
            )
            .toString();
      },
      clock: () => now,
    );

    final tokens = await oauth.signIn();

    expect(
      authorizationUri!.queryParameters['client_id'],
      '207565405172-osbisi7elvjcg00ive35ml2q4cqandbb.apps.googleusercontent.com',
    );
    expect(
      authorizationUri!.queryParameters['redirect_uri'],
      'app.chimahon.google.oauth:/oauth2redirect',
    );
    expect(
      authorizationUri!.queryParameters['scope']!.split(' '),
      containsAll([
        ChimahonGoogleOAuthConfig.driveFileScope,
        ChimahonGoogleOAuthConfig.driveAppDataScope,
      ]),
    );
    expect(authorizationUri!.queryParameters['access_type'], 'offline');
    expect(authorizationUri!.queryParameters['prompt'], 'consent');
    expect(authorizationUri!.queryParameters['code_challenge'], isNotEmpty);
    expect(tokenRequest!.bodyFields['code_verifier'], isNotEmpty);
    expect(tokenRequest!.bodyFields['client_secret'], isNull);
    expect(tokens.accessToken, 'access');
    expect(tokens.refreshToken, 'refresh');
    expect(
      tokens.grantedScopes,
      contains(ChimahonGoogleOAuthConfig.driveAppDataScope),
    );
    expect(tokens.expiresAt, now.add(const Duration(hours: 1)));
  });

  test(
    'refresh keeps the existing refresh token when Google omits it',
    () async {
      final oauth = GoogleDriveOAuthClient(
        client: MockClient((request) async {
          expect(request.bodyFields['grant_type'], 'refresh_token');
          expect(request.bodyFields['refresh_token'], 'existing-refresh');
          return http.Response(
            jsonEncode({'access_token': 'new-access', 'expires_in': '120'}),
            200,
          );
        }),
        clock: () => DateTime.utc(2026, 7, 17),
      );

      final tokens = await oauth.refresh('existing-refresh');

      expect(tokens.accessToken, 'new-access');
      expect(tokens.refreshToken, 'existing-refresh');
      expect(tokens.expiresAt, DateTime.utc(2026, 7, 17, 0, 2));
      expect(
        tokens.grantedScopes,
        contains(ChimahonGoogleOAuthConfig.driveAppDataScope),
      );
    },
  );

  test('rejects a refreshed grant that explicitly drops app data', () async {
    final oauth = GoogleDriveOAuthClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'new-access',
            'scope': ChimahonGoogleOAuthConfig.driveFileScope,
          }),
          200,
        ),
      ),
    );

    expect(
      oauth.refresh('existing-refresh'),
      throwsA(
        isA<GoogleDriveOAuthException>().having(
          (error) => error.code,
          'code',
          'insufficient_scope',
        ),
      ),
    );
  });

  test('accepts an omitted scope field as an unchanged full grant', () async {
    final oauth = GoogleDriveOAuthClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
          }),
          200,
        ),
      ),
      browser: (uri, _) async =>
          Uri.parse(ChimahonGoogleOAuthConfig.current.redirectUri)
              .replace(
                queryParameters: {
                  'code': 'authorization-code',
                  'state': uri.queryParameters['state'],
                },
              )
              .toString(),
    );

    final tokens = await oauth.signIn();

    expect(
      tokens.grantedScopes,
      containsAll({
        ChimahonGoogleOAuthConfig.driveFileScope,
        ChimahonGoogleOAuthConfig.driveAppDataScope,
      }),
    );
  });

  test('rejects a callback with a mismatched OAuth state', () async {
    final oauth = GoogleDriveOAuthClient(
      client: MockClient(
        (_) async => fail('token endpoint must not be called'),
      ),
      browser: (_, _) async =>
          'app.chimahon.google.oauth:/oauth2redirect?code=code&state=wrong',
    );

    expect(
      oauth.signIn(),
      throwsA(
        isA<GoogleDriveOAuthException>().having(
          (error) => error.message,
          'message',
          contains('invalid state'),
        ),
      ),
    );
  });

  test('validates state before accepting an OAuth error callback', () async {
    final oauth = GoogleDriveOAuthClient(
      client: MockClient(
        (_) async => fail('token endpoint must not be called'),
      ),
      browser: (_, _) async =>
          'app.chimahon.google.oauth:/oauth2redirect?error=access_denied'
          '&state=wrong',
    );

    expect(
      oauth.signIn(),
      throwsA(
        isA<GoogleDriveOAuthException>().having(
          (error) => error.code,
          'code',
          'invalid_state',
        ),
      ),
    );
  });

  test('rejects a callback at a different redirect address', () async {
    final oauth = GoogleDriveOAuthClient(
      client: MockClient(
        (_) async => fail('token endpoint must not be called'),
      ),
      browser: (uri, _) async =>
          Uri.parse('app.chimahon.google.oauth:/different-path')
              .replace(
                queryParameters: {
                  'code': 'authorization-code',
                  'state': uri.queryParameters['state'],
                },
              )
              .toString(),
    );

    expect(
      oauth.signIn(),
      throwsA(
        isA<GoogleDriveOAuthException>().having(
          (error) => error.code,
          'code',
          'invalid_callback',
        ),
      ),
    );
  });

  test(
    'accepts the relative callback returned by a desktop loopback',
    () async {
      const config = ChimahonGoogleOAuthConfig(
        clientId: 'same-project-desktop-client.apps.googleusercontent.com',
        redirectUri: 'http://127.0.0.1:43829/oauth2redirect',
      );
      http.Request? tokenRequest;
      final oauth = GoogleDriveOAuthClient(
        config: config,
        client: MockClient((request) async {
          tokenRequest = request;
          return http.Response(
            jsonEncode({
              'access_token': 'access',
              'refresh_token': 'refresh',
              'scope': ChimahonGoogleOAuthConfig.driveAppDataScope,
            }),
            200,
          );
        }),
        browser: (uri, callbackUrlScheme) async {
          expect(callbackUrlScheme, 'http://127.0.0.1:43829');
          return Uri(
            path: '/oauth2redirect',
            queryParameters: {
              'code': 'authorization-code',
              'state': uri.queryParameters['state'],
            },
          ).toString();
        },
      );

      final tokens = await oauth.signIn();

      expect(tokens.accessToken, 'access');
      expect(tokenRequest!.bodyFields['redirect_uri'], config.redirectUri);
    },
  );

  test('rejects sign-in when app-data permission is not granted', () async {
    final oauth = GoogleDriveOAuthClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'expires_in': 3600,
            'scope': ChimahonGoogleOAuthConfig.driveFileScope,
          }),
          200,
        ),
      ),
      browser: (uri, _) async =>
          Uri.parse(ChimahonGoogleOAuthConfig.current.redirectUri)
              .replace(
                queryParameters: {
                  'code': 'authorization-code',
                  'state': uri.queryParameters['state'],
                },
              )
              .toString(),
    );

    expect(
      oauth.signIn(),
      throwsA(
        isA<GoogleDriveOAuthException>().having(
          (error) => error.code,
          'code',
          'insufficient_scope',
        ),
      ),
    );
  });
}
