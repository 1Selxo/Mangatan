/// Process-local token for the Drive configuration that launched an OAuth flow.
class GoogleDriveConnectionIntentToken {
  const GoogleDriveConnectionIntentToken({
    required this.syncId,
    required this.generation,
  });

  final int syncId;
  final int generation;
}

/// Detects configuration ABA while a Google Drive OAuth flow is in progress.
class GoogleDriveConnectionIntentGeneration {
  GoogleDriveConnectionIntentGeneration(this.syncId);

  final int syncId;
  int _generation = 0;

  GoogleDriveConnectionIntentToken capture() =>
      GoogleDriveConnectionIntentToken(syncId: syncId, generation: _generation);

  void recordConfigurationChange() => _generation++;

  bool isCurrent(GoogleDriveConnectionIntentToken token) =>
      token.syncId == syncId && token.generation == _generation;

  void requireCurrent(GoogleDriveConnectionIntentToken token) {
    if (!isCurrent(token)) {
      throw const GoogleDriveConnectionIntentChangedException();
    }
  }
}

class GoogleDriveConnectionIntentChangedException implements Exception {
  const GoogleDriveConnectionIntentChangedException();

  @override
  String toString() =>
      'Google Drive connection settings changed during authorization.';
}
