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

  // third_party/yomitan/ext/js/language/el/modern-greek-transforms.js
  var conditions = {
    v: {
      name: "Verb",
      isDictionaryForm: true
    }
  };
  var modernGreekTransforms = {
    language: "el",
    conditions,
    transforms: {
      "\u03BE\u03B1\u03BD\u03B1-": {
        name: "\u03BE\u03B1\u03BD\u03B1-",
        rules: [
          // conditionIn is left empty because most likely the ξανα- form is not in the dictionary
          prefixInflection("\u03BE\u03B1\u03BD\u03B1", "", [], ["v"]),
          // ξαναρώτησε > ρώτησε
          prefixInflection("\u03BE\u03B1\u03BD\u03B1", "\u03B1", [], ["v"]),
          // ξανανθίζω > ανθίζω
          prefixInflection("\u03BE\u03B1\u03BD\u03AC", "\u03AD", [], ["v"]),
          // ξανάβαλε > έβαλε
          prefixInflection("\u03BE\u03B1\u03BD\u03AC", "\u03AC", [], ["v"]),
          // ξανάρχισε > άρχισε
          prefixInflection("\u03BE\u03B1\u03BD\u03AC\u03C0\u03B1", "\u03B5\u03AF\u03C0\u03B1", [], ["v"]),
          // edge case
          {
            // ξαναπάς > πας, ξαναλές > λες, ξαναφάς > φας, ξαναδεί > δει
            type: "other",
            isInflected: /^ξανα/,
            // cf. import {removeAlphabeticDiacritics} from '../text-processors.js';
            deinflect: (term) => term.replace(/^ξανα/, "").normalize("NFD").replace(/[\u0300-\u036f]/g, ""),
            conditionsIn: [],
            conditionsOut: ["v"]
          }
        ]
      }
    }
  };

  // third_party/yomitan/ext/js/language/transform-entries/el.js
  globalThis.mangatanRegisterYomitanTransforms("el", modernGreekTransforms);
})();
