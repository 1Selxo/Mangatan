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

  // third_party/yomitan/ext/js/language/ko/korean-transforms.js
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true,
      i18n: [
        {
          language: "ko",
          name: "\uB3D9\uC0AC / \uBCF4\uC870 \uB3D9\uC0AC"
        }
      ]
    },
    adj: {
      name: "Adjective",
      isDictionaryForm: true,
      i18n: [
        {
          language: "ko",
          name: "\uD615\uC6A9\uC0AC / \uBCF4\uC870 \uD615\uC6A9\uC0AC"
        }
      ]
    },
    ida: {
      name: "Postpositional particle ida",
      isDictionaryForm: true,
      i18n: [
        {
          language: "ko",
          name: "\uC870\uC0AC \uC774\uB2E4"
        }
      ]
    },
    p: {
      name: "Intermediate past tense ending",
      isDictionaryForm: false
    },
    f: {
      name: "Intermediate future tense ending",
      isDictionaryForm: false
    },
    eusi: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    euob: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    euo: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    sao: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    saob: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    sab: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    jaob: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    jao: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    jab: {
      name: "Intermediate formal ending",
      isDictionaryForm: false
    },
    do: {
      name: "Intermediate ending",
      isDictionaryForm: false
    }
  };
  var koreanTransforms = {
    language: "ko",
    conditions,
    transforms: {
      "\uC5B4\uAC04": {
        name: "\uC5B4\uAC04",
        description: "Stem",
        rules: [
          suffixInflection("\u3142", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3143", "\u3143\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3148", "\u3148\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3149", "\u3149\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3138", "\u3138\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3131", "\u3131\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3132", "\u3132\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3146", "\u3146\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141", "\u3141\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134", "\u3134\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147", "\u3147\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E", "\u314E\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314B", "\u314B\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314C", "\u314C\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314A", "\u314A\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314D", "\u314D\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u315B", "\u315B\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155", "\u3155\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3151", "\u3151\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150", "\u3150\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3152", "\u3152\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3154", "\u3154\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3156", "\u3156\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3157", "\u3157\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3163", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3160", "\u3160\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u315C", "\u315C\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3161", "\u3161\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uAC70\uB098": {
        name: "-\uAC70\uB098",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134\u314F", "", [], ["p", "f", "euob", "eusi"])
        ]
      },
      "-\uAC70\uB298": {
        name: "-\uAC70\uB298",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u3161\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134\u3161\u3139", "", [], ["p", "f", "euob", "eusi"])
        ]
      },
      "-\uAC70\uB2C8": {
        name: "-\uAC70\uB2C8",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134\u3163", "", [], ["p", "f", "euob", "eusi"])
        ]
      },
      "-\uAC70\uB2C8\uC640": {
        name: "-\uAC70\uB2C8\uC640",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u3163\u3147\u3157\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134\u3163\u3147\u3157\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC70\uB358": {
        name: "-\uAC70\uB358",
        rules: [
          suffixInflection("\u3131\u3153\u3137\u3153\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3137\u3153\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC70\uB4DC\uBA74": {
        name: "-\uAC70\uB4DC\uBA74",
        rules: [
          suffixInflection("\u3131\u3153\u3137\u3161\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3137\u3161\u3141\u3155\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC70\uB4E0": {
        name: "-\uAC70\uB4E0",
        rules: [
          suffixInflection("\u3131\u3153\u3137\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3137\u3161\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC70\uB4E4\uB791": {
        name: "-\uAC70\uB4E4\uB791",
        rules: [
          suffixInflection("\u3131\u3153\u3137\u3161\u3139\u3139\u314F\u3147", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3137\u3161\u3139\u3139\u314F\u3147", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC70\uB77C": {
        name: "-\uAC70\uB77C",
        rules: [
          suffixInflection("\u3131\u3153\u3139\u314F", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uAC74": {
        name: "-\uAC74",
        rules: [
          suffixInflection("\u3131\u3153\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134", "", [], ["p", "f", "euob", "eusi"])
        ]
      },
      "-\uAC74\uB300": {
        name: "-\uAC74\uB300",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u3137\u3150", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3131\u3153\u3134\u3137\u3150", "", [], ["p", "eusi", "jaob"])
        ]
      },
      "-\uAC74\uB9C8\uB294": {
        name: "-\uAC74\uB9C8\uB294",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134\u3141\u314F\u3134\u3161\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC74\uB9CC": {
        name: "-\uAC74\uB9CC",
        rules: [
          suffixInflection("\u3131\u3153\u3134\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3134\u3141\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC78\uB791": {
        name: "-\uAC78\uB791",
        rules: [
          suffixInflection("\u3131\u3153\u3139\u3139\u314F\u3147", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3139\u3139\u314F\u3147", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC83\uB2E4": {
        name: "-\uAC83\uB2E4",
        rules: [
          suffixInflection("\u3131\u3153\u3145\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3145\u3137\u314F", "", [], ["p", "eusi"])
        ]
      },
      "-\uAC83\uB9C8\uB294": {
        name: "-\uAC83\uB9C8\uB294",
        rules: [
          suffixInflection("\u3131\u3153\u3145\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3153\u3145\u3141\u314F\u3134\u3161\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAC8C": {
        name: "-\uAC8C",
        rules: [
          suffixInflection("\u3131\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3154", "", [], ["p", "eusi"])
        ]
      },
      "-\uAC8C\uB054": {
        name: "-\uAC8C\uB054",
        rules: [
          suffixInflection("\u3131\u3154\u3132\u3161\u3141", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3131\u3154\u3132\u3161\u3141", "", [], ["eusi"])
        ]
      },
      "-\uAC8C\uB098": {
        name: "-\uAC8C\uB098",
        rules: [
          suffixInflection("\u3131\u3154\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3131\u3154\u3134\u314F", "", [], ["eusi"])
        ]
      },
      "-\uAC8C\uC2DC\uB9AC": {
        name: "-\uAC8C\uC2DC\uB9AC",
        rules: [
          suffixInflection("\u3131\u3154\u3145\u3163\u3139\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3131\u3154\u3145\u3163\u3139\u3163", "", [], ["eusi"])
        ]
      },
      "-\uACA0": {
        name: "-\uACA0",
        rules: [
          suffixInflection("\u3131\u3154\u3146", "\u3137\u314F", ["f"], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3154\u3146", "", ["f"], ["p", "eusi"])
        ]
      },
      "-\uACE0": {
        name: "-\uACE0",
        rules: [
          suffixInflection("\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3157", "", [], ["p", "f", "eusi", "saob", "euob", "euo", "sab", "jaob", "jab"])
        ]
      },
      "-\uACE0\uB294 \uD558\uB2E4": {
        name: "-\uACE0\uB294 \uD558\uB2E4",
        rules: [
          suffixInflection("\u3131\u3157\u3134\u3161\u3134 \u314E\u314F\u3137\u314F", "\u3137\u314F", ["v"], ["v"]),
          suffixInflection("\u3131\u3157\u3134\u3161\u3134 \u314E\u314F\u3137\u314F", "", ["v"], ["eusi"])
        ]
      },
      "-\uACE4 \uD558\uB2E4": {
        name: "-\uACE4 \uD558\uB2E4",
        rules: [
          suffixInflection("\u3131\u3157\u3134 \u314E\u314F\u3137\u314F", "\u3137\u314F", ["v"], ["v"]),
          suffixInflection("\u3131\u3157\u3134 \u314E\u314F\u3137\u314F", "", ["v"], ["eusi"])
        ]
      },
      "-\uACE0\uB294": {
        name: "-\uACE0\uB294",
        rules: [
          suffixInflection("\u3131\u3157\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3131\u3157\u3134\u3161\u3134", "", [], ["eusi"])
        ]
      },
      "-\uACE4": {
        name: "-\uACE4",
        rules: [
          suffixInflection("\u3131\u3157\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3131\u3157\u3134", "", [], ["eusi"])
        ]
      },
      "-\uACE0\uB3C4": {
        name: "-\uACE0\uB3C4",
        rules: [
          suffixInflection("\u3131\u3157\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3157\u3137\u3157", "", [], ["eusi"])
        ]
      },
      "-\uACE0\uB9D0\uACE0": {
        name: "-\uACE0\uB9D0\uACE0",
        rules: [
          suffixInflection("\u3131\u3157\u3141\u314F\u3139\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3157\u3141\u314F\u3139\u3131\u3157", "", [], ["p", "eusi"])
        ]
      },
      "-\uACE0\uC11C": {
        name: "-\uACE0\uC11C",
        rules: [
          suffixInflection("\u3131\u3157\u3145\u3153", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3131\u3157\u3145\u3153", "", [], ["eusi"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3131\u3157\u3145\u3153", "\u3147\u314F\u3134\u3163\u3137\u314F", [], ["adj"])
        ]
      },
      "-\uACE0\uC57C": {
        name: "-\uACE0\uC57C",
        rules: [
          suffixInflection("\u3131\u3157\u3147\u3151", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3131\u3157\u3147\u3151", "", [], ["eusi"])
        ]
      },
      "-\uACE0\uC790": {
        name: "-\uACE0\uC790",
        rules: [
          suffixInflection("\u3131\u3157\u3148\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3131\u3157\u3148\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3131\u3157\u3148\u314F", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3131\u3157\u3148\u314F", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-\uACE0\uC800": {
        name: "-\uACE0\uC800",
        rules: [
          suffixInflection("\u3131\u3157\u3148\u3153", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3131\u3157\u3148\u3153", "", [], ["eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3131\u3157\u3148\u3153", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3131\u3157\u3148\u3153", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-\uAD00\uB370": {
        name: "-\uAD00\uB370",
        rules: [
          suffixInflection("\u3131\u3157\u314F\u3134\u3137\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3157\u314F\u3134\u3137\u3154", "", [], ["p", "eusi"])
        ]
      },
      "-\uAD6C\uB098": {
        name: "-\uAD6C\uB098",
        rules: [
          suffixInflection("\u3131\u315C\u3134\u314F", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3131\u315C\u3134\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAD6C\uB824": {
        name: "-\uAD6C\uB824",
        rules: [
          suffixInflection("\u3131\u315C\u3139\u3155", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u315C\u3139\u3155", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAD6C\uB8CC": {
        name: "-\uAD6C\uB8CC",
        rules: [
          suffixInflection("\u3131\u315C\u3139\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u315C\u3139\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAD6C\uB9CC": {
        name: "-\uAD6C\uB9CC",
        rules: [
          suffixInflection("\u3131\u315C\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u315C\u3141\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAD6C\uBA3C": {
        name: "-\uAD6C\uBA3C",
        rules: [
          suffixInflection("\u3131\u315C\u3141\u3153\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u315C\u3141\u3153\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAD6C\uBA74": {
        name: "-\uAD6C\uBA74",
        rules: [
          suffixInflection("\u3131\u315C\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u315C\u3141\u3155\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAD70": {
        name: "-\uAD70",
        rules: [
          suffixInflection("\u3131\u315C\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u315C\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAE30": {
        name: "-\uAE30",
        rules: [
          suffixInflection("\u3131\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAE30\uB85C": {
        name: "-\uAE30\uB85C",
        rules: [
          suffixInflection("\u3131\u3163\u3139\u3157", "\u3137\u314F", [], ["v", "adj", "ida"])
        ]
      },
      "-\uAE30\uB85C\uB2C8": {
        name: "-\uAE30\uB85C\uB2C8",
        rules: [
          suffixInflection("\u3131\u3163\u3139\u3157\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"])
        ]
      },
      "-\uAE30\uB85C\uC11C": {
        name: "-\uAE30\uB85C\uC11C",
        rules: [
          suffixInflection("\u3131\u3163\u3139\u3157\u3145\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3163\u3139\u3157\u3145\u3153", "", [], ["p"])
        ]
      },
      "-\uAE30\uB85C\uC11C\uB2C8": {
        name: "-\uAE30\uB85C\uC11C\uB2C8",
        rules: [
          suffixInflection("\u3131\u3163\u3139\u3157\u3145\u3153\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3163\u3139\u3157\u3145\u3153\u3134\u3163", "", [], ["p"])
        ]
      },
      "-\uAE30\uB85C\uC120\uB4E4": {
        name: "-\uAE30\uB85C\uC120\uB4E4",
        rules: [
          suffixInflection("\u3131\u3163\u3139\u3157\u3145\u3153\u3134\u3137\u3161\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3163\u3139\u3157\u3145\u3153\u3134\u3137\u3161\u3139", "", [], ["p"])
        ]
      },
      "-\uAE30\uC5D0": {
        name: "-\uAE30\uC5D0",
        rules: [
          suffixInflection("\u3131\u3163\u3147\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3163\u3147\u3154", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uAE38\uB798": {
        name: "-\uAE38\uB798",
        rules: [
          suffixInflection("\u3131\u3163\u3139\u3139\u3150", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3131\u3163\u3139\u3139\u3150", "", [], ["p", "eusi"])
        ]
      },
      "-(\uC73C)\u3139": {
        name: "-(\uC73C)\u3139",
        rules: [
          suffixInflection("\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uAC70\uB098": {
        name: "-(\uC73C)\u3139\uAC70\uB098",
        rules: [
          suffixInflection("\u3139\u3131\u3153\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3131\u3153\u3134\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3153\u3134\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3131\u3153\u3134\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3153\u3134\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3131\u3153\u3134\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3131\u3153\u3134\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3131\u3153\u3134\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3153\u3134\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\u3139\uAC78": {
        name: "-(\uC73C)\u3139\uAC78",
        rules: [
          suffixInflection("\u3139\u3131\u3153\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3131\u3153\u3139", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3153\u3139", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3131\u3153\u3139", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3153\u3139", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3131\u3153\u3139", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3131\u3153\u3139", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3131\u3153\u3139", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3153\u3139", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uAC8C": {
        name: "-(\uC73C)\u3139\uAC8C",
        rules: [
          suffixInflection("\u3139\u3131\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3131\u3154", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3131\u3154", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3131\u3154", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3131\u3154", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\u3139 \uAC70\uC57C": {
        name: "-(\uC73C)\u3139 \uAC70\uC57C",
        rules: [
          suffixInflection("\u3139 \u3131\u3153\u3147\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139 \u3131\u3153\u3147\u3151", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3147\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139 \u3131\u3153\u3147\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3147\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139 \u3131\u3153\u3147\u3151", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139 \u3131\u3153\u3147\u3151", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\u3139 \uAC70\uC608\uC694": {
        name: "-(\uC73C)\u3139 \uAC70\uC608\uC694",
        rules: [
          suffixInflection("\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139 \u3131\u3153\u3147\u3156\u3147\u315B", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\u3139 \uAC83\uC774\uB2E4": {
        name: "-(\uC73C)\u3139 \uAC83\uC774\uB2E4",
        rules: [
          suffixInflection("\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139 \u3131\u3153\u3145\u3147\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\u3139 \uAC83\uC785\uB2C8\uB2E4": {
        name: "-(\uC73C)\u3139 \uAC83\uC785\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139 \u3131\u3153\u3145\u3147\u3163\u3142\u3134\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\u3139 \uAC70\uB2E4": {
        name: "-(\uC73C)\u3139 \uAC70\uB2E4",
        rules: [
          suffixInflection("\u3139 \u3131\u3153\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139 \u3131\u3153\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139 \u3131\u3153\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139 \u3131\u3153\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139 \u3131\u3153\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\u3139 \uAC81\uB2C8\uB2E4": {
        name: "-(\uC73C)\u3139 \uAC81\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139 \u3131\u3153\u3142\u3134\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\u3139\uAED8": {
        name: "-(\uC73C)\u3139\uAED8",
        rules: [
          suffixInflection("\u3139\u3132\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3132\u3154", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u3154", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3132\u3154", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u3154", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u3154", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3132\u3154", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\uB098": {
        name: "-(\uC73C)\uB098",
        rules: [
          suffixInflection("\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3134\u314F", "", [], ["p", "f", "eusi", "sao"])
        ]
      },
      "-\uB098\uB2C8": {
        name: "-\uB098\uB2C8",
        rules: [
          suffixInflection("\u3134\u314F\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u314F\u3134\u3163", "", [], ["p", "f", "eusi", "sab", "euob"])
        ]
      },
      "-(\uC73C)\uB098\uB9C8": {
        name: "-(\uC73C)\uB098\uB9C8",
        rules: [
          suffixInflection("\u3134\u314F\u3141\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u314F\u3141\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u314F\u3141\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u314F\u3141\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u314F\u3141\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u314F\u3141\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u314F\u3141\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u314F\u3141\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u314F\u3141\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uB098\uC774\uAE4C": {
        name: "-\uB098\uC774\uAE4C",
        rules: [
          suffixInflection("\u3134\u314F\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u314F\u3147\u3163\u3132\u314F", "", [], ["p", "f", "eusi", "saob", "euob"])
        ]
      },
      "-\uB098\uC774\uB2E4": {
        name: "-\uB098\uC774\uB2E4",
        rules: [
          suffixInflection("\u3134\u314F\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u314F\u3147\u3163\u3137\u314F", "", [], ["p", "f", "eusi", "saob", "jaob", "jab", "euob"])
        ]
      },
      "-\uB0A8": {
        name: "-\uB0A8",
        rules: [
          suffixInflection("\u3134\u314F\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u314F\u3141", "", [], ["p", "f", "eusi"])
        ]
      },
      "-(\uC73C)\uB0D0": {
        name: "-(\uC73C)\uB0D0",
        rules: [
          suffixInflection("\u3134\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3151", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3151", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3151", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3151", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3151", "", [], ["p", "f", "eusi"])
        ]
      },
      "-(\uC73C)\uB0D0\uACE0": {
        name: "-(\uC73C)\uB0D0\uACE0",
        rules: [
          suffixInflection("\u3134\u3151\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3151\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3151\u3131\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3151\u3131\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3151\u3131\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3151\u3131\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3151\u3131\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3151\u3131\u3157", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3151\u3131\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB108\uB77C": {
        name: "-\uB108\uB77C",
        rules: [
          suffixInflection("\u3134\u3153\u3139\u314F", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uB124": {
        name: "-\uB124",
        rules: [
          suffixInflection("\u3134\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3154", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3154", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB178\uB2C8": {
        name: "-\uB178\uB2C8",
        rules: [
          suffixInflection("\u3134\u3157\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3157\u3134\u3163", "", [], ["p", "f", "eusi", "sab", "euob"])
        ]
      },
      "-\uB178\uB77C": {
        name: "-\uB178\uB77C",
        rules: [
          suffixInflection("\u3134\u3157\u3139\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3157\u3139\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uB178\uB77C\uACE0": {
        name: "-\uB178\uB77C\uACE0",
        rules: [
          suffixInflection("\u3134\u3157\u3139\u314F\u3131\u3157", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uB178\uB77C\uB2C8": {
        name: "-\uB178\uB77C\uB2C8",
        rules: [
          suffixInflection("\u3134\u3157\u3139\u314F\u3134\u3163", "\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uB178\uB77C\uB2C8\uAE4C": {
        name: "-\uB178\uB77C\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3134\u3157\u3139\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uB178\uB77C\uBA74": {
        name: "-\uB178\uB77C\uBA74",
        rules: [
          suffixInflection("\u3134\u3157\u3139\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3157\u3139\u314F\u3141\u3155\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3157\u3139\u314F\u3141\u3155\u3134", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3157\u3139\u314F\u3141\u3155\u3134", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C)\uB1E8": {
        name: "-(\uC73C)\uB1E8",
        rules: [
          suffixInflection("\u3134\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u315B", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u315B", "", [], ["eusi"])
        ]
      },
      "-\uB204": {
        name: "-\uB204",
        rules: [
          suffixInflection("\u3134\u315C", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u315C", "", [], ["p", "f"])
        ]
      },
      "-\uB204\uB098": {
        name: "-\uB204\uB098",
        rules: [
          suffixInflection("\u3134\u315C\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u315C\u3134\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB204\uB9CC": {
        name: "-\uB204\uB9CC",
        rules: [
          suffixInflection("\u3134\u315C\u3141\u314F\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u315C\u3141\u314F\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB204\uBA3C": {
        name: "-\uB204\uBA3C",
        rules: [
          suffixInflection("\u3134\u315C\u3141\u3153\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u315C\u3141\u3153\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB290\uB0D0": {
        name: "-\uB290\uB0D0",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3151", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB290\uB0D0\uACE0": {
        name: "-\uB290\uB0D0\uACE0",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3151\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3151\u3131\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB290\uB1E8": {
        name: "-\uB290\uB1E8",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB290\uB2C8": {
        name: "-\uB290\uB2C8",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB290\uB2C8\uB9CC": {
        name: "-\uB290\uB2C8\uB9CC",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3163\u3141\u314F\u3134 \u3141\u3157\u3145\u314E\u314F\u3137\u314F", "\u3137\u314F", ["v"], ["v", "adj"])
        ]
      },
      "-\uB290\uB77C": {
        name: "-\uB290\uB77C",
        rules: [
          suffixInflection("\u3134\u3161\u3139\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3139\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB290\uB77C\uACE0": {
        name: "-\uB290\uB77C\uACE0",
        rules: [
          suffixInflection("\u3134\u3161\u3139\u314F\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3139\u314F\u3131\u3157", "", [], ["eusi"])
        ]
      },
      "-\uB294": {
        name: "-\uB294",
        rules: [
          suffixInflection("\u3134\u3161\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134", "", [], ["eusi", "f"]),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134", "\uC5C6\uB2E4", [], ["adj"])
        ]
      },
      "-(\uC73C)\u3134": {
        name: "-(\uC73C)\u3134",
        rules: [
          suffixInflection("\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134", "", [], ["eusi", "f"])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uAC00": {
        name: "-(\uC73C/\uB290)\u3134\uAC00",
        rules: [
          suffixInflection("\u3134\u3131\u314F", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3131\u314F", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u314F", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3131\u314F", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u314F", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3131\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3131\u314F", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3131\u314F", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u314F", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3131\u314F", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uAC10": {
        name: "-(\uC73C/\uB290)\u3134\uAC10",
        rules: [
          suffixInflection("\u3134\u3131\u314F\u3141", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3131\u314F\u3141", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u314F\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u314F\u3141", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u314F\u3141", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3131\u314F\u3141", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u314F\u3141", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3131\u314F\u3141", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3131\u314F\u3141", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3131\u314F\u3141", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u314F\u3141", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3131\u314F\u3141", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uAC78": {
        name: "-(\uC73C/\uB290)\u3134\uAC78",
        rules: [
          suffixInflection("\u3134\u3131\u3153\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3131\u3153\u3139", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u3153\u3139", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u3153\u3139", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u3153\u3139", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3131\u3153\u3139", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u3153\u3139", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3131\u3153\u3139", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3131\u3153\u3139", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3131\u3153\u3139", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u3153\u3139", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3131\u3153\u3139", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uACE0": {
        name: "-(\uC73C/\uB290)\u3134\uACE0",
        rules: [
          suffixInflection("\u3134\u3131\u3157", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3131\u3157", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u3157", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u3157", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3131\u3157", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3131\u3157", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3131\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3131\u3157", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u3157", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3131\u3157", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-\uB294\uAD6C\uB098": {
        name: "-\uB294\uAD6C\uB098",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3134\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD6C\uB824": {
        name: "-\uB294\uAD6C\uB824",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3139\u3155", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3139\u3155", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD6C\uB8CC": {
        name: "-\uB294\uAD6C\uB8CC",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3139\u315B", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3139\u315B", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD6C\uB9CC": {
        name: "-\uB294\uAD6C\uB9CC",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3141\u314F\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3141\u314F\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD6C\uBA3C": {
        name: "-\uB294\uAD6C\uBA3C",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3141\u3153\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3141\u3153\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD6C\uBA74": {
        name: "-\uB294\uAD6C\uBA74",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3141\u3155\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD70": {
        name: "-\uB294\uAD70",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB294\uAD88\uB2C8": {
        name: "-\uB294\uAD88\uB2C8",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3153\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u315C\u3153\u3134\u3163", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3131\u315C\u3153\u3134\u3163", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3131\u315C\u3153\u3134\u3163", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-\uB294\uACFC\uB2C8": {
        name: "-\uB294\uACFC\uB2C8",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3131\u3157\u314F\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3131\u3157\u314F\u3134\u3163", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3131\u3157\u314F\u3134\u3163", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3131\u3157\u314F\u3134\u3163", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uB290)\u3134\uB2E4": {
        name: "-(\uB290)\u3134\uB2E4",
        rules: [
          suffixInflection("\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uACE0": {
        name: "-((\uB290)\u3134)\uB2E4\uACE0",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3131\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3131\u3157", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3131\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB098": {
        name: "-((\uB290)\u3134)\uB2E4\uB098",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3134\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3134\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB124": {
        name: "-((\uB290)\u3134)\uB2E4\uB124",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3134\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3134\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3154", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3154", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3134\u3154", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3134\u3154", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB290\uB2C8": {
        name: "-((\uB290)\u3134)\uB2E4\uB290\uB2C8",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3161\u3134\u3163", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3161\u3134\u3163", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3134\u3161\u3134\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB2C8": {
        name: "-((\uB290)\u3134)\uB2E4\uB2C8",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3163", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3163", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3134\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB2C8\uAE4C": {
        name: "-((\uB290)\u3134)\uB2E4\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3134\u3163\u3132\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB354\uB77C": {
        name: "-((\uB290)\u3134)\uB2E4\uB354\uB77C",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3137\u3153\u3139\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3137\u3153\u3139\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3137\u3153\u3139\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3137\u3153\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3137\u3153\u3139\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3137\u3153\u3139\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB9C8\uB294": {
        name: "-((\uB290)\u3134)\uB2E4\uB9C8\uB294",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u314F\u3134\u3161\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u314F\u3134\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141\u314F\u3134\u3161\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uB9CC": {
        name: "-((\uB290)\u3134)\uB2E4\uB9CC",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3141\u314F\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u314F\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u314F\u3134", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141\u314F\u3134", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uBA70": {
        name: "-((\uB290)\u3134)\uB2E4\uBA70",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3141\u3155", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3141\u3155", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u3155", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u3155", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141\u3155", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141\u3155", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uBA74": {
        name: "-((\uB290)\u3134)\uB2E4\uBA74",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u3155\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u3155\u3134", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141\u3155\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uBA74\uC11C": {
        name: "-((\uB290)\u3134)\uB2E4\uBA74\uC11C",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u3155\u3134\u3145\u3153", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141\u3155\u3134\u3145\u3153", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141\u3155\u3134\u3145\u3153", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uC190": {
        name: "-((\uB290)\u3134)\uB2E4\uC190",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3145\u3157\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3145\u3157\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3145\u3157\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3145\u3157\u3134", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141\u3155\u3134\u3145\u3157\u3134", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141\u3155\u3134\u3145\u3157\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uC624": {
        name: "-((\uB290)\u3134)\uB2E4\uC624",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3147\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3147\u3157", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3147\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3147\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E4\uC9C0": {
        name: "-((\uB290)\u3134)\uB2E4\uC9C0",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3148\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3148\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3148\u3163", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3148\u3163", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3148\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3148\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2E8\uB2E4": {
        name: "-((\uB290)\u3134)\uB2E8\uB2E4",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3134\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3134\u3137\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3134\u3137\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2F4": {
        name: "-((\uB290)\u3134)\uB2F4",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3141", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3141", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3137\u314F\u3141", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2F5\uB2C8\uAE4C": {
        name: "-((\uB290)\u3134)\uB2F5\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3142\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3142\u3134\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3142\u3134\u3163\u3132\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2F5\uB2C8\uB2E4": {
        name: "-((\uB290)\u3134)\uB2F5\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3142\u3134\u3163\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3142\u3134\u3163\u3137\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB2F5\uC2DC\uACE0": {
        name: "-((\uB290)\u3134)\uB2F5\uC2DC\uACE0",
        rules: [
          suffixInflection("\u3134\u3137\u314F\u3142\u3145\u3163\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3142\u3145\u3163\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u314F\u3142\u3145\u3163\u3131\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u314F\u3142\u3145\u3163\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3137\u314F\u3142\u3145\u3163\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3142\u3145\u3163\u3131\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB300": {
        name: "-((\uB290)\u3134)\uB300",
        rules: [
          suffixInflection("\u3134\u3137\u3150", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3150", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u3150", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u3150", "", [], ["eusi"]),
          suffixInflection("\u3137\u3150", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u3150", "", [], ["p", "f", "eusi"])
        ]
      },
      "-((\uB290)\u3134)\uB300\uC694": {
        name: "-((\uB290)\u3134)\uB300\uC694",
        rules: [
          suffixInflection("\u3134\u3137\u3150\u3147\u315B", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3150\u3147\u315B", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u3150\u3147\u315B", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u3150\u3147\u315B", "", [], ["eusi"]),
          suffixInflection("\u3137\u3150\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u3150\u3147\u315B", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3137\u3150\u3147\u315B", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3137\u3150\u3147\u315B", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-((\uB290)\u3134)\uB304\uB2E4": {
        name: "-((\uB290)\u3134)\uB304\uB2E4",
        rules: [
          suffixInflection("\u3134\u3137\u3150\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3150\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u3150\u3134\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3137\u3150\u3134\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3137\u3150\u3134\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u3150\u3134\u3137\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uB370": {
        name: "-(\uC73C/\uB290)\u3134\uB370",
        rules: [
          suffixInflection("\u3134\u3137\u3154", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3137\u3154", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3137\u3154", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3137\u3154", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3137\u3154", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3137\u3154", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3137\u3154", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3137\u3154", "", [], ["eusi", "sao"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3154", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3137\u3154", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3137\u3154", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uB381\uC1FC": {
        name: "-(\uC73C/\uB290)\u3134\uB381\uC1FC",
        rules: [
          suffixInflection("\u3134\u3137\u3154\u3142\u3145\u315B", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3137\u3154\u3142\u3145\u315B", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3137\u3154\u3142\u3145\u315B", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3137\u3154\u3142\u3145\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3137\u3154\u3142\u3145\u315B", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3137\u3154\u3142\u3145\u315B", "", [], [])
        ]
      },
      "-\uB294\uB3C4\uB2E4": {
        name: "-\uB294\uB3C4\uB2E4",
        rules: [
          suffixInflection("\u3134\u3161\u3134\u3137\u3157\u3137\u314F", "\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uBC14": {
        name: "-(\uC73C/\uB290)\u3134\uBC14",
        rules: [
          suffixInflection("\u3134\u3142\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3142\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3142\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3142\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3142\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3142\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3142\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3142\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3142\u314F", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3142\u314F", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3142\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3142\u314F", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3142\u314F", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uC9C0": {
        name: "-(\uC73C/\uB290)\u3134\uC9C0",
        rules: [
          suffixInflection("\u3134\u3148\u3163", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3148\u3163", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3161\u3134\u3148\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3148\u3163", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3163", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3148\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3148\u3163", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3148\u3163", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3148\u3163", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3148\u3163", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3148\u3163", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uC9C0\uACE0": {
        name: "-(\uC73C/\uB290)\u3134\uC9C0\uACE0",
        rules: [
          suffixInflection("\u3134\u3148\u3163\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3148\u3163\u3131\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3148\u3163\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3163\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3148\u3163\u3131\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3163\u3131\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3163\u3131\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3148\u3163\u3131\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3163\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3148\u3163\u3131\u3157", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3148\u3163\u3131\u3157", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3148\u3163\u3131\u3157", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C/\uB290)\u3134\uC9C0\uB77C": {
        name: "-(\uC73C/\uB290)\u3134\uC9C0\uB77C",
        rules: [
          suffixInflection("\u3134\u3148\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3148\u3163\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3148\u3163\u3139\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3148\u3163\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3163\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3163\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3148\u3163\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3163\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3148\u3163\u3139\u314F", "", [], ["p", "f", "eusi"]),
          suffixInflection("\u3147\u3163\u3146\u3134\u3161\u3134\u3148\u3163\u3139\u314F", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3134\u3161\u3134\u3148\u3163\u3139\u314F", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-(\uC73C)\uB2C8": {
        name: "-(\uC73C)\uB2C8",
        rules: [
          suffixInflection("\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163", "", [], ["p", "f", "eusi", "euo", "sao", "jao"])
        ]
      },
      "-(\uC73C)\uB2C8\uAE4C": {
        name: "-(\uC73C)\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uB2C8\uAE4C\uB290\uB8E8": {
        name: "-(\uC73C)\uB2C8\uAE4C\uB290\uB8E8",
        rules: [
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3139\u315C", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uB2C8\uAE4C\uB294": {
        name: "-(\uC73C)\uB2C8\uAE4C\uB294",
        rules: [
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134\u3161\u3134", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uB2C8\uAE50": {
        name: "-(\uC73C)\uB2C8\uAE50",
        rules: [
          suffixInflection("\u3134\u3163\u3132\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3132\u314F\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3132\u314F\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3132\u314F\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3132\u314F\u3134", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C/\uB290)\uB2C8\uB77C": {
        name: "-(\uC73C/\uB290)\uB2C8\uB77C",
        rules: [
          suffixInflection("\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3134\u3163\u3139\u314F", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3161\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3139\u314F", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3139\u314F", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3139\u314F", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3163\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3139\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-(\uC73C/\uB290)\uB2C8\uB9CC\uCE58": {
        name: "-(\uC73C/\uB290)\uB2C8\uB9CC\uCE58",
        rules: [
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314A\u3163", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C/\uB290)\uB2C8\uB9CC\uD07C": {
        name: "-(\uC73C/\uB290)\uB2C8\uB9CC\uD07C",
        rules: [
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3161\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["eusi"]),
          suffixInflection("\u3134\u3161\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["p", "f"])
        ]
      },
      "-\uB2E4": {
        name: "-\uB2E4",
        rules: [
          suffixInflection("\u3137\u314F", "", [], ["p", "f", "eusi", "ida"])
        ]
      },
      "-\uB2E4\uAC00": {
        name: "-\uB2E4\uAC00",
        rules: [
          suffixInflection("\u3137\u314F\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3131\u314F", "", [], ["p", "eusi"])
        ]
      },
      "-\uB2E4\uAC00\uB294": {
        name: "-\uB2E4\uAC00\uB294",
        rules: [
          suffixInflection("\u3137\u314F\u3131\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u314F\u3131\u314F\u3134\u3161\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB2E4\uAC04": {
        name: "-\uB2E4\uAC04",
        rules: [
          suffixInflection("\u3137\u314F\u3131\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3131\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB2E4\uB9C8\uB2E4": {
        name: "-\uB2E4\uB9C8\uB2E4",
        rules: [
          suffixInflection("\u3137\u314F\u3141\u314F\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u314F\u3141\u314F\u3137\u314F", "", [], ["p", "eusi"])
        ]
      },
      "-\uB2E4\uC2DC\uD53C": {
        name: "-\uB2E4\uC2DC\uD53C",
        rules: [
          suffixInflection("\u3137\u314F\u3145\u3163\u314D\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u314F\u3145\u3163\u314D\u3163", "", [], ["p", "f"]),
          suffixInflection("\u3147\u3163\u3146\u3137\u314F\u3145\u3163\u314D\u3163", "\uC788\uB2E4", [], []),
          suffixInflection("\u3147\u3153\u3142\u3145\u3137\u314F\u3145\u3163\u314D\u3163", "\uC5C6\uB2E4", [], [])
        ]
      },
      "-\uB2E8": {
        name: "-\uB2E8",
        rules: [
          suffixInflection("\u3137\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354": {
        name: "-\uB354",
        rules: [
          suffixInflection("\u3137\u3153", "\u3137\u314F", ["do"], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153", "", ["do"], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD6C\uB098": {
        name: "-\uB354\uAD6C\uB098",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3134\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD6C\uB824": {
        name: "-\uB354\uAD6C\uB824",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3139\u3155", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3139\u3155", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD6C\uB8CC": {
        name: "-\uB354\uAD6C\uB8CC",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3139\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3139\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD6C\uB9CC": {
        name: "-\uB354\uAD6C\uB9CC",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3141\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD6C\uBA3C": {
        name: "-\uB354\uAD6C\uBA3C",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3141\u3153\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3141\u3153\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD6C\uBA74": {
        name: "-\uB354\uAD6C\uBA74",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3141\u3155\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uAD70": {
        name: "-\uB354\uAD70",
        rules: [
          suffixInflection("\u3137\u3153\u3131\u315C\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3131\u315C\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB0D0": {
        name: "-\uB354\uB0D0",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3151", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB1E8": {
        name: "-\uB354\uB1E8",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB2C8": {
        name: "-\uB354\uB2C8",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3163", "", [], ["p", "f", "eusi", "euob", "euo", "sab"])
        ]
      },
      "-\uB354\uB2C8\uB77C": {
        name: "-\uB354\uB2C8\uB77C",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3163\u3139\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB2C8\uB9C8\uB294": {
        name: "-\uB354\uB2C8\uB9C8\uB294",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3163\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3163\u3141\u314F\u3134\u3161\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB2C8\uB9CC": {
        name: "-\uB354\uB2C8\uB9CC",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3163\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3163\u3141\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB2C8\uC774\uAE4C": {
        name: "-\uB354\uB2C8\uC774\uAE4C",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3163\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3163\u3147\u3163\u3132\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB2C8\uC774\uB2E4": {
        name: "-\uB354\uB2C8\uC774\uB2E4",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3163\u3147\u3163\u3137\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uB77C\uB3C4": {
        name: "-\uB354\uB77C\uB3C4",
        rules: [
          suffixInflection("\u3137\u3153\u3139\u314F\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3139\u314F\u3137\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uC774\uAE4C": {
        name: "-\uB354\uC774\uAE4C",
        rules: [
          suffixInflection("\u3137\u3153\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3147\u3163\u3132\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB354\uC774\uB2E4": {
        name: "-\uB354\uC774\uB2E4",
        rules: [
          suffixInflection("\u3137\u3153\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3147\u3163\u3137\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358": {
        name: "-\uB358",
        rules: [
          suffixInflection("\u3137\u3153\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uAC00": {
        name: "-\uB358\uAC00",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3131\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uAC10": {
        name: "-\uB358\uAC10",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3131\u314F\u3141", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3131\u314F\u3141", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uAC78": {
        name: "-\uB358\uAC78",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3131\u3153\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3131\u3153\u3139", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uACE0": {
        name: "-\uB358\uACE0",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3131\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uB370": {
        name: "-\uB358\uB370",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3137\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3137\u3154", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uB4E4": {
        name: "-\uB358\uB4E4",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3137\u3161\u3139", "", [], ["p"])
        ]
      },
      "-\uB358\uBC14": {
        name: "-\uB358\uBC14",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3142\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3142\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB358\uC9C0": {
        name: "-\uB358\uC9C0",
        rules: [
          suffixInflection("\u3137\u3153\u3134\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3153\u3134\u3148\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB370": {
        name: "-\uB370",
        rules: [
          suffixInflection("\u3137\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3154", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB370\uC694": {
        name: "-\uB370\uC694",
        rules: [
          suffixInflection("\u3137\u3154\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3154\u3147\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB3C4\uB2E4": {
        name: "-\uB3C4\uB2E4",
        rules: [
          suffixInflection("\u3137\u3157\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3157\u3137\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB3C4\uB85D": {
        name: "-\uB3C4\uB85D",
        rules: [
          suffixInflection("\u3137\u3157\u3139\u3157\u3131", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u3157\u3139\u3157\u3131", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB418": {
        name: "-(\uC73C)\uB418",
        rules: [
          suffixInflection("\u3137\u3157\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3137\u3157\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u3157\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3137\u3157\u3163", "", [], ["p", "f"])
        ]
      },
      "-\uB4DC\uAD6C\uB098": {
        name: "-\uB4DC\uAD6C\uB098",
        rules: [
          suffixInflection("\u3137\u3161\u3131\u315C\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3131\u315C\u3134\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uAD6C\uB8CC": {
        name: "-\uB4DC\uAD6C\uB8CC",
        rules: [
          suffixInflection("\u3137\u3161\u3131\u315C\u3139\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3131\u315C\u3139\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uAD6C\uBA74": {
        name: "-\uB4DC\uAD6C\uBA74",
        rules: [
          suffixInflection("\u3137\u3161\u3131\u315C\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3131\u315C\u3141\u3155\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uAD70": {
        name: "-\uB4DC\uAD70",
        rules: [
          suffixInflection("\u3137\u3161\u3131\u315C\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3131\u315C\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uB0D0": {
        name: "-\uB4DC\uB0D0",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3151", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uB2C8": {
        name: "-\uB4DC\uB2C8",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uB2C8\uB77C": {
        name: "-\uB4DC\uB2C8\uB77C",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3163\u3139\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uB77C": {
        name: "-\uB4DC\uB77C",
        rules: [
          suffixInflection("\u3137\u3161\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3139\u314F", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uB77C\uB3C4": {
        name: "-\uB4DC\uB77C\uB3C4",
        rules: [
          suffixInflection("\u3137\u3161\u3139\u314F\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3139\u314F\u3137\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4DC\uB77C\uBA74": {
        name: "-\uB4DC\uB77C\uBA74",
        rules: [
          suffixInflection("\u3137\u3161\u3139\u314F\u3141\u3155\u3134", "", [], ["p"])
        ]
      },
      "-\uB4DC\uB798\uB3C4": {
        name: "-\uB4DC\uB798\uB3C4",
        rules: [
          suffixInflection("\u3137\u3161\u3139\u3150\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3139\u3150\u3137\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4E0": {
        name: "-\uB4E0",
        rules: [
          suffixInflection("\u3137\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134", "", [], ["p", "eusi"])
        ]
      },
      "-\uB4E0\uAC00": {
        name: "-\uB4E0\uAC00",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3131\u314F", "", [], ["p", "eusi"])
        ]
      },
      "-\uB4E0\uAC78": {
        name: "-\uB4E0\uAC78",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3131\u3153\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3131\u3153\u3139", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4E0\uACE0": {
        name: "-\uB4E0\uACE0",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3131\u3157", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4E0\uB370": {
        name: "-\uB4E0\uB370",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3137\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3137\u3154", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4E0\uB4E4": {
        name: "-\uB4E0\uB4E4",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3137\u3161\u3139", "", [], ["p"])
        ]
      },
      "-\uB4E0\uC9C0": {
        name: "-\uB4E0\uC9C0",
        rules: [
          suffixInflection("\u3137\u3161\u3134\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3134\u3148\u3163", "", [], ["p", "eusi"])
        ]
      },
      "-\uB4EF": {
        name: "-\uB4EF",
        rules: [
          suffixInflection("\u3137\u3161\u3145", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3145", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB4EF\uC774": {
        name: "-\uB4EF\uC774",
        rules: [
          suffixInflection("\u3137\u3161\u3145\u3147\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3161\u3145\u3147\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uB514": {
        name: "-\uB514",
        rules: [
          suffixInflection("\u3137\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-(\uC73C)\uB77C": {
        name: "-(\uC73C)\uB77C",
        rules: [
          suffixInflection("\u3139\u314F", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uACE0": {
        name: "-(\uC73C)\uB77C\uACE0",
        rules: [
          suffixInflection("\u3139\u314F\u3131\u3157", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3131\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3131\u3157", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3131\u3157", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3131\u3157", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3131\u3157", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3131\u3157", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uAD6C": {
        name: "-(\uC73C)\uB77C\uAD6C",
        rules: [
          suffixInflection("\u3139\u314F\u3131\u315C", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3131\u315C", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3131\u315C", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3131\u315C", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3131\u315C", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3131\u315C", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3131\u315C", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3131\u315C", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uB098": {
        name: "-(\uC73C)\uB77C\uB098",
        rules: [
          suffixInflection("\u3139\u314F\u3134\u314F", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134\u314F", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uB124": {
        name: "-(\uC73C)\uB77C\uB124",
        rules: [
          suffixInflection("\u3139\u314F\u3134\u3154", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134\u3154", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134\u3154", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3154", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134\u3154", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134\u3154", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134\u3154", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uB290\uB2C8": {
        name: "-(\uC73C)\uB77C\uB290\uB2C8",
        rules: [
          suffixInflection("\u3139\u314F\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134\u3161\u3134\u3163", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134\u3161\u3134\u3163", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3161\u3134\u3163", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134\u3161\u3134\u3163", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134\u3161\u3134\u3163", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134\u3161\u3134\u3163", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uB2C8": {
        name: "-(\uC73C)\uB77C\uB2C8",
        rules: [
          suffixInflection("\u3139\u314F\u3134\u3163", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134\u3163", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134\u3163", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3163", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134\u3163", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134\u3163", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134\u3163", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uB2C8\uAE4C": {
        name: "-(\uC73C)\uB77C\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3139\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134\u3163\u3132\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134\u3163\u3132\u314F", "", [], ["eusi", "do"])
        ]
      },
      "-\uB77C\uB3C4": {
        name: "-\uB77C\uB3C4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3137\u3157", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3137\u3157", "\u3137\u314F", [], ["ida"])
        ]
      },
      "-(\uC73C)\uB77C\uBA70": {
        name: "-(\uC73C)\uB77C\uBA70",
        rules: [
          suffixInflection("\u3139\u314F\u3141\u3155", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3141\u3155", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141\u3155", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3141\u3155", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141\u3155", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3141\u3155", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3141\u3155", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3141\u3155", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uBA74": {
        name: "-(\uC73C)\uB77C\uBA74",
        rules: [
          suffixInflection("\u3139\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3141\u3155\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3141\u3155\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141\u3155\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3141\u3155\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3141\u3155\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3141\u3155\u3134", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uBA74\uC11C": {
        name: "-(\uC73C)\uB77C\uBA74\uC11C",
        rules: [
          suffixInflection("\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3141\u3155\u3134\u3145\u3153", "", [], ["eusi", "do"])
        ]
      },
      "-\uB77C\uC11C": {
        name: "-\uB77C\uC11C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3145\u3153", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3145\u3153", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u314F\u3145\u3153", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB77C\uC190": {
        name: "-(\uC73C)\uB77C\uC190",
        rules: [
          suffixInflection("\u3139\u314F\u3145\u3157\u3134", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3145\u3157\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3145\u3157\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3145\u3157\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3145\u3157\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3145\u3157\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3145\u3157\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3145\u3157\u3134", "", [], ["eusi", "do"])
        ]
      },
      "-\uB77C\uC57C": {
        name: "-\uB77C\uC57C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3147\u3151", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3147\u3151", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u314F\u3147\u3151", "", [], ["eusi"])
        ]
      },
      "-\uB77C\uC57C\uB9CC": {
        name: "-\uB77C\uC57C\uB9CC",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3147\u3151\u3141\u314F\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3147\u3151\u3141\u314F\u3134", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u314F\u3147\u3151\u3141\u314F\u3134", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB77C\uC624": {
        name: "-(\uC73C)\uB77C\uC624",
        rules: [
          suffixInflection("\u3139\u314F\u3147\u3157", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3147\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3147\u3157", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3147\u3157", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3147\u3157", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3147\u3157", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3147\u3157", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77C\uC9C0": {
        name: "-(\uC73C)\uB77C\uC9C0",
        rules: [
          suffixInflection("\u3139\u314F\u3148\u3163", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3148\u3163", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3148\u3163", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3148\u3163", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3148\u3163", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3148\u3163", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3148\u3163", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3148\u3163", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB77D": {
        name: "-(\uC73C)\uB77D",
        rules: [
          suffixInflection("\u3139\u314F\u3131", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u314F\u3131", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3131", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3131", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3131", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u314F\u3131", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3131", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\uB780": {
        name: "-(\uC73C)\uB780",
        rules: [
          suffixInflection("\u3139\u314F\u3134", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB780\uB2E4": {
        name: "-(\uC73C)\uB780\uB2E4",
        rules: [
          suffixInflection("\u3139\u314F\u3134\u3137\u314F", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3134\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3134\u3137\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3134\u3137\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3134\u3137\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3134\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3134\u3137\u314F", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB78C": {
        name: "-(\uC73C)\uB78C",
        rules: [
          suffixInflection("\u3139\u314F\u3141", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3141", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3141", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3141", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3141", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3141", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB78D\uB2C8\uAE4C": {
        name: "-(\uC73C)\uB78D\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3142\u3134\u3163\u3132\u314F", "", [], ["eusi", "do"])
        ]
      },
      "-(\uC73C)\uB78D\uB2C8\uB2E4": {
        name: "-(\uC73C)\uB78D\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3142\u3134\u3163\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB78D\uC2DC\uACE0": {
        name: "-\uB78D\uC2DC\uACE0",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u314F\u3142\u3145\u3163\u3131\u3157", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u314F\u3142\u3145\u3163\u3131\u3157", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u314F\u3142\u3145\u3163\u3131\u3157", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB798": {
        name: "-(\uC73C)\uB798",
        rules: [
          suffixInflection("\u3139\u3150", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u3150", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3150", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3150", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3150", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3150", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3150", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3150", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB798\uC694": {
        name: "-(\uC73C)\uB798\uC694",
        rules: [
          suffixInflection("\u3139\u3150\u3147\u315B", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u3150\u3147\u315B", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3150\u3147\u315B", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3150\u3147\u315B", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3150\u3147\u315B", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3150\u3147\u315B", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3150\u3147\u315B", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3150\u3147\u315B", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB7B4": {
        name: "-(\uC73C)\uB7B4",
        rules: [
          suffixInflection("\u3139\u3151", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u3151", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3151", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3151", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3151", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3151", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3151", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB7EC": {
        name: "-(\uC73C)\uB7EC",
        rules: [
          suffixInflection("\u3139\u3153", "\u3137\u314F", [], ["v", "ida"]),
          suffixInflection("\u3139\u3153", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3153", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3153", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3153", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3153", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3153", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uB2C8": {
        name: "-\uB7EC\uB2C8",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3134\u3163", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3134\u3163", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3134\u3163", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uB2C8\uB77C": {
        name: "-\uB7EC\uB2C8\uB77C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3134\u3163\u3139\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3134\u3163\u3139\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3134\u3163\u3139\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uB2C8\uC774\uAE4C": {
        name: "-\uB7EC\uB2C8\uC774\uAE4C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3134\u3163\u3147\u3163\u3132\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3134\u3163\u3147\u3163\u3132\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3134\u3163\u3147\u3163\u3132\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uB2C8\uC774\uB2E4": {
        name: "-\uB7EC\uB2C8\uC774\uB2E4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3134\u3163\u3147\u3163\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3134\u3163\u3147\u3163\u3137\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3134\u3163\u3147\u3163\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uB77C": {
        name: "-\uB7EC\uB77C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3139\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3139\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3139\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uC774\uAE4C": {
        name: "-\uB7EC\uC774\uAE4C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3147\u3163\u3132\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3147\u3163\u3132\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3147\u3163\u3132\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7EC\uC774\uB2E4": {
        name: "-\uB7EC\uC774\uB2E4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3147\u3163\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3147\u3163\u3137\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3147\u3163\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7F0\uAC00": {
        name: "-\uB7F0\uAC00",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3134\u3131\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3134\u3131\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3134\u3131\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB7F0\uB4E4": {
        name: "-\uB7F0\uB4E4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3153\u3134\u3137\u3161\u3139", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3153\u3134\u3137\u3161\u3139", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3153\u3134\u3137\u3161\u3139", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB824": {
        name: "-(\uC73C)\uB824",
        rules: [
          suffixInflection("\u3139\u3155", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uAC70\uB4E0": {
        name: "-(\uC73C)\uB824\uAC70\uB4E0",
        rules: [
          suffixInflection("\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3131\u3153\u3137\u3161\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uACE0": {
        name: "-(\uC73C)\uB824\uACE0",
        rules: [
          suffixInflection("\u3139\u3155\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3131\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3131\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3131\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3131\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3131\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uB098": {
        name: "-(\uC73C)\uB824\uB098",
        rules: [
          suffixInflection("\u3139\u3155\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3134\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3134\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3134\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uB2C8": {
        name: "-(\uC73C)\uB824\uB2C8",
        rules: [
          suffixInflection("\u3139\u3155\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3134\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3134\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3134\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uB2C8\uC640": {
        name: "-(\uC73C)\uB824\uB2C8\uC640",
        rules: [
          suffixInflection("\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3163\u3147\u3157\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uB4E0": {
        name: "-(\uC73C)\uB824\uB4E0",
        rules: [
          suffixInflection("\u3139\u3155\u3137\u3161\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3137\u3161\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3137\u3161\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3137\u3161\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3137\u3161\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3137\u3161\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3137\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3137\u3161\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uB9C8": {
        name: "-(\uC73C)\uB824\uB9C8",
        rules: [
          suffixInflection("\u3139\u3155\u3141\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3141\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3141\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3141\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3141\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uBA74": {
        name: "-(\uC73C)\uB824\uBA74",
        rules: [
          suffixInflection("\u3139\u3155\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3141\u3155\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3141\u3155\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u3155\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3141\u3155\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3141\u3155\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3141\u3155\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u3155\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB824\uBB34\uB098": {
        name: "-(\uC73C)\uB824\uBB34\uB098",
        rules: [
          suffixInflection("\u3139\u3155\u3141\u315C\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3141\u315C\u3134\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u315C\u3134\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3141\u315C\u3134\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u315C\u3134\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3141\u315C\u3134\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3141\u315C\u3134\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141\u315C\u3134\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB828": {
        name: "-(\uC73C)\uB828",
        rules: [
          suffixInflection("\u3139\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB828\uB9C8\uB294": {
        name: "-(\uC73C)\uB828\uB9C8\uB294",
        rules: [
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134\u3161\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB828\uB9CC": {
        name: "-(\uC73C)\uB828\uB9CC",
        rules: [
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3134\u3141\u314F\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3134\u3141\u314F\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3134\u3141\u314F\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB834": {
        name: "-(\uC73C)\uB834",
        rules: [
          suffixInflection("\u3139\u3155\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3141", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3141", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3141", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3141", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3141", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB835\uB2C8\uAE4C": {
        name: "-(\uC73C)\uB835\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3132\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB835\uB2C8\uB2E4": {
        name: "-(\uC73C)\uB835\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3142\u3134\u3163\u3137\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB837\uB2E4": {
        name: "-(\uC73C)\uB837\uB2E4",
        rules: [
          suffixInflection("\u3139\u3155\u3145\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3155\u3145\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3145\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3155\u3145\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3145\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3145\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3155\u3145\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3155\u3145\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3155\u3145\u3137\u314F", "", [], ["p"])
        ]
      },
      "-\uB85C\uACE0": {
        name: "-\uB85C\uACE0",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u3157", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u3157", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u3157", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uACE0\uB098": {
        name: "-\uB85C\uACE0\uB098",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u3157\u3134\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u3157\u3134\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u3157\u3134\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD6C\uB098": {
        name: "-\uB85C\uAD6C\uB098",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3134\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3134\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3134\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD6C\uB824": {
        name: "-\uB85C\uAD6C\uB824",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3139\u3155", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3139\u3155", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3139\u3155", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD6C\uB8CC": {
        name: "-\uB85C\uAD6C\uB8CC",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3139\u315B", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3139\u315B", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3139\u315B", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD6C\uB9CC": {
        name: "-\uB85C\uAD6C\uB9CC",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3141\u314F\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3141\u314F\u3134", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3141\u314F\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD6C\uBA3C": {
        name: "-\uB85C\uAD6C\uBA3C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3141\u3153\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3141\u3153\u3134", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3141\u3153\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD6C\uBA74": {
        name: "-\uB85C\uAD6C\uBA74",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3141\u3155\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3141\u3155\u3134", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3141\u3155\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uAD70": {
        name: "-\uB85C\uAD70",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3131\u315C\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3134", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3131\u315C\u3134", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uB2E4": {
        name: "-\uB85C\uB2E4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3137\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uB418": {
        name: "-\uB85C\uB418",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3137\u3157\u3163", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3137\u3157\u3163", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3137\u3157\u3163", "", [], ["eusi"])
        ]
      },
      "-\uB85C\uB77C": {
        name: "-\uB85C\uB77C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3139\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3139\u314F", "\uB2E4", [], ["ida"]),
          suffixInflection("", "\uB2E4", [], ["ida"])
        ]
      },
      "-\uB85C\uC11C\uB2C8": {
        name: "-\uB85C\uC11C\uB2C8",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3145\u3153\u3134\u3163", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3145\u3153\u3134\u3163", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3145\u3153\u3134\u3163", "\uB2E4", [], ["ida"])
        ]
      },
      "-\uB85C\uC138": {
        name: "-\uB85C\uC138",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3139\u3157\u3145\u3154", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3139\u3157\u3145\u3154", "\uB2E4", [], ["ida"]),
          suffixInflection("\u3139\u3157\u3145\u3154", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uB9AC": {
        name: "-(\uC73C)\uB9AC",
        rules: [
          suffixInflection("\u3139\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uAE4C": {
        name: "-(\uC73C)\uB9AC\uAE4C",
        rules: [
          suffixInflection("\u3139\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3132\u314F", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3132\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB2C8": {
        name: "-(\uC73C)\uB9AC\uB2C8",
        rules: [
          suffixInflection("\u3139\u3163\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3134\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3134\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3134\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3134\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3134\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3134\u3163", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3134\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB2C8\uB77C": {
        name: "-(\uC73C)\uB9AC\uB2C8\uB77C",
        rules: [
          suffixInflection("\u3139\u3163\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3134\u3163\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3134\u3163\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3134\u3163\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3134\u3163\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3134\u3163\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3134\u3163\u3139\u314F", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3134\u3163\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB2E4": {
        name: "-(\uC73C)\uB9AC\uB2E4",
        rules: [
          suffixInflection("\u3139\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3137\u314F", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3137\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB77C": {
        name: "-(\uC73C)\uB9AC\uB77C",
        rules: [
          suffixInflection("\u3139\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB85C\uB2E4": {
        name: "-(\uC73C)\uB9AC\uB85C\uB2E4",
        rules: [
          suffixInflection("\u3139\u3163\u3139\u3157\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3139\u3157\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3139\u3157\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3139\u3157\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3139\u3157\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3139\u3157\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3139\u3157\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3139\u3157\u3137\u314F", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3139\u3157\u3137\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB9CC\uCE58": {
        name: "-(\uC73C)\uB9AC\uB9CC\uCE58",
        rules: [
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314A\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uB9CC\uD07C": {
        name: "-(\uC73C)\uB9AC\uB9CC\uD07C",
        rules: [
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9AC\uC624": {
        name: "-(\uC73C)\uB9AC\uC624",
        rules: [
          suffixInflection("\u3139\u3163\u3147\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3163\u3147\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3147\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3163\u3147\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3147\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3147\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3163\u3147\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3163\u3147\u3157", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3163\u3147\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uB9C8": {
        name: "-(\uC73C)\uB9C8",
        rules: [
          suffixInflection("\u3141\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3141\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3141\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3141\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3141\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u314F", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\uB9E4": {
        name: "-(\uC73C)\uB9E4",
        rules: [
          suffixInflection("\u3141\u3150", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3141\u3150", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3150", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3150", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3150", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3150", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3150", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3150", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141\u3150", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uBA70": {
        name: "-(\uC73C)\uBA70",
        rules: [
          suffixInflection("\u3141\u3155", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3141\u3155", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3155", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3155", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3155", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3155", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3155", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141\u3155", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uBA74": {
        name: "-(\uC73C)\uBA74",
        rules: [
          suffixInflection("\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3141\u3155\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3155\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3155\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3155\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3155\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3155\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3155\u3134", "", [], ["eusi", "euo", "jao"]),
          suffixInflection("\u3147\u3161\u3141\u3155\u3134", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uBA74\uC11C": {
        name: "-(\uC73C)\uBA74\uC11C",
        rules: [
          suffixInflection("\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3141\u3155\u3134\u3145\u3153", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3155\u3134\u3145\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3155\u3134\u3145\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3155\u3134\u3145\u3153", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3155\u3134\u3145\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3155\u3134\u3145\u3153", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141\u3155\u3134\u3145\u3153", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uBBC0\uB85C": {
        name: "-(\uC73C)\uBBC0\uB85C",
        rules: [
          suffixInflection("\u3141\u3161\u3139\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3141\u3161\u3139\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3161\u3139\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3161\u3139\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3161\u3139\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3161\u3139\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3161\u3139\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3161\u3139\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141\u3161\u3139\u3157", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC0AC": {
        name: "-(\uC73C)\uC0AC",
        rules: [
          suffixInflection("\u3145\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u314F", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uC0AC\uC624": {
        name: "-\uC0AC\uC624",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157", "\u3137\u314F", ["sao"], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157", "", ["sao"], ["p", "f"])
        ]
      },
      "-\uC0AC\uC624\uB2C8\uAE4C": {
        name: "-\uC0AC\uC624\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3134\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC624\uB9AC\uAE4C": {
        name: "-\uC0AC\uC624\uB9AC\uAE4C",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC624\uB9AC\uB2E4": {
        name: "-\uC0AC\uC624\uB9AC\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC624\uB9AC\uC774\uAE4C": {
        name: "-\uC0AC\uC624\uB9AC\uC774\uAE4C",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC624\uB9AC\uC774\uB2E4": {
        name: "-\uC0AC\uC624\uB9AC\uC774\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC624\uC774\uB2E4": {
        name: "-\uC0AC\uC624\uC774\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3147\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC635": {
        name: "-\uC0AC\uC635",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3142", "\u3137\u314F", ["saob"], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3142", "", ["saob"], ["p", "f"])
        ]
      },
      "-\uC0AC\uC635\uB2C8\uAE4C": {
        name: "-\uC0AC\uC635\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC635\uB2C8\uB2E4": {
        name: "-\uC0AC\uC635\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC635\uB514\uAE4C": {
        name: "-\uC0AC\uC635\uB514\uAE4C",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC635\uB514\uB2E4": {
        name: "-\uC0AC\uC635\uB514\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC640": {
        name: "-\uC0AC\uC640",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC0AC\uC678\uB2E4": {
        name: "-\uC0AC\uC678\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3157\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3157\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC0AC\uC774\uB2E4": {
        name: "-(\uC73C)\uC0AC\uC774\uB2E4",
        rules: [
          suffixInflection("\u3145\u314F\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u314F\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u314F\u3147\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u314F\u3147\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3147\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u314F\u3147\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uC0BD": {
        name: "-\uC0BD",
        rules: [
          suffixInflection("\u3145\u314F\u3142", "\u3137\u314F", ["sab"], ["v", "adj"]),
          suffixInflection("\u3145\u314F\u3142", "", ["sab"], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC138": {
        name: "-(\uC73C)\uC138",
        rules: [
          suffixInflection("\u3145\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3145\u3154", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3154", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3145\u3154", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3154", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC138\uB098": {
        name: "-\uC138\uB098",
        rules: [
          suffixInflection("\u3145\u3154\u3134\u314F", "\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\uC138\uC694": {
        name: "-(\uC73C)\uC138\uC694",
        rules: [
          suffixInflection("\u3145\u3154\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3145\u3154\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u3154\u3147\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u3154\u3147\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3154\u3147\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3145\u3154\u3147\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3154\u3147\u315B", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\uC154\uC694": {
        name: "-(\uC73C)\uC154\uC694",
        rules: [
          suffixInflection("\u3145\u3155\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3145\u3155\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u3155\u3147\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u3155\u3147\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3155\u3147\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3145\u3155\u3147\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3155\u3147\u315B", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uC18C": {
        name: "-\uC18C",
        rules: [
          suffixInflection("\u3145\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3157", "", [], ["p", "f"])
        ]
      },
      "-\uC18C\uB2E4": {
        name: "-\uC18C\uB2E4",
        rules: [
          suffixInflection("\u3145\u3157\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3157\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC18C\uC11C": {
        name: "-(\uC73C)\uC18C\uC11C",
        rules: [
          suffixInflection("\u3145\u3157\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u3157\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u3157\u3145\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u3157\u3145\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3157\u3145\u3153", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3145\u3157\u3145\u3153", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3157\u3145\u3153", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-\uC18C\uC774\uAE4C": {
        name: "-\uC18C\uC774\uAE4C",
        rules: [
          suffixInflection("\u3145\u3157\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3145\u3157\u3147\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC18C\uC774\uB2E4": {
        name: "-\uC18C\uC774\uB2E4",
        rules: [
          suffixInflection("\u3145\u3157\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3157\u3147\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC1E0\uB2E4": {
        name: "-\uC1E0\uB2E4",
        rules: [
          suffixInflection("\u3145\u3157\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3157\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC2A4)\u3142\uB124": {
        name: "-(\uC2A4)\u3142\uB124",
        rules: [
          suffixInflection("\u3142\u3134\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3134\u3154", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3154", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3154", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3134\u3154", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uB2B0\uB2E4": {
        name: "-(\uC2A4)\u3142\uB2B0\uB2E4",
        rules: [
          suffixInflection("\u3142\u3134\u3161\u3163\u3134\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3134\u3161\u3163\u3134\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3161\u3163\u3134\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3161\u3163\u3134\u3137\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3134\u3161\u3163\u3134\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uB2C8\uAE4C": {
        name: "-(\uC2A4)\u3142\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3163\u3132\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3134\u3163\u3132\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uB2C8\uB2E4": {
        name: "-(\uC2A4)\u3142\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3134\u3163\u3137\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3134\u3163\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uB514\uAE4C": {
        name: "-(\uC2A4)\u3142\uB514\uAE4C",
        rules: [
          suffixInflection("\u3142\u3137\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3137\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3137\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3137\u3163\u3132\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3137\u3163\u3132\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uB514\uB2E4": {
        name: "-(\uC2A4)\u3142\uB514\uB2E4",
        rules: [
          suffixInflection("\u3142\u3137\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3137\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3137\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3137\u3163\u3137\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3137\u3163\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uB518\uB2E4": {
        name: "-(\uC2A4)\u3142\uB518\uB2E4",
        rules: [
          suffixInflection("\u3142\u3137\u3163\u3134\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3137\u3163\u3134\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3137\u3163\u3134\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3137\u3163\u3134\u3137\u314F", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3137\u3163\u3134\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uC8E0": {
        name: "-(\uC2A4)\u3142\uC8E0",
        rules: [
          suffixInflection("\u3142\u3148\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3148\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3148\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3148\u315B", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3148\u315B", "", [], ["eusi"])
        ]
      },
      "-(\uC2A4)\u3142\uC9C0\uC694": {
        name: "-(\uC2A4)\u3142\uC9C0\uC694",
        rules: [
          suffixInflection("\u3142\u3148\u3163\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3142\u3148\u3163\u3147\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3148\u3163\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3161\u3142\u3148\u3163\u3147\u315B", "", [], ["p", "f"]),
          suffixInflection("\u3142\u3148\u3163\u3147\u315B", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uC2DC": {
        name: "-(\uC73C)\uC2DC",
        rules: [
          suffixInflection("\u3145\u3163", "\u3137\u314F", ["eusi"], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3145\u3163", "\u3137\u314F", ["eusi"], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u3163", "\u3142\u3137\u314F", ["eusi"], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u3163", "\u3145\u3137\u314F", ["eusi"], ["v", "adj"]),
          suffixInflection("\u3145\u3163", "\u314E\u3137\u314F", ["eusi"], ["adj"]),
          suffixInflection("\u3145\u3163", "\u3139\u3137\u314F", ["eusi"], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3163", "\u3137\u3137\u314F", ["eusi"], ["v", "adj"]),
          suffixInflection("\u3145\u3163", "", ["eusi"], ["saob", "euob", "jaob"])
        ]
      },
      "-(\uC73C)\uC2DC\uC555": {
        name: "-(\uC73C)\uC2DC\uC555",
        rules: [
          suffixInflection("\u3145\u3163\u3147\u314F\u3142", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3145\u3163\u3147\u314F\u3142", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3147\u314F\u3142", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3145\u3163\u3147\u314F\u3142", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3147\u314F\u3142", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3163\u3147\u314F\u3142", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\uC2DC\uC5B4\uC694": {
        name: "-(\uC73C)\uC2DC\uC5B4\uC694",
        rules: [
          suffixInflection("\u3145\u3163\u3147\u3153\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3147\u3153\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3145\u3163\u3147\u3153\u3147\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3147\u3153\u3147\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3163\u3147\u3153\u3147\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3145\u3163\u3147\u3153\u3147\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3163\u3147\u3153\u3147\u315B", "\u3137\u3137\u314F", [], ["v", "adj"])
        ]
      },
      "-(\uC73C)\uC2ED\uC0AC": {
        name: "-(\uC73C)\uC2ED\uC0AC",
        rules: [
          suffixInflection("\u3145\u3163\u3142\u3145\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3145\u3163\u3142\u3145\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3142\u3145\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3145\u3163\u3142\u3145\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3142\u3145\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3163\u3142\u3145\u314F", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\uC2ED\uC2DC\uB2E4": {
        name: "-(\uC73C)\uC2ED\uC2DC\uB2E4",
        rules: [
          suffixInflection("\u3145\u3163\u3142\u3145\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3145\u3163\u3142\u3145\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3142\u3145\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3145\u3163\u3142\u3145\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3142\u3145\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3163\u3142\u3145\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\uC2ED\uC2DC\uC624": {
        name: "-(\uC73C)\uC2ED\uC2DC\uC624",
        rules: [
          suffixInflection("\u3145\u3163\u3142\u3145\u3163\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3145\u3163\u3142\u3145\u3163\u3147\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3142\u3145\u3163\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3145\u3163\u3142\u3145\u3163\u3147\u3157", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3145\u3163\u3142\u3145\u3163\u3147\u3157", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3145\u3163\u3142\u3145\u3163\u3147\u3157", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC544/\uC5B4": {
        name: "-\uC544/\uC5B4",
        rules: [
          suffixInflection("\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3155", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uB2E4": {
        name: "-\uC544/\uC5B4\uB2E4",
        rules: [
          suffixInflection("\u314F\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3155\u3137\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3137\u314F", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3137\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3137\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3137\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3137\u314F", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3137\u314F", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3137\u314F", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3137\u314F", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uB2E4\uAC00": {
        name: "-\uC544/\uC5B4\uB2E4\uAC00",
        rules: [
          suffixInflection("\u314F\u3137\u314F\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3137\u314F\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u314F\u3131\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3137\u314F\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u314F\u3131\u314F", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F\u3131\u314F", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3137\u314F\u3131\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3137\u314F\u3131\u314F", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3137\u314F\u3131\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3137\u314F\u3131\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3137\u314F\u3131\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3137\u314F\u3131\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3137\u314F\u3131\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u314F\u3131\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3137\u314F\u3131\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3137\u314F\u3131\u314F", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3137\u314F\u3131\u314F", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3137\u314F\u3131\u314F", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3137\u314F\u3131\u314F", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3137\u314F\u3131\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3137\u314F\u3131\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3137\u314F\u3131\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3137\u314F\u3131\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3137\u314F\u3131\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u314F\u3131\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F\u3131\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u314F\u3131\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u314F\u3131\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u314F\u3131\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uB3C4": {
        name: "-\uC544/\uC5B4\uB3C4",
        rules: [
          suffixInflection("\u314F\u3137\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3137\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3137\u3157", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u3157", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3137\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3137\u3157", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3137\u3157", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3137\u3157", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3137\u3157", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3137\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3137\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3137\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3137\u3157", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3137\u3157", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3137\u3157", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3137\u3157", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3137\u3157", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3137\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3137\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3137\u3157", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3137\u3157", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3137\u3157", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u3157", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u3157", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3137\u3157", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3137\u3157", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3137\u3157", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uB77C": {
        name: "-\uC544/\uC5B4\uB77C",
        rules: [
          suffixInflection("\u314F\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3139\u314F", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3139\u314F", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3139\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3139\u314F", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3139\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3139\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3139\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3139\u314F", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3139\u314F", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3139\u314F", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3139\u314F", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3139\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3139\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3139\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3139\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3139\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3139\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3139\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3139\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC11C": {
        name: "-\uC544/\uC5B4\uC11C",
        rules: [
          suffixInflection("\u314F\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3145\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3145\u3153", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3145\u3153", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3145\u3153", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3145\u3153", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3145\u3153", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3145\u3153", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3145\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3145\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3145\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3145\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3145\u3153", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3145\u3153", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3145\u3153", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3145\u3153", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3145\u3153", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3145\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3145\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3145\u3153", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3145\u3153", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3145\u3153", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3145\u3153", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3145\u3153", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3145\u3153", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3145\u3153", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3145\u3153", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC57C": {
        name: "-\uC544/\uC5B4\uC57C",
        rules: [
          suffixInflection("\u314F\u3147\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3147\u3151", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3147\u3151", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3147\u3151", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3147\u3151", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3147\u3151", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3147\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3147\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3147\u3151", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3147\u3151", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3147\u3151", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3147\u3151", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3147\u3151", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3147\u3151", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3147\u3151", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3147\u3151", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC57C\uACA0": {
        name: "-\uC544/\uC5B4\uC57C\uACA0",
        rules: [
          suffixInflection("\u314F\u3147\u3151\u3131\u3154\u3146", "\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3131\u3154\u3146", "\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151\u3131\u3154\u3146", "\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3131\u3154\u3146", "\u3137\u314F", ["f"], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3147\u3151\u3131\u3154\u3146", "\u314F\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3131\u3154\u3146", "\u3153\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u3151\u3131\u3154\u3146", "\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3155\u3147\u3151\u3131\u3154\u3146", "\u3163\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3147\u3151\u3131\u3154\u3146", "\u3147\u3163\u3137\u314F", ["f"], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3147\u3151\u3131\u3154\u3146", "\u314E\u314F\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3147\u3151\u3131\u3154\u3146", "\u314E\u314F\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3147\u3151\u3131\u3154\u3146", "\u3142\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3147\u3151\u3131\u3154\u3146", "\u3142\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151\u3131\u3154\u3146", "\u3145\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3131\u3154\u3146", "\u3145\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151\u3131\u3154\u3146", "\u3163\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151\u3131\u3154\u3146", "\u314F\u314E\u3137\u314F", ["f"], ["adj"]),
          suffixInflection("\u3150\u3147\u3151\u3131\u3154\u3146", "\u3153\u314E\u3137\u314F", ["f"], ["adj"]),
          suffixInflection("\u3156\u3147\u3151\u3131\u3154\u3146", "\u3155\u314E\u3137\u314F", ["f"], ["adj"]),
          suffixInflection("\u3152\u3147\u3151\u3131\u3154\u3146", "\u3151\u314E\u3137\u314F", ["f"], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3147\u3151\u3131\u3154\u3146", "\u3137\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3147\u3151\u3131\u3154\u3146", "\u3137\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3147\u3151\u3131\u3154\u3146", "\u3139\u3161\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3147\u3151\u3131\u3154\u3146", "\u3139\u3161\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3147\u3151\u3131\u3154\u3146", "\u3139\u3161\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151\u3131\u3154\u3146", "\u3161\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3131\u3154\u3146", "\u3161\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151\u3131\u3154\u3146", "\u3161\u3137\u314F", ["f"], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3131\u3154\u3146", "\u3161\u3137\u314F", ["f"], ["v", "adj"])
        ]
      },
      "-\uC544/\uC5B4\uC57C\uB9CC": {
        name: "-\uC544/\uC5B4\uC57C\uB9CC",
        rules: [
          suffixInflection("\u314F\u3147\u3151\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3147\u3151\u3141\u314F\u3134", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3141\u314F\u3134", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3151\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3147\u3151\u3141\u314F\u3134", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3147\u3151\u3141\u314F\u3134", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3147\u3151\u3141\u314F\u3134", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3147\u3151\u3141\u314F\u3134", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3147\u3151\u3141\u314F\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3147\u3151\u3141\u314F\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151\u3141\u314F\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3141\u314F\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151\u3141\u314F\u3134", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151\u3141\u314F\u3134", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3147\u3151\u3141\u314F\u3134", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3147\u3151\u3141\u314F\u3134", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3147\u3151\u3141\u314F\u3134", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3147\u3151\u3141\u314F\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3147\u3151\u3141\u314F\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3147\u3151\u3141\u314F\u3134", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3147\u3151\u3141\u314F\u3134", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3147\u3151\u3141\u314F\u3134", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151\u3141\u314F\u3134", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3141\u314F\u3134", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151\u3141\u314F\u3134", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3141\u314F\u3134", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3141\u314F\u3134", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC57C\uC9C0": {
        name: "-\uC544/\uC5B4\uC57C\uC9C0",
        rules: [
          suffixInflection("\u314F\u3147\u3151\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3147\u3151\u3148\u3163", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3148\u3163", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3151\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3147\u3151\u3148\u3163", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3147\u3151\u3148\u3163", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3147\u3151\u3148\u3163", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3147\u3151\u3148\u3163", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3147\u3151\u3148\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3147\u3151\u3148\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u3151\u3148\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3148\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151\u3148\u3163", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u3151\u3148\u3163", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3147\u3151\u3148\u3163", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3147\u3151\u3148\u3163", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3147\u3151\u3148\u3163", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3147\u3151\u3148\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3147\u3151\u3148\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3147\u3151\u3148\u3163", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3147\u3151\u3148\u3163", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3147\u3151\u3148\u3163", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151\u3148\u3163", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3148\u3163", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u3151\u3148\u3163", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u3151\u3148\u3163", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u3151\u3148\u3163", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC694": {
        name: "-\uC544/\uC5B4\uC694",
        rules: [
          suffixInflection("\u314F\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u315B", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u315B", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3147\u315B", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3147\u315B", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3156\u3147\u315B", "\u3147\u3163\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u314E\u3150\u3147\u315B", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3147\u315B", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3147\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3147\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3147\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3147\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u315B", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3147\u315B", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3147\u315B", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3147\u315B", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3147\u315B", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3147\u315B", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3147\u315B", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3147\u315B", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3147\u315B", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3147\u315B", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u315B", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u315B", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3147\u315B", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3147\u315B", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3154\u3147\u315B", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3147\u3153\u3147\u315B", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC9C0\uC774\uB2E4": {
        name: "-\uC544/\uC5B4\uC9C0\uC774\uB2E4",
        rules: [
          suffixInflection("\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3148\u3163\u3147\u3163\u3137\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3148\u3163\u3147\u3163\u3137\u314F", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3148\u3163\u3147\u3163\u3137\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3148\u3163\u3147\u3163\u3137\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3148\u3163\u3147\u3163\u3137\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3148\u3163\u3147\u3163\u3137\u314F", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3148\u3163\u3147\u3163\u3137\u314F", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3148\u3163\u3147\u3163\u3137\u314F", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3148\u3163\u3147\u3163\u3137\u314F", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3148\u3163\u3147\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3148\u3163\u3147\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC544/\uC5B4\uC9C0\uB2E4": {
        name: "-\uC544/\uC5B4\uC9C0\uB2E4",
        rules: [
          suffixInflection("\u314F\u3148\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3148\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3148\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3148\u3163\u3137\u314F", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3137\u314F", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3148\u3163\u3137\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3148\u3163\u3137\u314F", "\u3147\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u3150\u3148\u3163\u3137\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3148\u3163\u3137\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3148\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3148\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3148\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3148\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3148\u3163\u3137\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3148\u3163\u3137\u314F", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3148\u3163\u3137\u314F", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3148\u3163\u3137\u314F", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3148\u3163\u3137\u314F", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3148\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3148\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3148\u3163\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3148\u3163\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3148\u3163\u3137\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3148\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3148\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3148\u3163\u3137\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3148\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC558/\uC5C8": {
        name: "-\uC558/\uC5C8",
        rules: [
          suffixInflection("\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146", "\u314F\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj", "ida"]),
          suffixInflection("\u3153\u3146", "\u3153\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3155\u3146", "\u3163\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3146", "\u3147\u3163\u3137\u314F", ["p"], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3146", "\u314E\u314F\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3146", "\u314E\u314F\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3146", "\u3142\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3146", "\u3142\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3146", "\u3145\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3146", "\u3145\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3150\u3146", "\u3163\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3150\u3146", "\u314F\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3150\u3146", "\u3153\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3156\u3146", "\u3155\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3152\u3146", "\u3151\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3146", "\u3137\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3146", "\u3137\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3146", "\u3139\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3146", "\u3139\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3146", "\u3139\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3153\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3153\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3145\u3155\u3146", "\u3145\u3163", ["p"], ["eusi"]),
          suffixInflection("\u3145\u3163\u3147\u3153\u3146", "\u3145\u3163", ["p"], ["eusi"])
        ]
      },
      "-\uC558/\uC5C8\uC5C8": {
        name: "-\uC558/\uC5C8\uC5C8",
        rules: [
          suffixInflection("\u314F\u3146\u3147\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3146\u3147\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3146\u3147\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146\u3147\u3153\u3146", "\u314F\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3153\u3146\u3147\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3146\u3147\u3153\u3146", "\u3137\u314F", ["p"], ["v", "adj", "ida"]),
          suffixInflection("\u3153\u3146\u3147\u3153\u3146", "\u3153\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3155\u3146\u3147\u3153\u3146", "\u3163\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3146\u3147\u3153\u3146", "\u3147\u3163\u3137\u314F", ["p"], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3146\u3147\u3153\u3146", "\u314E\u314F\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3146\u3147\u3153\u3146", "\u314E\u314F\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3146\u3147\u3153\u3146", "\u3142\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3146\u3147\u3153\u3146", "\u3142\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3146\u3147\u3153\u3146", "\u3145\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3146\u3147\u3153\u3146", "\u3145\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3150\u3146\u3147\u3153\u3146", "\u3163\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3150\u3146\u3147\u3153\u3146", "\u314F\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3150\u3146\u3147\u3153\u3146", "\u3153\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3156\u3146\u3147\u3153\u3146", "\u3155\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3152\u3146\u3147\u3153\u3146", "\u3151\u314E\u3137\u314F", ["p"], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3146\u3147\u3153\u3146", "\u3137\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3146\u3147\u3153\u3146", "\u3137\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3146\u3147\u3153\u3146", "\u3139\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3146\u3147\u3153\u3146", "\u3139\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3146\u3147\u3153\u3146", "\u3139\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146\u3147\u3153\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3153\u3146\u3147\u3153\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u314F\u3146\u3147\u3153\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"]),
          suffixInflection("\u3153\u3146\u3147\u3153\u3146", "\u3161\u3137\u314F", ["p"], ["v", "adj"])
        ]
      },
      "-\uC558/\uC5C8\uC790": {
        name: "-\uC558/\uC5C8\uC790",
        rules: [
          suffixInflection("\u314F\u3146\u3148\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3146\u3148\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3146\u3148\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3146\u3148\u314F", "\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3146\u3148\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3146\u3148\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3153\u3146\u3148\u314F", "\u3153\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3155\u3146\u3148\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3155\u3146\u3148\u314F", "\u3147\u3163\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u314E\u3150\u3146\u3148\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314E\u314F\u3147\u3155\u3146\u3148\u314F", "\u314E\u314F\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F\u3146\u3148\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3153\u3146\u3148\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u314F\u3146\u3148\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3153\u3146\u3148\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3146\u3148\u314F", "\u3163\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3150\u3146\u3148\u314F", "\u314F\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3150\u3146\u3148\u314F", "\u3153\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3156\u3146\u3148\u314F", "\u3155\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3152\u3146\u3148\u314F", "\u3151\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u314F\u3146\u3148\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3153\u3146\u3148\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3146\u3148\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3146\u3148\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3161\u3139\u3153\u3148\u314F", "\u3139\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3146\u3148\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3146\u3148\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u314F\u3146\u3148\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3153\u3146\u3148\u314F", "\u3161\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3145\u3155\u3146\u3148\u314F", "\u3145\u3163", [], ["eusi"])
        ]
      },
      "-\uC57C": {
        name: "-\uC57C",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3147\u3151", "\u3147\u314F\u3134\u3163\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3163\u3147\u3151", "\u3147\u3163\u3137\u314F", [], ["ida"])
        ]
      },
      "-\uC5B8\uB9C8\uB294": {
        name: "-\uC5B8\uB9C8\uB294",
        rules: [
          suffixInflection("\u3147\u3153\u3134\u3141\u314F\u3134\u3161\u3134", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3147\u3153\u3134\u3141\u314F\u3134\u3161\u3134", "\uC774\uB2E4", [], ["ida"]),
          suffixInflection("\u3147\u3153\u3134\u3141\u314F\u3134\u3161\u3134", "", [], ["eusi"])
        ]
      },
      "-\uC5B8\uB9CC": {
        name: "-\uC5B8\uB9CC",
        rules: [
          suffixInflection("\u3147\u3153\u3134\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3153\u3134\u3141\u314F\u3134", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uC5B8\uC815": {
        name: "-\uC5B8\uC815",
        rules: [
          suffixInflection("\u3147\u3153\u3134\u3148\u3153\u3147", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3147\u3153\u3134\u3148\u3153\u3147", "\uC774\uB2E4", [], ["ida"]),
          suffixInflection("\u3147\u3153\u3134\u3148\u3153\u3147", "", [], ["eusi"])
        ]
      },
      "-\uC5D0\uB77C": {
        name: "-\uC5D0\uB77C",
        rules: [
          suffixInflection("\u3147\u3154\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\uC624": {
        name: "-(\uC73C)\uC624",
        rules: [
          suffixInflection("\u3147\u3157", "\u3137\u314F", ["euo"], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157", "\u3137\u314F", ["euo"], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157", "\u3142\u3137\u314F", ["euo"], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157", "\u3145\u3137\u314F", ["euo"], ["v", "adj"]),
          suffixInflection("\u3147\u3157", "\u314E\u3137\u314F", ["euo"], ["adj"]),
          suffixInflection("\u3147\u3157", "\u3139\u3137\u314F", ["euo"], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157", "\u3137\u3137\u314F", ["euo"], ["v", "adj"]),
          suffixInflection("\u3147\u3157", "", ["euo"], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157", "", ["euo"], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC624\uB2C8\uAE4C": {
        name: "-(\uC73C)\uC624\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3147\u3157\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3134\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3134\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3134\u3163\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3134\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3134\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3134\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC624\uB9AC\uC774\uAE4C": {
        name: "-(\uC73C)\uC624\uB9AC\uC774\uAE4C",
        rules: [
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3132\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uC624\uB9AC\uC774\uB2E4": {
        name: "-(\uC73C)\uC624\uB9AC\uC774\uB2E4",
        rules: [
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3139\u3163\u3147\u3163\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-\uC624\uC774\uAE4C": {
        name: "-\uC624\uC774\uAE4C",
        rules: [
          suffixInflection("\u3147\u3157\u3147\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3157\u3147\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3147\u3163\u3132\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\uC624\uC774\uB2E4": {
        name: "-(\uC73C)\uC624\uC774\uB2E4",
        rules: [
          suffixInflection("\u3147\u3157\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3147\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3147\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3147\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3147\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3147\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3147\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3147\u3163\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3147\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC62C\uC2B5\uB2C8\uB2E4": {
        name: "-\uC62C\uC2B5\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3147\u3157\u3139\u3145\u3161\u3142\u3134\u3163\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3147\u3163\u3147\u3157\u3139\u3145\u3161\u3142\u3134\u3163\u3137\u314F", "\uC774\uB2E4", [], ["ida"])
        ]
      },
      "-\uC62C\uC2DC\uB2E4": {
        name: "-\uC62C\uC2DC\uB2E4",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3147\u3157\u3139\u3145\u3163\u3137\u314F", "\uC544\uB2C8\uB2E4", [], ["adj"]),
          suffixInflection("\u3147\u3163\u3147\u3157\u3139\u3145\u3163\u3137\u314F", "\uC774\uB2E4", [], ["ida"])
        ]
      },
      "-(\uC73C)\uC635": {
        name: "-(\uC73C)\uC635",
        rules: [
          suffixInflection("\u3147\u3157\u3142", "\u3137\u314F", ["euob"], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142", "\u3137\u314F", ["euob"], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3142", "\u3142\u3137\u314F", ["euob"], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142", "\u3145\u3137\u314F", ["euob"], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142", "\u314E\u3137\u314F", ["euob"], ["adj"]),
          suffixInflection("\u3147\u3157\u3142", "\u3139\u3137\u314F", ["euob"], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3142", "\u3137\u3137\u314F", ["euob"], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142", "", ["euob"], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142", "", ["euob"], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC635\uB2C8\uAE4C": {
        name: "-(\uC73C)\uC635\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC635\uB2C8\uB2E4": {
        name: "-(\uC73C)\uC635\uB2C8\uB2E4",
        rules: [
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3134\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC635\uB514\uAE4C": {
        name: "-(\uC73C)\uC635\uB514\uAE4C",
        rules: [
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3132\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC635\uB514\uB2E4": {
        name: "-(\uC73C)\uC635\uB514\uB2E4",
        rules: [
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3137\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC635\uC18C\uC11C": {
        name: "-(\uC73C)\uC635\uC18C\uC11C",
        rules: [
          suffixInflection("\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3142\u3145\u3157\u3145\u3153", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC640": {
        name: "-(\uC73C)\uC640",
        rules: [
          suffixInflection("\u3147\u3157\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u314F", "", [], ["eusi", "euo", "jao"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u314F", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC678\uB2E4": {
        name: "-(\uC73C)\uC678\uB2E4",
        rules: [
          suffixInflection("\u3147\u3157\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3163\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u3157\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3163\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3157\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u3157\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3157\u3163\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u3157\u3163\u3137\u314F", "", [], ["p", "f"])
        ]
      },
      "-\uC694": {
        name: "-\uC694",
        rules: [
          suffixInflection("\u3147\u314F\u3134\u3163\u3147\u315B", "\uC544\uB2C8\uB2E4", [], ["ida"]),
          suffixInflection("\u3147\u315B", "\u3137\u314F", [], ["ida"])
        ]
      },
      "-(\uC73C)\uC6B0": {
        name: "-(\uC73C)\uC6B0",
        rules: [
          suffixInflection("\u3147\u315C", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3147\u315C", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3147\u315C", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3147\u315C", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3147\u315C", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3147\u315C", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\uC774": {
        name: "-(\uC73C)\uC774",
        rules: [
          suffixInflection("\u3147\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3163", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3147\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3163", "\u3137\u314F", [], ["adj"])
        ]
      },
      "-(\uC73C)\u3134\uB4E4": {
        name: "-(\uC73C)\u3134\uB4E4",
        rules: [
          suffixInflection("\u3134\u3137\u3161\u3139", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3137\u3161\u3139", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3137\u3161\u3139", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3137\u3161\u3139", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3137\u3161\u3139", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3137\u3161\u3139", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3137\u3161\u3139", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3137\u3161\u3139", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3134\uC989": {
        name: "-(\uC73C)\u3134\uC989",
        rules: [
          suffixInflection("\u3134\u3148\u3161\u3131", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3161\u3131", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3148\u3161\u3131", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3161\u3131", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3161\u3131", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3148\u3161\u3131", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3148\u3161\u3131", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3161\u3131", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3161\u3131", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3134\uC989\uC2A8": {
        name: "-(\uC73C)\u3134\uC989\uC2A8",
        rules: [
          suffixInflection("\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3161\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3134\u3148\u3161\u3131\u3145\u3161\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uAE4C": {
        name: "-(\uC73C)\u3139\uAE4C",
        rules: [
          suffixInflection("\u3139\u3132\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3132\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3132\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3132\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uAE5D\uC1FC": {
        name: "-(\uC73C)\u3139\uAE5D\uC1FC",
        rules: [
          suffixInflection("\u3139\u3132\u314F\u3142\u3145\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3132\u314F\u3142\u3145\u315B", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u314F\u3142\u3145\u315B", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3132\u314F\u3142\u3145\u315B", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u314F\u3142\u3145\u315B", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u314F\u3142\u3145\u315B", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3132\u314F\u3142\u3145\u315B", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u314F\u3142\u3145\u315B", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u314F\u3142\u3145\u315B", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uAF2C": {
        name: "-(\uC73C)\u3139\uAF2C",
        rules: [
          suffixInflection("\u3139\u3132\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3132\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3132\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3132\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3132\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3132\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB294\uC9C0": {
        name: "-(\uC73C)\u3139\uB294\uC9C0",
        rules: [
          suffixInflection("\u3139\u3134\u3161\u3134\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3134\u3161\u3134\u3148\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3134\u3161\u3134\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3134\u3161\u3134\u3148\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3134\u3161\u3134\u3148\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3134\u3161\u3134\u3148\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3134\u3161\u3134\u3148\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3134\u3161\u3134\u3148\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3134\u3161\u3134\u3148\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB370\uB77C\uB2C8": {
        name: "-(\uC73C)\u3139\uB370\uB77C\uB2C8",
        rules: [
          suffixInflection("\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3137\u3154\u3139\u314F\u3134\u3163", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3139\uB77C": {
        name: "-(\uC73C)\u3139\uB77C",
        rules: [
          suffixInflection("\u3139\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB77C\uACE0": {
        name: "-(\uC73C)\u3139\uB77C\uACE0",
        rules: [
          suffixInflection("\u3139\u3139\u314F\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u314F\u3131\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u314F\u3131\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u3131\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3131\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u314F\u3131\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u314F\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u3131\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB77C\uCE58\uBA74": {
        name: "-(\uC73C)\u3139\uB77C\uCE58\uBA74",
        rules: [
          suffixInflection("\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u314F\u314A\u3163\u3141\u3155\u3134", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3139\uB77D": {
        name: "-(\uC73C)\u3139\uB77D",
        rules: [
          suffixInflection("\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u314F\u3131 \u3141\u314F\u3139\u3139\u314F\u3131", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB798": {
        name: "-(\uC73C)\u3139\uB798",
        rules: [
          suffixInflection("\u3139\u3139\u3150", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u3150", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3150", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3150", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3150", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3150", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u3150", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3139\uB7EC\uB2C8": {
        name: "-(\uC73C)\u3139\uB7EC\uB2C8",
        rules: [
          suffixInflection("\u3139\u3139\u3153\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3153\u3134\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3153\u3134\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB7EC\uB77C": {
        name: "-(\uC73C)\u3139\uB7EC\uB77C",
        rules: [
          suffixInflection("\u3139\u3139\u3153\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3153\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3153\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3153\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB7F0\uAC00": {
        name: "-(\uC73C)\u3139\uB7F0\uAC00",
        rules: [
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3153\u3134\u3131\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB7F0\uACE0": {
        name: "-(\uC73C)\u3139\uB7F0\uACE0",
        rules: [
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3153\u3134\u3131\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3131\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB7F0\uC9C0": {
        name: "-(\uC73C)\u3139\uB7F0\uC9C0",
        rules: [
          suffixInflection("\u3139\u3139\u3153\u3134\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3148\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3153\u3134\u3148\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3148\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3148\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3153\u3134\u3148\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3153\u3134\u3148\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3153\u3134\u3148\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB808": {
        name: "-(\uC73C)\u3139\uB808",
        rules: [
          suffixInflection("\u3139\u3139\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3154", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3154", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3154", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3154", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3154", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3154", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3154", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3154", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB808\uB77C": {
        name: "-(\uC73C)\u3139\uB808\uB77C",
        rules: [
          suffixInflection("\u3139\u3139\u3154\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3139\u3154\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3154\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3154\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3154\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3154\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3154\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3139\u3154\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3154\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uB824\uACE0": {
        name: "-(\uC73C)\u3139\uB824\uACE0",
        rules: [
          suffixInflection("\u3139\u3139\u3155\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u3155\u3131\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3155\u3131\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3139\u3155\u3131\u3157", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3139\u3155\u3131\u3157", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3139\u3155\u3131\u3157", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3139\u3155\u3131\u3157", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3139\uB9DD\uC815": {
        name: "-(\uC73C)\u3139\uB9DD\uC815",
        rules: [
          suffixInflection("\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3141\u314F\u3147\u3148\u3153\u3147", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uBC16\uC5D0": {
        name: "-(\uC73C)\u3139\uBC16\uC5D0",
        rules: [
          suffixInflection("\u3139\u3142\u314F\u3132\u3147\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3142\u314F\u3132\u3147\u3154", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3142\u314F\u3132\u3147\u3154", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3142\u314F\u3132\u3147\u3154", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3142\u314F\u3132\u3147\u3154", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3142\u314F\u3132\u3147\u3154", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3142\u314F\u3132\u3147\u3154", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3142\u314F\u3132\u3147\u3154", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3142\u314F\u3132\u3147\u3154", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uBFD0\uB354\uB7EC": {
        name: "-(\uC73C)\u3139\uBFD0\uB354\uB7EC",
        rules: [
          suffixInflection("\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3143\u315C\u3134\u3137\u3153\u3139\u3153", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC0AC": {
        name: "-(\uC73C)\u3139\uC0AC",
        rules: [
          suffixInflection("\u3139\u3145\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3145\u314F", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u314F", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u314F", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u314F", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3145\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u314F", "\u3137\u3137\u314F", [], ["adj"])
        ]
      },
      "-(\uC73C)\u3139\uC0C8": {
        name: "-(\uC73C)\u3139\uC0C8",
        rules: [
          suffixInflection("\u3139\u3145\u3150", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3150", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3150", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3150", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3150", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3150", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3150", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3150", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3150", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC138": {
        name: "-(\uC73C)\u3139\uC138",
        rules: [
          suffixInflection("\u3139\u3145\u3154", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3154", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3154", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3154", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3154", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3154", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC138\uB77C": {
        name: "-(\uC73C)\u3139\uC138\uB77C",
        rules: [
          suffixInflection("\u3139\u3145\u3154\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3154\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3154\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3154\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3154\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3154\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC138\uB9D0\uC774\uC9C0": {
        name: "-(\uC73C)\u3139\uC138\uB9D0\uC774\uC9C0",
        rules: [
          suffixInflection("\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3154\u3141\u314F\u3139\u3147\u3163\u3148\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC18C\uB0D0": {
        name: "-(\uC73C)\u3139\uC18C\uB0D0",
        rules: [
          suffixInflection("\u3139\u3145\u3157\u3134\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3157\u3134\u3151", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3157\u3134\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3157\u3134\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3157\u3134\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3157\u3134\u3151", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3157\u3134\u3151", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3157\u3134\u3151", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3157\u3134\u3151", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC190\uAC00": {
        name: "-(\uC73C)\u3139\uC190\uAC00",
        rules: [
          suffixInflection("\u3139\u3145\u3157\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3157\u3134\u3131\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3157\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3157\u3134\u3131\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3157\u3134\u3131\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3157\u3134\u3131\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3157\u3134\u3131\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3157\u3134\u3131\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3157\u3134\u3131\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC218\uB85D": {
        name: "-(\uC73C)\u3139\uC218\uB85D",
        rules: [
          suffixInflection("\u3139\u3145\u315C\u3139\u3157\u3131", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u315C\u3139\u3157\u3131", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u315C\u3139\u3157\u3131", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u315C\u3139\u3157\u3131", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u315C\u3139\u3157\u3131", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u315C\u3139\u3157\u3131", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u315C\u3139\u3157\u3131", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u315C\u3139\u3157\u3131", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u315C\u3139\u3157\u3131", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC2DC": {
        name: "-(\uC73C)\u3139\uC2DC",
        rules: [
          suffixInflection("\u3139\u3145\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3145\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3145\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC2DC\uACE0": {
        name: "-(\uC73C)\u3139\uC2DC\uACE0",
        rules: [
          suffixInflection("\u3139\u3145\u3163\u3131\u3157", "\u3137\u314F", [], ["adj", "ida"]),
          suffixInflection("\u3139\u3145\u3163\u3131\u3157", "\u3139\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3163\u3131\u3157", "\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u315C\u3139\u3145\u3163\u3131\u3157", "\u3142\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3163\u3131\u3157", "\u3145\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3145\u3163\u3131\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3145\u3163\u3131\u3157", "\u3137\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3145\u3163\u3131\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3145\u3163\u3131\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC2F8\uB85D": {
        name: "-(\uC73C)\u3139\uC2F8\uB85D",
        rules: [
          suffixInflection("\u3139\u3146\u314F\u3139\u3157\u3131", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3146\u314F\u3139\u3157\u3131", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u314F\u3139\u3157\u3131", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3146\u314F\u3139\u3157\u3131", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u314F\u3139\u3157\u3131", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3146\u314F\u3139\u3157\u3131", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3146\u314F\u3139\u3157\u3131", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3146\u314F\u3139\u3157\u3131", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u314F\u3139\u3157\u3131", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC3D8\uB0D0": {
        name: "-(\uC73C)\u3139\uC3D8\uB0D0",
        rules: [
          suffixInflection("\u3139\u3146\u3157\u3134\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3146\u3157\u3134\u3151", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u3157\u3134\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3146\u3157\u3134\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u3157\u3134\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3146\u3157\u3134\u3151", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3146\u3157\u3134\u3151", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3146\u3157\u3134\u3151", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u3157\u3134\u3151", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC3DC\uAC00": {
        name: "-(\uC73C)\u3139\uC3DC\uAC00",
        rules: [
          suffixInflection("\u3139\u3146\u3157\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3146\u3157\u3134\u3131\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u3157\u3134\u3131\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3146\u3157\u3134\u3131\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u3157\u3134\u3131\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3146\u3157\u3134\u3131\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3146\u3157\u3134\u3131\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3146\u3157\u3134\u3131\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3146\u3157\u3134\u3131\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC774\uB9CC\uD07C": {
        name: "-(\uC73C)\u3139\uC774\uB9CC\uD07C",
        rules: [
          suffixInflection("\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["eusi", "euo"]),
          suffixInflection("\u3147\u3161\u3139\u3147\u3163\u3141\u314F\u3134\u314B\u3161\u3141", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC791\uC2DC\uBA74": {
        name: "-(\uC73C)\u3139\uC791\uC2DC\uBA74",
        rules: [
          suffixInflection("\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3148\u314F\u3131\u3145\u3163\u3141\u3155\u3134", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0": {
        name: "-(\uC73C)\u3139\uC9C0",
        rules: [
          suffixInflection("\u3139\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uB098": {
        name: "-(\uC73C)\u3139\uC9C0\uB098",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uB2C8": {
        name: "-(\uC73C)\u3139\uC9C0\uB2C8",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3163", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3163", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u3163", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3163", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3163", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u3163", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3163", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3163", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uB2C8\uB77C": {
        name: "-(\uC73C)\u3139\uC9C0\uB2C8\uB77C",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3163\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uB77C": {
        name: "-(\uC73C)\u3139\uC9C0\uB77C",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3139\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3139\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uB77C\uB3C4": {
        name: "-(\uC73C)\u3139\uC9C0\uB77C\uB3C4",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u314F\u3137\u3157", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uB85C\uB2E4": {
        name: "-(\uC73C)\u3139\uC9C0\uB85C\uB2E4",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3139\u3157\u3137\u314F", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uBA70": {
        name: "-(\uC73C)\u3139\uC9C0\uBA70",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3141\u3155", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3141\u3155", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3141\u3155", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3141\u3155", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3141\u3155", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3141\u3155", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3141\u3155", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3141\u3155", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3141\u3155", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uC5B4\uB2E4": {
        name: "-(\uC73C)\u3139\uC9C0\uC5B4\uB2E4",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "\u3137\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3137\u314F", "", [], ["eusi"])
        ]
      },
      "-(\uC73C)\u3139\uC9C0\uC5B8\uC815": {
        name: "-(\uC73C)\u3139\uC9C0\uC5B8\uC815",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3147\u3153\u3134\u3148\u3153\u3147", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C4\uB300": {
        name: "-(\uC73C)\u3139\uC9C4\uB300",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u3137\u3150", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C4\uB300\uB294": {
        name: "-(\uC73C)\u3139\uC9C4\uB300\uB294",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134\u3161\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C4\uB304": {
        name: "-(\uC73C)\u3139\uC9C4\uB304",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3137\u3150\u3134", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3139\uC9C4\uC800": {
        name: "-(\uC73C)\u3139\uC9C4\uC800",
        rules: [
          suffixInflection("\u3139\u3148\u3163\u3134\u3148\u3153", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3148\u3153", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3148\u3153", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3139\u3148\u3163\u3134\u3148\u3153", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3148\u3153", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3148\u3153", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3139\u3148\u3163\u3134\u3148\u3153", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3139\u3148\u3163\u3134\u3148\u3153", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3139\u3148\u3163\u3134\u3148\u3153", "", [], ["p"])
        ]
      },
      "-(\uC73C)\u3141": {
        name: "-(\uC73C)\u3141",
        rules: [
          suffixInflection("\u3141", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3141", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\u3141\uC138": {
        name: "-(\uC73C)\u3141\uC138",
        rules: [
          suffixInflection("\u3141\u3145\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3141\u3145\u3154", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3141\u3145\u3154", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3141\u3145\u3154", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3141\u3145\u3154", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3145\u3154", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\u3141\uB3C4": {
        name: "-(\uC73C)\u3141\uB3C4",
        rules: [
          suffixInflection("\u3141\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3141\u3137\u3157", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3137\u3157", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3137\u3157", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3137\u3157", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3137\u3157", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3137\u3157", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3137\u3157", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141\u3137\u3157", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\u3141\uC5D0\uB7B4": {
        name: "-(\uC73C)\u3141\uC5D0\uB7B4",
        rules: [
          suffixInflection("\u3141\u3147\u3154\u3139\u3151", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3139\u3141\u3147\u3154\u3139\u3151", "\u3139\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3147\u3154\u3139\u3151", "\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u315C\u3141\u3147\u3154\u3139\u3151", "\u3142\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3147\u3161\u3141\u3147\u3154\u3139\u3151", "\u3145\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3147\u3154\u3139\u3151", "\u314E\u3137\u314F", [], ["adj"]),
          suffixInflection("\u3139\u3147\u3161\u3141\u3147\u3154\u3139\u3151", "\u3137\u3137\u314F", [], ["v", "adj"]),
          suffixInflection("\u3141\u3147\u3154\u3139\u3151", "", [], ["eusi"]),
          suffixInflection("\u3147\u3161\u3141\u3147\u3154\u3139\u3151", "", [], ["p", "f"])
        ]
      },
      "-(\uC73C)\u3142\uC1FC": {
        name: "-(\uC73C)\u3142\uC1FC",
        rules: [
          suffixInflection("\u3142\u3145\u315B", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3142\u3145\u315B", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3142\u3145\u315B", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3142\u3145\u315B", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3142\u3145\u315B", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3142\u3145\u315B", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\u3142\uC2DC\uB2E4": {
        name: "-(\uC73C)\u3142\uC2DC\uB2E4",
        rules: [
          suffixInflection("\u3142\u3145\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3142\u3145\u3163\u3137\u314F", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3142\u3145\u3163\u3137\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3142\u3145\u3163\u3137\u314F", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3142\u3145\u3163\u3137\u314F", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3142\u3145\u3163\u3137\u314F", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-(\uC73C)\u3142\uC2DC\uC624": {
        name: "-(\uC73C)\u3142\uC2DC\uC624",
        rules: [
          suffixInflection("\u3142\u3145\u3163\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3142\u3145\u3163\u3147\u3157", "\u3139\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3142\u3145\u3163\u3147\u3157", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u315C\u3142\u3145\u3163\u3147\u3157", "\u3142\u3137\u314F", [], ["v"]),
          suffixInflection("\u3147\u3161\u3142\u3145\u3163\u3147\u3157", "\u3145\u3137\u314F", [], ["v"]),
          suffixInflection("\u3139\u3147\u3161\u3142\u3145\u3163\u3147\u3157", "\u3137\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790": {
        name: "-\uC790",
        rules: [
          suffixInflection("\u3148\u314F", "\u3137\u314F", [], ["v", "ida"])
        ]
      },
      "-\uC790\uACE0": {
        name: "-\uC790\uACE0",
        rules: [
          suffixInflection("\u3148\u314F\u3131\u3157", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uAD6C": {
        name: "-\uC790\uAD6C",
        rules: [
          suffixInflection("\u3148\u314F\u3131\u315C", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uAFB8\uB098": {
        name: "-\uC790\uAFB8\uB098",
        rules: [
          suffixInflection("\u3148\u314F\u3132\u315C\u3134\u314F", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uB290\uB2C8": {
        name: "-\uC790\uB290\uB2C8",
        rules: [
          suffixInflection("\u3148\u314F\u3134\u3161\u3134\u3163", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uB2C8\uAE4C": {
        name: "-\uC790\uB2C8\uAE4C",
        rules: [
          suffixInflection("\u3148\u314F\u3134\u3163\u3132\u314F", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uB9C8\uC790": {
        name: "-\uC790\uB9C8\uC790",
        rules: [
          suffixInflection("\u3148\u314F\u3141\u314F\u3148\u314F", "\u3137\u314F", [], ["v"]),
          suffixInflection("\u3148\u314F\u3141\u314F\u3148\u314F", "", [], ["eusi"])
        ]
      },
      "-\uC790\uBA70": {
        name: "-\uC790\uBA70",
        rules: [
          suffixInflection("\u3148\u314F\u3141\u3155", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uBA74": {
        name: "-\uC790\uBA74",
        rules: [
          suffixInflection("\u3148\u314F\u3141\u3155\u3134", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uBA74\uC11C": {
        name: "-\uC790\uBA74\uC11C",
        rules: [
          suffixInflection("\u3148\u314F\u3141\u3155\u3134\u3145\u3153", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uC190": {
        name: "-\uC790\uC190",
        rules: [
          suffixInflection("\u3148\u314F\u3145\u3157\u3134", "\u3137\u314F", [], ["v"])
        ]
      },
      "-\uC790\uC624": {
        name: "-\uC790\uC624",
        rules: [
          suffixInflection("\u3148\u314F\u3147\u3157", "\u3137\u314F", ["jao"], ["v"])
        ]
      },
      "-\uC790\uC635": {
        name: "-\uC790\uC635",
        rules: [
          suffixInflection("\u3148\u314F\u3147\u3157\u3142", "\u3137\u314F", ["jaob"], ["v"])
        ]
      },
      "-\uC7A1": {
        name: "-\uC7A1",
        rules: [
          suffixInflection("\u3148\u314F\u3142", "\u3137\u314F", ["jab"], ["v"])
        ]
      },
      "-\uC8E0": {
        name: "-\uC8E0",
        rules: [
          suffixInflection("\u3148\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3148\u315B", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uC9C0": {
        name: "-\uC9C0",
        rules: [
          suffixInflection("\u3148\u3163", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3148\u3163", "", [], ["p", "f", "eusi"])
        ]
      },
      "-\uC9C0\uB9C8\uB294": {
        name: "-\uC9C0\uB9C8\uB294",
        rules: [
          suffixInflection("\u3148\u3163\u3141\u314F\u3134\u3161\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3148\u3163\u3141\u314F\u3134\u3161\u3134", "", [], ["p", "f"])
        ]
      },
      "-\uC9C0\uB9CC": {
        name: "-\uC9C0\uB9CC",
        rules: [
          suffixInflection("\u3148\u3163\u3141\u314F\u3134", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3148\u3163\u3141\u314F\u3134", "", [], ["p", "f", "euo", "euob"])
        ]
      },
      "-\uC9C0\uB9CC\uC11C\uB3C4": {
        name: "-\uC9C0\uB9CC\uC11C\uB3C4",
        rules: [
          suffixInflection("\u3148\u3163\u3141\u314F\u3134\u3145\u3153\u3137\u3157", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3148\u3163\u3141\u314F\u3134\u3145\u3153\u3137\u3157", "", [], ["p", "f"])
        ]
      },
      "-\uC9C0\uC694": {
        name: "-\uC9C0\uC694",
        rules: [
          suffixInflection("\u3148\u3163\u3147\u315B", "\u3137\u314F", [], ["v", "adj", "ida"]),
          suffixInflection("\u3148\u3163\u3147\u315B", "", [], ["p", "f", "eusi"])
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/ko.js
  globalThis.mangatanRegisterYomitanTransforms("ko", koreanTransforms);
})();
