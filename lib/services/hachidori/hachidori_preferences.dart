import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

@immutable
class HachidoriLinkConfiguration {
  const HachidoriLinkConfiguration({
    required this.enabled,
    required this.address,
  });

  const HachidoriLinkConfiguration.disabled() : enabled = false, address = '';

  final bool enabled;
  final String address;

  HachidoriLinkConfiguration copyWith({bool? enabled, String? address}) =>
      HachidoriLinkConfiguration(
        enabled: enabled ?? this.enabled,
        address: address ?? this.address,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HachidoriLinkConfiguration &&
          enabled == other.enabled &&
          address == other.address;

  @override
  int get hashCode => Object.hash(enabled, address);
}

abstract interface class HachidoriConfigurationStore {
  Future<HachidoriLinkConfiguration> read();

  Future<void> write(HachidoriLinkConfiguration configuration);
}

class HachidoriPreferences implements HachidoriConfigurationStore {
  static const boxName = 'hachidori_preferences';
  static const _enabledKey = 'enabled';
  static const _addressKey = 'address';
  static const _persistedKeys = {_enabledKey, _addressKey};

  @override
  Future<HachidoriLinkConfiguration> read() async {
    try {
      final box = await _box();
      final address = box.get(_addressKey);
      return HachidoriLinkConfiguration(
        enabled: box.get(_enabledKey) == true,
        address: address is String ? address.trim() : '',
      );
    } on HiveError {
      return const HachidoriLinkConfiguration.disabled();
    }
  }

  @override
  Future<void> write(HachidoriLinkConfiguration configuration) async {
    final box = await _box();
    await box.putAll({
      _enabledKey: configuration.enabled,
      _addressKey: configuration.address.trim(),
    });
    final staleKeys = box.keys
        .where((key) => !_persistedKeys.contains(key))
        .toList(growable: false);
    if (staleKeys.isNotEmpty) await box.deleteAll(staleKeys);
  }

  Future<Box<dynamic>> _box() => Hive.openBox<dynamic>(boxName);
}
