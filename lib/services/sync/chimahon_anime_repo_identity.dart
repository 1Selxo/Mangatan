import 'package:mangayomi/modules/more/data_and_storage/providers/proto/BackupExtensionRepos.pb.dart';

/// Chimahon treats a signing-key fingerprint as unique across anime repository
/// URLs. Using the same identity during merge lets a migrated URL replace its
/// predecessor instead of restoring both and triggering a fingerprint clash.
String chimahonAnimeRepositoryIdentity(BackupExtensionRepos repository) {
  final fingerprint = repository.signingKeyFingerprint.trim().toLowerCase();
  if (fingerprint.isNotEmpty) return 'fingerprint:$fingerprint';

  final baseUrl = repository.baseUrl
      .trim()
      .replaceFirst(RegExp(r'/+$'), '')
      .toLowerCase();
  return 'url:$baseUrl';
}
