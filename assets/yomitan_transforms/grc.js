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

  // third_party/yomitan/ext/js/language/grc/ancient-greek-transforms.js
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true
    },
    n: {
      name: "Noun",
      isDictionaryForm: true
    },
    adj: {
      name: "Adjective",
      isDictionaryForm: true
    }
  };
  var ancientGreekTransforms = {
    language: "grc",
    conditions,
    transforms: {
      // inflections
      // verbs - active voice
      "2nd person singular present active indicative": {
        name: "2nd person singular present active indicative",
        rules: [
          suffixInflection("\u03B5\u03B9\u03C2", "\u03C9", [], ["v"]),
          suffixInflection("\u03B5\u03B9\u03C2", "\u03B5\u03C9", [], ["v"])
        ]
      },
      "3rd person singular present active indicative": {
        name: "3rd person singular present active indicative",
        rules: [
          suffixInflection("\u03B5\u03B9", "\u03C9", [], ["v"]),
          suffixInflection("\u03B5\u03B9", "\u03B5\u03C9", [], ["v"])
        ]
      },
      "1st person plural present active indicative": {
        name: "1st person plural present active indicative",
        rules: [
          suffixInflection("\u03BF\u03BC\u03B5\u03BD", "\u03C9", [], ["v"])
        ]
      },
      "2nd person plural present active indicative": {
        name: "2nd person plural present active indicative",
        rules: [
          suffixInflection("\u03B5\u03C4\u03B5", "\u03C9", [], ["v"])
        ]
      },
      "3rd person plural present active indicative": {
        name: "3rd person plural present active indicative",
        rules: [
          suffixInflection("\u03BF\u03C5\u03C3\u03B9", "\u03C9", [], ["v"]),
          suffixInflection("\u03BF\u03C5\u03C3\u03B9\u03BD", "\u03C9", [], ["v"])
        ]
      },
      // verbs - middle voice
      "2nd person singular present middle indicative": {
        name: "2nd person singular present middle indicative",
        rules: [
          suffixInflection("\u1FC3", "\u03BF\u03BC\u03B1\u03B9", [], ["v"]),
          suffixInflection("\u03B5\u03B9", "\u03BF\u03BC\u03B1\u03B9", [], ["v"])
        ]
      },
      "3rd person singular present middle indicative": {
        name: "3rd person singular present middle indicative",
        rules: [
          suffixInflection("\u03B5\u03C4\u03B1\u03B9", "\u03BF\u03BC\u03B1\u03B9", [], ["v"])
        ]
      },
      "1st person plural present middle indicative": {
        name: "1st person plural present middle indicative",
        rules: [
          suffixInflection("\u03BF\u03BC\u03B5\u03B8\u03B1", "\u03BF\u03BC\u03B1\u03B9", [], ["v"])
        ]
      },
      "2nd person plural present middle indicative": {
        name: "2nd person plural present middle indicative",
        rules: [
          suffixInflection("\u03B5\u03C3\u03B8\u03B5", "\u03BF\u03BC\u03B1\u03B9", [], ["v"])
        ]
      },
      "3rd person plural present middle indicative": {
        name: "3rd person plural present middle indicative",
        rules: [
          suffixInflection("\u03BF\u03BD\u03C4\u03B1\u03B9", "\u03BF\u03BC\u03B1\u03B9", [], ["v"])
        ]
      },
      // nouns
      "genitive singular": {
        name: "genitive singular",
        rules: [
          suffixInflection("\u03BF\u03C5", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1\u03C2", "\u03B1", [], ["n"]),
          suffixInflection("\u03BF\u03C5", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03BF\u03C5", "\u03BF\u03BD", [], ["n"]),
          suffixInflection("\u03B7\u03C2", "\u03B7", [], ["n"])
        ]
      },
      "dative singular": {
        name: "dative singular",
        rules: [
          suffixInflection("\u03C9", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03C9", "\u03BF\u03BD", [], ["n"])
        ]
      },
      "accusative singular": {
        name: "accusative singular",
        rules: [
          suffixInflection("\u03BF\u03BD", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1\u03BD", "\u03B1", [], ["n"]),
          suffixInflection("\u03B1\u03BD", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03B7\u03BD", "\u03B7", [], ["n"])
        ]
      },
      "vocative singular": {
        name: "vocative singular",
        rules: [
          suffixInflection("\u03B5", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03B7", "\u03B7", [], ["n"])
        ]
      },
      "nominative plural": {
        name: "nominative plural",
        rules: [
          suffixInflection("\u03BF\u03B9", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1\u03B9", "\u03B1", [], ["n"]),
          suffixInflection("\u03B1\u03B9", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03B1", "\u03BF\u03BD", [], ["n"]),
          suffixInflection("\u03B1\u03B9", "\u03B7", [], ["n"])
        ]
      },
      "genitive plural": {
        name: "genitive plural",
        rules: [
          suffixInflection("\u03C9\u03BD", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03C9\u03BD", "\u03B1", [], ["n"]),
          suffixInflection("\u03C9\u03BD", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03C9\u03BD", "\u03BF\u03BD", [], ["n"]),
          suffixInflection("\u03C9\u03BD", "\u03B7", [], ["n"])
        ]
      },
      "dative plural": {
        name: "dative plural",
        rules: [
          suffixInflection("\u03BF\u03B9\u03C2", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1\u03B9\u03C2", "\u03B1", [], ["n"]),
          suffixInflection("\u03B1\u03B9\u03C2", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03BF\u03B9\u03C2", "\u03BF\u03BD", [], ["n"]),
          suffixInflection("\u03B1\u03B9\u03C2", "\u03B7", [], ["n"])
        ]
      },
      "accusative plural": {
        name: "accusative plural",
        rules: [
          suffixInflection("\u03BF\u03C5\u03C2", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1\u03C2", "\u03B1", [], ["n"]),
          suffixInflection("\u03B1", "\u03BF\u03BD", [], ["n"]),
          suffixInflection("\u03B1\u03C2", "\u03B7", [], ["n"])
        ]
      },
      "vocative plural": {
        name: "vocative plural",
        rules: [
          suffixInflection("\u03BF\u03B9", "\u03BF\u03C2", [], ["n"]),
          suffixInflection("\u03B1\u03B9", "\u03B1", [], ["n"]),
          suffixInflection("\u03B1\u03B9", "\u03B1\u03C2", [], ["n"]),
          suffixInflection("\u03B1", "\u03BF\u03BD", [], ["n"]),
          suffixInflection("\u03B1\u03B9", "\u03B7", [], ["n"])
        ]
      },
      // adjectives
      "accusative singular masculine": {
        name: "accusative singular masculine",
        rules: [
          suffixInflection("\u03BF\u03BD", "\u03BF\u03C2", [], ["adj"])
        ]
      },
      // word formation
      "nominalization": {
        name: "nominalization",
        rules: [
          suffixInflection("\u03BF\u03C2", "\u03B5\u03C9", [], ["v"])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/grc.js
  globalThis.mangatanRegisterYomitanTransforms("grc", ancientGreekTransforms);
})();
