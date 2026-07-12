(() => {
  // third_party/yomitan/ext/js/language/language-transforms.js
  function suffixInflection(inflectedSuffix, deinflectedSuffix, conditionsIn, conditionsOut) {
    const suffixRegExp = new RegExp(inflectedSuffix + "$");
    return {
      type: "suffix",
      isInflected: suffixRegExp,
      deinflected: deinflectedSuffix,
      deinflect: (text) => text.slice(0, -inflectedSuffix.length) + deinflectedSuffix,
      conditionsIn,
      conditionsOut
    };
  }
  function prefixInflection(inflectedPrefix, deinflectedPrefix, conditionsIn, conditionsOut) {
    const prefixRegExp = new RegExp("^" + inflectedPrefix);
    return {
      type: "prefix",
      isInflected: prefixRegExp,
      deinflect: (text) => deinflectedPrefix + text.slice(inflectedPrefix.length),
      conditionsIn,
      conditionsOut
    };
  }

  // third_party/yomitan/ext/js/language/sga/old-irish-transforms.js
  function tryAlternateOrthography(notBeginning, originalOrthography, alternateOrthography, conditionsIn, conditionsOut) {
    const orthographyRegExp = notBeginning ? new RegExp("(?<!^)" + originalOrthography, "g") : new RegExp(originalOrthography, "g");
    return {
      type: "other",
      isInflected: orthographyRegExp,
      deinflect: (text) => text.replace(orthographyRegExp, alternateOrthography),
      conditionsIn,
      conditionsOut
    };
  }
  var conditions = {};
  var oldIrishTransforms = {
    language: "sga",
    conditions,
    transforms: {
      "nd for nn": {
        name: "nd for nn",
        description: "nd for nn",
        rules: [
          suffixInflection("nd", "nn", [], [])
        ]
      },
      "cg for c": {
        name: "cg for c",
        description: "cg for c",
        rules: [
          tryAlternateOrthography(false, "cg", "c", [], [])
        ]
      },
      "td for t": {
        name: "td for t",
        description: "td for t",
        rules: [
          tryAlternateOrthography(false, "td", "t", [], [])
        ]
      },
      "pb for p": {
        name: "pb for p",
        description: "pb for p",
        rules: [
          tryAlternateOrthography(false, "pb", "p", [], [])
        ]
      },
      "\u01FD/\xE6 for \xE9": {
        name: "\u01FD/\xE6 for \xE9",
        description: "\u01FD/\xE6 for \xE9",
        rules: [
          tryAlternateOrthography(false, "\u01FD", "\xE9", [], []),
          tryAlternateOrthography(false, "\xE6", "\xE9", [], [])
        ]
      },
      "doubled vowel": {
        name: "doubled vowel",
        description: "Doubled Vowel",
        rules: [
          tryAlternateOrthography(true, "aa", "\xE1", [], []),
          tryAlternateOrthography(true, "ee", "\xE9", [], []),
          tryAlternateOrthography(true, "ii", "\xED", [], []),
          tryAlternateOrthography(true, "oo", "\xF3", [], []),
          tryAlternateOrthography(true, "uu", "\xFA", [], [])
        ]
      },
      "doubled consonant": {
        name: "doubled consonant",
        description: "Doubled Consonant",
        rules: [
          tryAlternateOrthography(true, "cc", "c", [], []),
          tryAlternateOrthography(true, "pp", "p", [], []),
          tryAlternateOrthography(true, "tt", "t", [], []),
          tryAlternateOrthography(true, "gg", "g", [], []),
          tryAlternateOrthography(true, "bb", "b", [], []),
          tryAlternateOrthography(true, "dd", "d", [], []),
          tryAlternateOrthography(true, "rr", "r", [], []),
          tryAlternateOrthography(true, "ll", "l", [], []),
          tryAlternateOrthography(true, "nn", "n", [], []),
          tryAlternateOrthography(true, "mm", "m", [], []),
          tryAlternateOrthography(true, "ss", "s", [], [])
        ]
      },
      "lenited": {
        name: "lenited",
        description: "Non-Beginning Lenition",
        rules: [
          tryAlternateOrthography(true, "ch", "c", [], []),
          tryAlternateOrthography(true, "ph", "p", [], []),
          tryAlternateOrthography(true, "th", "t", [], [])
        ]
      },
      "lenited (Middle Irish)": {
        name: "lenited (Middle Irish)",
        description: "Non-Beginning Lenition (Middle Irish)",
        rules: [
          tryAlternateOrthography(true, "gh", "g", [], []),
          tryAlternateOrthography(true, "bh", "b", [], []),
          tryAlternateOrthography(true, "dh", "d", [], [])
        ]
      },
      "[IM] nasalized": {
        name: "[IM] nasalized",
        description: "Nasalized Word",
        rules: [
          prefixInflection("ng", "g", [], []),
          prefixInflection("mb", "b", [], []),
          prefixInflection("nd", "d", [], []),
          prefixInflection("n-", "", [], []),
          prefixInflection("m-", "", [], [])
        ]
      },
      "[IM] nasalized (Middle Irish)": {
        name: "[IM] nasalized (Middle Irish)",
        description: "Nasalized Word (Middle Irish)",
        rules: [
          prefixInflection("gc", "c", [], []),
          prefixInflection("bp", "p", [], []),
          prefixInflection("dt", "d", [], [])
        ]
      },
      "[IM] lenited": {
        name: "[IM] lenited",
        description: "Lenited Word",
        rules: [
          prefixInflection("ch", "c", [], []),
          prefixInflection("ph", "p", [], []),
          prefixInflection("th", "t", [], [])
        ]
      },
      "[IM] lenited (Middle Irish)": {
        name: "[IM] lenited (Middle Irish)",
        description: "Lenited Word (Middle Irish)",
        rules: [
          prefixInflection("gh", "g", [], []),
          prefixInflection("bh", "b", [], []),
          prefixInflection("dh", "d", [], [])
        ]
      },
      "[IM] aspirated": {
        name: "[IM] aspirated",
        description: "Aspirated Word",
        rules: [
          prefixInflection("ha", "a", [], []),
          prefixInflection("he", "e", [], []),
          prefixInflection("hi", "i", [], []),
          prefixInflection("ho", "o", [], []),
          prefixInflection("hu", "u", [], []),
          prefixInflection("h-", "", [], [])
        ]
      },
      "[IM] geminated": {
        name: "[IM] geminated",
        description: "Geminated Word",
        rules: [
          prefixInflection("cc", "c", [], []),
          prefixInflection("pp", "p", [], []),
          prefixInflection("tt", "t", [], []),
          prefixInflection("gg", "g", [], []),
          prefixInflection("bb", "b", [], []),
          prefixInflection("dd", "d", [], []),
          prefixInflection("rr", "r", [], []),
          prefixInflection("ll", "l", [], []),
          prefixInflection("nn", "n", [], []),
          prefixInflection("mm", "m", [], []),
          prefixInflection("ss", "s", [], []),
          prefixInflection("c-c", "c", [], []),
          prefixInflection("p-p", "p", [], []),
          prefixInflection("t-t", "t", [], []),
          prefixInflection("g-g", "g", [], []),
          prefixInflection("b-b", "b", [], []),
          prefixInflection("d-d", "d", [], []),
          prefixInflection("r-r", "r", [], []),
          prefixInflection("l-l", "l", [], []),
          prefixInflection("n-n", "n", [], []),
          prefixInflection("m-m", "m", [], []),
          prefixInflection("s-s", "s", [], [])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/sga.js
  globalThis.mangatanRegisterYomitanTransforms("sga", oldIrishTransforms);
})();
