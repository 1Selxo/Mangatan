import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mangayomi/services/hachidori/hachidori_models.dart';
import 'package:mangayomi/services/hachidori/hachidori_protocol.dart';
import 'package:mangayomi/services/hachidori/hachidori_wire_adapter.dart';
import 'package:mangayomi/src/rust/api/hoshidicts.dart';
import 'package:web_socket_channel/io.dart';

export 'hachidori_models.dart';

abstract interface class HachidoriWebSocket {
  Future<void> get ready;

  Stream<Object?> get messages;

  void send(String text);

  Future<void> close([int? code, String? reason]);
}

typedef HachidoriWebSocketConnector =
    Future<HachidoriWebSocket> Function(Uri address, {required String origin});

abstract interface class HachidoriReconnectHandle {
  void cancel();
}

typedef HachidoriReconnectScheduler =
    HachidoriReconnectHandle Function(Duration delay, void Function() callback);

class HachidoriSharingClient extends ChangeNotifier
    implements HachidoriLinkClient {
  HachidoriSharingClient({
    required String clientName,
    required String clientVersion,
    HachidoriWebSocketConnector? connector,
    HachidoriReconnectScheduler? reconnectScheduler,
    this.origin = hachidoriDefaultOrigin,
    this.connectWait = const Duration(seconds: 5),
  }) : _clientName = clientName,
       _clientVersion = clientVersion,
       _connector = connector ?? _connectIoWebSocket,
       _reconnectScheduler = reconnectScheduler ?? _scheduleReconnectTimer;

  final String _clientName;
  final String _clientVersion;
  final HachidoriWebSocketConnector _connector;
  final HachidoriReconnectScheduler _reconnectScheduler;
  final String origin;
  final Duration connectWait;

  HachidoriClientState _state = const HachidoriClientState();
  HachidoriWebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  final StreamController<HachidoriLibraryEvent> _libraryEvents =
      StreamController<HachidoriLibraryEvent>.broadcast();
  final Map<int, _PendingRequest> _pending = {};
  final Set<_ReadyWaiter> _waiting = {};
  int _generation = 0;
  int _nextRequestId = 0;
  int? _dictionaryGeneration;
  HachidoriReconnectHandle? _reconnectHandle;
  int _reconnectAttempt = 0;
  bool _connectInFlight = false;
  bool _disposed = false;

  HachidoriClientState get state => _state;

  Stream<HachidoriLibraryEvent> get libraryEvents => _libraryEvents.stream;

  int? get dictionaryGeneration => _dictionaryGeneration;

  void link(String address) {
    final parsed = HachidoriLinkAddress.parse(address);
    _cancelReconnect();
    _reconnectAttempt = 0;
    _rejectPendingAndWaiting(
      const HachidoriConnectionException(
        'The linked Hachidori is not reachable.',
      ),
    );
    final generation = ++_generation;
    _dictionaryGeneration = null;
    final previous = _socket;
    _socket = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (previous != null) unawaited(previous.close());
    _setState(
      HachidoriClientState(linked: true, address: parsed, connecting: true),
    );
    unawaited(_connect(parsed, generation));
  }

  void unlink() {
    _cancelReconnect();
    _reconnectAttempt = 0;
    _generation++;
    _dictionaryGeneration = null;
    _rejectPendingAndWaiting(
      const HachidoriConnectionException(
        'The linked Hachidori is not reachable.',
      ),
    );
    final previous = _socket;
    _socket = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (previous != null) unawaited(previous.close());
    _setState(const HachidoriClientState());
  }

  Future<HachidoriProbeResult> probe(String address) async {
    final parsed = HachidoriLinkAddress.parse(address);
    HachidoriWebSocket? socket;
    StreamSubscription<Object?>? subscription;
    final result = Completer<HachidoriProbeResult>();
    Timer? timeout;
    try {
      socket = await _connector(parsed.parsedUri, origin: origin);
      await socket.ready.timeout(connectWait);
      subscription = socket.messages.listen(
        (message) {
          if (result.isCompleted) return;
          try {
            switch (_parseHostFrame(message)) {
              case _HelloFrame(:final host, :final snapshot):
                final frozenSnapshot = _freezeMap(snapshot);
                result.complete(
                  HachidoriProbeResult(
                    host: host,
                    snapshot: frozenSnapshot,
                    dictionaries: _parseDictionaries(frozenSnapshot),
                  ),
                );
              case _PingFrame():
                socket?.send(jsonEncode({'kind': 'pong'}));
              case _ByeFrame(:final reason):
                result.completeError(
                  HachidoriConnectionException(
                    reason.isEmpty
                        ? 'The Hachidori host refused the connection.'
                        : reason,
                  ),
                );
              case _ReplyFrame() || _StorageFrame():
                throw const FormatException(
                  'received sharing data before the host hello',
                );
            }
          } on Object catch (error, stackTrace) {
            result.completeError(
              HachidoriProtocolException(_describe(error)),
              stackTrace,
            );
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!result.isCompleted) {
            result.completeError(
              HachidoriConnectionException(_describe(error)),
              stackTrace,
            );
          }
        },
        onDone: () {
          if (!result.isCompleted) {
            result.completeError(
              const HachidoriConnectionException(
                'The Hachidori host closed the connection.',
              ),
            );
          }
        },
      );
      timeout = Timer(connectWait, () {
        if (!result.isCompleted) {
          result.completeError(
            const HachidoriConnectionException(
              'The Hachidori host did not answer in time.',
            ),
          );
        }
      });
      socket.send(_clientHello());
      return await result.future;
    } on HachidoriException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        HachidoriConnectionException(_describe(error)),
        stackTrace,
      );
    } finally {
      timeout?.cancel();
      await subscription?.cancel();
      await socket?.close();
    }
  }

  Future<HachidoriEngineStatus> status() async {
    final response = await _request('hd_status');
    return _parseTypedResponse(() {
      final generation = response.generation;
      final ready = response.payload['ready'];
      final loading = response.payload['loading'];
      final failed = response.payload['failedDictionaries'];
      if (ready is! bool || loading is! bool || failed is! List) {
        throw const HachidoriProtocolException('malformed hd_status response');
      }
      final status = HachidoriEngineStatus(
        ready: ready,
        loading: loading,
        dictionaryCount: _responseCount(
          response.payload['dictionaryCount'],
          'dictionaryCount',
        ),
        failedDictionaries: List<Object?>.unmodifiable(failed),
        generation: generation,
        storageBackend: response.payload['storageBackend'] is String
            ? response.payload['storageBackend'] as String
            : '',
        threaded: response.payload['threaded'] == true,
      );
      _adoptDictionaryGeneration(generation);
      return status;
    });
  }

  Future<List<HoshiLookupResult>> lookup(
    String text, {
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  }) async {
    final response = await _request('hd_lookup', {
      'text': text,
      'maxResults': maxResults,
      'scanLength': scanLength,
      'options': options.toJson(),
    });
    return _parseTypedResponse(() {
      _responseCount(response.payload['dictionaryCount'], 'dictionaryCount');
      final results = adaptHachidoriLookupResults(response.payload['results']);
      _adoptDictionaryGeneration(response.generation);
      return results;
    });
  }

  Future<List<HoshiLookupResult>> lookupDictionary(
    String text, {
    required String dictionary,
    int maxResults = 10,
    int scanLength = 20,
    HachidoriLookupOptions options = const HachidoriLookupOptions(),
  }) async {
    final response = await _request('hd_lookup_dictionary', {
      'text': text,
      'dictionary': dictionary,
      'maxResults': maxResults,
      'scanLength': scanLength,
      'options': options.toJson(),
    });
    return _parseTypedResponse(() {
      _responseCount(response.payload['dictionaryCount'], 'dictionaryCount');
      final results = adaptHachidoriLookupResults(response.payload['results']);
      _adoptDictionaryGeneration(response.generation);
      return results;
    });
  }

  Future<List<HoshiLookupResult>> lookupKanji(String character) async {
    final response = await _request('hd_kanji', {'character': character});
    return _parseTypedResponse(
      () => adaptHachidoriKanji(response.payload['kanji']),
    );
  }

  Future<List<HoshiDictionaryStyle>> styles() async {
    final response = await _request('hd_styles');
    return _parseTypedResponse(
      () => adaptHachidoriStyles(response.payload['styles']),
    );
  }

  Future<Uint8List?> media({
    required String dictionary,
    required String path,
  }) async {
    final generation = _dictionaryGeneration;
    if (generation == null) {
      throw const HachidoriProtocolException(
        'A dictionary lookup is required before loading remote media.',
      );
    }
    try {
      final response = await _request('hd_media', {
        'dictionary': dictionary,
        'path': path,
        'generation': generation,
      });
      if (response.generation != generation) {
        _dictionaryGeneration = null;
        throw const HachidoriProtocolException(
          'The remote dictionary media changed after lookup.',
        );
      }
      return _parseTypedResponse(
        () => adaptHachidoriMedia(response.payload['dataUrl']),
      );
    } on HachidoriRemoteException catch (error) {
      if (error.message.toLowerCase().contains('generation')) {
        _dictionaryGeneration = null;
      }
      rethrow;
    } on HachidoriProtocolException {
      _dictionaryGeneration = null;
      rethrow;
    }
  }

  Future<void> _connect(HachidoriLinkAddress address, int generation) async {
    if (_connectInFlight ||
        _disposed ||
        generation != _generation ||
        !_state.linked) {
      return;
    }
    _connectInFlight = true;
    try {
      final socket = await _connector(address.parsedUri, origin: origin);
      await socket.ready;
      if (_disposed || generation != _generation || !_state.linked) {
        await socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.messages.listen(
        (message) => _handleMessage(socket, generation, message),
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketError(socket, generation, error);
        },
        onDone: () => _handleSocketDone(socket, generation),
      );
      socket.send(_clientHello());
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _rejectWaiting(
        HachidoriConnectionException(
          'The linked Hachidori is not reachable: ${_describe(error)}',
        ),
      );
      _setState(
        HachidoriClientState(
          linked: true,
          address: address,
          error: error.toString(),
        ),
      );
      _scheduleReconnect(generation);
    } finally {
      if (generation == _generation) _connectInFlight = false;
    }
  }

  void _handleMessage(
    HachidoriWebSocket socket,
    int generation,
    Object? message,
  ) {
    if (_socket != socket || _generation != generation) return;
    try {
      final frame = _parseHostFrame(message);
      switch (frame) {
        case _HelloFrame():
          final snapshot = _freezeMap(frame.snapshot);
          final dictionaries = _parseDictionaries(snapshot);
          _dictionaryGeneration = null;
          _cancelReconnect();
          _reconnectAttempt = 0;
          _setState(
            HachidoriClientState(
              linked: true,
              address: _state.address,
              ready: true,
              host: frame.host,
              snapshot: snapshot,
              dictionaries: dictionaries,
            ),
          );
          _libraryEvents.add(
            const HachidoriLibraryEvent(kind: HachidoriLibraryEventKind.hello),
          );
          _resolveWaiting(generation);
        case _StorageFrame():
          if (!_state.ready) {
            throw const FormatException(
              'received shared storage before the host hello',
            );
          }
          final next = Map<String, Object?>.from(_state.snapshot);
          for (final entry in frame.changes.entries) {
            if (entry.value == null) {
              next.remove(entry.key);
            } else {
              next[entry.key] = _freezeJson(entry.value);
            }
          }
          final snapshot = Map<String, Object?>.unmodifiable(next);
          final dictionaries = _parseDictionaries(snapshot);
          _setState(
            HachidoriClientState(
              linked: true,
              address: _state.address,
              ready: true,
              host: _state.host,
              snapshot: snapshot,
              dictionaries: dictionaries,
            ),
          );
          _libraryEvents.add(
            HachidoriLibraryEvent(
              kind: HachidoriLibraryEventKind.storage,
              changedKeys: Set<String>.unmodifiable(frame.changes.keys),
            ),
          );
        case _PingFrame():
          socket.send(jsonEncode({'kind': 'pong'}));
        case _ByeFrame():
          _closeWithError(
            socket,
            frame.reason.isEmpty
                ? 'The linked Hachidori refused the connection.'
                : frame.reason,
          );
        case _ReplyFrame():
          _handleReply(socket, generation, frame);
      }
    } on Object catch (error) {
      _closeWithError(socket, _describe(error));
    }
  }

  void _handleSocketError(
    HachidoriWebSocket socket,
    int generation,
    Object error,
  ) {
    if (_socket != socket || _generation != generation) return;
    _closeWithError(socket, _describe(error));
  }

  void _handleSocketDone(HachidoriWebSocket socket, int generation) {
    if (_socket != socket || _generation != generation) return;
    _disconnectSocket(
      socket,
      generation,
      'The linked Hachidori is not reachable.',
    );
  }

  void _disconnectSocket(
    HachidoriWebSocket socket,
    int generation,
    String error,
  ) {
    if (_socket != socket || _generation != generation) return;
    _socket = null;
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
    _rejectPendingAndWaiting(HachidoriConnectionException(error));
    _setState(
      HachidoriClientState(
        linked: _state.linked,
        address: _state.address,
        error: error,
        snapshot: _state.snapshot,
        dictionaries: _state.dictionaries,
      ),
    );
    _libraryEvents.add(
      const HachidoriLibraryEvent(kind: HachidoriLibraryEventKind.disconnected),
    );
    unawaited(socket.close());
    _scheduleReconnect(generation);
  }

  void _closeWithError(HachidoriWebSocket socket, String error) {
    if (_socket != socket) return;
    _disconnectSocket(socket, _generation, error);
  }

  Future<_TypedResponse> _request(
    String type, [
    Map<String, Object?> fields = const {},
  ]) async {
    if (_disposed) {
      throw const HachidoriConnectionException(
        'The linked Hachidori is not reachable.',
      );
    }
    final requestId = ++_nextRequestId;
    final requestGeneration = _generation;
    if (!_state.ready) {
      await _waitUntilReady(requestGeneration);
    }
    final socket = _socket;
    if (requestGeneration != _generation || !_state.ready || socket == null) {
      throw const HachidoriConnectionException(
        'The linked Hachidori is not reachable.',
      );
    }

    final completer = Completer<_TypedResponse>();
    _pending[requestId] = _PendingRequest(
      generation: requestGeneration,
      resultType: '${type}_result',
      completer: completer,
    );
    try {
      socket.send(
        jsonEncode({
          'kind': 'request',
          'id': requestId,
          'message': {
            'target': 'hoshidicts-offscreen',
            'type': type,
            'requestId': requestId,
            ...fields,
          },
        }),
      );
    } on Object catch (error, stackTrace) {
      _pending.remove(requestId);
      Error.throwWithStackTrace(
        HachidoriConnectionException(_describe(error)),
        stackTrace,
      );
    }
    return completer.future;
  }

  Future<void> _waitUntilReady(int generation) {
    if (_state.ready && generation == _generation) return Future.value();
    if (!_state.linked || generation != _generation) {
      return Future.error(
        const HachidoriConnectionException(
          'The linked Hachidori is not reachable.',
        ),
      );
    }
    final address = _state.address;
    if (address != null && _socket == null && !_connectInFlight) {
      _cancelReconnect();
      _setState(
        HachidoriClientState(
          linked: true,
          address: address,
          connecting: true,
          snapshot: _state.snapshot,
          dictionaries: _state.dictionaries,
        ),
      );
      unawaited(_connect(address, generation));
    }
    final completer = Completer<void>();
    late final _ReadyWaiter waiter;
    final timer = Timer(connectWait, () {
      if (_waiting.remove(waiter) && !completer.isCompleted) {
        completer.completeError(
          const HachidoriConnectionException(
            'The linked Hachidori is not reachable.',
          ),
        );
      }
    });
    waiter = _ReadyWaiter(
      generation: generation,
      completer: completer,
      timer: timer,
    );
    _waiting.add(waiter);
    return completer.future;
  }

  void _resolveWaiting(int generation) {
    for (final waiter in _waiting.toList()) {
      if (waiter.generation != generation) continue;
      _waiting.remove(waiter);
      waiter.timer.cancel();
      if (!waiter.completer.isCompleted) waiter.completer.complete();
    }
  }

  void _rejectWaiting(HachidoriException error) {
    for (final waiter in _waiting) {
      waiter.timer.cancel();
      if (!waiter.completer.isCompleted) {
        waiter.completer.completeError(error);
      }
    }
    _waiting.clear();
  }

  void _rejectPendingAndWaiting(HachidoriException error) {
    for (final request in _pending.values) {
      if (!request.completer.isCompleted) {
        request.completer.completeError(error);
      }
    }
    _pending.clear();
    _rejectWaiting(error);
  }

  void _handleReply(
    HachidoriWebSocket socket,
    int generation,
    _ReplyFrame frame,
  ) {
    final id = frame.id;
    if (id is! num || !id.isFinite || id != id.truncate()) return;
    final requestId = id.toInt();
    final request = _pending[requestId];
    if (request == null || request.generation != generation) return;
    _pending.remove(requestId);
    try {
      final payload = _stringMap(frame.response, 'malformed sharing response');
      if (payload['type'] != request.resultType ||
          payload['requestId'] != requestId ||
          payload['ok'] is! bool) {
        throw const HachidoriProtocolException('malformed sharing response');
      }
      final generationValue = _responseGeneration(payload['generation']);
      if (payload['ok'] != true) {
        throw HachidoriRemoteException(
          payload['error']?.toString() ?? 'The Hachidori request failed.',
          code: payload['errorCode'] is String
              ? payload['errorCode'] as String
              : null,
        );
      }
      request.completer.complete(
        _TypedResponse(
          payload: Map<String, Object?>.unmodifiable(payload),
          generation: generationValue,
        ),
      );
    } on HachidoriRemoteException catch (error, stackTrace) {
      request.completer.completeError(error, stackTrace);
    } on Object catch (error, stackTrace) {
      final protocolError = error is HachidoriProtocolException
          ? error
          : HachidoriProtocolException(_describe(error));
      request.completer.completeError(protocolError, stackTrace);
      _closeWithError(socket, protocolError.message);
    }
  }

  void _adoptDictionaryGeneration(int generation) {
    final current = _dictionaryGeneration;
    if (current == null || generation > current) {
      _dictionaryGeneration = generation;
    }
  }

  T _parseTypedResponse<T>(T Function() parse) {
    try {
      return parse();
    } on HachidoriProtocolException catch (error) {
      final socket = _socket;
      if (socket != null) _closeWithError(socket, error.message);
      rethrow;
    }
  }

  String _clientHello() => jsonEncode({
    'kind': 'hello',
    'protocol': hachidoriProtocolVersion,
    'version': _clientVersion,
    'name': _clientName,
    'capabilities': <String>[],
  });

  void _scheduleReconnect(int generation) {
    if (_disposed ||
        generation != _generation ||
        !_state.linked ||
        _reconnectHandle != null) {
      return;
    }
    const delays = <int>[500, 1000, 2000, 4000, 8000, 10000];
    final index = _reconnectAttempt < delays.length
        ? _reconnectAttempt
        : delays.length - 1;
    final milliseconds = delays[index];
    _reconnectAttempt++;
    _reconnectHandle = _reconnectScheduler(
      Duration(milliseconds: milliseconds),
      () {
        _reconnectHandle = null;
        if (_disposed || generation != _generation || !_state.linked) {
          return;
        }
        final address = _state.address;
        if (address == null) return;
        _setState(
          HachidoriClientState(
            linked: true,
            address: address,
            connecting: true,
            snapshot: _state.snapshot,
            dictionaries: _state.dictionaries,
          ),
        );
        unawaited(_connect(address, generation));
      },
    );
  }

  void _cancelReconnect() {
    _reconnectHandle?.cancel();
    _reconnectHandle = null;
  }

  void _setState(HachidoriClientState value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelReconnect();
    _generation++;
    _rejectPendingAndWaiting(
      const HachidoriConnectionException(
        'The linked Hachidori is not reachable.',
      ),
    );
    unawaited(_subscription?.cancel());
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close());
    unawaited(_libraryEvents.close());
    super.dispose();
  }
}

class _PendingRequest {
  const _PendingRequest({
    required this.generation,
    required this.resultType,
    required this.completer,
  });

  final int generation;
  final String resultType;
  final Completer<_TypedResponse> completer;
}

class _ReadyWaiter {
  const _ReadyWaiter({
    required this.generation,
    required this.completer,
    required this.timer,
  });

  final int generation;
  final Completer<void> completer;
  final Timer timer;
}

class _TypedResponse {
  const _TypedResponse({required this.payload, required this.generation});

  final Map<String, Object?> payload;
  final int generation;
}

sealed class _HostFrame {
  const _HostFrame();
}

class _HelloFrame extends _HostFrame {
  const _HelloFrame({required this.host, required this.snapshot});

  final HachidoriHostIdentity host;
  final Map<String, Object?> snapshot;
}

class _ReplyFrame extends _HostFrame {
  const _ReplyFrame({required this.id, required this.response});

  final Object id;
  final Object? response;
}

class _StorageFrame extends _HostFrame {
  const _StorageFrame(this.changes);

  final Map<String, Object?> changes;
}

class _PingFrame extends _HostFrame {
  const _PingFrame();
}

class _ByeFrame extends _HostFrame {
  const _ByeFrame(this.reason);

  final String reason;
}

_HostFrame _parseHostFrame(Object? message) {
  if (message is! String) {
    throw const FormatException('malformed sharing frame');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(message);
  } on FormatException {
    throw const FormatException('malformed sharing frame');
  }
  final frame = _stringMap(decoded, 'malformed sharing frame');
  switch (frame['kind']) {
    case 'hello':
      if (frame['protocol'] != hachidoriProtocolVersion) {
        throw FormatException(
          'unsupported sharing protocol ${jsonEncode(frame['protocol'])}',
        );
      }
      final snapshot = _stringMap(frame['snapshot'], 'malformed sharing hello');
      return _HelloFrame(
        host: HachidoriHostIdentity(
          version: frame['version']?.toString() ?? '',
          name: frame['name']?.toString() ?? '',
          dictionaryCount: _nonnegativeInt(frame['dictionaryCount']),
          capabilities: _parseCapabilities(frame['capabilities']),
        ),
        snapshot: snapshot,
      );
    case 'reply':
      final id = frame['id'];
      if (id is! String && id is! num) {
        throw const FormatException('malformed sharing reply');
      }
      return _ReplyFrame(id: id!, response: frame['response']);
    case 'storage':
      return _StorageFrame(
        _stringMap(frame['changes'], 'malformed sharing storage frame'),
      );
    case 'ping':
      return const _PingFrame();
    case 'bye':
      return _ByeFrame(frame['reason']?.toString() ?? '');
    default:
      throw FormatException(
        'unknown sharing frame ${jsonEncode(frame['kind'])}',
      );
  }
}

Map<String, Object?> _stringMap(Object? value, String message) {
  if (value is! Map || value is List) throw FormatException(message);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw FormatException(message);
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<String> _parseCapabilities(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.length > 32) {
    throw const FormatException('malformed sharing capabilities');
  }
  final capabilities = <String>[];
  for (final item in value) {
    if (item is! String || item.isEmpty || item.length > 100) {
      throw const FormatException('malformed sharing capabilities');
    }
    if (!capabilities.contains(item)) capabilities.add(item);
  }
  return List<String>.unmodifiable(capabilities);
}

int _nonnegativeInt(Object? value) {
  final number = value is num ? value.toInt() : 0;
  return number < 0 ? 0 : number;
}

int _responseGeneration(Object? value) {
  const maxSafeInteger = 9007199254740991;
  if (value is! num ||
      !value.isFinite ||
      value != value.truncate() ||
      value < 0 ||
      value > maxSafeInteger) {
    throw const HachidoriProtocolException('invalid dictionary generation');
  }
  return value.toInt();
}

int _responseCount(Object? value, String field) {
  if (value is! num ||
      !value.isFinite ||
      value != value.truncate() ||
      value < 0) {
    throw HachidoriProtocolException('invalid $field');
  }
  return value.toInt();
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in value.entries) entry.key: _freezeJson(entry.value),
    });

Object? _freezeJson(Object? value) {
  if (value is Map) {
    return _freezeMap(_stringMap(value, 'malformed sharing snapshot'));
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw const FormatException('malformed sharing snapshot');
}

List<HachidoriDictionaryInfo> _parseDictionaries(
  Map<String, Object?> snapshot,
) {
  final rawState = snapshot['dictionaryState'];
  if (rawState == null) return const [];
  final state = _stringMap(rawState, 'malformed dictionary state');
  if (state['schemaVersion'] != 1) {
    throw FormatException(
      'unsupported dictionary state schema ${state['schemaVersion']}',
    );
  }
  final rows = state['dictionaries'];
  if (rows is! List) throw const FormatException('malformed dictionary state');
  final dictionaries = <HachidoriDictionaryInfo>[];
  for (final raw in rows) {
    final row = _stringMap(raw, 'malformed shared dictionary');
    final title = row['title'];
    if (title is! String || title.isEmpty) {
      throw const FormatException('malformed shared dictionary');
    }
    final displayName = row['displayName'];
    if (displayName != null && displayName is! String) {
      throw const FormatException('malformed shared dictionary');
    }
    dictionaries.add(
      HachidoriDictionaryInfo(
        id: row['id'] is String ? row['id'] as String : '',
        title: title,
        displayName: displayName is String && displayName.trim().isNotEmpty
            ? displayName.trim()
            : null,
        enabled: row['enabled'] != false,
        favorite: row['favorite'] == true,
        revision: row['revision'] is String ? row['revision'] as String : '',
        termCount: _nonnegativeInt(row['termCount']),
        frequencyCount: _nonnegativeInt(row['frequencyCount']),
        pitchCount: _nonnegativeInt(row['pitchCount']),
        kanjiCount: _nonnegativeInt(row['kanjiCount']),
        mediaCount: _nonnegativeInt(row['mediaCount']),
      ),
    );
  }
  return List<HachidoriDictionaryInfo>.unmodifiable(dictionaries);
}

String _describe(Object error) =>
    error is FormatException ? error.message : error.toString();

Future<HachidoriWebSocket> _connectIoWebSocket(
  Uri address, {
  required String origin,
}) async {
  return _IoHachidoriWebSocket(
    IOWebSocketChannel.connect(
      address,
      headers: {'Origin': origin},
      connectTimeout: const Duration(seconds: 5),
    ),
  );
}

HachidoriReconnectHandle _scheduleReconnectTimer(
  Duration delay,
  void Function() callback,
) => _TimerReconnectHandle(Timer(delay, callback));

class _TimerReconnectHandle implements HachidoriReconnectHandle {
  const _TimerReconnectHandle(this.timer);

  final Timer timer;

  @override
  void cancel() => timer.cancel();
}

class _IoHachidoriWebSocket implements HachidoriWebSocket {
  _IoHachidoriWebSocket(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  Future<void> close([int? code, String? reason]) =>
      _channel.sink.close(code, reason);
}
