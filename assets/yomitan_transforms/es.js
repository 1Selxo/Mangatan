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
  function wholeWordInflection(inflectedWord, deinflectedWord, conditionsIn, conditionsOut) {
    const regex = new RegExp("^" + inflectedWord + "$");
    return {
      type: "wholeWord",
      isInflected: regex,
      deinflect: () => deinflectedWord,
      conditionsIn,
      conditionsOut
    };
  }

  // third_party/yomitan/ext/js/language/es/spanish-transforms.js
  var REFLEXIVE_PATTERN = /\b(me|te|se|nos|os)\s+(\w+)(ar|er|ir)\b/g;
  var ACCENTS = /* @__PURE__ */ new Map([
    ["a", "\xE1"],
    ["e", "\xE9"],
    ["i", "\xED"],
    ["o", "\xF3"],
    ["u", "\xFA"]
  ]);
  function addAccent(char) {
    return ACCENTS.get(char) || char;
  }
  var conditions = {
    n: {
      name: "Noun",
      isDictionaryForm: true,
      subConditions: ["ns", "np"]
    },
    np: {
      name: "Noun plural",
      isDictionaryForm: false
    },
    ns: {
      name: "Noun singular",
      isDictionaryForm: false
    },
    v: {
      name: "Verb",
      isDictionaryForm: true,
      subConditions: ["v_ar", "v_er", "v_ir"]
    },
    v_ar: {
      name: "-ar verb",
      isDictionaryForm: false
    },
    v_er: {
      name: "-er verb",
      isDictionaryForm: false
    },
    v_ir: {
      name: "-ir verb",
      isDictionaryForm: false
    },
    adj: {
      name: "Adjective",
      isDictionaryForm: true
    }
  };
  var spanishTransforms = {
    language: "es",
    conditions,
    transforms: {
      "plural": {
        name: "plural",
        description: "Plural form of a noun",
        rules: [
          suffixInflection("s", "", ["np"], ["ns"]),
          suffixInflection("es", "", ["np"], ["ns"]),
          suffixInflection("ces", "z", ["np"], ["ns"]),
          // 'lápices' -> lápiz
          ...[..."aeiou"].map((v) => suffixInflection(`${v}ses`, `${addAccent(v)}s`, ["np"], ["ns"])),
          // 'autobuses' -> autobús
          ...[..."aeiou"].map((v) => suffixInflection(`${v}nes`, `${addAccent(v)}n`, ["np"], ["ns"]))
          // 'canciones' -> canción
        ]
      },
      "feminine adjective": {
        name: "feminine adjective",
        description: "feminine form of an adjective",
        rules: [
          suffixInflection("a", "o", ["adj"], ["adj"]),
          suffixInflection("a", "", ["adj"], ["adj"]),
          // encantadora -> encantador, española -> español
          ...[..."aeio"].map((v) => suffixInflection(`${v}na`, `${addAccent(v)}n`, ["adj"], ["adj"])),
          // dormilona -> dormilón, chiquitina -> chiquitín
          ...[..."aeio"].map((v) => suffixInflection(`${v}sa`, `${addAccent(v)}s`, ["adj"], ["adj"]))
          // francesa -> francés
        ]
      },
      "present indicative": {
        name: "present indicative",
        description: "Present indicative form of a verb",
        rules: [
          // STEM-CHANGING RULES FIRST
          // e->ie for -ar
          {
            type: "other",
            isInflected: /ie([a-z]*)(o|as|a|an)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(o|as|a|an)$/, "ar"),
            conditionsIn: ["v_ar"],
            conditionsOut: ["v_ar"]
          },
          // e->ie for -er
          {
            type: "other",
            isInflected: /ie([a-z]*)(o|es|e|en)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(o|es|e|en)$/, "er"),
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          // e->ie for -ir
          {
            type: "other",
            isInflected: /ie([a-z]*)(o|es|e|en)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(o|es|e|en)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // o->ue for -ar
          {
            type: "other",
            isInflected: /ue([a-z]*)(o|as|a|an)$/,
            deinflect: (term) => {
              if (term.startsWith("jue")) {
                return term.replace(/ue/, "u").replace(/(o|as|a|an)$/, "ar");
              }
              return term.replace(/ue/, "o").replace(/(o|as|a|an)$/, "ar");
            },
            conditionsIn: ["v_ar"],
            conditionsOut: ["v_ar"]
          },
          // o->ue for -er
          {
            type: "other",
            isInflected: /ue([a-z]*)(o|es|e|en)$/,
            deinflect: (term) => {
              if (term.startsWith("hue")) {
                return term.replace(/hue/, "o").replace(/(o|es|e|en)$/, "er");
              }
              return term.replace(/ue/, "o").replace(/(o|es|e|en)$/, "er");
            },
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          // o->ue for -ir
          {
            type: "other",
            isInflected: /ue([a-z]*)(o|es|e|en)$/,
            deinflect: (term) => term.replace(/ue/, "o").replace(/(o|es|e|en)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // e->i for -ir
          {
            type: "other",
            isInflected: /i([a-z]*)(o|es|e|en)$/,
            deinflect: (term) => term.replace(/i/, "e").replace(/(o|es|e|en)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // -ar verbs
          suffixInflection("o", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("as", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("a", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("amos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xE1is", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("an", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("o", "er", ["v_er"], ["v_er"]),
          suffixInflection("es", "er", ["v_er"], ["v_er"]),
          suffixInflection("e", "er", ["v_er"], ["v_er"]),
          suffixInflection("emos", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xE9is", "er", ["v_er"], ["v_er"]),
          suffixInflection("en", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("o", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("es", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("e", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("imos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xEDs", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("en", "ir", ["v_ir"], ["v_ir"]),
          // i -> y verbs (incluir, huir, construir...)
          suffixInflection("uyo", "uir", ["v_ir"], ["v_ir"]),
          suffixInflection("uyes", "uir", ["v_ir"], ["v_ir"]),
          suffixInflection("uye", "uir", ["v_ir"], ["v_ir"]),
          suffixInflection("uyen", "uir", ["v_ir"], ["v_ir"]),
          // -tener verbs
          suffixInflection("tengo", "tener", ["v"], ["v"]),
          suffixInflection("tienes", "tener", ["v"], ["v"]),
          suffixInflection("tiene", "tener", ["v"], ["v"]),
          suffixInflection("tenemos", "tener", ["v"], ["v"]),
          suffixInflection("ten\xE9is", "tener", ["v"], ["v"]),
          suffixInflection("tienen", "tener", ["v"], ["v"]),
          // -oír verbs
          suffixInflection("oigo", "o\xEDr", ["v"], ["v"]),
          suffixInflection("oyes", "o\xEDr", ["v"], ["v"]),
          suffixInflection("oye", "o\xEDr", ["v"], ["v"]),
          suffixInflection("o\xEDmos", "o\xEDr", ["v"], ["v"]),
          suffixInflection("o\xEDs", "o\xEDr", ["v"], ["v"]),
          suffixInflection("oyen", "o\xEDr", ["v"], ["v"]),
          // -venir verbs
          suffixInflection("vengo", "venir", ["v"], ["v"]),
          suffixInflection("vienes", "venir", ["v"], ["v"]),
          suffixInflection("viene", "venir", ["v"], ["v"]),
          suffixInflection("venimos", "venir", ["v"], ["v"]),
          suffixInflection("ven\xEDs", "venir", ["v"], ["v"]),
          suffixInflection("vienen", "venir", ["v"], ["v"]),
          // Verbs with Irregular Yo Forms
          // -guir, -ger, or -gir verbs
          suffixInflection("go", "guir", ["v"], ["v"]),
          suffixInflection("jo", "ger", ["v"], ["v"]),
          suffixInflection("jo", "gir", ["v"], ["v"]),
          suffixInflection("aigo", "aer", ["v"], ["v"]),
          suffixInflection("zco", "cer", ["v"], ["v"]),
          suffixInflection("zco", "cir", ["v"], ["v"]),
          suffixInflection("hago", "hacer", ["v"], ["v"]),
          suffixInflection("pongo", "poner", ["v"], ["v"]),
          suffixInflection("lgo", "lir", ["v"], ["v"]),
          suffixInflection("lgo", "ler", ["v"], ["v"]),
          wholeWordInflection("quepo", "caber", ["v"], ["v"]),
          wholeWordInflection("doy", "dar", ["v"], ["v"]),
          wholeWordInflection("s\xE9", "saber", ["v"], ["v"]),
          wholeWordInflection("veo", "ver", ["v"], ["v"]),
          // Ser, estar, ir, haber
          wholeWordInflection("soy", "ser", ["v"], ["v"]),
          wholeWordInflection("eres", "ser", ["v"], ["v"]),
          wholeWordInflection("es", "ser", ["v"], ["v"]),
          wholeWordInflection("somos", "ser", ["v"], ["v"]),
          wholeWordInflection("sois", "ser", ["v"], ["v"]),
          wholeWordInflection("son", "ser", ["v"], ["v"]),
          wholeWordInflection("estoy", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE1s", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE1", "estar", ["v"], ["v"]),
          wholeWordInflection("estamos", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE1is", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE1n", "estar", ["v"], ["v"]),
          wholeWordInflection("voy", "ir", ["v"], ["v"]),
          wholeWordInflection("vas", "ir", ["v"], ["v"]),
          wholeWordInflection("va", "ir", ["v"], ["v"]),
          wholeWordInflection("vamos", "ir", ["v"], ["v"]),
          wholeWordInflection("vais", "ir", ["v"], ["v"]),
          wholeWordInflection("van", "ir", ["v"], ["v"]),
          wholeWordInflection("he", "haber", ["v"], ["v"]),
          wholeWordInflection("has", "haber", ["v"], ["v"]),
          wholeWordInflection("ha", "haber", ["v"], ["v"]),
          wholeWordInflection("hemos", "haber", ["v"], ["v"]),
          wholeWordInflection("hab\xE9is", "haber", ["v"], ["v"]),
          wholeWordInflection("han", "haber", ["v"], ["v"])
        ]
      },
      "preterite": {
        name: "preterite",
        description: "Preterite (past) form of a verb",
        rules: [
          // e->i for -ir
          {
            type: "other",
            isInflected: /i([a-z]*)(ió|ieron)$/,
            // this only happens in 3rd person - singular and plural
            deinflect: (term) => term.replace(/i/, "e").replace(/(ió|ieron)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // o->u for -ir
          {
            type: "other",
            isInflected: /u([a-z]*)(ió|ieron)$/,
            deinflect: (term) => term.replace(/u/, "o").replace(/(ió|ieron)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // -ar verbs
          suffixInflection("\xE9", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aste", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xF3", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("amos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("asteis", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aron", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("\xED", "er", ["v_er"], ["v_er"]),
          suffixInflection("iste", "er", ["v_er"], ["v_er"]),
          suffixInflection("i\xF3", "er", ["v_er"], ["v_er"]),
          suffixInflection("imos", "er", ["v_er"], ["v_er"]),
          suffixInflection("isteis", "er", ["v_er"], ["v_er"]),
          suffixInflection("ieron", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("\xED", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("iste", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("i\xF3", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("imos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("isteis", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("ieron", "ir", ["v_ir"], ["v_ir"]),
          // -car, -gar, -zar verbs
          suffixInflection("qu\xE9", "car", ["v"], ["v"]),
          suffixInflection("gu\xE9", "gar", ["v"], ["v"]),
          suffixInflection("c\xE9", "zar", ["v"], ["v"]),
          // -uir verbs
          suffixInflection("\xED", "uir", ["v"], ["v"]),
          // Verbs with irregular forms
          wholeWordInflection("fui", "ser", ["v"], ["v"]),
          wholeWordInflection("fuiste", "ser", ["v"], ["v"]),
          wholeWordInflection("fue", "ser", ["v"], ["v"]),
          wholeWordInflection("fuimos", "ser", ["v"], ["v"]),
          wholeWordInflection("fuisteis", "ser", ["v"], ["v"]),
          wholeWordInflection("fueron", "ser", ["v"], ["v"]),
          wholeWordInflection("fui", "ir", ["v"], ["v"]),
          wholeWordInflection("fuiste", "ir", ["v"], ["v"]),
          wholeWordInflection("fue", "ir", ["v"], ["v"]),
          wholeWordInflection("fuimos", "ir", ["v"], ["v"]),
          wholeWordInflection("fuisteis", "ir", ["v"], ["v"]),
          wholeWordInflection("fueron", "ir", ["v"], ["v"]),
          wholeWordInflection("di", "dar", ["v"], ["v"]),
          wholeWordInflection("diste", "dar", ["v"], ["v"]),
          wholeWordInflection("dio", "dar", ["v"], ["v"]),
          wholeWordInflection("dimos", "dar", ["v"], ["v"]),
          wholeWordInflection("disteis", "dar", ["v"], ["v"]),
          wholeWordInflection("dieron", "dar", ["v"], ["v"]),
          suffixInflection("hice", "hacer", ["v"], ["v"]),
          suffixInflection("hiciste", "hacer", ["v"], ["v"]),
          suffixInflection("hizo", "hacer", ["v"], ["v"]),
          suffixInflection("hicimos", "hacer", ["v"], ["v"]),
          suffixInflection("hicisteis", "hacer", ["v"], ["v"]),
          suffixInflection("hicieron", "hacer", ["v"], ["v"]),
          suffixInflection("puse", "poner", ["v"], ["v"]),
          suffixInflection("pusiste", "poner", ["v"], ["v"]),
          suffixInflection("puso", "poner", ["v"], ["v"]),
          suffixInflection("pusimos", "poner", ["v"], ["v"]),
          suffixInflection("pusisteis", "poner", ["v"], ["v"]),
          suffixInflection("pusieron", "poner", ["v"], ["v"]),
          suffixInflection("dije", "decir", ["v"], ["v"]),
          suffixInflection("dijiste", "decir", ["v"], ["v"]),
          suffixInflection("dijo", "decir", ["v"], ["v"]),
          suffixInflection("dijimos", "decir", ["v"], ["v"]),
          suffixInflection("dijisteis", "decir", ["v"], ["v"]),
          suffixInflection("dijeron", "decir", ["v"], ["v"]),
          suffixInflection("vine", "venir", ["v"], ["v"]),
          suffixInflection("viniste", "venir", ["v"], ["v"]),
          suffixInflection("vino", "venir", ["v"], ["v"]),
          suffixInflection("vinimos", "venir", ["v"], ["v"]),
          suffixInflection("vinisteis", "venir", ["v"], ["v"]),
          suffixInflection("vinieron", "venir", ["v"], ["v"]),
          wholeWordInflection("quise", "querer", ["v"], ["v"]),
          wholeWordInflection("quisiste", "querer", ["v"], ["v"]),
          wholeWordInflection("quiso", "querer", ["v"], ["v"]),
          wholeWordInflection("quisimos", "querer", ["v"], ["v"]),
          wholeWordInflection("quisisteis", "querer", ["v"], ["v"]),
          wholeWordInflection("quisieron", "querer", ["v"], ["v"]),
          suffixInflection("tuve", "tener", ["v"], ["v"]),
          suffixInflection("tuviste", "tener", ["v"], ["v"]),
          suffixInflection("tuvo", "tener", ["v"], ["v"]),
          suffixInflection("tuvimos", "tener", ["v"], ["v"]),
          suffixInflection("tuvisteis", "tener", ["v"], ["v"]),
          suffixInflection("tuvieron", "tener", ["v"], ["v"]),
          wholeWordInflection("pude", "poder", ["v"], ["v"]),
          wholeWordInflection("pudiste", "poder", ["v"], ["v"]),
          wholeWordInflection("pudo", "poder", ["v"], ["v"]),
          wholeWordInflection("pudimos", "poder", ["v"], ["v"]),
          wholeWordInflection("pudisteis", "poder", ["v"], ["v"]),
          wholeWordInflection("pudieron", "poder", ["v"], ["v"]),
          wholeWordInflection("supe", "saber", ["v"], ["v"]),
          wholeWordInflection("supiste", "saber", ["v"], ["v"]),
          wholeWordInflection("supo", "saber", ["v"], ["v"]),
          wholeWordInflection("supimos", "saber", ["v"], ["v"]),
          wholeWordInflection("supisteis", "saber", ["v"], ["v"]),
          wholeWordInflection("supieron", "saber", ["v"], ["v"]),
          wholeWordInflection("estuve", "estar", ["v"], ["v"]),
          wholeWordInflection("estuviste", "estar", ["v"], ["v"]),
          wholeWordInflection("estuvo", "estar", ["v"], ["v"]),
          wholeWordInflection("estuvimos", "estar", ["v"], ["v"]),
          wholeWordInflection("estuvisteis", "estar", ["v"], ["v"]),
          wholeWordInflection("estuvieron", "estar", ["v"], ["v"]),
          wholeWordInflection("anduve", "andar", ["v"], ["v"]),
          wholeWordInflection("anduviste", "andar", ["v"], ["v"]),
          wholeWordInflection("anduvo", "andar", ["v"], ["v"]),
          wholeWordInflection("anduvimos", "andar", ["v"], ["v"]),
          wholeWordInflection("anduvisteis", "andar", ["v"], ["v"]),
          wholeWordInflection("anduvieron", "andar", ["v"], ["v"])
        ]
      },
      "imperfect": {
        name: "imperfect",
        description: "Imperfect form of a verb",
        rules: [
          // -ar verbs
          suffixInflection("aba", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("abas", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aba", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xE1bamos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("abais", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aban", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("\xEDa", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xEDas", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xEDa", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xEDamos", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xEDais", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xEDan", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("\xEDa", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xEDas", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xEDa", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xEDamos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xEDais", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xEDan", "ir", ["v_ir"], ["v_ir"]),
          // -ir verbs with stem changes
          suffixInflection("e\xEDa", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("e\xEDas", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("e\xEDa", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("e\xEDamos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("e\xEDais", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("e\xEDan", "ir", ["v_ir"], ["v_ir"]),
          // irregular verbs ir, ser, ver
          wholeWordInflection("era", "ser", ["v"], ["v"]),
          wholeWordInflection("eras", "ser", ["v"], ["v"]),
          wholeWordInflection("era", "ser", ["v"], ["v"]),
          wholeWordInflection("\xE9ramos", "ser", ["v"], ["v"]),
          wholeWordInflection("erais", "ser", ["v"], ["v"]),
          wholeWordInflection("eran", "ser", ["v"], ["v"]),
          wholeWordInflection("iba", "ir", ["v"], ["v"]),
          wholeWordInflection("ibas", "ir", ["v"], ["v"]),
          wholeWordInflection("iba", "ir", ["v"], ["v"]),
          wholeWordInflection("\xEDbamos", "ir", ["v"], ["v"]),
          wholeWordInflection("ibais", "ir", ["v"], ["v"]),
          wholeWordInflection("iban", "ir", ["v"], ["v"]),
          wholeWordInflection("ve\xEDa", "ver", ["v"], ["v"]),
          wholeWordInflection("ve\xEDas", "ver", ["v"], ["v"]),
          wholeWordInflection("ve\xEDa", "ver", ["v"], ["v"]),
          wholeWordInflection("ve\xEDamos", "ver", ["v"], ["v"]),
          wholeWordInflection("ve\xEDais", "ver", ["v"], ["v"]),
          wholeWordInflection("ve\xEDan", "ver", ["v"], ["v"])
        ]
      },
      "progressive": {
        name: "progressive",
        description: "Progressive form of a verb",
        rules: [
          // e->i for -ir
          {
            type: "other",
            isInflected: /i([a-z]*)(iendo)$/,
            deinflect: (term) => term.replace(/i/, "e").replace(/(iendo)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // o->u for -er
          {
            type: "other",
            isInflected: /u([a-z]*)(iendo)$/,
            deinflect: (term) => term.replace(/u/, "o").replace(/(iendo)$/, "er"),
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          // o->u for -ir
          {
            type: "other",
            isInflected: /u([a-z]*)(iendo)$/,
            deinflect: (term) => term.replace(/u/, "o").replace(/(iendo)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // regular
          suffixInflection("ando", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("iendo", "er", ["v_er"], ["v_er"]),
          suffixInflection("iendo", "ir", ["v_ir"], ["v_ir"]),
          // vowel before the ending (-yendo)
          suffixInflection("ayendo", "aer", ["v_er"], ["v_er"]),
          // traer -> trayendo, caer -> cayendo
          suffixInflection("eyendo", "eer", ["v_er"], ["v_er"]),
          // leer -> leyendo
          suffixInflection("uyendo", "uir", ["v_ir"], ["v_ir"]),
          // huir -> huyendo
          // irregular
          wholeWordInflection("oyendo", "o\xEDr", ["v"], ["v"]),
          wholeWordInflection("yendo", "ir", ["v"], ["v"])
        ]
      },
      "imperative": {
        name: "imperative",
        description: "Imperative form of a verb",
        rules: [
          {
            type: "other",
            isInflected: /ie([a-z]*)(a|e|en)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(a|e|en)$/, "ar"),
            conditionsIn: ["v_ar"],
            conditionsOut: ["v_ar"]
          },
          {
            type: "other",
            isInflected: /ie([a-z]*)(e|a|an)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(e|a|an)$/, "er"),
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          {
            type: "other",
            isInflected: /ie([a-z]*)(e|a|an)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(e|a|an)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          {
            type: "other",
            isInflected: /ue([a-z]*)(a|e|en)$/,
            deinflect: (term) => {
              if (term.startsWith("jue")) {
                return term.replace(/ue/, "u").replace(/(a|ue|uen)$/, "ar");
              }
              return term.replace(/ue/, "o").replace(/(a|e|en)$/, "ar");
            },
            conditionsIn: ["v_ar"],
            conditionsOut: ["v_ar"]
          },
          {
            type: "other",
            isInflected: /ue([a-z]*)(e|a|an)$/,
            deinflect: (term) => {
              if (term.startsWith("hue")) {
                return term.replace(/hue/, "o").replace(/(e|a|an)$/, "er");
              }
              return term.replace(/ue/, "o").replace(/(e|a|an)$/, "er");
            },
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          {
            type: "other",
            isInflected: /ue([a-z]*)(e|a|an)$/,
            deinflect: (term) => term.replace(/ue/, "o").replace(/(e|a|an)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          {
            type: "other",
            isInflected: /i([a-z]*)(e|a|an)$/,
            deinflect: (term) => term.replace(/i/, "e").replace(/(e|a|an)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // -ar verbs
          suffixInflection("a", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("emos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("ad", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("e", "er", ["v_er"], ["v_er"]),
          suffixInflection("amos", "ar", ["v_er"], ["v_er"]),
          suffixInflection("ed", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("e", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("amos", "ar", ["v_ir"], ["v_ir"]),
          suffixInflection("id", "ir", ["v_ir"], ["v_ir"]),
          // irregular verbs
          wholeWordInflection("diga", "decir", ["v"], ["v"]),
          wholeWordInflection("s\xE9", "ser", ["v"], ["v"]),
          wholeWordInflection("ve", "ir", ["v"], ["v"]),
          wholeWordInflection("ten", "tener", ["v"], ["v"]),
          wholeWordInflection("ven", "venir", ["v"], ["v"]),
          wholeWordInflection("haz", "hacer", ["v"], ["v"]),
          wholeWordInflection("di", "decir", ["v"], ["v"]),
          wholeWordInflection("pon", "poner", ["v"], ["v"]),
          wholeWordInflection("sal", "salir", ["v"], ["v"]),
          // negative commands
          // -ar verbs
          suffixInflection("es", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("emos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xE9is", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("as", "er", ["v_er"], ["v_er"]),
          suffixInflection("amos", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xE1is", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("as", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("amos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xE1is", "ir", ["v_ir"], ["v_ir"])
        ]
      },
      "conditional": {
        name: "conditional",
        description: "Conditional form of a verb",
        rules: [
          suffixInflection("\xEDa", "", ["v"], ["v"]),
          suffixInflection("\xEDas", "", ["v"], ["v"]),
          suffixInflection("\xEDa", "", ["v"], ["v"]),
          suffixInflection("\xEDamos", "", ["v"], ["v"]),
          suffixInflection("\xEDais", "", ["v"], ["v"]),
          suffixInflection("\xEDan", "", ["v"], ["v"]),
          // irregular verbs
          wholeWordInflection("dir\xEDa", "decir", ["v"], ["v"]),
          wholeWordInflection("dir\xEDas", "decir", ["v"], ["v"]),
          wholeWordInflection("dir\xEDa", "decir", ["v"], ["v"]),
          wholeWordInflection("dir\xEDamos", "decir", ["v"], ["v"]),
          wholeWordInflection("dir\xEDais", "decir", ["v"], ["v"]),
          wholeWordInflection("dir\xEDan", "decir", ["v"], ["v"]),
          wholeWordInflection("har\xEDa", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xEDas", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xEDa", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xEDamos", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xEDais", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xEDan", "hacer", ["v"], ["v"]),
          wholeWordInflection("pondr\xEDa", "poner", ["v"], ["v"]),
          wholeWordInflection("pondr\xEDas", "poner", ["v"], ["v"]),
          wholeWordInflection("pondr\xEDa", "poner", ["v"], ["v"]),
          wholeWordInflection("pondr\xEDamos", "poner", ["v"], ["v"]),
          wholeWordInflection("pondr\xEDais", "poner", ["v"], ["v"]),
          wholeWordInflection("pondr\xEDan", "poner", ["v"], ["v"]),
          wholeWordInflection("saldr\xEDa", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xEDas", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xEDa", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xEDamos", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xEDais", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xEDan", "salir", ["v"], ["v"]),
          wholeWordInflection("tendr\xEDa", "tener", ["v"], ["v"]),
          wholeWordInflection("tendr\xEDas", "tener", ["v"], ["v"]),
          wholeWordInflection("tendr\xEDa", "tener", ["v"], ["v"]),
          wholeWordInflection("tendr\xEDamos", "tener", ["v"], ["v"]),
          wholeWordInflection("tendr\xEDais", "tener", ["v"], ["v"]),
          wholeWordInflection("tendr\xEDan", "tener", ["v"], ["v"]),
          wholeWordInflection("vendr\xEDa", "venir", ["v"], ["v"]),
          wholeWordInflection("vendr\xEDas", "venir", ["v"], ["v"]),
          wholeWordInflection("vendr\xEDa", "venir", ["v"], ["v"]),
          wholeWordInflection("vendr\xEDamos", "venir", ["v"], ["v"]),
          wholeWordInflection("vendr\xEDais", "venir", ["v"], ["v"]),
          wholeWordInflection("vendr\xEDan", "venir", ["v"], ["v"]),
          wholeWordInflection("querr\xEDa", "querer", ["v"], ["v"]),
          wholeWordInflection("querr\xEDas", "querer", ["v"], ["v"]),
          wholeWordInflection("querr\xEDa", "querer", ["v"], ["v"]),
          wholeWordInflection("querr\xEDamos", "querer", ["v"], ["v"]),
          wholeWordInflection("querr\xEDais", "querer", ["v"], ["v"]),
          wholeWordInflection("querr\xEDan", "querer", ["v"], ["v"]),
          wholeWordInflection("podr\xEDa", "poder", ["v"], ["v"]),
          wholeWordInflection("podr\xEDas", "poder", ["v"], ["v"]),
          wholeWordInflection("podr\xEDa", "poder", ["v"], ["v"]),
          wholeWordInflection("podr\xEDamos", "poder", ["v"], ["v"]),
          wholeWordInflection("podr\xEDais", "poder", ["v"], ["v"]),
          wholeWordInflection("podr\xEDan", "poder", ["v"], ["v"]),
          wholeWordInflection("sabr\xEDa", "saber", ["v"], ["v"]),
          wholeWordInflection("sabr\xEDas", "saber", ["v"], ["v"]),
          wholeWordInflection("sabr\xEDa", "saber", ["v"], ["v"]),
          wholeWordInflection("sabr\xEDamos", "saber", ["v"], ["v"]),
          wholeWordInflection("sabr\xEDais", "saber", ["v"], ["v"]),
          wholeWordInflection("sabr\xEDan", "saber", ["v"], ["v"])
        ]
      },
      "future": {
        name: "future",
        description: "Future form of a verb",
        rules: [
          suffixInflection("\xE9", "", ["v"], ["v"]),
          suffixInflection("\xE1s", "", ["v"], ["v"]),
          suffixInflection("\xE1", "", ["v"], ["v"]),
          suffixInflection("emos", "", ["v"], ["v"]),
          suffixInflection("\xE9is", "", ["v"], ["v"]),
          suffixInflection("\xE1n", "", ["v"], ["v"]),
          // irregular verbs
          suffixInflection("dir\xE9", "decir", ["v"], ["v"]),
          suffixInflection("dir\xE1s", "decir", ["v"], ["v"]),
          suffixInflection("dir\xE1", "decir", ["v"], ["v"]),
          suffixInflection("diremos", "decir", ["v"], ["v"]),
          suffixInflection("dir\xE9is", "decir", ["v"], ["v"]),
          suffixInflection("dir\xE1n", "decir", ["v"], ["v"]),
          wholeWordInflection("har\xE9", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xE1s", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xE1", "hacer", ["v"], ["v"]),
          wholeWordInflection("haremos", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xE9is", "hacer", ["v"], ["v"]),
          wholeWordInflection("har\xE1n", "hacer", ["v"], ["v"]),
          suffixInflection("pondr\xE9", "poner", ["v"], ["v"]),
          suffixInflection("pondr\xE1s", "poner", ["v"], ["v"]),
          suffixInflection("pondr\xE1", "poner", ["v"], ["v"]),
          suffixInflection("pondremos", "poner", ["v"], ["v"]),
          suffixInflection("pondr\xE9is", "poner", ["v"], ["v"]),
          suffixInflection("pondr\xE1n", "poner", ["v"], ["v"]),
          wholeWordInflection("saldr\xE9", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xE1s", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xE1", "salir", ["v"], ["v"]),
          wholeWordInflection("saldremos", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xE9is", "salir", ["v"], ["v"]),
          wholeWordInflection("saldr\xE1n", "salir", ["v"], ["v"]),
          suffixInflection("tendr\xE9", "tener", ["v"], ["v"]),
          suffixInflection("tendr\xE1s", "tener", ["v"], ["v"]),
          suffixInflection("tendr\xE1", "tener", ["v"], ["v"]),
          suffixInflection("tendremos", "tener", ["v"], ["v"]),
          suffixInflection("tendr\xE9is", "tener", ["v"], ["v"]),
          suffixInflection("tendr\xE1n", "tener", ["v"], ["v"]),
          suffixInflection("vendr\xE9", "venir", ["v"], ["v"]),
          suffixInflection("vendr\xE1s", "venir", ["v"], ["v"]),
          suffixInflection("vendr\xE1", "venir", ["v"], ["v"]),
          suffixInflection("vendremos", "venir", ["v"], ["v"]),
          suffixInflection("vendr\xE9is", "venir", ["v"], ["v"]),
          suffixInflection("vendr\xE1n", "venir", ["v"], ["v"])
        ]
      },
      "present subjunctive": {
        name: "present subjunctive",
        description: "Present subjunctive form of a verb",
        rules: [
          // STEM-CHANGING RULES FIRST
          // e->ie for -ar
          {
            type: "other",
            isInflected: /ie([a-z]*)(e|es|e|en)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(e|es|e|en)$/, "ar"),
            conditionsIn: ["v_ar"],
            conditionsOut: ["v_ar"]
          },
          // e->ie for -er
          {
            type: "other",
            isInflected: /ie([a-z]*)(a|as|a|an)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(a|as|a|an)$/, "er"),
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          // e->ie for -ir
          {
            type: "other",
            isInflected: /ie([a-z]*)(a|as|a|an)$/,
            deinflect: (term) => term.replace(/ie/, "e").replace(/(a|as|a|an)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // o->ue for -ar
          {
            type: "other",
            isInflected: /ue([a-z]*)(e|es|e|en)$/,
            deinflect: (term) => {
              if (term.startsWith("jue")) {
                return term.replace(/ue/, "u").replace(/(ue|ues|ue|uen)$/, "ar");
              }
              return term.replace(/ue/, "o").replace(/(e|es|e|en)$/, "ar");
            },
            conditionsIn: ["v_ar"],
            conditionsOut: ["v_ar"]
          },
          // o->ue for -er
          {
            type: "other",
            isInflected: /ue([a-z]*)(a|as|a|an)$/,
            deinflect: (term) => {
              if (term.startsWith("hue")) {
                return term.replace(/hue/, "o").replace(/(a|as|a|an)$/, "er");
              }
              return term.replace(/ue/, "o").replace(/(a|as|a|an)$/, "er");
            },
            conditionsIn: ["v_er"],
            conditionsOut: ["v_er"]
          },
          // o->ue for -ir
          {
            type: "other",
            isInflected: /ue([a-z]*)(a|as|a|an)$/,
            deinflect: (term) => term.replace(/ue/, "o").replace(/(a|as|a|an)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // e->i for -ir
          {
            type: "other",
            isInflected: /i([a-z]*)(a|as|a|an)$/,
            deinflect: (term) => term.replace(/i/, "e").replace(/(a|as|a|an)$/, "ir"),
            conditionsIn: ["v_ir"],
            conditionsOut: ["v_ir"]
          },
          // -ar verbs
          suffixInflection("e", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("es", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("e", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("emos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xE9is", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("en", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("a", "er", ["v_er"], ["v_er"]),
          suffixInflection("as", "er", ["v_er"], ["v_er"]),
          suffixInflection("a", "er", ["v_er"], ["v_er"]),
          suffixInflection("amos", "er", ["v_er"], ["v_er"]),
          suffixInflection("\xE1is", "er", ["v_er"], ["v_er"]),
          suffixInflection("an", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("a", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("as", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("a", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("amos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("\xE1is", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("an", "ir", ["v_ir"], ["v_ir"]),
          // irregular verbs
          wholeWordInflection("d\xE9", "dar", ["v"], ["v"]),
          wholeWordInflection("des", "dar", ["v"], ["v"]),
          wholeWordInflection("d\xE9", "dar", ["v"], ["v"]),
          wholeWordInflection("demos", "dar", ["v"], ["v"]),
          wholeWordInflection("deis", "dar", ["v"], ["v"]),
          wholeWordInflection("den", "dar", ["v"], ["v"]),
          wholeWordInflection("est\xE9", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE9s", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE9", "estar", ["v"], ["v"]),
          wholeWordInflection("estemos", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE9is", "estar", ["v"], ["v"]),
          wholeWordInflection("est\xE9n", "estar", ["v"], ["v"]),
          wholeWordInflection("sea", "ser", ["v"], ["v"]),
          wholeWordInflection("seas", "ser", ["v"], ["v"]),
          wholeWordInflection("sea", "ser", ["v"], ["v"]),
          wholeWordInflection("seamos", "ser", ["v"], ["v"]),
          wholeWordInflection("se\xE1is", "ser", ["v"], ["v"]),
          wholeWordInflection("sean", "ser", ["v"], ["v"]),
          wholeWordInflection("vaya", "ir", ["v"], ["v"]),
          wholeWordInflection("vayas", "ir", ["v"], ["v"]),
          wholeWordInflection("vaya", "ir", ["v"], ["v"]),
          wholeWordInflection("vayamos", "ir", ["v"], ["v"]),
          wholeWordInflection("vay\xE1is", "ir", ["v"], ["v"]),
          wholeWordInflection("vayan", "ir", ["v"], ["v"]),
          wholeWordInflection("haya", "haber", ["v"], ["v"]),
          wholeWordInflection("hayas", "haber", ["v"], ["v"]),
          wholeWordInflection("haya", "haber", ["v"], ["v"]),
          wholeWordInflection("hayamos", "haber", ["v"], ["v"]),
          wholeWordInflection("hay\xE1is", "haber", ["v"], ["v"]),
          wholeWordInflection("hayan", "haber", ["v"], ["v"]),
          wholeWordInflection("sepa", "saber", ["v"], ["v"]),
          wholeWordInflection("sepas", "saber", ["v"], ["v"]),
          wholeWordInflection("sepa", "saber", ["v"], ["v"]),
          wholeWordInflection("sepamos", "saber", ["v"], ["v"]),
          wholeWordInflection("sep\xE1is", "saber", ["v"], ["v"]),
          wholeWordInflection("sepan", "saber", ["v"], ["v"])
        ]
      },
      "imperfect subjunctive": {
        name: "imperfect subjunctive",
        description: "Imperfect subjunctive form of a verb",
        rules: [
          // -ar verbs
          suffixInflection("ara", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("ase", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aras", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("ases", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("ara", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("ase", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xE1ramos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("\xE1semos", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("arais", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aseis", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("aran", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("asen", "ar", ["v_ar"], ["v_ar"]),
          // -er verbs
          suffixInflection("iera", "er", ["v_er"], ["v_er"]),
          suffixInflection("iese", "er", ["v_er"], ["v_er"]),
          suffixInflection("ieras", "er", ["v_er"], ["v_er"]),
          suffixInflection("ieses", "er", ["v_er"], ["v_er"]),
          suffixInflection("iera", "er", ["v_er"], ["v_er"]),
          suffixInflection("iese", "er", ["v_er"], ["v_er"]),
          suffixInflection("i\xE9ramos", "er", ["v_er"], ["v_er"]),
          suffixInflection("i\xE9semos", "er", ["v_er"], ["v_er"]),
          suffixInflection("ierais", "er", ["v_er"], ["v_er"]),
          suffixInflection("ieseis", "er", ["v_er"], ["v_er"]),
          suffixInflection("ieran", "er", ["v_er"], ["v_er"]),
          suffixInflection("iesen", "er", ["v_er"], ["v_er"]),
          // -ir verbs
          suffixInflection("iera", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("iese", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("ieras", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("ieses", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("iera", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("iese", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("i\xE9ramos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("i\xE9semos", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("ierais", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("ieseis", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("ieran", "ir", ["v_ir"], ["v_ir"]),
          suffixInflection("iesen", "ir", ["v_ir"], ["v_ir"]),
          // irregular verbs
          wholeWordInflection("fuera", "ser", ["v"], ["v"]),
          wholeWordInflection("fuese", "ser", ["v"], ["v"]),
          wholeWordInflection("fueras", "ser", ["v"], ["v"]),
          wholeWordInflection("fueses", "ser", ["v"], ["v"]),
          wholeWordInflection("fuera", "ser", ["v"], ["v"]),
          wholeWordInflection("fuese", "ser", ["v"], ["v"]),
          wholeWordInflection("fu\xE9ramos", "ser", ["v"], ["v"]),
          wholeWordInflection("fu\xE9semos", "ser", ["v"], ["v"]),
          wholeWordInflection("fuerais", "ser", ["v"], ["v"]),
          wholeWordInflection("fueseis", "ser", ["v"], ["v"]),
          wholeWordInflection("fueran", "ser", ["v"], ["v"]),
          wholeWordInflection("fuesen", "ser", ["v"], ["v"]),
          wholeWordInflection("fuera", "ir", ["v"], ["v"]),
          wholeWordInflection("fuese", "ir", ["v"], ["v"]),
          wholeWordInflection("fueras", "ir", ["v"], ["v"]),
          wholeWordInflection("fueses", "ir", ["v"], ["v"]),
          wholeWordInflection("fuera", "ir", ["v"], ["v"]),
          wholeWordInflection("fuese", "ir", ["v"], ["v"]),
          wholeWordInflection("fu\xE9ramos", "ir", ["v"], ["v"]),
          wholeWordInflection("fu\xE9semos", "ir", ["v"], ["v"]),
          wholeWordInflection("fuerais", "ir", ["v"], ["v"]),
          wholeWordInflection("fueseis", "ir", ["v"], ["v"]),
          wholeWordInflection("fueran", "ir", ["v"], ["v"]),
          wholeWordInflection("fuesen", "ir", ["v"], ["v"])
        ]
      },
      "participle": {
        name: "participle",
        description: "Participle form of a verb",
        rules: [
          // -ar verbs
          suffixInflection("ado", "ar", ["adj"], ["v_ar"]),
          // -er verbs
          suffixInflection("ido", "er", ["adj"], ["v_er"]),
          // -ir verbs
          suffixInflection("ido", "ir", ["adj"], ["v_ir"]),
          // irregular verbs
          suffixInflection("o\xEDdo", "o\xEDr", ["adj"], ["v"]),
          wholeWordInflection("dicho", "decir", ["adj"], ["v"]),
          wholeWordInflection("escrito", "escribir", ["adj"], ["v"]),
          wholeWordInflection("hecho", "hacer", ["adj"], ["v"]),
          wholeWordInflection("muerto", "morir", ["adj"], ["v"]),
          wholeWordInflection("puesto", "poner", ["adj"], ["v"]),
          wholeWordInflection("roto", "romper", ["adj"], ["v"]),
          wholeWordInflection("visto", "ver", ["adj"], ["v"]),
          wholeWordInflection("vuelto", "volver", ["adj"], ["v"])
        ]
      },
      "reflexive": {
        name: "reflexive",
        description: "Reflexive form of a verb",
        rules: [
          suffixInflection("arse", "ar", ["v_ar"], ["v_ar"]),
          suffixInflection("erse", "er", ["v_er"], ["v_er"]),
          suffixInflection("irse", "ir", ["v_ir"], ["v_ir"])
        ]
      },
      "pronoun substitution": {
        name: "pronoun substitution",
        description: "Substituted pronoun of a reflexive verb",
        rules: [
          suffixInflection("arme", "arse", ["v_ar"], ["v_ar"]),
          suffixInflection("arte", "arse", ["v_ar"], ["v_ar"]),
          suffixInflection("arnos", "arse", ["v_er"], ["v_er"]),
          suffixInflection("erme", "erse", ["v_er"], ["v_er"]),
          suffixInflection("erte", "erse", ["v_er"], ["v_er"]),
          suffixInflection("ernos", "erse", ["v_er"], ["v_er"]),
          suffixInflection("irme", "irse", ["v_ir"], ["v_ir"]),
          suffixInflection("irte", "irse", ["v_ir"], ["v_ir"]),
          suffixInflection("irnos", "irse", ["v_ir"], ["v_ir"])
        ]
      },
      "pronominal": {
        // me despertar -> despertarse
        name: "pronominal",
        description: "Pronominal form of a verb",
        rules: [
          {
            type: "other",
            isInflected: new RegExp(REFLEXIVE_PATTERN),
            deinflect: (term) => {
              return term.replace(REFLEXIVE_PATTERN, (_match, _pronoun, verb, ending) => `${verb}${ending}se`);
            },
            conditionsIn: ["v"],
            conditionsOut: ["v"]
          }
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/es.js
  globalThis.mangatanRegisterYomitanTransforms("es", spanishTransforms);
})();
