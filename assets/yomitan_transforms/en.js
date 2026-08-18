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

  // third_party/yomitan/ext/js/language/en/english-transforms.js
  function doubledConsonantInflection(consonants, suffix, conditionsIn, conditionsOut) {
    const inflections = [];
    for (const consonant of consonants) {
      inflections.push(suffixInflection(`${consonant}${consonant}${suffix}`, consonant, conditionsIn, conditionsOut));
    }
    return inflections;
  }
  var pastSuffixInflections = [
    suffixInflection("ed", "", ["v"], ["v"]),
    // 'walked'
    suffixInflection("ed", "e", ["v"], ["v"]),
    // 'hoped'
    suffixInflection("ied", "y", ["v"], ["v"]),
    // 'tried'
    suffixInflection("cked", "c", ["v"], ["v"]),
    // 'frolicked'
    ...doubledConsonantInflection("bdgklmnprstz", "ed", ["v"], ["v"]),
    suffixInflection("laid", "lay", ["v"], ["v"]),
    suffixInflection("paid", "pay", ["v"], ["v"]),
    suffixInflection("said", "say", ["v"], ["v"])
  ];
  var ingSuffixInflections = [
    suffixInflection("ing", "", ["v"], ["v"]),
    // 'walking'
    suffixInflection("ing", "e", ["v"], ["v"]),
    // 'driving'
    suffixInflection("ying", "ie", ["v"], ["v"]),
    // 'lying'
    suffixInflection("cking", "c", ["v"], ["v"]),
    // 'panicking'
    ...doubledConsonantInflection("bdgklmnprstz", "ing", ["v"], ["v"])
  ];
  var thirdPersonSgPresentSuffixInflections = [
    suffixInflection("s", "", ["v"], ["v"]),
    // 'walks'
    suffixInflection("es", "", ["v"], ["v"]),
    // 'teaches'
    suffixInflection("ies", "y", ["v"], ["v"])
    // 'tries'
  ];
  var phrasalVerbParticles = ["aboard", "about", "above", "across", "ahead", "alongside", "apart", "around", "aside", "astray", "away", "back", "before", "behind", "below", "beneath", "besides", "between", "beyond", "by", "close", "down", "east", "west", "north", "south", "eastward", "westward", "northward", "southward", "forward", "backward", "backwards", "forwards", "home", "in", "inside", "instead", "near", "off", "on", "opposite", "out", "outside", "over", "overhead", "past", "round", "since", "through", "throughout", "together", "under", "underneath", "up", "within", "without"];
  var phrasalVerbPrepositions = ["aback", "about", "above", "across", "after", "against", "ahead", "along", "among", "apart", "around", "as", "aside", "at", "away", "back", "before", "behind", "below", "between", "beyond", "by", "down", "even", "for", "forth", "forward", "from", "in", "into", "of", "off", "on", "onto", "open", "out", "over", "past", "round", "through", "to", "together", "toward", "towards", "under", "up", "upon", "way", "with", "without"];
  var particlesDisjunction = phrasalVerbParticles.join("|");
  var phrasalVerbWordSet = /* @__PURE__ */ new Set([...phrasalVerbParticles, ...phrasalVerbPrepositions]);
  var phrasalVerbWordDisjunction = [...phrasalVerbWordSet].join("|");
  var phrasalVerbInterposedObjectRule = {
    type: "other",
    isInflected: new RegExp(`^\\w* (?:(?!\\b(${phrasalVerbWordDisjunction})\\b).)+ (?:${particlesDisjunction})`),
    deinflect: (term) => {
      return term.replace(new RegExp(`(?<=\\w) (?:(?!\\b(${phrasalVerbWordDisjunction})\\b).)+ (?=(?:${particlesDisjunction}))`), " ");
    },
    conditionsIn: [],
    conditionsOut: ["v_phr"]
  };
  function createPhrasalVerbInflection(inflected, deinflected) {
    return {
      type: "other",
      isInflected: new RegExp(`^\\w*${inflected} (?:${phrasalVerbWordDisjunction})`),
      deinflect: (term) => {
        return term.replace(new RegExp(`(?<=)${inflected}(?= (?:${phrasalVerbWordDisjunction}))`), deinflected);
      },
      conditionsIn: ["v"],
      conditionsOut: ["v_phr"]
    };
  }
  function createPhrasalVerbInflectionsFromSuffixInflections(sourceRules) {
    return sourceRules.flatMap(({ isInflected, deinflected }) => {
      if (typeof deinflected === "undefined") {
        return [];
      }
      const inflectedSuffix = isInflected.source.replace("$", "");
      const deinflectedSuffix = deinflected;
      return [createPhrasalVerbInflection(inflectedSuffix, deinflectedSuffix)];
    });
  }
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
  var englishTransforms = {
    language: "en",
    conditions,
    transforms: {
      "plural": {
        name: "plural",
        description: "Plural form of a noun",
        rules: [
          suffixInflection("s", "", ["np"], ["ns"]),
          suffixInflection("es", "", ["np"], ["ns"]),
          suffixInflection("ies", "y", ["np"], ["ns"]),
          suffixInflection("ves", "fe", ["np"], ["ns"]),
          suffixInflection("ves", "f", ["np"], ["ns"])
        ]
      },
      "possessive": {
        name: "possessive",
        description: "Possessive form of a noun",
        rules: [
          suffixInflection("'s", "", ["n"], ["n"]),
          suffixInflection("s'", "s", ["n"], ["n"])
        ]
      },
      "past": {
        name: "past",
        description: "Simple past tense of a verb",
        rules: [
          ...pastSuffixInflections,
          ...createPhrasalVerbInflectionsFromSuffixInflections(pastSuffixInflections)
        ]
      },
      "ing": {
        name: "ing",
        description: "Present participle of a verb",
        rules: [
          ...ingSuffixInflections,
          ...createPhrasalVerbInflectionsFromSuffixInflections(ingSuffixInflections)
        ]
      },
      "3rd pers. sing. pres": {
        name: "3rd pers. sing. pres",
        description: "Third person singular present tense of a verb",
        rules: [
          ...thirdPersonSgPresentSuffixInflections,
          ...createPhrasalVerbInflectionsFromSuffixInflections(thirdPersonSgPresentSuffixInflections)
        ]
      },
      "interposed object": {
        name: "interposed object",
        description: "Phrasal verb with interposed object",
        rules: [
          phrasalVerbInterposedObjectRule
        ]
      },
      "archaic": {
        name: "archaic",
        description: "Archaic form of a word",
        rules: [
          suffixInflection("'d", "ed", ["v"], ["v"])
        ]
      },
      "adverb": {
        name: "adverb",
        description: "Adverb form of an adjective",
        rules: [
          suffixInflection("ly", "", ["adv"], ["adj"]),
          // 'quickly'
          suffixInflection("ily", "y", ["adv"], ["adj"]),
          // 'happily'
          suffixInflection("ly", "le", ["adv"], ["adj"])
          // 'humbly'
        ]
      },
      "comparative": {
        name: "comparative",
        description: "Comparative form of an adjective",
        rules: [
          suffixInflection("er", "", ["adj"], ["adj"]),
          // 'faster'
          suffixInflection("er", "e", ["adj"], ["adj"]),
          // 'nicer'
          suffixInflection("ier", "y", ["adj"], ["adj"]),
          // 'happier'
          ...doubledConsonantInflection("bdgmnt", "er", ["adj"], ["adj"])
        ]
      },
      "superlative": {
        name: "superlative",
        description: "Superlative form of an adjective",
        rules: [
          suffixInflection("est", "", ["adj"], ["adj"]),
          // 'fastest'
          suffixInflection("est", "e", ["adj"], ["adj"]),
          // 'nicest'
          suffixInflection("iest", "y", ["adj"], ["adj"]),
          // 'happiest'
          ...doubledConsonantInflection("bdgmnt", "est", ["adj"], ["adj"])
        ]
      },
      "dropped g": {
        name: "dropped g",
        description: "Dropped g in -ing form of a verb",
        rules: [
          suffixInflection("in'", "ing", ["v"], ["v"])
        ]
      },
      "-y": {
        name: "-y",
        description: "Adjective formed from a verb or noun",
        rules: [
          suffixInflection("y", "", ["adj"], ["n", "v"]),
          // 'dirty', 'pushy'
          suffixInflection("y", "e", ["adj"], ["n", "v"]),
          // 'hazy'
          ...doubledConsonantInflection("glmnprst", "y", [], ["n", "v"])
          // 'baggy', 'saggy'
        ]
      },
      "un-": {
        name: "un-",
        description: "Negative form of an adjective, adverb, or verb",
        rules: [
          prefixInflection("un", "", ["adj", "adv", "v"], ["adj", "adv", "v"])
        ]
      },
      "going-to future": {
        name: "going-to future",
        description: "Going-to future tense of a verb",
        rules: [
          prefixInflection("going to ", "", ["v"], ["v"])
        ]
      },
      "will future": {
        name: "will future",
        description: "Will-future tense of a verb",
        rules: [
          prefixInflection("will ", "", ["v"], ["v"])
        ]
      },
      "imperative negative": {
        name: "imperative negative",
        description: "Negative imperative form of a verb",
        rules: [
          prefixInflection("don't ", "", ["v"], ["v"]),
          prefixInflection("do not ", "", ["v"], ["v"])
        ]
      },
      "-able": {
        name: "-able",
        description: "Adjective formed from a verb",
        rules: [
          suffixInflection("able", "", ["adj"], ["v"]),
          suffixInflection("able", "e", ["adj"], ["v"]),
          suffixInflection("iable", "y", ["adj"], ["v"]),
          ...doubledConsonantInflection("bdgklmnprstz", "able", ["adj"], ["v"])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/en.js
  globalThis.mangatanRegisterYomitanTransforms("en", englishTransforms);
})();
