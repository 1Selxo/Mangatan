/// A copy of a real database, for scenarios that should see what the user's
/// app sees. Point MANGATAN_PROFILE_DB at a folder holding a COPY of
/// mangayomiDb.isar; every scenario works on a further copy of it.
library;

import 'dart:io';

import 'package:isar_community/isar.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/providers/storage_provider.dart';

import '../journeys/harness/journey.dart' show ensureIsar;

final realDatabaseDir = Platform.environment['MANGATAN_PROFILE_DB'];

/// Opens a private copy of the real database, with the settings made safe for
/// a headless run: none of the user's bridge paths, no logging.
Future<Isar> openRealDatabaseCopy(Directory into) async {
  await ensureIsar();
  into.createSync(recursive: true);
  File('$realDatabaseDir/mangayomiDb.isar')
      .copySync('${into.path}/mangayomiDb.isar');
  final db = await Isar.open(
    appIsarSchemas,
    directory: into.path,
    name: 'mangayomiDb',
  );
  final settings = (await db.settings.get(227))!;
  await db.writeTxn(
    () => db.settings.put(
      settings
        ..onboardingCompleted = true
        ..followSystemTheme = false
        ..enableLogs = false
        ..jrePath = ''
        ..extensionServerPath = ''
        ..androidProxyServer = 'http://127.0.0.1:1',
    ),
  );
  return db;
}
