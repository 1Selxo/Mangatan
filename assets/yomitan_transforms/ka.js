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

  // third_party/yomitan/ext/js/language/ka/georgian-transforms.js
  var suffixes = [
    "\u10D4\u10D1\u10D8",
    "\u10D4\u10D1\u10E1",
    "\u10D4\u10D1\u10D4\u10D1\u10D8\u10E1",
    // plural suffixes
    "\u10DB\u10D0",
    // ergative
    "\u10E1",
    // dative
    "\u10D8\u10E1",
    // genitive
    "\u10D8\u10D7",
    // instrumental
    "\u10D0\u10D3",
    // adverbial
    "\u10DD",
    // vocative
    "\u10E8\u10D8",
    "\u10D6\u10D4",
    "\u10E8\u10D8\u10D0",
    "\u10D6\u10D4\u10D0"
  ];
  var stemCompletionRules = [
    suffixInflection("\u10D2\u10DC", "\u10D2\u10DC\u10D8", ["n", "adj"], ["n", "adj"]),
    suffixInflection("\u10DC", "\u10DC\u10D8", ["n", "adj"], ["n", "adj"])
  ];
  var vowelRestorationRules = [
    suffixInflection("\u10D2", "\u10D2\u10D0", ["n", "adj"], ["n", "adj"])
  ];
  var georgianTransforms = {
    language: "kat",
    conditions: {
      v: {
        name: "Verb",
        isDictionaryForm: true
      },
      n: {
        name: "Noun",
        isDictionaryForm: true,
        subConditions: ["np", "ns"]
      },
      np: {
        name: "Noun plural",
        isDictionaryForm: true
      },
      ns: {
        name: "Noun singular",
        isDictionaryForm: true
      },
      adj: {
        name: "Adjective",
        isDictionaryForm: true
      },
      adv: {
        name: "Adverb",
        isDictionaryForm: true
      }
    },
    transforms: {
      nounAdjSuffixStripping: {
        name: "noun-adj-suffix-stripping",
        description: "Strip Georgian noun and adjective declension suffixes",
        rules: suffixes.map((suffix) => suffixInflection(suffix, "", ["n", "adj"], ["n", "adj"]))
      },
      nounAdjStemCompletion: {
        name: "noun-adj-stem-completion",
        description: "Restore nominative suffix -\u10D8 for consonant-ending noun/adjective stems",
        rules: stemCompletionRules
      },
      vowelRestoration: {
        name: "vowel-restoration",
        description: "Restore truncated vowels if applicable",
        rules: vowelRestorationRules
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/ka.js
  globalThis.mangatanRegisterYomitanTransforms("ka", georgianTransforms);
})();
