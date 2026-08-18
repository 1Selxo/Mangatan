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

  // third_party/yomitan/ext/js/language/yi/yiddish-transforms.js
  var mutations = [
    { new: "\u05E2", orig: "\uFB2E" },
    // Ayin to pasekh alef
    { new: "\u05E2", orig: "\uFB2F" },
    // Ayin to komets alef
    { new: "\u05E2", orig: "\u05D0" },
    // Ayin to shumter alef
    { new: "\u05F1", orig: "\u05E2" },
    // Vov yud to ayin
    { new: "\u05F2", orig: "\u05F1" },
    // Tsvey yudn to Vov yud
    { new: "\u05D9", orig: "\u05D5" }
    // Yud to Vov
  ];
  function umlautMutationSuffixInflection(inflectedSuffix, deinflectedSuffix, conditionsIn, conditionsOut) {
    const suffixRegExp = new RegExp(inflectedSuffix + "$");
    return mutations.map((mutation) => ({
      type: "suffix",
      isInflected: suffixRegExp,
      deinflected: deinflectedSuffix,
      deinflect: (text) => {
        const match = new RegExp(/[\u05E2\u05F0\u05D0\uFB2E\u05F1\u05D5\u05F2\uFB1D\uFB1F\u05D9\uFB2F](?!.*[\u05E2\u05F0\u05D0\uFB2E\u05F1\u05D5\u05F2\uFB1D\uFB1F\u05D9\uFB2F])/).exec(text.slice(0, -inflectedSuffix.length));
        return match?.[0] !== mutation.new ? "" : text.slice(0, match.index) + mutation.orig + text.slice(match.index + 1, -inflectedSuffix.length) + deinflectedSuffix;
      },
      conditionsIn,
      conditionsOut
    }));
  }
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true,
      subConditions: ["vpast", "vpresent"]
    },
    vpast: {
      name: "Verb, past tense",
      isDictionaryForm: false
    },
    vpresent: {
      name: "Verb, present tense",
      isDictionaryForm: true
    },
    n: {
      name: "Noun",
      isDictionaryForm: true,
      subConditions: ["np", "ns"]
    },
    np: {
      name: "Noun plural",
      isDictionaryForm: false
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
  var yiddishTransforms = {
    language: "yi",
    conditions,
    transforms: {
      plural: {
        name: "plural",
        description: "plural form of a noun",
        rules: [
          suffixInflection("\u05E1", "", ["np"], ["ns"]),
          // -s
          suffixInflection("\u05DF", "", ["np"], ["ns"]),
          // -n
          suffixInflection("\u05D9\u05DD", "", ["np"], ["ns"]),
          // -im, hebrew
          suffixInflection("\u05E2\u05E8", "", ["np"], ["ns"]),
          // -er
          suffixInflection("\u05E2\u05DA", "", ["np"], ["ns"]),
          // -ekh
          suffixInflection("\u05E2\u05DF", "", ["np"], ["ns"]),
          // -en
          suffixInflection("\u05E2\u05E1", "", ["np"], ["ns"]),
          // -es
          suffixInflection("\u05D5\u05EA", "", ["np"], ["ns"]),
          // -ot, hebrew
          suffixInflection("\u05E0\u05E1", "", ["np"], ["ns"]),
          // -ns
          suffixInflection("\u05E2\u05E8\u05E2\u05DF", "", ["np"], ["ns"]),
          // -eren
          suffixInflection("\u05E2\u05E0\u05E2\u05E1", "", ["np"], ["ns"]),
          // -enes
          suffixInflection("\u05E2\u05E0\u05E1", "", ["np"], ["ns"]),
          // -ens
          suffixInflection("\u05E2\u05E8\u05E1", "", ["np"], ["ns"]),
          // -ers
          suffixInflection("\u05E1\u05E2\u05E8", "", ["np"], ["ns"])
          // -ser
        ]
      },
      umlaut_plural: {
        name: "umlaut_plural",
        description: "plural form of a umlaut noun",
        rules: [
          ...umlautMutationSuffixInflection("\u05E2\u05E8", "", ["np"], ["ns"]),
          // -er
          ...umlautMutationSuffixInflection("\u05E2\u05E1", "", ["np"], ["ns"]),
          // -es
          ...umlautMutationSuffixInflection("\u05D9\u05DD", "", ["np"], ["ns"]),
          // -im
          ...umlautMutationSuffixInflection("\u05E2\u05DF", "", ["np"], ["ns"]),
          // -en
          ...umlautMutationSuffixInflection("\u05DF", "", ["np"], ["ns"]),
          // -n
          ...umlautMutationSuffixInflection("\u05E1", "", ["np"], ["ns"]),
          // -s
          ...umlautMutationSuffixInflection("\u05E2\u05DA", "", ["np"], ["ns"]),
          // -ekh
          ...umlautMutationSuffixInflection("\u05E2\u05E8\u05E1", "", ["np"], ["ns"])
          // -ers
        ]
      },
      diminutive: {
        name: "diminutive",
        description: "diminutive form of a noun",
        rules: [
          suffixInflection("\u05D8\u05E9\u05D9\u05E7", "", ["n"], ["n"]),
          // -tshik
          suffixInflection("\u05E7\u05E2", "", ["n"], ["n"]),
          // -ke
          suffixInflection("\u05DC", "", ["n"], ["n"]),
          // -l
          suffixInflection("\u05E2\u05DC\u05E2", "", ["n"], ["n"])
          // -ele
        ]
      },
      diminutive_and_umlaut: {
        name: "diminutive_and_umlaut",
        description: "diminutive form of a noun with stem umlaut",
        rules: [
          ...umlautMutationSuffixInflection("\u05DC", "", ["n"], ["n"]),
          // -l
          ...umlautMutationSuffixInflection("\u05E2\u05DC\u05E2", "", ["n"], ["n"])
          // -ele
        ]
      },
      verb_present_singular_to_first_person: {
        name: "verb_present_singular_to_first_person",
        description: "Turn the second and third person singular form to first person",
        rules: [
          suffixInflection("\u05E1\u05D8", "", ["v"], ["vpresent"]),
          // -st
          suffixInflection("\u05D8", "", ["v"], ["vpresent"]),
          // -t
          suffixInflection("\u05E0\u05D3\u05D9\u05E7", "", ["v"], ["vpresent"])
          // -ndik
        ]
      },
      verb_present_plural_to_first_person: {
        name: "verb_present_plural_to_first_person",
        description: "Turn the second plural form to first person plural form",
        rules: [
          suffixInflection("\u05D8\u05E1", "\u05E0", ["v"], ["vpresent"]),
          // -ts
          suffixInflection("\u05D8", "\u05E0", ["v"], ["vpresent"])
          // -t
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/yi.js
  globalThis.mangatanRegisterYomitanTransforms("yi", yiddishTransforms);
})();
