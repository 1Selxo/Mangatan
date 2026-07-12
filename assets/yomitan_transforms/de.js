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

  // third_party/yomitan/ext/js/language/de/german-transforms.js
  var separablePrefixes = ["ab", "an", "auf", "aus", "auseinander", "bei", "da", "dabei", "dar", "daran", "dazwischen", "durch", "ein", "empor", "entgegen", "entlang", "entzwei", "fehl", "fern", "fest", "fort", "frei", "gegen\xFCber", "gleich", "heim", "her", "herab", "heran", "herauf", "heraus", "herbei", "herein", "her\xFCber", "herum", "herunter", "hervor", "hin", "hinab", "hinauf", "hinaus", "hinein", "hinterher", "hinunter", "hinweg", "hinzu", "hoch", "los", "mit", "nach", "nebenher", "nieder", "statt", "um", "vor", "voran", "voraus", "vorbei", "vor\xFCber", "vorweg", "weg", "weiter", "wieder", "zu", "zurecht", "zur\xFCck", "zusammen"];
  var germanLetters = "a-zA-Z\xE4\xF6\xFC\xDF\xC4\xD6\xDC\u1E9E";
  function separatedPrefix(prefix, conditionsIn, conditionsOut) {
    const regex = new RegExp(`^([${germanLetters}]+) .+ ${prefix}$`);
    return {
      type: "other",
      isInflected: regex,
      deinflect: (term) => {
        return term.replace(regex, "$1 " + prefix);
      },
      conditionsIn,
      conditionsOut
    };
  }
  var separatedPrefixInflections = separablePrefixes.map((prefix) => {
    return separatedPrefix(prefix, [], []);
  });
  var zuInfinitiveInflections = separablePrefixes.map((prefix) => {
    return prefixInflection(prefix + "zu", prefix, [], ["v"]);
  });
  function getBasicPastParticiples() {
    const regularPastParticiple = new RegExp(`^ge([${germanLetters}]+)t$`);
    const suffixes = ["n", "en"];
    return suffixes.map((suffix) => ({
      type: "other",
      isInflected: regularPastParticiple,
      deinflect: (term) => {
        return term.replace(regularPastParticiple, `$1${suffix}`);
      },
      conditionsIn: [],
      conditionsOut: ["vw"]
    }));
  }
  function getSeparablePastParticiples() {
    const prefixDisjunction = separablePrefixes.join("|");
    const separablePastParticiple = new RegExp(`^(${prefixDisjunction})ge([${germanLetters}]+)t$`);
    const suffixes = ["n", "en"];
    return suffixes.map((suffix) => ({
      type: "other",
      isInflected: separablePastParticiple,
      deinflect: (term) => {
        return term.replace(separablePastParticiple, `$1$2${suffix}`);
      },
      conditionsIn: [],
      conditionsOut: ["vw"]
    }));
  }
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true,
      subConditions: ["vw", "vst"]
    },
    vw: {
      name: "Weak verb",
      isDictionaryForm: true
    },
    vst: {
      name: "Strong verb",
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
  var germanTransforms = {
    language: "de",
    conditions,
    transforms: {
      "nominalization": {
        name: "nominalization",
        description: "Noun formed from a verb",
        rules: [
          suffixInflection("ung", "en", [], ["v"]),
          suffixInflection("lung", "eln", [], ["v"]),
          suffixInflection("rung", "rn", [], ["v"])
        ]
      },
      "-bar": {
        name: "-bar",
        description: "-able adjective from a verb",
        rules: [
          suffixInflection("bar", "en", ["adj"], ["v"]),
          suffixInflection("bar", "n", ["adj"], ["v"])
        ]
      },
      "negative": {
        name: "negative",
        description: "Negation",
        rules: [
          prefixInflection("un", "", [], ["adj"])
        ]
      },
      "past participle": {
        name: "past participle",
        rules: [
          ...getBasicPastParticiples(),
          ...getSeparablePastParticiples()
        ]
      },
      "separated prefix": {
        name: "separated prefix",
        rules: [
          ...separatedPrefixInflections
        ]
      },
      "zu-infinitive": {
        name: "zu-infinitive",
        rules: [
          ...zuInfinitiveInflections
        ]
      },
      "-heit": {
        name: "-heit",
        description: "1. Converts an adjective into a noun and usually denotes an abstract quality of the adjectival root. It is often equivalent to the English suffixes -ness, -th, -ty, -dom:\n	 sch\xF6n (\u201Cbeautiful\u201D) + -heit \u2192 Sch\xF6nheit (\u201Cbeauty\u201D)\n	 neu (\u201Cnew\u201D) + -heit \u2192 Neuheit (\u201Cnovelty\u201D)\n2. Converts concrete nouns into abstract nouns:\n	 Kind (\u201Cchild\u201D) + -heit \u2192 Kindheit (\u201Cchildhood\u201D)\n	 Christ (\u201CChristian\u201D) + -heit \u2192 Christenheit (\u201CChristendom\u201D)\n",
        rules: [
          suffixInflection("heit", "", ["n"], ["adj", "n"]),
          suffixInflection("keit", "", ["n"], ["adj", "n"])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/de.js
  globalThis.mangatanRegisterYomitanTransforms("de", germanTransforms);
})();
