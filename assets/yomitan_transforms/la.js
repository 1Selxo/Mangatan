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

  // third_party/yomitan/ext/js/language/la/latin-transforms.js
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true
    },
    n: {
      name: "Noun",
      isDictionaryForm: true,
      subConditions: ["ns", "np"]
    },
    ns: {
      name: "Noun singular",
      isDictionaryForm: true,
      subConditions: ["n1s", "n2s", "n3s", "n4s", "n5s"]
    },
    np: {
      name: "Noun plural",
      isDictionaryForm: true,
      subConditions: ["n1p", "n2p", "n3p", "n4p", "n5p"]
    },
    n1: {
      name: "Noun, 1st declension",
      isDictionaryForm: true,
      subConditions: ["n1s", "n1p"]
    },
    n1p: {
      name: "Noun, 1st declension, plural",
      isDictionaryForm: true
    },
    n1s: {
      name: "Noun, 1st declension, singular",
      isDictionaryForm: true
    },
    n2: {
      name: "Noun, 2nd declension",
      isDictionaryForm: true,
      subConditions: ["n2s", "n2p"]
    },
    n2p: {
      name: "Noun, 2nd declension, plural",
      isDictionaryForm: true
    },
    n2s: {
      name: "Noun, 2nd declension, singular",
      isDictionaryForm: true
    },
    n3: {
      name: "Noun, 3rd declension",
      isDictionaryForm: true,
      subConditions: ["n3s", "n3p"]
    },
    n3p: {
      name: "Noun, 3rd declension, plural",
      isDictionaryForm: true
    },
    n3s: {
      name: "Noun, 3rd declension, singular",
      isDictionaryForm: true
    },
    n4: {
      name: "Noun, 4th declension",
      isDictionaryForm: true,
      subConditions: ["n4s", "n4p"]
    },
    n4p: {
      name: "Noun, 4th declension, plural",
      isDictionaryForm: true
    },
    n4s: {
      name: "Noun, 4th declension, singular",
      isDictionaryForm: true
    },
    n5: {
      name: "Noun, 5th declension",
      isDictionaryForm: true,
      subConditions: ["n5s", "n5p"]
    },
    n5p: {
      name: "Noun, 5th declension, plural",
      isDictionaryForm: true
    },
    n5s: {
      name: "Noun, 5th declension, singular",
      isDictionaryForm: true
    },
    adj: {
      name: "Adjective",
      isDictionaryForm: true,
      subConditions: ["adj3", "adj12"]
    },
    adj12: {
      name: "Adjective, 1st-2nd declension",
      isDictionaryForm: true
    },
    adj3: {
      name: "Adjective, 3rd declension",
      isDictionaryForm: true
    },
    adv: {
      name: "Adverb",
      isDictionaryForm: true
    }
  };
  var latinTransforms = {
    language: "la",
    conditions,
    transforms: {
      plural: {
        name: "plural",
        description: "Plural declension",
        rules: [
          suffixInflection("i", "us", ["n2p"], ["n2s"]),
          suffixInflection("i", "us", ["adj12"], ["adj12"]),
          suffixInflection("e", "", ["n1p"], ["n1s"]),
          suffixInflection("ae", "a", ["adj12"], ["adj12"]),
          suffixInflection("a", "um", ["adj12"], ["adj12"])
        ]
      },
      feminine: {
        name: "feminine",
        description: "Adjective form",
        rules: [
          suffixInflection("a", "us", ["adj12"], ["adj12"])
        ]
      },
      neuter: {
        name: "neuter",
        description: "Adjective form",
        rules: [
          suffixInflection("um", "us", ["adj12"], ["adj12"])
        ]
      },
      ablative: {
        name: "ablative",
        description: "Ablative case",
        rules: [
          suffixInflection("o", "um", ["n2s"], ["n2s"])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/la.js
  globalThis.mangatanRegisterYomitanTransforms("la", latinTransforms);
})();
