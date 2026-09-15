import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/services/hachidori/hachidori_protocol.dart';
import 'package:mangayomi/services/hachidori/hachidori_sharing_client.dart';

void main() {
  group('HachidoriSharingClient handshake', () {
    test(
      'uses the ecosystem origin and sends the exact protocol-v1 hello',
      () async {
        final connector = _FakeConnector();
        final client = HachidoriSharingClient(
          connector: connector.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );

        client.link('localhost');
        await pumpEventQueue();

        expect(
          connector.addresses.single.toString(),
          'ws://127.0.0.1:8771/link',
        );
        expect(connector.origins, const [hachidoriDefaultOrigin]);
        expect(connector.sockets.single.decodedSent, [
          {
            'kind': 'hello',
            'protocol': 1,
            'version': '1.2.22',
            'name': 'Mangatan',
            'capabilities': <Object?>[],
          },
        ]);
        expect(client.state.ready, isFalse);

        client.dispose();
      },
    );

    test('allows an explicit non-default Origin', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Test client',
        clientVersion: 'test',
        origin: 'app://test-hoshidicts-client',
      );

      client.link('example.test');
      await pumpEventQueue();

      expect(connector.origins, const ['app://test-hoshidicts-client']);
      client.dispose();
    });
  });

  group('HachidoriSharingClient host frames', () {
    test(
      'becomes ready only after a validated hello and keeps its snapshot',
      () async {
        final connector = _FakeConnector();
        final client = HachidoriSharingClient(
          connector: connector.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );
        client.link('host.test');
        await pumpEventQueue();

        connector.sockets.single.receive({
          'kind': 'hello',
          'protocol': 1,
          'version': '0.9.0',
          'name': 'Hachidori in Firefox',
          'dictionaryCount': 2,
          'capabilities': ['future-read-v1'],
          'snapshot': {
            'options': {'frequencyOrder': 'ascending'},
            'dictionaryState': {
              'schemaVersion': 1,
              'revision': 7,
              'dictionaries': [
                {
                  'id': 'jmdict',
                  'title': 'JMdict',
                  'displayName': 'JMdict English',
                  'enabled': true,
                  'termCount': 100,
                  'frequencyCount': 4,
                },
                {
                  'id': 'pitch',
                  'title': 'Pitch',
                  'enabled': false,
                  'pitchCount': 20,
                },
              ],
            },
          },
        });
        await pumpEventQueue();

        expect(client.state.ready, isTrue);
        expect(client.state.error, isNull);
        expect(client.state.host?.name, 'Hachidori in Firefox');
        expect(client.state.host?.version, '0.9.0');
        expect(client.state.host?.dictionaryCount, 2);
        expect(client.state.host?.capabilities, const ['future-read-v1']);
        expect(client.state.snapshot['options'], const {
          'frequencyOrder': 'ascending',
        });
        expect(
          client.state.dictionaries
              .map(
                (dictionary) => (
                  dictionary.title,
                  dictionary.displayName,
                  dictionary.enabled,
                ),
              )
              .toList(),
          const [('JMdict', 'JMdict English', true), ('Pitch', null, false)],
        );

        client.dispose();
      },
    );

    test('answers ping and applies storage changes in memory', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      final events = <HachidoriLibraryEvent>[];
      final subscription = client.libraryEvents.listen(events.add);
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      socket.receive({'kind': 'ping'});
      socket.receive({
        'kind': 'storage',
        'changes': {
          'dictionaryState': {
            'schemaVersion': 1,
            'revision': 8,
            'dictionaries': [
              {
                'id': 'kanji',
                'title': 'Kanji',
                'enabled': true,
                'kanjiCount': 42,
              },
            ],
          },
          'options': {'frequencyOrder': 'descending'},
        },
      });
      await pumpEventQueue();

      expect(socket.decodedSent.last, {'kind': 'pong'});
      expect(client.state.dictionaries.single.title, 'Kanji');
      expect(client.state.snapshot['options'], const {
        'frequencyOrder': 'descending',
      });
      expect(events.map((event) => event.kind), [
        HachidoriLibraryEventKind.hello,
        HachidoriLibraryEventKind.storage,
      ]);

      await subscription.cancel();
      client.dispose();
    });

    test('bye surfaces its reason and closes the socket', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      socket.receive({'kind': 'bye', 'reason': 'This client is not allowed.'});
      await pumpEventQueue();

      expect(client.state.ready, isFalse);
      expect(client.state.error, 'This client is not allowed.');
      expect(socket.closed, isTrue);
      client.dispose();
    });

    test('rejects deeply nested frames before decoding', () async {
      final connector = _FakeConnector();
      final scheduler = _FakeReconnectScheduler();
      final client = HachidoriSharingClient(
        connector: connector.call,
        reconnectScheduler: scheduler.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('127.0.0.1');
      await pumpEventQueue();
      final socket = connector.sockets.single;

      socket.receiveRaw('${'[' * 65}null${']' * 65}');
      await pumpEventQueue();

      expect(socket.closed, isTrue);
      expect(client.state.ready, isFalse);
      client.dispose();
    });

    test(
      'protocol mismatch, malformed JSON, and unknown frames fail closed',
      () async {
        final frames = <Object?>[
          {
            'kind': 'hello',
            'protocol': 2,
            'version': 'future',
            'name': 'Future host',
            'dictionaryCount': 0,
            'snapshot': <String, Object?>{},
          },
          '{not json',
          {'kind': 'mystery'},
        ];

        for (final frame in frames) {
          final connector = _FakeConnector();
          final client = HachidoriSharingClient(
            connector: connector.call,
            clientName: 'Mangatan',
            clientVersion: '1.2.22',
          );
          client.link('host.test');
          await pumpEventQueue();
          final socket = connector.sockets.single;
          socket.receiveRaw(frame is String ? frame : jsonEncode(frame));
          await pumpEventQueue();

          expect(client.state.ready, isFalse, reason: '$frame');
          expect(client.state.error, isNotEmpty, reason: '$frame');
          expect(socket.closed, isTrue, reason: '$frame');
          client.dispose();
        }
      },
    );
  });

  group('HachidoriSharingClient request lifecycle', () {
    test(
      'sends typed status requests and correlates out-of-order replies',
      () async {
        final connector = _FakeConnector();
        final client = HachidoriSharingClient(
          connector: connector.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );
        client.link('host.test');
        await pumpEventQueue();
        final socket = connector.sockets.single;
        socket.receive(_hello(snapshot: const {}));
        await pumpEventQueue();

        final first = client.status();
        final second = client.status();
        await pumpEventQueue();
        final requests = socket.decodedSent
            .whereType<Map<String, dynamic>>()
            .where((frame) => frame['kind'] == 'request')
            .toList();
        expect(requests, [
          {
            'kind': 'request',
            'id': 1,
            'message': {
              'target': 'hoshidicts-offscreen',
              'type': 'hd_status',
              'requestId': 1,
            },
          },
          {
            'kind': 'request',
            'id': 2,
            'message': {
              'target': 'hoshidicts-offscreen',
              'type': 'hd_status',
              'requestId': 2,
            },
          },
        ]);

        socket.reply(
          requests[1],
          _statusResponse(requestId: 2, generation: 12),
        );
        socket.reply(
          requests[0],
          _statusResponse(requestId: 1, generation: 11),
        );

        expect((await first).generation, 11);
        expect((await second).generation, 12);
        expect(client.dictionaryGeneration, 12);
        client.dispose();
      },
    );

    test('a disconnected request waits for hello, then sends once', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;

      final pending = client.status();
      await pumpEventQueue();
      expect(
        socket.decodedSent.where(
          (frame) => frame is Map && frame['kind'] == 'request',
        ),
        isEmpty,
      );

      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();
      final request = socket.decodedSent
          .whereType<Map<String, dynamic>>()
          .singleWhere((frame) => frame['kind'] == 'request');
      socket.reply(request, _statusResponse(requestId: 1, generation: 3));

      expect((await pending).generation, 3);
      client.dispose();
    });

    test('the connection wait expires without a host hello', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
        connectWait: const Duration(milliseconds: 20),
      );
      client.link('host.test');
      await pumpEventQueue();

      await expectLater(
        client.status(),
        throwsA(
          isA<HachidoriConnectionException>().having(
            (error) => error.message,
            'message',
            contains('not reachable'),
          ),
        ),
      );
      client.dispose();
    });

    test('socket close rejects every pending read', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      final first = client.status();
      final second = client.status();
      await pumpEventQueue();
      await socket.drop();

      await expectLater(first, throwsA(isA<HachidoriConnectionException>()));
      await expectLater(second, throwsA(isA<HachidoriConnectionException>()));
      client.dispose();
    });

    test('remote request failures do not close a healthy socket', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      final failed = client.status();
      await pumpEventQueue();
      final failedRequest = _lastRequest(socket, 'hd_status');
      socket.reply(failedRequest, {
        'type': 'hd_status_result',
        'requestId': failedRequest['id'],
        'ok': false,
        'error': 'The engine is updating.',
        'errorCode': 'engine-mutating',
      });

      await expectLater(
        failed,
        throwsA(
          isA<HachidoriRemoteException>()
              .having((error) => error.code, 'code', 'engine-mutating')
              .having(
                (error) => error.message,
                'message',
                'The engine is updating.',
              ),
        ),
      );
      expect(socket.closed, isFalse);
      expect(client.state.ready, isTrue);

      final next = client.status();
      await pumpEventQueue();
      final nextRequest = _lastRequest(socket, 'hd_status');
      socket.reply(
        nextRequest,
        _statusResponse(requestId: nextRequest['id'] as int, generation: 3),
      );
      expect((await next).generation, 3);
      client.dispose();
    });

    test(
      'request send failure disconnects and schedules reconnection',
      () async {
        final connector = _FakeConnector();
        final scheduler = _FakeReconnectScheduler();
        final client = HachidoriSharingClient(
          connector: connector.call,
          reconnectScheduler: scheduler.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );
        client.link('host.test');
        await pumpEventQueue();
        final socket = connector.sockets.single;
        socket.receive(_hello(snapshot: const {}));
        await pumpEventQueue();
        socket.sendError = StateError('write failed');

        await expectLater(
          client.status(),
          throwsA(isA<HachidoriConnectionException>()),
        );

        expect(socket.closed, isTrue);
        expect(client.state.ready, isFalse);
        expect(scheduler.delays, const [Duration(milliseconds: 500)]);
        client.dispose();
      },
    );

    test('a host that never replies does not leak a pending request', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
        requestWait: const Duration(milliseconds: 20),
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      await expectLater(
        client.status(),
        throwsA(
          isA<HachidoriConnectionException>().having(
            (error) => error.message,
            'message',
            contains('did not answer in time'),
          ),
        ),
      );

      final next = client.status();
      await pumpEventQueue();
      final request = _lastRequest(socket, 'hd_status');
      socket.reply(
        request,
        _statusResponse(requestId: request['id'] as int, generation: 3),
      );
      expect((await next).generation, 3);
      client.dispose();
    });

    test(
      'relink connects the new host while the old connector is pending',
      () async {
        final connector = _DelayedFirstConnector();
        final client = HachidoriSharingClient(
          connector: connector.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );

        client.link('old.test');
        await pumpEventQueue();
        expect(connector.addresses.single.host, 'old.test');

        client.link('new.test');
        await pumpEventQueue();

        expect(connector.addresses.map((address) => address.host), [
          'old.test',
          'new.test',
        ]);
        final newSocket = connector.sockets.single;
        newSocket.receive(_hello(snapshot: const {}));
        await pumpEventQueue();
        expect(client.state.ready, isTrue);
        expect(client.state.address?.parsedUri.host, 'new.test');

        connector.completeFirst();
        await pumpEventQueue();
        expect(connector.firstSocket.closed, isTrue);
        expect(client.state.ready, isTrue);
        expect(client.state.address?.parsedUri.host, 'new.test');
        client.dispose();
      },
    );

    test(
      'relink rejects old work and ignores obsolete socket replies',
      () async {
        final connector = _FakeConnector();
        final client = HachidoriSharingClient(
          connector: connector.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );
        client.link('old.test');
        await pumpEventQueue();
        final oldSocket = connector.sockets.single;
        oldSocket.receive(_hello(snapshot: const {}));
        await pumpEventQueue();
        final oldRequestFuture = client.status();
        await pumpEventQueue();
        final oldRequest = oldSocket.decodedSent
            .whereType<Map<String, dynamic>>()
            .singleWhere((frame) => frame['kind'] == 'request');

        client.link('new.test');
        await expectLater(
          oldRequestFuture,
          throwsA(isA<HachidoriConnectionException>()),
        );
        await pumpEventQueue();
        final newSocket = connector.sockets.last;
        newSocket.receive(_hello(snapshot: const {}));
        await pumpEventQueue();
        final currentFuture = client.status();
        await pumpEventQueue();
        final currentRequest = newSocket.decodedSent
            .whereType<Map<String, dynamic>>()
            .singleWhere((frame) => frame['kind'] == 'request');

        oldSocket.receiveRaw(
          jsonEncode({
            'kind': 'reply',
            'id': currentRequest['id'],
            'response': _statusResponse(
              requestId: currentRequest['id'] as int,
              generation: 99,
            ),
          }),
        );
        newSocket.reply(
          currentRequest,
          _statusResponse(
            requestId: currentRequest['id'] as int,
            generation: 4,
          ),
        );

        expect((await currentFuture).generation, 4);
        expect(client.dictionaryGeneration, 4);
        expect(oldRequest['id'], 1);
        client.dispose();
      },
    );
  });

  group('HachidoriSharingClient reconnect and probe', () {
    test(
      'uses capped exponential reconnect delays and requires a fresh hello',
      () async {
        final connector = _FakeConnector();
        final scheduler = _FakeReconnectScheduler();
        final client = HachidoriSharingClient(
          connector: connector.call,
          reconnectScheduler: scheduler.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );
        client.link('host.test');
        await pumpEventQueue();
        connector.sockets.single.receive(_hello(snapshot: const {}));
        await pumpEventQueue();
        expect(client.state.ready, isTrue);

        await connector.sockets.single.drop();
        await pumpEventQueue();
        expect(scheduler.delays, const [Duration(milliseconds: 500)]);

        scheduler.fireLast();
        await pumpEventQueue();
        expect(connector.sockets, hasLength(2));
        expect(client.state.ready, isFalse);
        expect(client.state.connecting, isTrue);

        connector.sockets.last.receive(_hello(snapshot: const {}));
        await pumpEventQueue();
        expect(client.state.ready, isTrue);

        connector.failures.addAll(List.filled(6, StateError('offline')));
        await connector.sockets.last.drop();
        await pumpEventQueue();
        for (var index = 0; index < 6; index++) {
          scheduler.fireLast();
          await pumpEventQueue();
        }

        expect(scheduler.delays, const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 500),
          Duration(seconds: 1),
          Duration(seconds: 2),
          Duration(seconds: 4),
          Duration(seconds: 8),
          Duration(seconds: 10),
          Duration(seconds: 10),
        ]);
        client.dispose();
      },
    );

    test('a read cancels a scheduled retry and connects immediately', () async {
      final connector = _FakeConnector();
      final scheduler = _FakeReconnectScheduler();
      final client = HachidoriSharingClient(
        connector: connector.call,
        reconnectScheduler: scheduler.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      connector.sockets.single.receive(_hello(snapshot: const {}));
      await pumpEventQueue();
      await connector.sockets.single.drop();
      await pumpEventQueue();

      final pending = client.status();
      await pumpEventQueue();

      expect(scheduler.entries.single.cancelled, isTrue);
      expect(connector.sockets, hasLength(2));
      final socket = connector.sockets.last;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();
      final request = socket.decodedSent
          .whereType<Map<String, dynamic>>()
          .singleWhere((frame) => frame['kind'] == 'request');
      socket.reply(
        request,
        _statusResponse(requestId: request['id'] as int, generation: 3),
      );

      expect((await pending).generation, 3);
      client.dispose();
    });

    test('probe validates a host without changing linked state', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );

      final resultFuture = client.probe('probe.test:9123');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      expect(
        connector.addresses.single.toString(),
        'ws://probe.test:9123/link',
      );
      expect(connector.origins.single, hachidoriDefaultOrigin);
      expect(socket.decodedSent.single, {
        'kind': 'hello',
        'protocol': 1,
        'version': '1.2.22',
        'name': 'Mangatan',
        'capabilities': <Object?>[],
      });
      socket.receive({'kind': 'ping'});
      socket.receive(
        _hello(
          snapshot: {
            'dictionaryState': {
              'schemaVersion': 1,
              'dictionaries': [
                {'id': 'jmdict', 'title': 'JMdict', 'enabled': true},
              ],
            },
          },
        ),
      );

      final result = await resultFuture;
      expect(socket.decodedSent.last, {'kind': 'pong'});
      expect(result.host.name, 'Test host');
      expect(result.dictionaries.single.title, 'JMdict');
      expect(socket.closed, isTrue);
      expect(client.state.linked, isFalse);
      client.dispose();
    });
  });

  group('HachidoriSharingClient typed dictionary reads', () {
    test(
      'sends exact lookup messages and adopts monotonic generations',
      () async {
        final connector = _FakeConnector();
        final client = HachidoriSharingClient(
          connector: connector.call,
          clientName: 'Mangatan',
          clientVersion: '1.2.22',
        );
        client.link('host.test');
        await pumpEventQueue();
        final socket = connector.sockets.single;
        socket.receive(_hello(snapshot: const {}));
        await pumpEventQueue();

        final lookupFuture = client.lookup(
          '食べた',
          maxResults: 8,
          scanLength: 12,
          options: const HachidoriLookupOptions(
            frequencyDictionary: 'JPDB',
            frequencyOrder: HachidoriFrequencyOrder.ascending,
            primaryReading: 'たべる',
          ),
        );
        await pumpEventQueue();
        final lookupRequest = socket.decodedSent
            .whereType<Map<String, dynamic>>()
            .singleWhere(
              (frame) => (frame['message'] as Map?)?['type'] == 'hd_lookup',
            );
        expect(lookupRequest, {
          'kind': 'request',
          'id': 1,
          'message': {
            'target': 'hoshidicts-offscreen',
            'type': 'hd_lookup',
            'requestId': 1,
            'text': '食べた',
            'maxResults': 8,
            'scanLength': 12,
            'options': {
              'frequencyDictionary': 'JPDB',
              'frequencyOrder': 'ascending',
              'primaryReading': 'たべる',
            },
          },
        });
        socket.reply(
          lookupRequest,
          _lookupResponse(requestId: 1, generation: 7),
        );
        final lookup = await lookupFuture;
        expect(lookup.single.term.expression, '食べる');
        expect(client.dictionaryGeneration, 7);

        final dictionaryFuture = client.lookupDictionary(
          '食べる',
          dictionary: 'JMdict',
          maxResults: 4,
          scanLength: 16,
        );
        await pumpEventQueue();
        final dictionaryRequest = socket.decodedSent
            .whereType<Map<String, dynamic>>()
            .singleWhere(
              (frame) =>
                  (frame['message'] as Map?)?['type'] == 'hd_lookup_dictionary',
            );
        expect(dictionaryRequest['message'], {
          'target': 'hoshidicts-offscreen',
          'type': 'hd_lookup_dictionary',
          'requestId': 2,
          'text': '食べる',
          'dictionary': 'JMdict',
          'maxResults': 4,
          'scanLength': 16,
          'options': {
            'frequencyDictionary': '',
            'frequencyOrder': 'auto',
            'primaryReading': '',
          },
        });
        socket.reply(
          dictionaryRequest,
          _lookupResponse(
            requestId: 2,
            generation: 9,
            type: 'hd_lookup_dictionary',
          ),
        );
        await dictionaryFuture;
        expect(client.dictionaryGeneration, 9);

        final olderFuture = client.lookup('食');
        await pumpEventQueue();
        final olderRequest = socket.decodedSent
            .whereType<Map<String, dynamic>>()
            .lastWhere(
              (frame) => (frame['message'] as Map?)?['type'] == 'hd_lookup',
            );
        socket.reply(
          olderRequest,
          _lookupResponse(requestId: 3, generation: 8),
        );
        await olderFuture;
        expect(client.dictionaryGeneration, 9);
        client.dispose();
      },
    );

    test('adapts Kanji, styles, and generation-bound media reads', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      final statusFuture = client.status();
      await pumpEventQueue();
      final statusRequest = _lastRequest(socket, 'hd_status');
      socket.reply(statusRequest, _statusResponse(requestId: 1, generation: 5));
      await statusFuture;

      final kanjiFuture = client.lookupKanji('食');
      await pumpEventQueue();
      final kanjiRequest = _lastRequest(socket, 'hd_kanji');
      expect(kanjiRequest['message'], {
        'target': 'hoshidicts-offscreen',
        'type': 'hd_kanji',
        'requestId': 2,
        'character': '食',
      });
      socket.reply(kanjiRequest, {
        'type': 'hd_kanji_result',
        'requestId': 2,
        'ok': true,
        'error': null,
        'generation': 5,
        'kanji': {
          'character': '食',
          'entries': [
            {
              'dictionary': 'KANJIDIC',
              'onyomi': 'ショク',
              'kunyomi': 'た.べる',
              'tags': 'jouyou',
              'definitions': ['eat'],
              'stats': <Object?>[],
            },
          ],
        },
      });
      expect((await kanjiFuture).single.term.expression, '食');

      final stylesFuture = client.styles();
      await pumpEventQueue();
      final stylesRequest = _lastRequest(socket, 'hd_styles');
      expect(stylesRequest['message'], {
        'target': 'hoshidicts-offscreen',
        'type': 'hd_styles',
        'requestId': 3,
      });
      socket.reply(stylesRequest, {
        'type': 'hd_styles_result',
        'requestId': 3,
        'ok': true,
        'error': null,
        'generation': 5,
        'styles': [
          {'dictionary': 'JMdict', 'styles': '.entry {}'},
        ],
      });
      expect((await stylesFuture).single.dictName, 'JMdict');

      final mediaFuture = client.media(dictionary: 'JMdict', path: 'image.png');
      await pumpEventQueue();
      final mediaRequest = _lastRequest(socket, 'hd_media');
      expect(mediaRequest['message'], {
        'target': 'hoshidicts-offscreen',
        'type': 'hd_media',
        'requestId': 4,
        'dictionary': 'JMdict',
        'path': 'image.png',
        'generation': 5,
      });
      socket.reply(mediaRequest, {
        'type': 'hd_media_result',
        'requestId': 4,
        'ok': true,
        'error': null,
        'generation': 5,
        'dataUrl': 'data:image/png;base64,iVBORw0KGgo=',
      });
      expect(await mediaFuture, [137, 80, 78, 71, 13, 10, 26, 10]);
      client.dispose();
    });

    test('media rejects missing or changed dictionary generations', () async {
      final connector = _FakeConnector();
      final client = HachidoriSharingClient(
        connector: connector.call,
        clientName: 'Mangatan',
        clientVersion: '1.2.22',
      );
      client.link('host.test');
      await pumpEventQueue();
      final socket = connector.sockets.single;
      socket.receive(_hello(snapshot: const {}));
      await pumpEventQueue();

      await expectLater(
        client.media(dictionary: 'JMdict', path: 'image.png'),
        throwsA(isA<HachidoriProtocolException>()),
      );
      expect(
        socket.decodedSent.whereType<Map<String, dynamic>>().where(
          (frame) => (frame['message'] as Map?)?['type'] == 'hd_media',
        ),
        isEmpty,
      );

      final statusFuture = client.status();
      await pumpEventQueue();
      socket.reply(
        _lastRequest(socket, 'hd_status'),
        _statusResponse(requestId: 1, generation: 3),
      );
      await statusFuture;

      final mediaFuture = client.media(dictionary: 'JMdict', path: 'image.png');
      await pumpEventQueue();
      final mediaRequest = _lastRequest(socket, 'hd_media');
      socket.reply(mediaRequest, {
        'type': 'hd_media_result',
        'requestId': 2,
        'ok': true,
        'error': null,
        'generation': 4,
        'dataUrl': 'data:image/png;base64,iVBORw0KGgo=',
      });
      await expectLater(
        mediaFuture,
        throwsA(isA<HachidoriProtocolException>()),
      );
      expect(client.dictionaryGeneration, isNull);
      client.dispose();
    });
  });
}

Map<String, Object?> _hello({required Map<String, Object?> snapshot}) => {
  'kind': 'hello',
  'protocol': 1,
  'version': '1.0.0',
  'name': 'Test host',
  'dictionaryCount': 0,
  'capabilities': <Object?>[],
  'snapshot': snapshot,
};

Map<String, Object?> _statusResponse({
  required int requestId,
  required int generation,
}) => {
  'type': 'hd_status_result',
  'requestId': requestId,
  'ok': true,
  'error': null,
  'ready': true,
  'loading': false,
  'dictionaryCount': 2,
  'failedDictionaries': <Object?>[],
  'generation': generation,
  'storageBackend': 'opfs',
  'threaded': true,
};

Map<String, Object?> _lookupResponse({
  required int requestId,
  required int generation,
  String type = 'hd_lookup',
}) => {
  'type': '${type}_result',
  'requestId': requestId,
  'ok': true,
  'error': null,
  'generation': generation,
  'dictionaryCount': 1,
  'results': [
    {
      'matched': '食べた',
      'deinflected': '食べる',
      'trace': <Object?>[],
      'preprocessorSteps': 0,
      'term': {
        'expression': '食べる',
        'reading': 'たべる',
        'rules': 'v1',
        'score': 1,
        'glossaries': [
          {
            'dictionary': 'JMdict',
            'glossary': 'to eat',
            'definitionTags': '',
            'termTags': '',
          },
        ],
        'frequencies': <Object?>[],
        'pitches': <Object?>[],
      },
    },
  ],
};

Map<String, dynamic> _lastRequest(_FakeSocket socket, String type) => socket
    .decodedSent
    .whereType<Map<String, dynamic>>()
    .lastWhere((frame) => (frame['message'] as Map?)?['type'] == type);

class _FakeConnector {
  final List<Uri> addresses = [];
  final List<String> origins = [];
  final List<_FakeSocket> sockets = [];
  final List<Object> failures = [];

  Future<HachidoriWebSocket> call(Uri address, {required String origin}) async {
    addresses.add(address);
    origins.add(origin);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

class _DelayedFirstConnector {
  final List<Uri> addresses = [];
  final List<_FakeSocket> sockets = [];
  final Completer<HachidoriWebSocket> _first = Completer<HachidoriWebSocket>();
  final _FakeSocket firstSocket = _FakeSocket();

  Future<HachidoriWebSocket> call(Uri address, {required String origin}) {
    addresses.add(address);
    if (addresses.length == 1) return _first.future;
    final socket = _FakeSocket();
    sockets.add(socket);
    return Future.value(socket);
  }

  void completeFirst() => _first.complete(firstSocket);
}

class _FakeReconnectScheduler {
  final List<_FakeReconnectEntry> entries = [];

  List<Duration> get delays =>
      entries.map((entry) => entry.delay).toList(growable: false);

  HachidoriReconnectHandle call(Duration delay, void Function() callback) {
    final entry = _FakeReconnectEntry(delay, callback);
    entries.add(entry);
    return entry;
  }

  void fireLast() => entries.last.fire();
}

class _FakeReconnectEntry implements HachidoriReconnectHandle {
  _FakeReconnectEntry(this.delay, this.callback);

  final Duration delay;
  final void Function() callback;
  bool cancelled = false;
  bool fired = false;

  void fire() {
    if (cancelled || fired) return;
    fired = true;
    callback();
  }

  @override
  void cancel() => cancelled = true;
}

class _FakeSocket implements HachidoriWebSocket {
  final StreamController<Object?> _messages = StreamController<Object?>();
  final List<String> sent = [];
  bool closed = false;
  Object? sendError;

  List<Object?> get decodedSent => sent.map(jsonDecode).toList();

  void receive(Map<String, Object?> frame) => receiveRaw(jsonEncode(frame));

  void receiveRaw(Object? frame) => _messages.add(frame);

  void reply(Map<String, dynamic> request, Map<String, Object?> response) {
    receive({'kind': 'reply', 'id': request['id'], 'response': response});
  }

  Future<void> drop() async {
    if (closed) return;
    closed = true;
    await _messages.close();
  }

  @override
  Stream<Object?> get messages => _messages.stream;

  @override
  Future<void> get ready => Future.value();

  @override
  void send(String text) {
    if (sendError case final error?) throw error;
    sent.add(text);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (closed) return;
    closed = true;
  }
}
