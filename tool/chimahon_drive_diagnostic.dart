import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

const _maxResponseBytes = 4 * 1024 * 1024;
const _maxReferenceBytes = 250 << 20;
const _referencePathSegment = 'reference';

Future<void> main(List<String> arguments) async {
  try {
    final options = ChimahonDriveDiagnosticOptions.parse(arguments);
    if (options.showHelp) {
      stdout.writeln(_usage);
      return;
    }
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      throw StateError(
        'The app-owned diagnostic is supported on macOS, Windows, and Linux.',
      );
    }
    final referenceFile = await _validatedReferenceFile(options);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final nonce = _randomHex(32);
    final callback = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      pathSegments: [options.operation.callbackPathPrefix, nonce],
    );
    final referenceRequestPath = callback
        .replace(
          pathSegments: [...callback.pathSegments, _referencePathSegment],
        )
        .path;
    final deepLink = options.buildDeepLink(callback);
    final response = Completer<String>();
    late final StreamSubscription<HttpRequest> subscription;
    subscription = server.listen((request) async {
      if (request.method == 'GET' &&
          referenceFile != null &&
          request.requestedUri.path == referenceRequestPath) {
        await _serveReferenceBackup(request, referenceFile);
        return;
      }
      if (request.method != 'POST' ||
          request.requestedUri.path != callback.path) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      if (response.isCompleted) {
        request.response.statusCode = HttpStatus.conflict;
        await request.response.close();
        return;
      }
      try {
        final body = await _readLimitedUtf8(request, _maxResponseBytes);
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        response.complete(body);
      } catch (error, stackTrace) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        await request.response.close();
        response.completeError(error, stackTrace);
      }
    });

    try {
      if (options.operation ==
          ChimahonDriveDiagnosticOperation.conditionalWriteProbe) {
        stderr.writeln(
          'Running the explicitly authorized probe against one new disposable '
          'Drive app-data file. Mangatan will attempt guarded cleanup.',
        );
      } else if (options.operation ==
          ChimahonDriveDiagnosticOperation.syncPreview) {
        stderr.writeln(
          'Running a read-only Chimahon merge preview. No local, sidecar, or '
          'Drive write is available to this operation.',
        );
      }
      await _openDiagnosticLink(deepLink, appPath: options.appPath);
      final raw = await response.future.timeout(options.timeout);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Mangatan returned an invalid response.');
      }
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(decoded));
      if (decoded['ok'] != true) {
        exitCode = 2;
      }
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  } on TimeoutException {
    stderr.writeln(
      'Timed out waiting for the running Mangatan debug app. Rebuild it after '
      'adding the diagnostic bridge, then try again.',
    );
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<File?> _validatedReferenceFile(
  ChimahonDriveDiagnosticOptions options,
) async {
  final path = options.referencePath;
  if (path == null) return null;
  final file = File(path);
  final stat = await file.stat();
  if (stat.type != FileSystemEntityType.file) {
    throw const FormatException('The reference backup is not a regular file.');
  }
  if (stat.size <= 0) {
    throw const FormatException('The reference backup is empty.');
  }
  if (stat.size > _maxReferenceBytes) {
    throw const FormatException('The reference backup is too large.');
  }
  return file;
}

Future<void> _serveReferenceBackup(HttpRequest request, File file) async {
  try {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size <= 0 ||
        stat.size > _maxReferenceBytes) {
      request.response.statusCode = HttpStatus.unprocessableEntity;
      await request.response.close();
      return;
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..contentLength = stat.size
      ..headers.contentType = ContentType.binary
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set('X-Content-Type-Options', 'nosniff');
    await request.response.addStream(file.openRead());
    await request.response.close();
  } catch (_) {
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    } catch (_) {}
  }
}

Future<void> _openDiagnosticLink(Uri link, {String? appPath}) async {
  late final ProcessResult result;
  if (Platform.isMacOS) {
    result = await Process.run('/usr/bin/open', [
      if (appPath != null) ...['-a', appPath],
      link.toString(),
    ], runInShell: false);
  } else if (Platform.isWindows) {
    result = await Process.run('explorer.exe', [
      link.toString(),
    ], runInShell: false);
  } else {
    if (appPath != null) {
      final executable = File(appPath);
      final type = FileSystemEntity.typeSync(appPath, followLinks: true);
      final isExecutable =
          type == FileSystemEntityType.file &&
          executable.statSync().mode & 0x49 != 0;
      if (!p.isAbsolute(appPath) || !isExecutable) {
        throw const FormatException(
          'On Linux, --app must be an absolute path to an executable file '
          'with an execute permission bit.',
        );
      }
      await Process.start(
        executable.path,
        [link.toString()],
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
      // Waiting for a cold-started GUI app to exit would deadlock before this
      // diagnostic can receive its callback.
      return;
    } else {
      result = await Process.run('xdg-open', [
        link.toString(),
      ], runInShell: false);
    }
  }
  if (result.exitCode != 0) {
    throw StateError('Could not send the diagnostic request to Mangatan.');
  }
}

Future<String> _readLimitedUtf8(HttpRequest request, int maximumBytes) async {
  if (request.contentLength > maximumBytes) {
    throw const FormatException('Mangatan returned an oversized response.');
  }
  final bytes = <int>[];
  await for (final chunk in request) {
    bytes.addAll(chunk);
    if (bytes.length > maximumBytes) {
      throw const FormatException('Mangatan returned an oversized response.');
    }
  }
  return utf8.decode(bytes);
}

String _randomHex(int byteCount) {
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var index = 0; index < byteCount; index++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

enum ChimahonDriveDiagnosticOperation {
  inspect(
    argumentValue: 'inspect',
    deepLinkHost: 'chimahon-drive-diagnostic',
    callbackPathPrefix: 'chimahon-drive-diagnostic',
  ),
  conditionalWriteProbe(
    argumentValue: 'conditional-write-probe',
    deepLinkHost: 'chimahon-drive-conditional-write-probe',
    callbackPathPrefix: 'chimahon-drive-conditional-write-probe',
  ),
  syncPreview(
    argumentValue: 'sync-preview',
    deepLinkHost: 'chimahon-drive-sync-preview',
    callbackPathPrefix: 'chimahon-drive-sync-preview',
  );

  const ChimahonDriveDiagnosticOperation({
    required this.argumentValue,
    required this.deepLinkHost,
    required this.callbackPathPrefix,
  });

  final String argumentValue;
  final String deepLinkHost;
  final String callbackPathPrefix;
}

class ChimahonDriveDiagnosticOptions {
  const ChimahonDriveDiagnosticOptions({
    required this.appPath,
    required this.timeout,
    required this.showHelp,
    required this.operation,
    required this.allowDisposableDriveWrites,
    required this.referencePath,
  });

  factory ChimahonDriveDiagnosticOptions.parse(List<String> arguments) {
    String? appPath;
    var timeout = const Duration(seconds: 120);
    var showHelp = false;
    var operation = ChimahonDriveDiagnosticOperation.inspect;
    var operationSeen = false;
    var allowDisposableDriveWrites = false;
    String? referencePath;
    for (final argument in arguments) {
      if (argument == '--help' || argument == '-h') {
        showHelp = true;
      } else if (argument.startsWith('--operation=')) {
        if (operationSeen) {
          throw const FormatException('--operation may only be supplied once.');
        }
        operationSeen = true;
        final value = argument.substring('--operation='.length);
        operation = ChimahonDriveDiagnosticOperation.values.firstWhere(
          (candidate) => candidate.argumentValue == value,
          orElse: () =>
              throw FormatException('Unknown diagnostic operation: $value'),
        );
      } else if (argument == '--allow-disposable-drive-writes') {
        if (allowDisposableDriveWrites) {
          throw const FormatException(
            '--allow-disposable-drive-writes may only be supplied once.',
          );
        }
        allowDisposableDriveWrites = true;
      } else if (argument.startsWith('--reference=')) {
        if (referencePath != null) {
          throw const FormatException('--reference may only be supplied once.');
        }
        referencePath = argument.substring('--reference='.length).trim();
        if (referencePath.isEmpty) {
          throw const FormatException('--reference cannot be blank.');
        }
      } else if (argument.startsWith('--app=')) {
        appPath = argument.substring('--app='.length).trim();
        if (appPath.isEmpty) {
          throw const FormatException('--app cannot be blank.');
        }
      } else if (argument.startsWith('--timeout-seconds=')) {
        final seconds = int.tryParse(
          argument.substring('--timeout-seconds='.length),
        );
        if (seconds == null || seconds <= 0 || seconds > 600) {
          throw const FormatException(
            '--timeout-seconds must be between 1 and 600.',
          );
        }
        timeout = Duration(seconds: seconds);
      } else {
        throw FormatException('Unknown argument: $argument');
      }
    }
    if (!showHelp) {
      if (operation == ChimahonDriveDiagnosticOperation.conditionalWriteProbe &&
          !allowDisposableDriveWrites) {
        throw const FormatException(
          'The conditional-write probe requires both '
          '--operation=conditional-write-probe and '
          '--allow-disposable-drive-writes.',
        );
      }
      if (operation == ChimahonDriveDiagnosticOperation.inspect &&
          allowDisposableDriveWrites) {
        throw const FormatException(
          '--allow-disposable-drive-writes is only valid with '
          '--operation=conditional-write-probe.',
        );
      }
      if (operation == ChimahonDriveDiagnosticOperation.syncPreview &&
          referencePath == null) {
        throw const FormatException(
          'The sync preview requires --reference=/path/to/backup.tachibk.',
        );
      }
      if (operation != ChimahonDriveDiagnosticOperation.syncPreview &&
          referencePath != null) {
        throw const FormatException(
          '--reference is only valid with --operation=sync-preview.',
        );
      }
    }
    return ChimahonDriveDiagnosticOptions(
      appPath: appPath,
      timeout: timeout,
      showHelp: showHelp,
      operation: operation,
      allowDisposableDriveWrites: allowDisposableDriveWrites,
      referencePath: referencePath,
    );
  }

  final String? appPath;
  final Duration timeout;
  final bool showHelp;
  final ChimahonDriveDiagnosticOperation operation;
  final bool allowDisposableDriveWrites;
  final String? referencePath;

  Uri buildDeepLink(Uri callback) => Uri(
    scheme: 'mangayomi',
    host: operation.deepLinkHost,
    queryParameters: {
      'callback': callback.toString(),
      if (operation == ChimahonDriveDiagnosticOperation.conditionalWriteProbe)
        'allow-disposable-drive-writes': 'true',
      if (operation == ChimahonDriveDiagnosticOperation.syncPreview)
        'reference-transport': 'loopback',
    },
  );
}

const _usage = '''
Run a Chimahon Drive diagnostic through the running Mangatan debug app.

The default `inspect` operation is GET-only. The conditional-write probe
creates and mutates one uniquely named disposable app-data file, tests stale
write rejection, and attempts guarded cleanup. It never targets the canonical
Chimahon sync file.

Usage:
  dart run tool/chimahon_drive_diagnostic.dart [options]

Options:
  --operation=inspect          Run the default GET-only inspection.
  --operation=conditional-write-probe
                               Run the disposable conditional-write probe.
  --operation=sync-preview     Run a read-only local/Drive merge preview.
  --allow-disposable-drive-writes
                               Required with conditional-write-probe.
  --reference=/path/to/backup.tachibk
                               Required with sync-preview; served only over a
                               nonce-bound IPv4 loopback request.
  --app=/path/to/Mangatan      Target a macOS app bundle or Linux executable.
  --timeout-seconds=120        Wait up to this many seconds (maximum 600).
  -h, --help                   Show this help.
''';
