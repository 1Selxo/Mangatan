// Prepares a data folder for tool/perf/real_app_driver.dart: a copy of a real
// database (never the original) with the Mihon bridge pointed at a chosen JRE
// and server JAR.
//
//   MANGATAN_PROFILE_DB=<folder with a copy of mangayomiDb.isar>
//   MANGATAN_PROFILE_ROOT=<new data folder>
//   MANGATAN_PROFILE_JRE=<java.exe>  MANGATAN_PROFILE_JAR=<server jar>
//     flutter test test/profile/prepare_real_root_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/providers/storage_provider.dart';

import '../journeys/harness/journey.dart' show ensureIsar;

final _env = Platform.environment;

void main() {
  test('prepare a real-data folder', () async {
    await ensureIsar();
    final databases = Directory(
      '${_env['MANGATAN_PROFILE_ROOT']}/documents/Mangatan/databases',
    )..createSync(recursive: true);
    File('${_env['MANGATAN_PROFILE_DB']}/mangayomiDb.isar')
        .copySync('${databases.path}/mangayomiDb.isar');
    final db = await Isar.open(
      appIsarSchemas,
      directory: databases.path,
      name: 'mangayomiDb',
    );
    final settings = (await db.settings.get(227))!;
    await db.writeTxn(
      () => db.settings.put(
        settings
          ..jrePath = _env['MANGATAN_PROFILE_JRE']
          ..extensionServerPath = _env['MANGATAN_PROFILE_JAR']
          ..androidProxyServer = 'http://127.0.0.1:1'
          ..enableLogs = true,
      ),
    );
    await db.close();
  }, skip: _env['MANGATAN_PROFILE_ROOT'] == null);
}
