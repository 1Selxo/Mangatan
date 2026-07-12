(() => {
  // third_party/yomitan/ext/js/language/language-transforms.js
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

  // third_party/yomitan/ext/js/language/ga/irish-transforms.js
  var eclipsisPrefixInflections = [
    prefixInflection("mb", "b", ["n"], ["n"]),
    // 'mbean'
    prefixInflection("gc", "c", ["n"], ["n"]),
    // 'gclann'
    prefixInflection("nd", "d", ["n"], ["n"]),
    // 'ndul'
    prefixInflection("bhf", "f", ["n"], ["n"]),
    // bhfear
    prefixInflection("ng", "g", ["n"], ["n"]),
    // nGaeilge
    prefixInflection("bp", "p", ["n"], ["n"]),
    // bpáiste
    prefixInflection("dt", "t", ["n"], ["n"])
    // dtriail
  ];
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true,
      subConditions: ["v_phr"]
    },
    v_phr: {
      name: "Phrasal verb",
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
  };
  var irishTransforms = {
    language: "ga",
    conditions,
    transforms: {
      eclipsis: {
        name: "eclipsis",
        description: "eclipsis form of a noun",
        rules: [
          ...eclipsisPrefixInflections
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/ga.js
  globalThis.mangatanRegisterYomitanTransforms("ga", irishTransforms);
})();
