/// [json] with every non-ASCII character written as a `\u` escape.
///
/// `jsonDecode` reads it back to exactly the same value. Stored this way, a
/// source's filter and preference lists are plain ASCII, which Isar decodes
/// on a fast path into one-byte strings: reading the installed sources got
/// four times faster and their strings took half the memory. Those lists
/// together were larger than the extensions' APKs, and the launch reads the
/// installed sources several times. Non-ASCII text can only occur inside
/// JSON strings, where an escape is always valid.
String asciiJson(String json) {
  var firstNonAscii = -1;
  for (var i = 0; i < json.length; i++) {
    if (json.codeUnitAt(i) > 0x7f) {
      firstNonAscii = i;
      break;
    }
  }
  if (firstNonAscii < 0) return json;
  final out = StringBuffer(json.substring(0, firstNonAscii));
  for (var i = firstNonAscii; i < json.length; i++) {
    final unit = json.codeUnitAt(i);
    if (unit <= 0x7f) {
      out.writeCharCode(unit);
    } else {
      // UTF-16 code units, so characters outside the BMP become the
      // surrogate pair JSON expects.
      out
        ..write(r'\u')
        ..write(unit.toRadixString(16).padLeft(4, '0'));
    }
  }
  return out.toString();
}

/// [asciiJson] for a value that may be absent.
String? asciiJsonOrNull(String? json) => json == null ? null : asciiJson(json);
