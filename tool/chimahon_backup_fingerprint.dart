import 'dart:convert';
import 'dart:io';

import 'package:mangayomi/services/sync/chimahon_backup_fingerprint.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/chimahon_backup_fingerprint.dart BACKUP [...]',
    );
    return;
  }

  final reports = <Map<String, Object?>>[];
  for (var index = 0; index < arguments.length; index++) {
    final file = File(arguments[index]);
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size <= 0) {
      throw FormatException('Backup ${index + 1} is not a non-empty file.');
    }
    final fingerprint = ChimahonBackupFingerprint.fromBytes(
      await file.readAsBytes(),
    );
    reports.add({'input': index + 1, ...fingerprint.toSafeJson()});
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(reports));
}
