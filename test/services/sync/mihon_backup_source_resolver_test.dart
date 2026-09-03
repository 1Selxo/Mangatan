import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';
import 'package:mangayomi/services/sync/mihon_backup_source_resolver.dart';

void main() {
  test('binds a backup source to the installed Mihon factory source', () {
    final installed = Source(
      id: 99,
      name: 'Installed name',
      lang: 'ja',
      isAdded: true,
      isActive: false,
      sourceCode: 'apk-bytes',
      additionalParams: encodeMihonSourceMetadata(
        sourceId: 123456789,
        packageName: 'pkg.source',
      ),
    )..sourceCodeLanguage = SourceCodeLanguage.mihon;

    final resolved = resolveMihonBackupSource(
      nativeId: 123456789,
      backupSources: [
        BackupSource(name: 'Backup name', sourceId: Int64(123456789)),
      ],
      localSources: [installed],
    );

    expect(resolved.installed, isTrue);
    expect(resolved.localId, 99);
    expect(resolved.name, 'Installed name');
    expect(resolved.language, 'ja');
  });

  test('keeps metadata when the source is not installed yet', () {
    final resolved = resolveMihonBackupSource(
      nativeId: 7,
      backupSources: [BackupSource(name: 'Remote', sourceId: Int64(7))],
      localSources: const [],
    );

    expect(resolved.installed, isFalse);
    expect(resolved.localId, isNull);
    expect(resolved.name, 'Remote');
  });

  test('normalizes current milliseconds and legacy seconds', () {
    expect(normalizeMihonTimestamp(1700000000000), 1700000000000);
    expect(normalizeMihonTimestamp(1700000000), 1700000000000);
  });
}
