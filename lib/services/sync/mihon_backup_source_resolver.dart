import 'package:mangayomi/eval/mihon/bridge_protocol.dart';
import 'package:mangayomi/models/source.dart';
import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupSource.pb.dart';

class ResolvedMihonBackupSource {
  const ResolvedMihonBackupSource({
    required this.nativeId,
    required this.name,
    required this.language,
    required this.localId,
    required this.installed,
  });

  final int nativeId;
  final String name;
  final String language;
  final int? localId;
  final bool installed;
}

ResolvedMihonBackupSource resolveMihonBackupSource({
  required int nativeId,
  required Iterable<BackupSource> backupSources,
  required Iterable<Source> localSources,
}) {
  final backupName = backupSources
      .where((source) => source.sourceId.toInt() == nativeId)
      .map((source) => source.name)
      .firstOrNull;

  final installed = localSources.where((source) {
    if (!(source.isAdded ?? false) || (source.sourceCode?.isEmpty ?? true)) {
      return false;
    }
    final metadata = mihonSourceMetadata(source);
    return metadata?.sourceId == nativeId.toString() ||
        (metadata == null && source.id == nativeId);
  }).firstOrNull;

  return ResolvedMihonBackupSource(
    nativeId: nativeId,
    name: installed?.name ?? backupName ?? 'Unknown',
    language: installed?.lang ?? 'en',
    localId: installed?.id,
    installed: installed != null,
  );
}

/// Current Mihon backups store milliseconds. Very old Tachiyomi-derived
/// backups occasionally stored seconds, which can be detected safely by size.
int normalizeMihonTimestamp(int value) {
  if (value <= 0) return value;
  return value < 100000000000 ? value * 1000 : value;
}
