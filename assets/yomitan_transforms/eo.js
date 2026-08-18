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

  // third_party/yomitan/ext/js/language/eo/esperanto-transforms.js
  var conditions = {
    n: {
      name: "Noun",
      isDictionaryForm: true
    },
    adj: {
      name: "Adjective",
      isDictionaryForm: true
    },
    adv: {
      name: "Adverb",
      isDictionaryForm: true
    },
    v: {
      name: "Verb",
      isDictionaryForm: true
    }
  };
  var esperantoTransforms = {
    language: "eo",
    conditions,
    transforms: {
      // general inflections
      "accusative": {
        name: "accusative",
        description: "Accusative form of a word",
        rules: [
          suffixInflection("n", "", [], [])
        ]
      },
      "plural": {
        name: "plural",
        description: "Plural form of a word",
        rules: [
          suffixInflection("j", "", [], [])
        ]
      },
      "diminutive": {
        name: "diminutive",
        description: "Diminutive form of a noun",
        rules: [
          suffixInflection("eto", "o", [], ["n"])
        ]
      },
      "directional": {
        name: "directional",
        description: [
          "An adverb in accusative case indicates direction",
          "kie: where",
          "kien: to where"
        ].join("\n"),
        rules: [
          suffixInflection("en", "e", [], ["adv"])
        ]
      },
      "locational": {
        name: "locational",
        description: [
          "A noun becoming an adverb indicates location",
          "surpinto : peak, tip, top",
          "surpinte: at the peak, at the tip, at the top",
          "\u0109ambro : room",
          "\u0109ambre: at the room, in the room"
        ].join("\n"),
        rules: [
          suffixInflection("e", "o", [], ["n"])
        ]
      },
      "adjectival": {
        name: "adjectival",
        description: "Adjectival form of a noun",
        rules: [
          suffixInflection("a", "o", [], ["n"])
        ]
      },
      "adverbial (adj -> adv)": {
        name: "adverbial",
        description: "Adverbial form of an adjective",
        rules: [
          suffixInflection("e", "a", [], ["adj"])
        ]
      },
      "adverbial (v -> adv)": {
        name: "adverbial",
        description: "Adverbial form of a verb",
        rules: [
          suffixInflection("e", "i", [], ["v"])
        ]
      },
      // suffixes
      "-ejo (noun)": {
        name: "-ejo",
        description: [
          "Suffix which turns a word into a place designed for that specific thing",
          "kafo: coffee",
          "kafejo: caf\xE9"
        ].join("\n"),
        rules: [
          suffixInflection("ejo", "o", [], ["n"])
        ]
      },
      "-ejo (verb)": {
        name: "-ejo",
        description: [
          "Suffix which turns a word into a place designed for that specific action",
          "kuiri: to cook",
          "kuirejo: kitchen"
        ].join("\n"),
        rules: [
          suffixInflection("ejo", "i", [], ["v"])
        ]
      },
      "-ujo (noun)": {
        name: "-ujo",
        description: [
          "Suffix which turns a word into a box or container for that specific thing",
          "abelo: a bee",
          "abelujo: a beehive",
          "",
          "Suffix which turns a word into a place where a type of people can be found",
          "patro: father",
          "patrujo: fatherland",
          "",
          "Suffix which turns a flower or fruit into a plant or tree which the flower or fruit can be found in",
          "pomo: an apple",
          "pomujo: an apple tree"
        ].join("\n"),
        rules: [
          suffixInflection("ujo", "o", [], ["n"])
        ]
      },
      "-ujo (adjective)": {
        name: "-ujo",
        description: [
          "Suffix which turns a descriptive word into a box or container for that specific type of thing",
          "frida: cold",
          "fridujo: a refrigerator"
        ].join("\n"),
        rules: [
          suffixInflection("ujo", "a", [], ["adj"])
        ]
      },
      "-ujo (verb)": {
        name: "-ujo",
        description: [
          "Suffix which turns an action into a box or container for that specific type of activity",
          "lavi: to wash",
          "lavujo: a sink"
        ].join("\n"),
        rules: [
          suffixInflection("ujo", "i", [], ["v"])
        ]
      },
      "-ebla": {
        name: "-ebla",
        description: [
          "Suffix which shows possibility",
          "kompreni: to understand",
          "komprenebla: understandable"
        ].join("\n"),
        rules: [
          suffixInflection("ebla", "i", [], ["v"])
        ]
      },
      "-ado": {
        name: "-ado",
        description: [
          "Suffix which turns an action into a thing representing the action",
          "vivi: to live",
          "vivado: life",
          "spiri: to breathe",
          "spirado: respiration"
        ].join("\n"),
        rules: [
          suffixInflection("ado", "i", [], ["v"])
        ]
      },
      // prefixes
      "mal-": {
        name: "mal-",
        description: "Prefix which turns an action, description, thing, or direction into its opposite meaning",
        rules: [
          prefixInflection("mal", "", [], [])
        ]
      },
      "kun-": {
        name: "kun-",
        description: [
          "Prefix meaning to do the action together with other people",
          "labori: to work",
          "kunlabori: to collaborate"
        ].join("\n"),
        rules: [
          prefixInflection("kun", "", [], [])
        ]
      },
      "ekster-": {
        name: "ekster-",
        description: [
          'Prefix meaning "outside of"',
          "lando: country",
          "eksterlando: foreign country"
        ].join("\n"),
        rules: [
          prefixInflection("ekster", "", [], [])
        ]
      },
      "ek-": {
        name: "ek-",
        description: [
          "Prefix meaning to begin the action",
          "kanti: to sing",
          "ekkanti: to begin to sing"
        ].join("\n"),
        rules: [
          prefixInflection("ek", "", [], [])
        ]
      },
      "\u0135us-": {
        name: "\u0135us-",
        description: [
          "Prefix meaning something is newly or recently done",
          "vekita: awakened",
          "\u0135usvekita: newly/recently awakened"
        ].join("\n"),
        rules: [
          prefixInflection("\u0135us", "", [], [])
        ]
      },
      "el-": {
        name: "el-",
        description: [
          "Prefix meaning to do the action in an outward direction",
          "tiri: to pull",
          "eltiri: to pull out",
          "",
          "Prefix meaning to do the action all the way to completion",
          "trinki: to drink",
          "eltrinki: to drink up, to drink all of something",
          "lerni: to learn",
          "ellerni: to learn all that you can, to master",
          "uzi: to use",
          "eluzi: to use up, wear out"
        ].join("\n"),
        rules: [
          prefixInflection("el", "", [], [])
        ]
      },
      "dis-": {
        name: "dis-",
        description: [
          'Prefix meaning "separation, being apart, spreading out"',
          "\u015Dvebi: to float",
          "dis\u015Dvebi: to float out/separately",
          "fali: to fall",
          "disfali: to fall apart",
          "doni: to give",
          "disdoni: to give out, to distribute",
          "sendo: a thing that is sent",
          "dissendo: a broadcast"
        ].join("\n"),
        rules: [
          prefixInflection("dis", "", [], [])
        ]
      },
      "for-": {
        name: "for-",
        description: [
          'Prefix meaning "movement to a far distance"',
          "flugi: to fly",
          "forflugi: to fly away",
          "",
          'Prefix meaning "disappearance/annihilation"',
          "uzi: to use",
          "foruzi: to use up (until nothing is left)"
        ].join("\n"),
        rules: [
          prefixInflection("for", "", [], [])
        ]
      },
      "mis-": {
        name: "mis-",
        description: [
          'Prefix meaning "wrong, erroneous"',
          "kompreni: to understand",
          "miskompreni: to misunderstand",
          "paroli: to speak",
          "misparoli: to misspeak"
        ].join("\n"),
        rules: [
          prefixInflection("mis", "", [], [])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/eo.js
  globalThis.mangatanRegisterYomitanTransforms("eo", esperantoTransforms);
})();
