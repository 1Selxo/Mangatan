import 'package:mangayomi/services/mining/anki_markers.dart';

/// A Chimahon-compatible language profile. Dictionary order, enabled state,
/// lookup language, and Anki mining configuration move together when profiles
/// are switched.
class DictionaryProfile {
  const DictionaryProfile({
    required this.id,
    required this.name,
    this.languageCode = 'ja',
    this.anki = const AnkiMiningProfile(),
    this.dictionaryOrder = const [],
    this.enabledDictionaries = const {},
    this.dictionaryCollapseMode = 'expand_all',
    this.dictionaryDisplayModes = const {},
    this.duplicateAction = 'prevent',
    this.cropMode = 'full',
  });

  factory DictionaryProfile.fromJson(Map<dynamic, dynamic> json) {
    return DictionaryProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Default',
      // Chimahon deliberately permits an empty language (not eligible for
      // automatic matching) and future BCP-47 codes unknown to this build.
      languageCode: json['languageCode']?.toString() ?? '',
      anki: AnkiMiningProfile.fromJson(
        json['anki'] is Map ? json['anki'] as Map : null,
      ),
      dictionaryOrder: _stringList(json['dictionaryOrder']),
      enabledDictionaries: _stringList(json['enabledDictionaries']).toSet(),
      dictionaryCollapseMode:
          json['dictionaryCollapseMode']?.toString() ?? 'expand_all',
      dictionaryDisplayModes: _stringMap(json['dictionaryDisplayModes']),
      duplicateAction: json['duplicateAction']?.toString() ?? 'prevent',
      cropMode: json['cropMode']?.toString() ?? 'full',
    );
  }

  final String id;
  final String name;
  final String languageCode;
  final AnkiMiningProfile anki;
  final List<String> dictionaryOrder;

  /// Empty means every installed dictionary is enabled, matching Chimahon.
  final Set<String> enabledDictionaries;
  final String dictionaryCollapseMode;
  final Map<String, String> dictionaryDisplayModes;
  final String duplicateAction;
  final String cropMode;

  bool isDictionaryEnabled(String name) =>
      enabledDictionaries.isEmpty || enabledDictionaries.contains(name);

  /// Applies Chimahon's profile update when a dictionary is imported.
  DictionaryProfile withInstalledDictionary(String name) {
    if (name.isEmpty || dictionaryOrder.contains(name)) return this;
    return copyWith(
      dictionaryOrder: [...dictionaryOrder, name],
      enabledDictionaries: enabledDictionaries.isEmpty
          ? enabledDictionaries
          : {...enabledDictionaries, name},
    );
  }

  /// Removes every profile reference to a deleted dictionary. This prevents
  /// stale enable/collapse state from returning if the title is reinstalled.
  DictionaryProfile withoutDictionary(String name) => copyWith(
    dictionaryOrder: dictionaryOrder
        .where((dictionary) => dictionary != name)
        .toList(growable: false),
    enabledDictionaries: {...enabledDictionaries}..remove(name),
    dictionaryDisplayModes: {...dictionaryDisplayModes}..remove(name),
  );

  DictionaryProfile copyWith({
    String? id,
    String? name,
    String? languageCode,
    AnkiMiningProfile? anki,
    List<String>? dictionaryOrder,
    Set<String>? enabledDictionaries,
    String? dictionaryCollapseMode,
    Map<String, String>? dictionaryDisplayModes,
    String? duplicateAction,
    String? cropMode,
  }) {
    return DictionaryProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      languageCode: languageCode ?? this.languageCode,
      anki: anki ?? this.anki,
      dictionaryOrder: dictionaryOrder ?? this.dictionaryOrder,
      enabledDictionaries: enabledDictionaries ?? this.enabledDictionaries,
      dictionaryCollapseMode:
          dictionaryCollapseMode ?? this.dictionaryCollapseMode,
      dictionaryDisplayModes:
          dictionaryDisplayModes ?? this.dictionaryDisplayModes,
      duplicateAction: duplicateAction ?? this.duplicateAction,
      cropMode: cropMode ?? this.cropMode,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'languageCode': languageCode,
    'anki': anki.toJson(),
    'dictionaryOrder': dictionaryOrder,
    'enabledDictionaries': enabledDictionaries.toList(),
    'dictionaryCollapseMode': dictionaryCollapseMode,
    'dictionaryDisplayModes': dictionaryDisplayModes,
    'duplicateAction': duplicateAction,
    'cropMode': cropMode,
  };

  static List<String> _stringList(Object? value) => value is Iterable
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  static Map<String, String> _stringMap(Object? value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item.toString()))
      : const {};
}
