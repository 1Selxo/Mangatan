/// Matching of dictionary names stored in profiles against the dictionaries
/// installed on this device.
///
/// Profiles refer to dictionaries by name, but those names are not stable:
/// many Yomitan titles embed their revision date (`JMdict [2026-11-06]`), an
/// update on another device produces the new date, and synced profiles carry
/// that device's names. Exact matches always win; a name with no exact match
/// falls back to the same title without its dated bracket.
library;

final _datedBracket = RegExp(r'\s*\[[^\[\]]*\d[^\[\]]*\]');
final _whitespace = RegExp(r'\s+');

/// The revision-independent identity of a dictionary title.
String dictionaryIdentityKey(String name) => name
    .replaceAll(_datedBracket, ' ')
    .replaceAll(_whitespace, ' ')
    .trim()
    .toLowerCase();

/// Returns the installed names referred to by [names].
///
/// A name that is installed matches only itself. Any other name matches every
/// installed dictionary with the same [dictionaryIdentityKey], unless one of
/// [names] already matched a dictionary with that identity exactly; this
/// keeps a stale `JMdict` entry from re-enabling a second JMdict revision the
/// user deliberately left off.
Set<String> matchInstalledDictionaryNames(
  Iterable<String> names,
  Iterable<String> installed,
) {
  final installedNames = installed.toSet();
  final requested = names.toSet();
  final matched = requested.where(installedNames.contains).toSet();
  final exactKeys = matched.map(dictionaryIdentityKey).toSet();
  final fuzzyKeys = {
    for (final name in requested)
      if (!installedNames.contains(name)) dictionaryIdentityKey(name),
  }..removeAll(exactKeys);
  if (fuzzyKeys.isEmpty) return matched;
  return {
    ...matched,
    for (final name in installedNames)
      if (fuzzyKeys.contains(dictionaryIdentityKey(name))) name,
  };
}

/// Resolves a profile's enabled set to the installed dictionaries it enables.
///
/// An empty set means every dictionary is enabled. A set that matches no
/// installed dictionary is stale (it came from another device or predates an
/// update), and is treated the same way: the settings screen cannot save a
/// state with every dictionary disabled, so "nothing matches" never reflects
/// a user choice and must not silently turn every lookup off.
Set<String> resolveEnabledDictionaryNames(
  Set<String> enabled,
  Iterable<String> installed,
) {
  final installedNames = installed.toSet();
  if (enabled.isEmpty) return installedNames;
  final matched = matchInstalledDictionaryNames(enabled, installedNames);
  return matched.isEmpty ? installedNames : matched;
}

/// Rewrites [order] so names that are not installed but match an installed
/// dictionary by identity take that dictionary's local name. Unmatched names
/// are kept so another device's ordering survives a round trip.
List<String> alignDictionaryOrder(
  List<String> order,
  Iterable<String> installed,
) {
  final installedNames = installed.toSet();
  final used = order.where(installedNames.contains).toSet();
  final aligned = <String>[];
  for (final name in order) {
    if (installedNames.contains(name)) {
      if (!aligned.contains(name)) aligned.add(name);
      continue;
    }
    final key = dictionaryIdentityKey(name);
    final replacements = [
      for (final candidate in installedNames)
        if (!used.contains(candidate) &&
            dictionaryIdentityKey(candidate) == key)
          candidate,
    ]..sort();
    if (replacements.isEmpty) {
      if (!aligned.contains(name)) aligned.add(name);
      continue;
    }
    used.addAll(replacements);
    aligned.addAll(replacements);
  }
  return aligned;
}

/// Merges an enabled set received through sync into this device's state.
///
/// The remote device decides for every local dictionary it also has (matched
/// by identity, so a different revision still counts). Dictionaries the
/// remote device does not know keep their local state, and remote names with
/// no local counterpart are kept so they round-trip back unchanged.
/// [localEnabled] is null when this device has no matching profile yet.
Set<String> mergeSyncedEnabledDictionaryNames({
  required Set<String> remoteEnabled,
  required Iterable<String> remoteKnown,
  required Set<String>? localEnabled,
  required Iterable<String> installed,
}) {
  final installedNames = installed.toSet();
  if (installedNames.isEmpty) return remoteEnabled;
  final known = matchInstalledDictionaryNames({
    ...remoteKnown,
    ...remoteEnabled,
  }, installedNames);
  // An empty remote set means everything the remote device has is enabled.
  final remoteOn = remoteEnabled.isEmpty
      ? known
      : matchInstalledDictionaryNames(remoteEnabled, installedNames);
  final localOn = localEnabled == null
      ? installedNames
      : resolveEnabledDictionaryNames(localEnabled, installedNames);
  final enabledHere = {
    for (final name in installedNames)
      if (known.contains(name)
          ? remoteOn.contains(name)
          : localOn.contains(name))
        name,
  };
  final foreign = {
    for (final name in remoteEnabled)
      if (matchInstalledDictionaryNames({name}, installedNames).isEmpty) name,
  };
  if (foreign.isEmpty && enabledHere.length == installedNames.length) {
    return const {};
  }
  return {...enabledHere, ...foreign};
}
