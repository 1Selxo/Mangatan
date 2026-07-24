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

  // third_party/yomitan/ext/js/language/sq/albanian-transforms.js
  function conjugationIISuffixInflection(inflectedSuffix, deinflectedSuffix, conditionsIn, conditionsOut) {
    return {
      ...suffixInflection(inflectedSuffix, deinflectedSuffix, conditionsIn, conditionsOut),
      type: "other",
      isInflected: new RegExp(".*[^j]" + inflectedSuffix + "$")
    };
  }
  var conditions = {
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
  };
  var albanianTransforms = {
    language: "sq",
    conditions,
    transforms: {
      // Nouns
      "definite": {
        name: "definite",
        description: "Definite form of a noun",
        rules: [
          // Masculine
          suffixInflection("ku", "k", [], ["n"]),
          suffixInflection("gu", "g", [], ["n"]),
          suffixInflection("hu", "h", [], ["n"]),
          suffixInflection("au", "a", [], ["n"]),
          suffixInflection("iu", "i", [], ["n"]),
          suffixInflection("eu", "e", [], ["n"]),
          suffixInflection("i", "\xEB", [], ["n"]),
          suffixInflection("i", "", [], ["n"]),
          suffixInflection("ri", "", [], ["n"]),
          suffixInflection("oi", "ua", [], ["n"]),
          // Feminine
          suffixInflection("a", "\xEB", [], ["n"]),
          suffixInflection("a", "", [], ["n"]),
          suffixInflection("ja", "e", [], ["n"])
        ]
      },
      "singular definite accusative": {
        name: "singular definite accusative",
        description: "Singular definite accusative form of a noun",
        rules: [
          suffixInflection("n", "", [], ["n"])
        ]
      },
      "plural": {
        name: "plural",
        description: "Plural form of a noun",
        rules: [
          suffixInflection("e", "", ["np"], ["ns"]),
          suffixInflection("t", "", ["np"], ["ns"])
        ]
      },
      // Verbs
      "present indicative second-person singular": {
        name: "present indicative second-person singular",
        description: "Present indicative second-person singular form of a verb",
        rules: [
          suffixInflection("on", "oj", [], ["v"]),
          suffixInflection("uan", "uaj", [], ["v"]),
          suffixInflection("n", "j", [], ["v"]),
          suffixInflection("hesh", "hem", [], ["v"])
        ]
      },
      "present indicative third-person singular": {
        name: "present indicative third-person singular",
        description: "Present indicative third-person singular form of a verb",
        rules: [
          suffixInflection("on", "oj", [], ["v"]),
          suffixInflection("uan", "uaj", [], ["v"]),
          suffixInflection("n", "j", [], ["v"]),
          suffixInflection("het", "hem", [], ["v"])
        ]
      },
      "present indicative first-person plural": {
        name: "present indicative first-person plural",
        description: "Present indicative first-person plural form of a verb",
        rules: [
          suffixInflection("m\xEB", "", [], ["v"]),
          suffixInflection("im", "", [], ["v"]),
          suffixInflection("hemi", "hem", [], ["v"])
        ]
      },
      "present indicative second-person plural": {
        name: "present indicative second-person plural",
        description: "Present indicative second-person plural form of a verb",
        rules: [
          suffixInflection("ni", "j", [], ["v"]),
          suffixInflection("ni", "", [], ["v"]),
          suffixInflection("heni", "hem", [], ["v"])
        ]
      },
      "present indicative third-person plural": {
        name: "present indicative third-person plural",
        description: "Present indicative third-person plural form of a verb",
        rules: [
          suffixInflection("n\xEB", "", [], ["v"]),
          suffixInflection("in", "", [], ["v"]),
          suffixInflection("hen", "hem", [], ["v"])
        ]
      },
      "imperfect first-person singular indicative": {
        name: "imperfect first-person singular indicative",
        description: "Imperfect first-person singular indicative form of a verb",
        rules: [
          suffixInflection("ja", "j", [], ["v"]),
          suffixInflection("ja", "", [], ["v"]),
          suffixInflection("hesha", "hem", [], ["v"])
        ]
      },
      "imperfect second-person singular indicative": {
        name: "imperfect second-person singular indicative",
        description: "Imperfect second-person singular indicative form of a verb",
        rules: [
          suffixInflection("je", "j", [], ["v"]),
          suffixInflection("je", "", [], ["v"]),
          suffixInflection("heshe", "hem", [], ["v"])
        ]
      },
      "imperfect third-person singular indicative": {
        name: "imperfect third-person singular indicative",
        description: "Imperfect third-person singular indicative form of a verb",
        rules: [
          suffixInflection("nte", "j", [], ["v"]),
          suffixInflection("te", "", [], ["v"]),
          suffixInflection("hej", "hem", [], ["v"])
        ]
      },
      "imperfect first-person plural indicative": {
        name: "imperfect first-person plural indicative",
        description: "Imperfect first-person plural indicative form of a verb",
        rules: [
          suffixInflection("nim", "j", [], ["v"]),
          suffixInflection("nim", "", [], ["v"]),
          suffixInflection("heshim", "hem", [], ["v"])
        ]
      },
      "imperfect second-person plural indicative": {
        name: "imperfect second-person plural indicative",
        description: "Imperfect second-person plural indicative form of a verb",
        rules: [
          suffixInflection("nit", "j", [], ["v"]),
          suffixInflection("nit", "", [], ["v"]),
          suffixInflection("heshit", "hem", [], ["v"])
        ]
      },
      "imperfect third-person plural indicative": {
        name: "imperfect third-person plural indicative",
        description: "Imperfect third-person plural indicative form of a verb",
        rules: [
          suffixInflection("nin", "j", [], ["v"]),
          suffixInflection("nin", "", [], ["v"]),
          suffixInflection("heshin", "hem", [], ["v"])
        ]
      },
      "aorist first-person singular indicative": {
        name: "aorist first-person singular indicative",
        description: "Aorist first-person singular indicative form of a verb",
        rules: [
          suffixInflection("ova", "uaj", [], ["v"]),
          suffixInflection("va", "j", [], ["v"]),
          conjugationIISuffixInflection("a", "", [], ["v"])
        ]
      },
      "aorist second-person singular indicative": {
        name: "aorist second-person singular indicative",
        description: "Aorist second-person singular indicative form of a verb",
        rules: [
          suffixInflection("ove", "uaj", [], ["v"]),
          suffixInflection("ve", "j", [], ["v"]),
          conjugationIISuffixInflection("e", "", [], ["v"])
        ]
      },
      "aorist third-person singular indicative": {
        name: "aorist third-person singular indicative",
        description: "Aorist third-person singular indicative form of a verb",
        rules: [
          suffixInflection("oi", "oj", [], ["v"]),
          suffixInflection("oi", "uaj", [], ["v"]),
          suffixInflection("u", "j", [], ["v"]),
          conjugationIISuffixInflection("i", "", [], ["v"]),
          suffixInflection("ye", "ej", [], ["v"])
        ]
      },
      "aorist first-person plural indicative": {
        name: "aorist first-person plural indicative",
        description: "Aorist first-person plural indicative form of a verb",
        rules: [
          suffixInflection("uam", "oj", [], ["v"]),
          suffixInflection("uam", "uaj", [], ["v"]),
          suffixInflection("m\xEB", "j", [], ["v"]),
          conjugationIISuffixInflection("\xEBm", "", [], ["v"])
        ]
      },
      "aorist second-person plural indicative": {
        name: "aorist second-person plural indicative",
        description: "Aorist second-person plural indicative form of a verb",
        rules: [
          suffixInflection("uat", "oj", [], ["v"]),
          suffixInflection("uat", "uaj", [], ["v"]),
          suffixInflection("t\xEB", "j", [], ["v"]),
          conjugationIISuffixInflection("\xEBt", "", [], ["v"])
        ]
      },
      "aorist third-person plural indicative": {
        name: "aorist third-person plural indicative",
        description: "Aorist third-person plural indicative form of a verb",
        rules: [
          suffixInflection("uan", "oj", [], ["v"]),
          suffixInflection("uan", "uaj", [], ["v"]),
          suffixInflection("n\xEB", "j", [], ["v"]),
          conjugationIISuffixInflection("\xEBn", "", [], ["v"])
        ]
      },
      "imperative second-person singular present": {
        name: "imperative second-person singular present",
        description: "Imperative second-person singular present form of a verb",
        rules: [
          suffixInflection("o", "oj", [], ["v"]),
          suffixInflection("hu", "hem", [], ["v"])
        ]
      },
      "imperative second-person plural present": {
        name: "imperative second-person plural present",
        description: "Imperative second-person plural present form of a verb",
        rules: [
          suffixInflection("ni", "j", [], ["v"]),
          suffixInflection("ni", "", [], ["v"]),
          suffixInflection("huni", "hem", [], ["v"])
        ]
      },
      "participle": {
        name: "participle",
        description: "Participle form of a verb",
        rules: [
          suffixInflection("uar", "oj", [], ["v"]),
          suffixInflection("ur", "", [], ["v"]),
          suffixInflection("r\xEB", "j", [], ["v"]),
          suffixInflection("yer", "ej", [], ["v"])
        ]
      },
      "mediopassive": {
        name: "mediopassive",
        description: "Mediopassive form of a verb",
        rules: [
          suffixInflection("hem", "h", ["v"], ["v"]),
          suffixInflection("hem", "j", ["v"], ["v"])
        ]
      },
      "optative first-person singular present": {
        name: "optative first-person singular present",
        description: "Optative first-person singular present form of a verb",
        rules: [
          suffixInflection("fsha", "j", [], ["v"])
        ]
      },
      "optative second-person singular present": {
        name: "optative second-person singular present",
        description: "Optative second-person singular present form of a verb",
        rules: [
          suffixInflection("fsh", "j", [], ["v"])
        ]
      },
      "optative third-person singular present": {
        name: "optative third-person singular present",
        description: "Optative third-person singular present form of a verb",
        rules: [
          suffixInflection("ft\xEB", "j", [], ["v"])
        ]
      },
      "optative first-person plural present": {
        name: "optative first-person plural present",
        description: "Optative first-person plural present form of a verb",
        rules: [
          suffixInflection("fshim", "j", [], ["v"])
        ]
      },
      "optative second-person plural present": {
        name: "optative second-person plural present",
        description: "Optative second-person plural present form of a verb",
        rules: [
          suffixInflection("fshi", "j", [], ["v"])
        ]
      },
      "optative third-person plural present": {
        name: "optative third-person plural present",
        description: "Optative third-person plural present form of a verb",
        rules: [
          suffixInflection("fshin", "j", [], ["v"])
        ]
      },
      "nominalization": {
        name: "nominalization",
        description: "Noun form of a verb",
        rules: [
          suffixInflection("im", "oj", [], ["v"]),
          suffixInflection("im", "ej", [], ["v"]),
          suffixInflection("je", "", [], ["v"])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/sq.js
  globalThis.mangatanRegisterYomitanTransforms("sq", albanianTransforms);
})();
