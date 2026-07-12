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

  // third_party/yomitan/ext/js/language/ar/arabic-transforms.js
  var arabicLetters = "[\u0620-\u065F\u066E-\u06D3\u06D5\u06EE\u06EF\u06FA-\u06FC\u06FF]";
  var directObjectPronouns1st = ["\u0646\u064A", "\u0646\u0627"];
  var directObjectPronouns2nd = ["\u0643", "\u0643\u0645\u0627", "\u0643\u0645", "\u0643\u0646"];
  var directObjectPronouns3rd = ["\u0647", "\u0647\u0627", "\u0647\u0645\u0627", "\u0647\u0645", "\u0647\u0646"];
  var directObjectPronouns = [...directObjectPronouns1st, ...directObjectPronouns2nd, ...directObjectPronouns3rd];
  var possessivePronouns = ["\u064A", "\u0646\u0627", ...directObjectPronouns2nd, ...directObjectPronouns3rd];
  var nonAssimilatingPossessivePronouns = ["\u0646\u0627", ...directObjectPronouns2nd, ...directObjectPronouns3rd];
  function getImperfectPrefixes(prefix, includeLiPrefix = true) {
    return [
      `${prefix}`,
      `\u0648${prefix}`,
      `\u0641${prefix}`,
      `\u0633${prefix}`,
      `\u0648\u0633${prefix}`,
      `\u0641\u0633${prefix}`,
      ...includeLiPrefix ? [`\u0644${prefix}`, `\u0648\u0644${prefix}`, `\u0641\u0644${prefix}`] : []
    ];
  }
  function conditionalPrefixInflection(inflectedPrefix, deinflectedPrefix, initialStemSegment, conditionsIn, conditionsOut) {
    const prefixRegExp = new RegExp("^" + inflectedPrefix + initialStemSegment);
    return {
      type: "prefix",
      isInflected: prefixRegExp,
      deinflect: (text) => deinflectedPrefix + text.slice(inflectedPrefix.length),
      conditionsIn,
      conditionsOut
    };
  }
  function conditionalSuffixInflection(inflectedSuffix, deinflectedSuffix, finalStemSegment, conditionsIn, conditionsOut) {
    const suffixRegExp = new RegExp(finalStemSegment + inflectedSuffix + "$");
    return {
      type: "suffix",
      isInflected: suffixRegExp,
      deinflected: deinflectedSuffix,
      deinflect: (text) => text.slice(0, -inflectedSuffix.length) + deinflectedSuffix,
      conditionsIn,
      conditionsOut
    };
  }
  function sandwichInflection(inflectedPrefix, deinflectedPrefix, inflectedSuffix, deinflectedSuffix, conditionsIn, conditionsOut, { initialStemSegment = "", finalStemSegment = "" } = {}) {
    if (!inflectedSuffix && !deinflectedSuffix) {
      return conditionalPrefixInflection(
        inflectedPrefix,
        deinflectedPrefix,
        initialStemSegment,
        conditionsIn,
        conditionsOut
      );
    }
    if (!inflectedPrefix && !deinflectedPrefix) {
      return conditionalSuffixInflection(
        inflectedSuffix,
        deinflectedSuffix,
        finalStemSegment,
        conditionsIn,
        conditionsOut
      );
    }
    const regex = new RegExp(
      `^${inflectedPrefix}${initialStemSegment}${arabicLetters}+${finalStemSegment}${inflectedSuffix}$`
    );
    return {
      type: "other",
      isInflected: regex,
      deinflect: (text) => deinflectedPrefix + text.slice(inflectedPrefix.length, -inflectedSuffix.length) + deinflectedSuffix,
      conditionsIn,
      conditionsOut
    };
  }
  function getImperfectRules(inflectedPrefix, deinflectedPrefix, inflectedSuffix, deinflectedSuffix, {
    attachedSuffix = inflectedSuffix,
    attachesTo1st = true,
    attachesTo2nd = true,
    includeLiPrefix = true,
    initialStemSegment = "",
    finalStemSegment = ""
  } = {}) {
    const stemSegments = { initialStemSegment, finalStemSegment };
    const rules = getImperfectPrefixes(inflectedPrefix, includeLiPrefix).flatMap((pre) => [
      sandwichInflection(pre, deinflectedPrefix, inflectedSuffix, deinflectedSuffix, ["iv_p"], ["iv"], stemSegments),
      // With attached direct object pronouns
      ...attachesTo1st ? directObjectPronouns1st.map((p) => sandwichInflection(
        pre,
        deinflectedPrefix,
        attachedSuffix + p,
        deinflectedSuffix,
        ["iv_p"],
        ["iv"],
        stemSegments
      )) : [],
      ...attachesTo2nd ? directObjectPronouns2nd.map((p) => sandwichInflection(
        pre,
        deinflectedPrefix,
        attachedSuffix + p,
        deinflectedSuffix,
        ["iv_p"],
        ["iv"],
        stemSegments
      )) : [],
      ...directObjectPronouns3rd.map((p) => sandwichInflection(
        pre,
        deinflectedPrefix,
        attachedSuffix + p,
        deinflectedSuffix,
        ["iv_p"],
        ["iv"],
        stemSegments
      ))
    ]);
    if (!deinflectedPrefix) {
      const opts = {
        attachedSuffix,
        attachesTo1st,
        attachesTo2nd,
        includeLiPrefix,
        initialStemSegment,
        finalStemSegment
      };
      rules.push(
        ...getImperfectRules(inflectedPrefix, "\u0623", inflectedSuffix, deinflectedSuffix, opts),
        ...getImperfectRules(inflectedPrefix, "\u0627", inflectedSuffix, deinflectedSuffix, opts)
      );
    }
    return rules;
  }
  var conditions = {
    n: {
      name: "Noun",
      isDictionaryForm: true
    },
    n_p: {
      name: "Noun with Prefix only",
      isDictionaryForm: false,
      subConditions: ["n_wa", "n_bi", "n_ka", "n_li", "n_al", "n_bi_al", "n_ka_al", "n_lil", "n_li_al"]
    },
    n_def: {
      name: "Noun with Definite Prefix",
      isDictionaryForm: false,
      subConditions: ["n_al", "n_bi_al", "n_ka_al", "n_lil", "n_li_al"]
    },
    n_indef: {
      name: "Noun with Indefinite Prefix",
      isDictionaryForm: false,
      subConditions: ["n_wa", "n_bi", "n_ka", "n_li"]
    },
    n_nom: {
      name: "Nominative Noun with Prefix",
      isDictionaryForm: false,
      subConditions: ["n_wa", "n_li", "n_al"]
    },
    n_nom_indef: {
      name: "Nominative Noun with Indefinite Prefix",
      isDictionaryForm: false,
      subConditions: ["n_wa", "n_li"]
    },
    n_wa: {
      name: "Noun with \u0648 Prefix",
      isDictionaryForm: false
    },
    n_bi: {
      name: "Noun with \u0628 Prefix",
      isDictionaryForm: false
    },
    n_ka: {
      name: "Noun with \u0643 Prefix",
      isDictionaryForm: false
    },
    n_li: {
      name: "Noun with \u0644 Prefix",
      isDictionaryForm: false
    },
    n_al: {
      name: "Noun with \u0627\u0644 Prefix",
      isDictionaryForm: false
    },
    n_bi_al: {
      name: "Noun with \u0628\u0627\u0644 Prefix",
      isDictionaryForm: false
    },
    n_ka_al: {
      name: "Noun with \u0643\u0627\u0644 Prefix",
      isDictionaryForm: false
    },
    n_lil: {
      name: "Noun with \u0644\u0644 Prefix",
      isDictionaryForm: false
    },
    n_li_al: {
      name: "Noun with Assimilated \u0644\u0644 Prefix",
      isDictionaryForm: false
    },
    n_s: {
      name: "Noun with Suffix",
      isDictionaryForm: false
    },
    v: {
      name: "Verb",
      isDictionaryForm: true,
      subConditions: ["pv", "iv", "cv"]
    },
    pv: {
      name: "Perfect Verb (no affixes)",
      isDictionaryForm: true
    },
    pv_p: {
      name: "Perfect Verb with Prefix",
      isDictionaryForm: false
    },
    pv_s: {
      name: "Perfect Verb with Suffix only",
      isDictionaryForm: false
    },
    iv: {
      name: "Imperfect Verb (no affixes)",
      isDictionaryForm: true
    },
    iv_p: {
      name: "Imperfect Verb with Prefix",
      isDictionaryForm: false
    },
    iv_s: {
      name: "Imperfect Verb with Suffix only",
      isDictionaryForm: false
    },
    cv: {
      name: "Command Verb (no affixes)",
      isDictionaryForm: true
    },
    cv_p: {
      name: "Command Verb with Prefix",
      isDictionaryForm: false
    },
    cv_s: {
      name: "Command Verb with Suffix only",
      isDictionaryForm: false
    }
  };
  var arabicTransforms = {
    language: "ar",
    conditions,
    transforms: {
      // Noun
      "NPref-Wa": {
        name: "and",
        description: "and (\u0648); and, so (\u0641)",
        rules: [
          prefixInflection("\u0648", "", ["n_wa"], ["n"]),
          prefixInflection("\u0641", "", ["n_wa"], ["n"])
        ]
      },
      "NPref-Bi": {
        name: "by, with",
        description: "by, with",
        rules: [
          prefixInflection("\u0628", "", ["n_bi"], ["n"]),
          prefixInflection("\u0648\u0628", "", ["n_bi"], ["n"]),
          prefixInflection("\u0641\u0628", "", ["n_bi"], ["n"])
        ]
      },
      "NPref-Ka": {
        name: "like, such as",
        description: "like, such as",
        rules: [
          prefixInflection("\u0643", "", ["n_ka"], ["n"]),
          prefixInflection("\u0648\u0643", "", ["n_ka"], ["n"]),
          prefixInflection("\u0641\u0643", "", ["n_ka"], ["n"])
        ]
      },
      "NPref-Li": {
        name: "for, to; indeed, truly",
        description: "for, to (\u0644\u0650); indeed, truly (\u0644\u064E)",
        rules: [
          prefixInflection("\u0644", "", ["n_li"], ["n"]),
          prefixInflection("\u0648\u0644", "", ["n_li"], ["n"]),
          prefixInflection("\u0641\u0644", "", ["n_li"], ["n"])
        ]
      },
      "NPref-Al": {
        name: "the",
        description: "the",
        rules: [
          prefixInflection("\u0627\u0644", "", ["n_al"], ["n"]),
          prefixInflection("\u0648\u0627\u0644", "", ["n_al"], ["n"]),
          prefixInflection("\u0641\u0627\u0644", "", ["n_al"], ["n"])
        ]
      },
      "NPref-BiAl": {
        name: "by/with + the",
        description: "by/with + the",
        rules: [
          prefixInflection("\u0628\u0627\u0644", "", ["n_bi_al"], ["n"]),
          prefixInflection("\u0648\u0628\u0627\u0644", "", ["n_bi_al"], ["n"]),
          prefixInflection("\u0641\u0628\u0627\u0644", "", ["n_bi_al"], ["n"])
        ]
      },
      "NPref-KaAl": {
        name: "like/such as + the",
        description: "like/such as + the",
        rules: [
          prefixInflection("\u0643\u0627\u0644", "", ["n_ka_al"], ["n"]),
          prefixInflection("\u0648\u0643\u0627\u0644", "", ["n_ka_al"], ["n"]),
          prefixInflection("\u0641\u0643\u0627\u0644", "", ["n_ka_al"], ["n"])
        ]
      },
      "NPref-Lil": {
        name: "for/to + the",
        description: "for/to + the",
        rules: [
          conditionalPrefixInflection("\u0644\u0644", "", "(?!\u0644)", ["n_lil"], ["n"]),
          conditionalPrefixInflection("\u0648\u0644\u0644", "", "(?!\u0644)", ["n_lil"], ["n"]),
          conditionalPrefixInflection("\u0641\u0644\u0644", "", "(?!\u0644)", ["n_lil"], ["n"])
        ]
      },
      "NPref-LiAl": {
        name: "for/to + the",
        description: "for/to + the, assimilated with initial \u0644",
        rules: [
          prefixInflection("\u0644\u0644", "\u0644", ["n_li_al"], ["n"]),
          prefixInflection("\u0648\u0644\u0644", "\u0644", ["n_li_al"], ["n"]),
          prefixInflection("\u0641\u0644\u0644", "\u0644", ["n_li_al"], ["n"])
        ]
      },
      "NSuff-h": {
        name: "pos. pron.",
        description: "possessive pronoun",
        rules: [
          ...nonAssimilatingPossessivePronouns.map((p) => suffixInflection(p, "", ["n_s"], ["n_indef", "n"])),
          conditionalSuffixInflection("\u064A", "", "(?<!\u064A)", ["n_s"], ["n_indef", "n"])
        ]
      },
      "NSuff-ap": {
        name: "fem. sg.",
        description: "fem. sg.",
        rules: [
          suffixInflection("\u0629", "", ["n_s"], ["n_p", "n"])
        ]
      },
      "NSuff-ath": {
        name: "fem. sg. + pos. pron.",
        description: "fem. sg. + possessive pronoun",
        rules: [
          ...possessivePronouns.map((p) => suffixInflection(`\u062A${p}`, "", ["n_s"], ["n_indef", "n"])),
          ...possessivePronouns.map((p) => suffixInflection(`\u062A${p}`, "\u0629", ["n_s"], ["n_indef", "n"]))
        ]
      },
      "NSuff-AF": {
        name: "acc. indef.",
        description: "accusative indefinite (\u0627\u064B)",
        rules: [
          suffixInflection("\u0627", "", ["n_s"], ["n_wa", "n"]),
          suffixInflection("\u0627\u064B", "", ["n_s"], ["n_wa", "n"]),
          suffixInflection("\u064B\u0627", "", ["n_s"], ["n_wa", "n"])
        ]
      },
      "NSuff-An": {
        name: "dual",
        description: "nominative m. dual",
        rules: [
          suffixInflection("\u0627\u0646", "", ["n_s"], ["n_nom", "n"]),
          suffixInflection("\u0622\u0646", "\u0623", ["n_s"], ["n_nom", "n"])
        ]
      },
      "NSuff-Ah": {
        name: "dual + pos. pron.",
        description: "nominative m. dual + possessive pronoun",
        rules: [
          suffixInflection("\u0627", "", ["n_s"], ["n_nom_indef", "n"]),
          suffixInflection("\u0622", "\u0623", ["n_s"], ["n_nom_indef", "n"]),
          ...possessivePronouns.map((p) => suffixInflection(`\u0627${p}`, "", ["n_s"], ["n_nom_indef", "n"])),
          ...possessivePronouns.map((p) => suffixInflection(`\u0622${p}`, "\u0623", ["n_s"], ["n_nom_indef", "n"]))
        ]
      },
      "NSuff-ayn": {
        name: "dual",
        description: "accusative/genitive m. dual",
        rules: [
          suffixInflection("\u064A\u0646", "", ["n_s"], ["n_p", "n"])
        ]
      },
      "NSuff-ayh": {
        name: "dual + pos. pron.",
        description: "accusative/genitive m. dual + possessive pronoun",
        rules: [
          suffixInflection("\u064A", "", ["n_s"], ["n_indef", "n"]),
          ...nonAssimilatingPossessivePronouns.map((p) => suffixInflection(`\u064A${p}`, "", ["n_s"], ["n_indef", "n"]))
        ]
      },
      "NSuff-atAn": {
        name: "dual",
        description: "nominative f. dual",
        rules: [
          suffixInflection("\u062A\u0627\u0646", "", ["n_s"], ["n_nom", "n"]),
          suffixInflection("\u062A\u0627\u0646", "\u0629", ["n_s"], ["n_nom", "n"])
        ]
      },
      "NSuff-atAh": {
        name: "dual + pos. pron.",
        description: "nominative f. dual + possessive pronoun",
        rules: [
          suffixInflection("\u062A\u0627", "", ["n_s"], ["n_nom_indef", "n"]),
          suffixInflection("\u062A\u0627", "\u0629", ["n_s"], ["n_nom_indef", "n"]),
          ...possessivePronouns.map((p) => suffixInflection(`\u062A\u0627${p}`, "", ["n_s"], ["n_nom_indef", "n"])),
          ...possessivePronouns.map((p) => suffixInflection(`\u062A\u0627${p}`, "\u0629", ["n_s"], ["n_nom_indef", "n"]))
        ]
      },
      "NSuff-tayn": {
        name: "dual",
        description: "accusative/genitive f. dual",
        rules: [
          suffixInflection("\u062A\u064A\u0646", "", ["n_s"], ["n_p", "n"]),
          suffixInflection("\u062A\u064A\u0646", "\u0629", ["n_s"], ["n_p", "n"])
        ]
      },
      "NSuff-tayh": {
        name: "dual + pos. pron.",
        description: "accusative/genitive f. dual + possessive pronoun",
        rules: [
          suffixInflection("\u062A\u064A", "", ["n_s"], ["n_indef", "n"]),
          suffixInflection("\u062A\u064A", "\u0629", ["n_s"], ["n_indef", "n"]),
          ...nonAssimilatingPossessivePronouns.map((p) => suffixInflection(`\u062A\u064A${p}`, "", ["n_s"], ["n_indef", "n"])),
          ...nonAssimilatingPossessivePronouns.map((p) => suffixInflection(`\u062A\u064A${p}`, "\u0629", ["n_s"], ["n_indef", "n"]))
        ]
      },
      "NSuff-At": {
        name: "f. pl.",
        description: "sound f. plural",
        rules: [
          suffixInflection("\u0627\u062A", "", ["n_s"], ["n_p", "n"]),
          suffixInflection("\u0627\u062A", "\u0629", ["n_s"], ["n_p", "n"]),
          suffixInflection("\u0622\u062A", "\u0623", ["n_s"], ["n_p", "n"]),
          suffixInflection("\u0622\u062A", "\u0623\u0629", ["n_s"], ["n_p", "n"])
        ]
      },
      "NSuff-Ath": {
        name: "f. pl. + pos. pron.",
        description: "sound f. plural + possessive pronoun",
        rules: [
          ...possessivePronouns.map((p) => suffixInflection(`\u0627\u062A${p}`, "", ["n_s"], ["n_indef", "n"])),
          ...possessivePronouns.map((p) => suffixInflection(`\u0627\u062A${p}`, "\u0629", ["n_s"], ["n_indef", "n"])),
          ...possessivePronouns.map((p) => suffixInflection(`\u0622\u062A${p}`, "\u0623", ["n_s"], ["n_indef", "n"])),
          ...possessivePronouns.map((p) => suffixInflection(`\u0622\u062A${p}`, "\u0623\u0629", ["n_s"], ["n_indef", "n"]))
        ]
      },
      "NSuff-wn": {
        name: "m. pl.",
        description: "nominative sound m. plural",
        rules: [
          suffixInflection("\u0648\u0646", "", ["n_s"], ["n_nom", "n"])
        ]
      },
      "NSuff-wh": {
        name: "m. pl + pos. pron.",
        description: "nominative sound m. plural + possessive pronoun",
        rules: [
          suffixInflection("\u0648", "", ["n_s"], ["n_nom_indef", "n"]),
          ...nonAssimilatingPossessivePronouns.map((p) => suffixInflection(`\u0648${p}`, "", ["n_s"], ["n_nom_indef", "n"]))
        ]
      },
      "NSuff-iyn": {
        name: "m. pl.",
        description: "accusative/genitive sound m. plural",
        rules: [
          suffixInflection("\u064A\u0646", "", ["n_s"], ["n_p", "n"])
        ]
      },
      "NSuff-iyh": {
        name: "m. pl. + pos. pron.",
        description: "accusative/genitive sound m. plural + possessive pronoun",
        rules: [
          suffixInflection("\u064A", "", ["n_s"], ["n_indef", "n"]),
          ...nonAssimilatingPossessivePronouns.map((p) => suffixInflection(`\u064A${p}`, "", ["n_s"], ["n_indef", "n"]))
        ]
      },
      // Perfect Verb
      "PVPref-Wa": {
        name: "and",
        description: "and (\u0648); and, so (\u0641)",
        rules: [
          prefixInflection("\u0648", "", ["pv_p"], ["pv_s", "pv"]),
          prefixInflection("\u0641", "", ["pv_p"], ["pv_s", "pv"])
        ]
      },
      "PVPref-La": {
        name: "would have",
        description: "Result clause particle (if ... I would have ...)",
        rules: [prefixInflection("\u0644", "", ["pv_p"], ["pv_s", "pv"])]
      },
      "PVSuff-ah": {
        name: "Perfect Tense",
        description: "Perfect Verb + D.O pronoun",
        rules: directObjectPronouns.map((p) => suffixInflection(p, "", ["pv_s"], ["pv"]))
      },
      "PVSuff-n": {
        name: "Perfect Tense",
        description: "Perfect Verb suffixes assimilating with \u0646",
        rules: [
          // Stem doesn't end in ن
          conditionalSuffixInflection("\u0646", "", "(?<!\u0646)", ["pv_s"], ["pv"]),
          ...directObjectPronouns.map((p) => conditionalSuffixInflection(`\u0646${p}`, "", "(?<!\u0646)", ["pv_s"], ["pv"])),
          conditionalSuffixInflection("\u0646\u0627", "", "(?<!\u0646)", ["pv_s"], ["pv"]),
          ...directObjectPronouns2nd.map((p) => conditionalSuffixInflection(`\u0646\u0627${p}`, "", "(?<!\u0646)", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => conditionalSuffixInflection(`\u0646\u0627${p}`, "", "(?<!\u0646)", ["pv_s"], ["pv"])),
          // Suffixes assimilated with stems ending in ن
          ...directObjectPronouns.map((p) => suffixInflection(`\u0646${p}`, "\u0646", ["pv_s"], ["pv"])),
          suffixInflection("\u0646\u0627", "\u0646", ["pv_s"], ["pv"]),
          ...directObjectPronouns2nd.map((p) => suffixInflection(`\u0646\u0627${p}`, "\u0646", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u0646\u0627${p}`, "\u0646", ["pv_s"], ["pv"]))
        ]
      },
      "PVSuff-t": {
        name: "Perfect Tense",
        description: "Perfect Verb suffixes assimilating with \u062A",
        rules: [
          // This can either be 3rd p. f. singular, or 1st/2nd p. singular
          // The former doesn't assimilate, the latter do, so the below accounts for both
          suffixInflection("\u062A", "", ["pv_s"], ["pv"]),
          ...directObjectPronouns.map((p) => suffixInflection(`\u062A${p}`, "", ["pv_s"], ["pv"])),
          // Stem doesn't end in ت
          conditionalSuffixInflection("\u062A\u0645\u0627", "", "(?<!\u062A)", ["pv_s"], ["pv"]),
          ...directObjectPronouns1st.map((p) => conditionalSuffixInflection(`\u062A\u0645\u0627${p}`, "", "(?<!\u062A)", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => conditionalSuffixInflection(`\u062A\u0645\u0627${p}`, "", "(?<!\u062A)", ["pv_s"], ["pv"])),
          conditionalSuffixInflection("\u062A\u0645", "", "(?<!\u062A)", ["pv_s"], ["pv"]),
          ...directObjectPronouns1st.map((p) => conditionalSuffixInflection(`\u062A\u0645\u0648${p}`, "", "(?<!\u062A)", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => conditionalSuffixInflection(`\u062A\u0645\u0648${p}`, "", "(?<!\u062A)", ["pv_s"], ["pv"])),
          conditionalSuffixInflection("\u062A\u0646", "", "(?<!\u062A)", ["pv_s"], ["pv"]),
          ...directObjectPronouns1st.map((p) => conditionalSuffixInflection(`\u062A\u0646${p}`, "", "(?<!\u062A)", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => conditionalSuffixInflection(`\u062A\u0646${p}`, "", "(?<!\u062A)", ["pv_s"], ["pv"])),
          // Suffixes assimilated with stems ending in ت
          ...directObjectPronouns.map((p) => suffixInflection(`\u062A${p}`, "\u062A", ["pv_s"], ["pv"])),
          suffixInflection("\u062A\u0645\u0627", "\u062A", ["pv_s"], ["pv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u062A\u0645\u0627${p}`, "\u062A", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u062A\u0645\u0627${p}`, "\u062A", ["pv_s"], ["pv"])),
          suffixInflection("\u062A\u0645", "\u062A", ["pv_s"], ["pv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u062A\u0645\u0648${p}`, "\u062A", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u062A\u0645\u0648${p}`, "\u062A", ["pv_s"], ["pv"])),
          suffixInflection("\u062A\u0646", "\u062A", ["pv_s"], ["pv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u062A\u0646${p}`, "\u062A", ["pv_s"], ["pv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u062A\u0646${p}`, "\u062A", ["pv_s"], ["pv"]))
        ]
      },
      "PVSuff-at": {
        name: "Perfect Tense",
        description: "Perfect Verb non-assimilating \u062A suffixes",
        rules: [
          suffixInflection("\u062A\u0627", "", ["pv_s"], ["pv"]),
          ...directObjectPronouns.map((p) => suffixInflection(`\u062A\u0627${p}`, "", ["pv_s"], ["pv"]))
        ]
      },
      "PVSuff-A": {
        name: "Perfect Tense",
        description: "Perfect Verb 3rd. m. dual",
        rules: [
          suffixInflection("\u0627", "", ["pv_s"], ["pv"]),
          ...directObjectPronouns.map((p) => suffixInflection(`\u0627${p}`, "", ["pv_s"], ["pv"])),
          // Combines with أ to form آ
          suffixInflection("\u0622", "\u0623", ["pv_s"], ["pv"]),
          ...directObjectPronouns.map((p) => suffixInflection(`\u0622${p}`, "\u0623", ["pv_s"], ["pv"]))
        ]
      },
      "PVSuff-uw": {
        name: "Perfect Tense",
        description: "Perfect Verb 3rd. m. pl.",
        rules: [
          suffixInflection("\u0648\u0627", "", ["pv_s"], ["pv"]),
          ...directObjectPronouns.map((p) => suffixInflection(`\u0648${p}`, "", ["pv_s"], ["pv"]))
        ]
      },
      // Imperfect Verb
      "IVPref-hw": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 3rd. m. sing.",
        rules: [...getImperfectRules("\u064A", "", "", "")]
      },
      "IVPref-hy": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 3rd. f. sing.",
        rules: [...getImperfectRules("\u062A", "", "", "")]
      },
      "IVPref-hmA": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 3rd. m. dual",
        rules: [
          // Indicative
          ...getImperfectRules("\u064A", "", "\u0627\u0646", "", { includeLiPrefix: false }),
          ...getImperfectRules("\u064A", "", "\u0622\u0646", "\u0623", { includeLiPrefix: false }),
          // Subjunctive
          ...getImperfectRules("\u064A", "", "\u0627", ""),
          ...getImperfectRules("\u064A", "", "\u0622", "\u0623")
        ]
      },
      "IVPref-hmA-ta": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 3rd. f. dual",
        rules: [
          // Indicative
          ...getImperfectRules("\u062A", "", "\u0627\u0646", "", { includeLiPrefix: false }),
          ...getImperfectRules("\u062A", "", "\u0622\u0646", "\u0623", { includeLiPrefix: false }),
          // Subjunctive
          ...getImperfectRules("\u062A", "", "\u0627", ""),
          ...getImperfectRules("\u062A", "", "\u0622", "\u0623")
        ]
      },
      "IVPref-hm": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 3rd. m. pl.",
        rules: [
          // Indicative
          ...getImperfectRules("\u064A", "", "\u0648\u0646", "", { includeLiPrefix: false }),
          // Subjunctive
          ...getImperfectRules("\u064A", "", "\u0648\u0627", "", { attachedSuffix: "\u0648" })
        ]
      },
      "IVPref-hn": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 3rd. f. pl.",
        rules: [
          ...getImperfectRules("\u064A", "", "\u0646", "", { finalStemSegment: "(?<!\u0646)" }),
          ...getImperfectRules("\u064A", "", "\u0646", "\u0646")
        ]
      },
      "IVPref-Anta": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 2nd. m. sing.",
        rules: [...getImperfectRules("\u062A", "", "", "", { attachesTo2nd: false })]
      },
      "IVPref-Anti": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 2nd. f. sing.",
        rules: [
          ...getImperfectRules("\u062A", "", "\u064A\u0646", "", { attachesTo2nd: false, includeLiPrefix: false }),
          // Indicative
          ...getImperfectRules("\u062A", "", "\u064A", "", { attachesTo2nd: false })
          // Subjunctive
        ]
      },
      "IVPref-AntmA": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 2nd. dual",
        rules: [
          // Indicative
          ...getImperfectRules("\u062A", "", "\u0627\u0646", "", { attachesTo2nd: false, includeLiPrefix: false }),
          ...getImperfectRules("\u062A", "", "\u0622\u0646", "\u0623", { attachesTo2nd: false, includeLiPrefix: false }),
          // Subjunctive
          ...getImperfectRules("\u062A", "", "\u0627", "", { attachesTo2nd: false }),
          ...getImperfectRules("\u062A", "", "\u0622", "\u0623", { attachesTo2nd: false })
        ]
      },
      "IVPref-Antm": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 2nd. m. pl.",
        rules: [
          // Indicative
          ...getImperfectRules("\u062A", "", "\u0648\u0646", "", { attachesTo2nd: false, includeLiPrefix: false }),
          // Subjunctive
          ...getImperfectRules("\u062A", "", "\u0648\u0627", "", { attachesTo2nd: false, attachedSuffix: "\u0648" })
        ]
      },
      "IVPref-Antn": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 2nd. f. pl.",
        rules: [
          ...getImperfectRules("\u062A", "", "\u0646", "", { attachesTo2nd: false, finalStemSegment: "(?<!\u0646)" }),
          ...getImperfectRules("\u062A", "", "\u0646", "\u0646", { attachesTo2nd: false })
        ]
      },
      "IVPref-AnA": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 1st. sing.",
        rules: [
          ...getImperfectRules("\u0623", "", "", "", { attachesTo1st: false }),
          ...getImperfectRules("\u0622", "\u0623", "", "", { attachesTo1st: false })
        ]
      },
      "IVPref-nHn": {
        name: "Imperfect Tense",
        description: "Imperfect Verb 1st. pl.",
        rules: [...getImperfectRules("\u0646", "", "", "", { attachesTo1st: false })]
      },
      // Command Verb
      "CVPref": {
        name: "Imperative",
        description: "Command Verb",
        rules: [
          prefixInflection("\u0648", "", ["cv_p"], ["cv_s"]),
          prefixInflection("\u0641", "", ["cv_p"], ["cv_s"]),
          prefixInflection("\u0627", "", ["cv_p"], ["cv_s", "cv"]),
          prefixInflection("\u0648\u0627", "", ["cv_p"], ["cv_s", "cv"]),
          prefixInflection("\u0641\u0627", "", ["cv_p"], ["cv_s", "cv"])
        ]
      },
      "CVSuff": {
        name: "Imperative",
        description: "Command Verb",
        rules: [
          // 2nd. m. sing.
          ...directObjectPronouns1st.map((p) => suffixInflection(p, "", ["cv_s"], ["cv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(p, "", ["cv_s"], ["cv"])),
          // 2nd. f. sing
          suffixInflection("\u064A", "", ["cv_s"], ["cv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u064A${p}`, "", ["cv_s"], ["cv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u064A${p}`, "", ["cv_s"], ["cv"])),
          // 2nd. dual
          suffixInflection("\u0627", "", ["cv_s"], ["cv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u0627${p}`, "", ["cv_s"], ["cv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u0627${p}`, "", ["cv_s"], ["cv"])),
          // 2nd. m. pl.
          suffixInflection("\u0648\u0627", "", ["cv_s"], ["cv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u0648${p}`, "", ["cv_s"], ["cv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u0648${p}`, "", ["cv_s"], ["cv"])),
          // 2nd. f. pl.
          suffixInflection("\u0646", "", ["cv_s"], ["cv"]),
          ...directObjectPronouns1st.map((p) => suffixInflection(`\u0646${p}`, "", ["cv_s"], ["cv"])),
          ...directObjectPronouns3rd.map((p) => suffixInflection(`\u0646${p}`, "", ["cv_s"], ["cv"]))
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/ar.js
  globalThis.mangatanRegisterYomitanTransforms("ar", arabicTransforms);
  globalThis.mangatanRegisterYomitanTransforms("arz", arabicTransforms);
})();
