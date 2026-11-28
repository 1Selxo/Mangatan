import 'dart:convert';
import 'dart:io';

import 'package:mangayomi/models/source.dart';
import 'package:path/path.dart' as p;

/// What the launch refresh of Mihon factory sources found last time, per
/// extension, so a launch can skip the extensions nothing has changed for.
///
/// The refresh asks the bridge for every installed source's preferences and
/// sources on each launch, which uploads every APK and loads every
/// extension: most of the bridge's startup work, for the same answers as
/// last time. An extension is skipped when its APK, its sources and their
/// stored preferences and the bridge are as they were after a successful
/// refresh less than a day ago. Every request to the bridge carries the
/// source's preferences anyway, so nothing depends on the refresh pushing
/// them. Kept in a file beside the database: no schema change.
class MihonLaunchRefreshMemory {
  MihonLaunchRefreshMemory._(this._file, this._entries, this._now);

  static const fileName = '.mihon-launch-refresh-v1.json';
  static const maxAge = Duration(days: 1);

  final File? _file;
  final Map<String, ({String fingerprint, int at})> _entries;
  final DateTime Function() _now;

  /// Reads the memory from [directory]; empty when there is none or it
  /// cannot be read.
  static Future<MihonLaunchRefreshMemory> load(
    Directory? directory, {
    DateTime Function() now = DateTime.now,
  }) async {
    final file = directory == null
        ? null
        : File(p.join(directory.path, fileName));
    final entries = <String, ({String fingerprint, int at})>{};
    try {
      if (file != null && await file.exists()) {
        final json = jsonDecode(await file.readAsString());
        if (json is Map) {
          for (final MapEntry(:key, :value) in json.entries) {
            if (value is Map &&
                value['fingerprint'] is String &&
                value['at'] is int) {
              entries['$key'] = (
                fingerprint: value['fingerprint'] as String,
                at: value['at'] as int,
              );
            }
          }
        }
      }
    } catch (_) {
      // An unreadable memory only means refreshing everything once.
    }
    return MihonLaunchRefreshMemory._(file, entries, now);
  }

  /// Whether [group] (one extension's sources) is as the last successful
  /// refresh left it, under [bridge], less than [maxAge] ago.
  bool isUnchanged(String key, List<Source> group, String bridge) {
    final entry = _entries[key];
    if (entry == null) return false;
    final age = _now().millisecondsSinceEpoch - entry.at;
    return age >= 0 &&
        age < maxAge.inMilliseconds &&
        entry.fingerprint == fingerprint(group, bridge);
  }

  /// Notes that [group] was refreshed successfully just now.
  void remember(String key, List<Source> group, String bridge) {
    _entries[key] = (
      fingerprint: fingerprint(group, bridge),
      at: _now().millisecondsSinceEpoch,
    );
  }

  /// Forgets [key], after a refresh of it failed.
  void forget(String key) => _entries.remove(key);

  Future<void> save() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(
        jsonEncode({
          for (final MapEntry(:key, :value) in _entries.entries)
            key: {'fingerprint': value.fingerprint, 'at': value.at},
        }),
        flush: true,
      );
    } catch (_) {
      // Not remembering only costs a full refresh next launch.
    }
  }

  /// What the refresh's answers depend on: the APK, which sources there are
  /// and their stored preferences, and the bridge. Hashed with FNV-1a, which
  /// unlike String.hashCode is the same in every run.
  static String fingerprint(List<Source> group, String bridge) {
    final sorted = [...group]..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    var hash = _fnv(bridge);
    for (final source in sorted) {
      final code = source.sourceCode ?? '';
      hash = _fnv(
        '${source.id}|${source.version}|${source.sourceCodeUrl}|'
        '${code.length}',
        hash,
      );
      hash = _fnvSampled(code, hash);
      hash = _fnv(source.preferenceList ?? '', hash);
    }
    return '${sorted.length}:${hash.toRadixString(16)}';
  }

  static const _offset = 0x811c9dc5;

  static int _fnv(String text, [int hash = _offset]) {
    for (var i = 0; i < text.length; i++) {
      hash = ((hash ^ text.codeUnitAt(i)) * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  /// Every 61st character and the last 4 KB: an APK that changed also has
  /// another version or address, which are hashed in full.
  static int _fnvSampled(String code, int hash) {
    for (var i = 0; i < code.length; i += 61) {
      hash = ((hash ^ code.codeUnitAt(i)) * 0x01000193) & 0xffffffff;
    }
    final tail = code.length > 4096 ? code.length - 4096 : 0;
    return _fnv(code.substring(tail), hash);
  }
}
