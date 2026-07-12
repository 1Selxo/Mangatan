(() => {
  // third_party/yomitan/ext/js/language/aii/assyrian-neo-aramaic-text-preprocessors.js
  var optionalDiacritics = ["\u0303", "\u0304", "\u0307", "\u0308", "\u0323", "\u032E", "\u0330", "\u0331", "\u0730", "\u0731", "\u0732", "\u0733", "\u0734", "\u0735", "\u0736", "\u0737", "\u0738", "\u0739", "\u073A", "\u073B", "\u073C", "\u073D", "\u073E", "\u073F", "\u0740", "\u0741", "\u0742", "\u0743", "\u0744", "\u0745", "\u0746", "\u0747", "\u0748", "\u0749", "\u074A"];
  var diacriticsRegex = new RegExp(`[${optionalDiacritics.join("")}]`, "g");
  var removeSyriacScriptDiacritics = {
    name: "Remove diacritics",
    description: "\u071F\u0735\u072C\u0739\u0712\u0742 \u2B05\uFE0F \u071F\u072C\u0712",
    process: (text) => [text, text.replace(diacriticsRegex, "")]
  };

  // third_party/yomitan/ext/js/language/ar/arabic-text-preprocessors.js
  var optionalDiacritics2 = [
    "\u0618",
    // Small Fatha
    "\u0619",
    // Small Damma
    "\u061A",
    // Small Kasra
    "\u064B",
    // Fathatan
    "\u064C",
    // Dammatan
    "\u064D",
    // Kasratan
    "\u064E",
    // Fatha
    "\u064F",
    // Damma
    "\u0650",
    // Kasra
    "\u0651",
    // Shadda
    "\u0652",
    // Sukun
    "\u0653",
    // Maddah
    "\u0654",
    // Hamza Above
    "\u0655",
    // Hamza Below
    "\u0656",
    // Subscript Alef
    "\u0670"
    // Dagger Alef
  ];
  var diacriticsRegex2 = new RegExp(`[${optionalDiacritics2.join("")}]`, "g");
  var removeArabicScriptDiacritics = {
    name: "Remove diacritics",
    description: "\u0648\u064E\u0644\u064E\u062F\u064E \u2192 \u0648\u0644\u062F",
    process: (text) => [text, text.replace(diacriticsRegex2, "")]
  };
  var removeTatweel = {
    name: "Remove tatweel characters",
    description: "\u0644\u0640\u0643\u0646 \u2192 \u0644\u0643\u0646",
    process: (text) => [text, text.replaceAll("\u0640", "")]
  };
  var normalizeUnicode = {
    name: "Normalize unicode",
    description: "\uFEF4 \u2192 \u064A",
    process: (text) => [text, text.normalize("NFKC")]
  };
  var addHamzaTop = {
    name: "Add Hamza to top of Alif",
    description: "\u0627\u0643\u0628\u0631 \u2192 \u0623\u0643\u0628\u0631",
    process: (text) => [text, text.replace("\u0627", "\u0623")]
  };
  var addHamzaBottom = {
    name: "Add Hamza to bottom of Alif",
    description: "\u0627\u0633\u0644\u0627\u0645 \u2192 \u0625\u0633\u0644\u0627\u0645",
    process: (text) => [text, text.replace("\u0627", "\u0625")]
  };
  var convertAlifMaqsuraToYaa = {
    name: "Convert Alif Maqsura to Yaa",
    description: "\u0641\u0649 \u2192 \u0641\u064A",
    process: (text) => [text, text.replace(/ى$/, "\u064A")]
  };
  var convertHaToTaMarbuta = {
    name: "Convert final Ha to Ta Marbuta",
    description: "\u0644\u063A\u0647 \u2192 \u0644\u063A\u0629",
    process: (text) => [text, text.replace(/ه$/, "\u0629")]
  };

  // third_party/yomitan/ext/js/language/CJK-util.js
  function isCodePointInRanges(codePoint, ranges) {
    for (const [min, max] of ranges) {
      if (codePoint >= min && codePoint <= max) {
        return true;
      }
    }
    return false;
  }
  var KANGXI_RADICALS_RANGE = [12032, 12255];
  var CJK_RADICALS_SUPPLEMENT_RANGE = [11904, 12031];
  var CJK_STROKES_RANGE = [12736, 12783];
  var CJK_RADICALS_RANGES = [
    KANGXI_RADICALS_RANGE,
    CJK_RADICALS_SUPPLEMENT_RANGE,
    CJK_STROKES_RANGE
  ];
  function normalizeRadicals(text) {
    let result = "";
    for (let i = 0; i < text.length; i++) {
      const codePoint = text[i].codePointAt(0);
      result += codePoint && isCodePointInRanges(codePoint, CJK_RADICALS_RANGES) ? text[i].normalize("NFKD") : text[i];
    }
    return result;
  }
  var normalizeRadicalCharacters = {
    name: "Normalize radical characters",
    description: "\u2F00 \u2192 \u4E00 (U+2F00 \u2192 U+4E00)",
    process: (str) => [str, normalizeRadicals(str)]
  };

  // third_party/yomitan/ext/js/language/de/german-text-preprocessors.js
  var eszettPreprocessor = {
    name: 'Convert "\xDF" to "ss"',
    description: "\xDF \u2192 ss, \u1E9E \u2192 SS and vice versa",
    process: (str) => [
      str,
      str.replace(/ẞ/g, "SS").replace(/ß/g, "ss"),
      str.replace(/SS/g, "\u1E9E").replace(/ss/g, "\xDF")
    ]
  };

  // third_party/yomitan/ext/js/language/el/modern-greek-processors.js
  var removeDoubleAcuteAccents = {
    name: "Remove double acute accents",
    description: "\u03C0\u03C1\u03CC\u03C3\u03C9\u03C0\u03CC \u2192 \u03C0\u03C1\u03CC\u03C3\u03C9\u03C0\u03BF",
    process: (str) => [str, removeDoubleAcuteAccentsImpl(str)]
  };
  function removeDoubleAcuteAccentsImpl(word) {
    const ACUTE_ACCENT = "\u0301";
    const decomposed = [...word.normalize("NFD")];
    const firstIndex = decomposed.indexOf(ACUTE_ACCENT);
    const updated = decomposed.filter((char, index) => char !== ACUTE_ACCENT || index === firstIndex);
    return updated.join("").normalize("NFC");
  }

  // third_party/yomitan/ext/js/language/fr/french-text-preprocessors.js
  var apostropheVariants = {
    name: "Search for apostrophe variants",
    description: "' \u2192 \u2019 and vice versa",
    process: (str) => [
      str,
      str.replace(/'/g, "\u2019"),
      str.replace(/\u2019/g, "'")
    ]
  };

  // third_party/yomitan/ext/js/language/grc/ancient-greek-processors.js
  var convertLatinToGreek = {
    name: "Convert latin characters to greek",
    description: "a \u2192 \u03B1, A \u2192 \u0391, b \u2192 \u03B2, B \u2192 \u0392, etc.",
    process: (str) => [str, latinToGreek(str)]
  };
  function latinToGreek(latin) {
    latin = latin.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const singleMap = {
      a: "\u03B1",
      b: "\u03B2",
      g: "\u03B3",
      d: "\u03B4",
      e: "\u03B5",
      z: "\u03B6",
      \u0113: "\u03B7",
      i: "\u03B9",
      k: "\u03BA",
      l: "\u03BB",
      m: "\u03BC",
      n: "\u03BD",
      x: "\u03BE",
      o: "\u03BF",
      p: "\u03C0",
      r: "\u03C1",
      s: "\u03C3",
      t: "\u03C4",
      u: "\u03C5",
      \u014D: "\u03C9",
      A: "\u0391",
      B: "\u0392",
      G: "\u0393",
      D: "\u0394",
      E: "\u0395",
      Z: "\u0396",
      \u0112: "\u0397",
      I: "\u0399",
      K: "\u039A",
      L: "\u039B",
      M: "\u039C",
      N: "\u039D",
      X: "\u039E",
      O: "\u039F",
      P: "\u03A0",
      R: "\u03A1",
      S: "\u03A3",
      T: "\u03A4",
      U: "\u03A5",
      \u014C: "\u03A9"
    };
    const doubleMap = {
      th: "\u03B8",
      ph: "\u03C6",
      ch: "\u03C7",
      ps: "\u03C8",
      Th: "\u0398",
      Ph: "\u03A6",
      Ch: "\u03A7",
      Ps: "\u03A8"
    };
    let result = latin;
    for (const [double, greek] of Object.entries(doubleMap)) {
      result = result.replace(new RegExp(double, "g"), greek);
    }
    for (const [single, greek] of Object.entries(singleMap)) {
      result = result.replace(new RegExp(single, "g"), greek);
    }
    result = result.replace(/σ$/, "\u03C2");
    return result;
  }

  // third_party/yomitan/ext/js/language/it/italian-processors.js
  var removeApostrophedWords = {
    name: "Remove common apostrophed words",
    description: "dell'Italia > Italia, c'erano > erano",
    process: (str) => [
      str,
      removeApostrophedWordsImpl(str)
    ]
  };
  function removeApostrophedWordsImpl(word) {
    return word.replace(/(l|dell|all|dall|nell|sull|coll|un|quest|quell|c|n)['’]/g, "");
  }

  // third_party/yomitan/ext/js/language/la/latin-text-preprocessors.js
  var processDiphtongs = {
    name: "Convert \xE6 to ae",
    description: "\xE6 \u2192 ae, \xC6 \u2192 AE, \u0153 \u2192 oe, \u0152 \u2192 OE",
    process: (str) => [
      str,
      str.replace(/æ/g, "ae").replace(/Æ/g, "AE").replace(/œ/g, "oe").replace(/Œ/g, "OE"),
      str.replace(/ae/g, "\xE6").replace(/AE/g, "\xC6").replace(/oe/g, "\u0153").replace(/OE/g, "\u0152")
    ]
  };

  // third_party/yomitan/ext/js/core/event-dispatcher.js
  var EventDispatcher = class {
    /**
     * Creates a new instance.
     */
    constructor() {
      this._eventMap = /* @__PURE__ */ new Map();
    }
    /**
     * Triggers an event with the given name and specified argument.
     * @template {import('core').EventNames<TSurface>} TName
     * @param {TName} eventName The string representing the event's name.
     * @param {import('core').EventArgument<TSurface, TName>} details The argument passed to the callback functions.
     * @returns {boolean} `true` if any callbacks were registered, `false` otherwise.
     */
    trigger(eventName, details) {
      const callbacks = this._eventMap.get(eventName);
      if (typeof callbacks === "undefined") {
        return false;
      }
      for (const callback of callbacks) {
        callback(details);
      }
      return true;
    }
    /**
     * Adds a single event listener to a specific event.
     * @template {import('core').EventNames<TSurface>} TName
     * @param {TName} eventName The string representing the event's name.
     * @param {import('core').EventHandler<TSurface, TName>} callback The event listener callback to add.
     */
    on(eventName, callback) {
      let callbacks = this._eventMap.get(eventName);
      if (typeof callbacks === "undefined") {
        callbacks = [];
        this._eventMap.set(eventName, callbacks);
      }
      callbacks.push(callback);
    }
    /**
     * Removes a single event listener from a specific event.
     * @template {import('core').EventNames<TSurface>} TName
     * @param {TName} eventName The string representing the event's name.
     * @param {import('core').EventHandler<TSurface, TName>} callback The event listener callback to add.
     * @returns {boolean} `true` if the callback was removed, `false` otherwise.
     */
    off(eventName, callback) {
      const callbacks = this._eventMap.get(eventName);
      if (typeof callbacks === "undefined") {
        return false;
      }
      const ii = callbacks.length;
      for (let i = 0; i < ii; ++i) {
        if (callbacks[i] === callback) {
          callbacks.splice(i, 1);
          if (callbacks.length === 0) {
            this._eventMap.delete(eventName);
          }
          return true;
        }
      }
      return false;
    }
    /**
     * Checks if an event has any listeners.
     * @template {import('core').EventNames<TSurface>} TName
     * @param {TName} eventName The string representing the event's name.
     * @returns {boolean} `true` if the event has listeners, `false` otherwise.
     */
    hasListeners(eventName) {
      const callbacks = this._eventMap.get(eventName);
      return typeof callbacks !== "undefined" && callbacks.length > 0;
    }
  };

  // third_party/yomitan/ext/js/core/extension-error.js
  var ExtensionError = class _ExtensionError extends Error {
    /**
     * @param {string} message
     */
    constructor(message) {
      super(message);
      this.name = "ExtensionError";
      this._data = void 0;
    }
    /** @type {unknown} */
    get data() {
      return this._data;
    }
    set data(value) {
      this._data = value;
    }
    /**
     * Converts an `Error` object to a serializable JSON object.
     * @param {unknown} error An error object to convert.
     * @returns {import('core').SerializedError} A simple object which can be serialized by `JSON.stringify()`.
     */
    static serialize(error) {
      try {
        if (typeof error === "object" && error !== null) {
          const { name, message, stack } = (
            /** @type {import('core').SerializableObject} */
            error
          );
          const result = {
            name: typeof name === "string" ? name : "",
            message: typeof message === "string" ? message : "",
            stack: typeof stack === "string" ? stack : ""
          };
          if (error instanceof _ExtensionError) {
            result.data = error.data;
          }
          return result;
        }
      } catch (e) {
      }
      return (
        /** @type {import('core').SerializedError2} */
        {
          value: error,
          hasValue: true
        }
      );
    }
    /**
     * Converts a serialized error into a standard `Error` object.
     * @param {import('core').SerializedError} serializedError A simple object which was initially generated by the `serialize` function.
     * @returns {ExtensionError} A new `Error` instance.
     */
    static deserialize(serializedError) {
      if (serializedError.hasValue) {
        const { value } = serializedError;
        return new _ExtensionError(`Error of type ${typeof value}: ${value}`);
      }
      const { message, name, stack, data } = serializedError;
      const error = new _ExtensionError(message);
      error.name = name;
      error.stack = stack;
      if (typeof data !== "undefined") {
        error.data = data;
      }
      return error;
    }
  };

  // third_party/yomitan/ext/js/core/log.js
  var Logger = class extends EventDispatcher {
    constructor() {
      super();
      this._extensionName = "Extension";
      this._issueUrl = "https://github.com/yomidevs/yomitan/issues";
    }
    /**
     * @param {string} extensionName
     */
    configure(extensionName) {
      this._extensionName = extensionName;
    }
    /**
     * @param {unknown} message
     * @param {...unknown} optionalParams
     */
    log(message, ...optionalParams) {
      console.log(message, ...optionalParams);
    }
    /**
     * Logs a warning.
     * @param {unknown} error The error to log. This is typically an `Error` or `Error`-like object.
     */
    warn(error) {
      this.logGenericError(error, "warn");
    }
    /**
     * Logs an error.
     * @param {unknown} error The error to log. This is typically an `Error` or `Error`-like object.
     */
    error(error) {
      this.logGenericError(error, "error");
    }
    /**
     * Logs a generic error.
     * @param {unknown} error The error to log. This is typically an `Error` or `Error`-like object.
     * @param {import('log').LogLevel} level
     * @param {import('log').LogContext} [context]
     */
    logGenericError(error, level, context) {
      if (typeof context === "undefined") {
        context = typeof location === "undefined" ? { url: "unknown" } : { url: location.href };
      }
      let errorString;
      try {
        if (typeof error === "string") {
          errorString = error;
        } else {
          errorString = typeof error === "object" && error !== null ? (
            // eslint-disable-next-line @typescript-eslint/no-base-to-string
            error.toString()
          ) : `${error}`;
          if (/^\[object \w+\]$/.test(errorString)) {
            errorString = JSON.stringify(error);
          }
        }
      } catch (e) {
        errorString = `${error}`;
      }
      let errorStack;
      try {
        errorStack = error instanceof Error ? typeof error.stack === "string" ? error.stack.trimEnd() : "" : "";
      } catch (e) {
        errorStack = "";
      }
      let errorData;
      try {
        if (error instanceof ExtensionError) {
          errorData = error.data;
        }
      } catch (e) {
      }
      if (errorStack.startsWith(errorString)) {
        errorString = errorStack;
      } else if (errorStack.length > 0) {
        errorString += `
${errorStack}`;
      }
      let message = `${this._extensionName} has encountered a problem.`;
      message += `
Originating URL: ${context.url}
`;
      message += errorString;
      if (typeof errorData !== "undefined") {
        message += `
Data: ${JSON.stringify(errorData, null, 4)}`;
      }
      if (this._issueUrl !== null) {
        message += `

Issues can be reported at ${this._issueUrl}`;
      }
      switch (level) {
        case "log":
          console.log(message);
          break;
        case "warn":
          console.warn(message);
          break;
        case "error":
          console.error(message);
          break;
      }
      this.trigger("logGenericError", { error, level, context });
    }
  };
  var log = new Logger();

  // third_party/yomitan/ext/js/language/language-transformer.js
  var LanguageTransformer = class _LanguageTransformer {
    constructor() {
      this._nextFlagIndex = 0;
      this._transforms = [];
      this._conditionTypeToConditionFlagsMap = /* @__PURE__ */ new Map();
      this._partOfSpeechToConditionFlagsMap = /* @__PURE__ */ new Map();
    }
    /** */
    clear() {
      this._nextFlagIndex = 0;
      this._transforms = [];
      this._conditionTypeToConditionFlagsMap.clear();
      this._partOfSpeechToConditionFlagsMap.clear();
    }
    /**
     * @param {import('language-transformer').LanguageTransformDescriptor} descriptor
     * @throws {Error}
     */
    addDescriptor(descriptor) {
      const { conditions, transforms } = descriptor;
      const conditionEntries = Object.entries(conditions);
      const { conditionFlagsMap, nextFlagIndex } = this._getConditionFlagsMap(conditionEntries, this._nextFlagIndex);
      const transforms2 = [];
      for (const [transformId, transform] of Object.entries(transforms)) {
        const { name, description, rules } = transform;
        const rules2 = [];
        for (let j = 0, jj = rules.length; j < jj; ++j) {
          const { type, isInflected, deinflect, conditionsIn, conditionsOut } = rules[j];
          const conditionFlagsIn = this._getConditionFlagsStrict(conditionFlagsMap, conditionsIn);
          if (conditionFlagsIn === null) {
            throw new Error(`Invalid conditionsIn for transform ${transformId}.rules[${j}]`);
          }
          const conditionFlagsOut = this._getConditionFlagsStrict(conditionFlagsMap, conditionsOut);
          if (conditionFlagsOut === null) {
            throw new Error(`Invalid conditionsOut for transform ${transformId}.rules[${j}]`);
          }
          rules2.push({
            type,
            isInflected,
            deinflect,
            conditionsIn: conditionFlagsIn,
            conditionsOut: conditionFlagsOut
          });
        }
        const isInflectedTests = rules.map((rule) => rule.isInflected);
        const heuristic = new RegExp(isInflectedTests.map((regExp) => regExp.source).join("|"));
        transforms2.push({ id: transformId, name, description, rules: rules2, heuristic });
      }
      this._nextFlagIndex = nextFlagIndex;
      for (const transform of transforms2) {
        this._transforms.push(transform);
      }
      for (const [type, { isDictionaryForm }] of conditionEntries) {
        const flags = conditionFlagsMap.get(type);
        if (typeof flags === "undefined") {
          continue;
        }
        this._conditionTypeToConditionFlagsMap.set(type, flags);
        if (isDictionaryForm) {
          this._partOfSpeechToConditionFlagsMap.set(type, flags);
        }
      }
    }
    /**
     * @param {string[]} partsOfSpeech
     * @returns {number}
     */
    getConditionFlagsFromPartsOfSpeech(partsOfSpeech) {
      return this._getConditionFlags(this._partOfSpeechToConditionFlagsMap, partsOfSpeech);
    }
    /**
     * @param {string[]} conditionTypes
     * @returns {number}
     */
    getConditionFlagsFromConditionTypes(conditionTypes) {
      return this._getConditionFlags(this._conditionTypeToConditionFlagsMap, conditionTypes);
    }
    /**
     * @param {string} conditionType
     * @returns {number}
     */
    getConditionFlagsFromConditionType(conditionType) {
      return this._getConditionFlags(this._conditionTypeToConditionFlagsMap, [conditionType]);
    }
    /**
     * @param {string} sourceText
     * @returns {import('language-transformer-internal').TransformedText[]}
     */
    transform(sourceText) {
      const results = [_LanguageTransformer.createTransformedText(sourceText, 0, [])];
      for (let i = 0; i < results.length; ++i) {
        const { text, conditions, trace } = results[i];
        for (const transform of this._transforms) {
          if (!transform.heuristic.test(text)) {
            continue;
          }
          const { id, rules } = transform;
          for (let j = 0, jj = rules.length; j < jj; ++j) {
            const rule = rules[j];
            if (!_LanguageTransformer.conditionsMatch(conditions, rule.conditionsIn)) {
              continue;
            }
            const { isInflected, deinflect } = rule;
            if (!isInflected.test(text)) {
              continue;
            }
            const isCycle = trace.some((frame) => frame.transform === id && frame.ruleIndex === j && frame.text === text);
            if (isCycle) {
              log.warn(new Error(`Cycle detected in transform[${id}] rule[${j}] for text: ${text}
Trace: ${JSON.stringify(trace)}`));
              continue;
            }
            results.push(_LanguageTransformer.createTransformedText(
              deinflect(text),
              rule.conditionsOut,
              this._extendTrace(trace, { transform: id, ruleIndex: j, text })
            ));
          }
        }
      }
      return results;
    }
    /**
     * @param {string[]} inflectionRules
     * @returns {import('dictionary').InflectionRuleChain}
     */
    getUserFacingInflectionRules(inflectionRules) {
      return inflectionRules.map((rule) => {
        const fullRule = this._transforms.find((transform) => transform.id === rule);
        if (typeof fullRule === "undefined") {
          return { name: rule };
        }
        const { name, description } = fullRule;
        return description ? { name, description } : { name };
      });
    }
    /**
     * @param {string} text
     * @param {number} conditions
     * @param {import('language-transformer-internal').Trace} trace
     * @returns {import('language-transformer-internal').TransformedText}
     */
    static createTransformedText(text, conditions, trace) {
      return { text, conditions, trace };
    }
    /**
     * If `currentConditions` is `0`, then `nextConditions` is ignored and `true` is returned.
     * Otherwise, there must be at least one shared condition between `currentConditions` and `nextConditions`.
     * @param {number} currentConditions
     * @param {number} nextConditions
     * @returns {boolean}
     */
    static conditionsMatch(currentConditions, nextConditions) {
      return currentConditions === 0 || (currentConditions & nextConditions) !== 0;
    }
    /**
     * @param {import('language-transformer').ConditionMapEntries} conditions
     * @param {number} nextFlagIndex
     * @returns {{conditionFlagsMap: Map<string, number>, nextFlagIndex: number}}
     * @throws {Error}
     */
    _getConditionFlagsMap(conditions, nextFlagIndex) {
      const conditionFlagsMap = /* @__PURE__ */ new Map();
      let targets = conditions;
      while (targets.length > 0) {
        const nextTargets = [];
        for (const target of targets) {
          const [type, condition] = target;
          const { subConditions } = condition;
          let flags = 0;
          if (typeof subConditions === "undefined") {
            if (nextFlagIndex >= 32) {
              throw new Error("Maximum number of conditions was exceeded");
            }
            flags = 1 << nextFlagIndex;
            ++nextFlagIndex;
          } else {
            const multiFlags = this._getConditionFlagsStrict(conditionFlagsMap, subConditions);
            if (multiFlags === null) {
              nextTargets.push(target);
              continue;
            } else {
              flags = multiFlags;
            }
          }
          conditionFlagsMap.set(type, flags);
        }
        if (nextTargets.length === targets.length) {
          throw new Error("Maximum number of conditions was exceeded");
        }
        targets = nextTargets;
      }
      return { conditionFlagsMap, nextFlagIndex };
    }
    /**
     * @param {Map<string, number>} conditionFlagsMap
     * @param {string[]} conditionTypes
     * @returns {?number}
     */
    _getConditionFlagsStrict(conditionFlagsMap, conditionTypes) {
      let flags = 0;
      for (const conditionType of conditionTypes) {
        const flags2 = conditionFlagsMap.get(conditionType);
        if (typeof flags2 === "undefined") {
          return null;
        }
        flags |= flags2;
      }
      return flags;
    }
    /**
     * @param {Map<string, number>} conditionFlagsMap
     * @param {string[]} conditionTypes
     * @returns {number}
     */
    _getConditionFlags(conditionFlagsMap, conditionTypes) {
      let flags = 0;
      for (const conditionType of conditionTypes) {
        let flags2 = conditionFlagsMap.get(conditionType);
        if (typeof flags2 === "undefined") {
          flags2 = 0;
        }
        flags |= flags2;
      }
      return flags;
    }
    /**
     * @param {import('language-transformer-internal').Trace} trace
     * @param {import('language-transformer-internal').TraceFrame} newFrame
     * @returns {import('language-transformer-internal').Trace}
     */
    _extendTrace(trace, newFrame) {
      const newTrace = [newFrame];
      for (const { transform, ruleIndex, text } of trace) {
        newTrace.push({ transform, ruleIndex, text });
      }
      return newTrace;
    }
  };

  // third_party/yomitan/ext/js/language/ru/russian-text-preprocessors.js
  var removeRussianDiacritics = {
    name: "Remove diacritics",
    description: "A\u0301 \u2192 A, a\u0301 \u2192 a",
    process: (str) => [str, str.replace(/\u0301/g, "")]
  };
  var yoToE = {
    name: 'Convert "\u0451" to "\u0435"',
    description: "\u0451 \u2192 \u0435, \u0401 \u2192 \u0415 and vice versa",
    process: (str) => [
      str,
      str.replace(/ё/g, "\u0435").replace(/Ё/g, "\u0415"),
      str.replace(/е/g, "\u0451").replace(/Е/g, "\u0401")
    ]
  };

  // third_party/yomitan/ext/js/language/text-processors.js
  var MAX_PROCESS_VARIANTS = 4096;
  var decapitalize = {
    name: "Decapitalize text",
    description: "CAPITALIZED TEXT \u2192 capitalized text",
    process: (str) => [str, str.toLowerCase()]
  };
  var capitalizeFirstLetter = {
    name: "Capitalize first letter",
    description: "lowercase text \u2192 Lowercase text",
    process: (str) => [str, str.charAt(0).toUpperCase() + str.slice(1)]
  };
  var removeAlphabeticDiacritics = {
    name: "Remove Alphabetic Diacritics",
    description: "\u1F04\u03AE\xE9 -> \u03B1\u03B7e",
    process: (str) => [str, str.normalize("NFD").replace(/[\u0300-\u036f]/g, "")]
  };

  // third_party/yomitan/ext/js/language/sh/serbo-croatian-text-preprocessors.js
  function generateDiacriticVariants(str) {
    str = str.normalize("NFC");
    let variants = [""];
    let warned = false;
    for (let i = 0; i < str.length; i++) {
      const ch = str[i];
      const next = str[i + 1];
      if ((ch === "d" || ch === "D") && (next === "j" || next === "J")) {
        const base = ch + next;
        const \u0111 = ch === "D" ? "\u0110" : "\u0111";
        variants = variants.flatMap((v) => [v + base, v + \u0111]);
        i++;
      } else {
        let choices;
        switch (ch) {
          case "c":
            choices = ["c", "\u010D", "\u0107"];
            break;
          case "C":
            choices = ["C", "\u010C", "\u0106"];
            break;
          case "z":
            choices = ["z", "\u017E"];
            break;
          case "Z":
            choices = ["Z", "\u017D"];
            break;
          case "s":
            choices = ["s", "\u0161"];
            break;
          case "S":
            choices = ["S", "\u0160"];
            break;
          default:
            choices = [ch];
            break;
        }
        variants = variants.flatMap((v) => choices.map((c) => v + c));
      }
      if (variants.length > MAX_PROCESS_VARIANTS) {
        if (!warned) {
          console.warn(`addSerboCroatianDiacritics: input "${str}" produces too many variants; truncating to ${MAX_PROCESS_VARIANTS}`);
          warned = true;
        }
        variants = variants.slice(0, MAX_PROCESS_VARIANTS);
      }
    }
    return variants;
  }
  var addSerboCroatianDiacritics = {
    name: "Add diacritics",
    description: "c \u2192 \u010D/\u0107, z \u2192 \u017E, s \u2192 \u0161, dj \u2192 \u0111",
    process: (str) => generateDiacriticVariants(str)
  };
  var removeSerboCroatianAccentMarks = {
    name: "Remove vowel accents",
    description: "A\u0301 \u2192 A, a\u0301 \u2192 a",
    process: (str) => [
      str,
      str.normalize("NFD").replace(/[aeiourAEIOUR][\u0300-\u036f]/g, (match) => match[0])
    ]
  };

  // third_party/yomitan/ext/js/language/vi/viet-text-preprocessors.js
  var TONE = "([\u0300\u0309\u0303\u0301\u0323])";
  var COMBINING_BREVE = "\u0306";
  var COMBINING_CIRCUMFLEX_ACCENT = "\u0302";
  var COMBINING_HORN = "\u031B";
  var DIACRITICS = `${COMBINING_BREVE}${COMBINING_CIRCUMFLEX_ACCENT}${COMBINING_HORN}`;
  var re1 = new RegExp(`${TONE}([aeiouy${DIACRITICS}]+)`, "i");
  var re2 = new RegExp(`(?<=[${DIACRITICS}])(.)${TONE}`, "i");
  var re3 = new RegExp(`(?<=[ae])([iouy])${TONE}`, "i");
  var re4 = new RegExp(`(?<=[oy])([iuy])${TONE}`, "i");
  var re5 = new RegExp(`(?<!q)(u)([aeiou])${TONE}`, "i");
  var re6 = new RegExp(`(?<!g)(i)([aeiouy])${TONE}`, "i");
  var re7 = new RegExp(`(?<!q)([ou])([aeoy])${TONE}(?!\\w)`, "i");
  function normalizeDiacriticsImpl(str, style) {
    let result = str.normalize("NFD");
    result = result.replace(re1, "$2$1");
    result = result.replace(re2, "$2$1");
    result = result.replace(re3, "$2$1");
    result = result.replace(re4, "$2$1");
    result = result.replace(re5, "$1$3$2");
    result = result.replace(re6, "$1$3$2");
    if (style === "old") {
      result = result.replace(re7, "$1$3$2");
    }
    return result.normalize("NFC");
  }
  var normalizeDiacritics = {
    name: "Normalize Diacritics",
    description: "Normalize diacritics and their placements (in either the old style or new style). NFC normalization is used.",
    process: (str) => [str, normalizeDiacriticsImpl(str, "old"), normalizeDiacriticsImpl(str, "new")]
  };

  // third_party/yomitan/ext/js/language/yi/yiddish-text-postprocessors.js
  var final_letter_map = /* @__PURE__ */ new Map([
    ["\u05DE", "\u05DD"],
    // מ to ם
    ["\u05E0", "\u05DF"],
    // נ to ן
    ["\u05E6", "\u05E5"],
    // צ to ץ
    ["\u05E4", "\u05E3"],
    // פ to ף
    ["\u05DB", "\u05DA"]
    // כ to ך
  ]);
  var ligatures = [
    { lig: "\u05F0", split: "\u05D5\u05D5" },
    // װ -> וו
    { lig: "\u05F1", split: "\u05D5\u05D9" },
    // ױ -> וי
    { lig: "\u05F2", split: "\u05D9\u05D9" },
    // ײ -> יי
    { lig: "\uFB1D", split: "\u05D9\u05B4" },
    // יִ -> יִ
    { lig: "\uFB1F", split: "\u05D9\u05D9\u05B7" },
    // ײַ -> ייַ
    { lig: "\uFB2E", split: "\u05D0\u05B7" },
    // Pasekh alef
    { lig: "\uFB2F", split: "\u05D0\u05B8" }
    // Komets alef
  ];
  var convertFinalLetters = {
    name: "Convert to Final Letters",
    description: "\u05E7\u05D5\u05D9\u05E3 \u2192 \u05E7\u05D5\u05D9\u05E4\u05BF",
    process: (str) => {
      const len = str.length - 1;
      if ([...final_letter_map.keys()].includes(str.charAt(len))) {
        str = str.substring(0, len) + final_letter_map.get(str.substring(len));
      }
      return [str];
    }
  };
  var convertYiddishLigatures = {
    name: "Split Ligatures",
    description: "\u05D5\u05D5 \u2192 \u05F0",
    process: (str) => {
      let direct = str;
      for (const ligature of ligatures) {
        direct = direct.replace(ligature.lig, ligature.split);
      }
      let inverse = str;
      for (const ligature of ligatures) {
        inverse = inverse.replace(ligature.split, ligature.lig);
      }
      return [str, direct, inverse];
    }
  };

  // third_party/yomitan/ext/js/language/yi/yiddish-text-preprocessors.js
  var ligatures2 = [
    { lig: "\u05F0", split: "\u05D5\u05D5" },
    // װ -> וו
    { lig: "\u05F1", split: "\u05D5\u05D9" },
    // ױ -> וי
    { lig: "\u05F2", split: "\u05D9\u05D9" },
    // ײ -> יי
    { lig: "\uFB1D", split: "\u05D9\u05B4" },
    // יִ -> יִ
    { lig: "\uFB1F", split: "\u05D9\u05D9\u05B7" },
    // ײַ -> ייַ
    { lig: "\uFB2E", split: "\u05D0\u05B7" },
    // Pasekh alef
    { lig: "\uFB2F", split: "\u05D0\u05B8" }
    // Komets alef
  ];
  var combineYiddishLigatures = {
    name: "Combine Ligatures",
    description: "\u05D5\u05D5 \u2192 \u05F0",
    process: (str) => {
      for (const ligature of ligatures2) {
        str = str.replace(ligature.split, ligature.lig);
      }
      return [str];
    }
  };
  var removeYiddishDiacritics = {
    name: "Remove Diacritics",
    description: "\u05E4\u05D0\u05EA \u2192 \u05E4\u05BF\u05D0\u05B8\u05EA\u05BC",
    process: (str) => [str.replace(/[\u05B0-\u05C7]/g, "")]
  };

  // third_party/yomitan/ext/js/language/mangatan-entry.js
  var capitalizationPreprocessors = { decapitalize, capitalizeFirstLetter };
  var arabicPreprocessors = {
    removeArabicScriptDiacritics,
    removeTatweel,
    normalizeUnicode,
    addHamzaTop,
    addHamzaBottom,
    convertAlifMaqsuraToYaa
  };
  var descriptors = /* @__PURE__ */ new Map();
  function add(iso, textPreprocessors = {}, languageTransforms = null, textPostprocessors = {}) {
    descriptors.set(iso, { iso, textPreprocessors, languageTransforms, textPostprocessors });
  }
  add("aii", { removeSyriacScriptDiacritics });
  add("ar", arabicPreprocessors);
  add("arz", { ...arabicPreprocessors, convertHaToTaMarbuta });
  for (const iso of ["be", "bg", "cs", "da", "et", "fi", "gd", "haw", "hu", "lv", "mn", "mt", "nl", "no", "pl", "pt", "sv", "tr", "tok", "uk", "cy"]) {
    add(iso, capitalizationPreprocessors);
  }
  add("de", { ...capitalizationPreprocessors, eszettPreprocessor });
  add("el", { ...capitalizationPreprocessors, removeDoubleAcuteAccents });
  add("en", capitalizationPreprocessors);
  add("eo", capitalizationPreprocessors);
  add("es", capitalizationPreprocessors);
  add("eu", capitalizationPreprocessors);
  add("fa", { removeArabicScriptDiacritics });
  add("fr", { ...capitalizationPreprocessors, apostropheVariants });
  add("ga", capitalizationPreprocessors);
  add("grc", { ...capitalizationPreprocessors, removeAlphabeticDiacritics, convertLatinToGreek });
  for (const iso of ["he", "hi", "lo", "kn", "km", "th"]) add(iso);
  add("id", { ...capitalizationPreprocessors, removeAlphabeticDiacritics });
  add("it", { ...capitalizationPreprocessors, removeAlphabeticDiacritics, removeApostrophedWords });
  add("ka");
  add("la", { ...capitalizationPreprocessors, removeAlphabeticDiacritics, processDiphtongs });
  add("ro", { ...capitalizationPreprocessors, removeAlphabeticDiacritics });
  add("ru", { ...capitalizationPreprocessors, yoToE, removeRussianDiacritics });
  add("sga", { ...capitalizationPreprocessors, removeAlphabeticDiacritics });
  add("sh", { ...capitalizationPreprocessors, removeSerboCroatianAccentMarks, addSerboCroatianDiacritics });
  add("sq", capitalizationPreprocessors);
  add("tl", { ...capitalizationPreprocessors, removeAlphabeticDiacritics });
  add("vi", { ...capitalizationPreprocessors, normalizeDiacritics });
  add(
    "yi",
    { removeYiddishDiacritics, combineYiddishLigatures },
    null,
    { convertFinalLetters, convertYiddishLigatures }
  );
  add("yue", { normalizeRadicalCharacters });
  add("zh", { normalizeRadicalCharacters });
  var transformers = /* @__PURE__ */ new Map();
  function getTransformer(descriptor) {
    if (!descriptor.languageTransforms) return null;
    let transformer = transformers.get(descriptor.iso);
    if (!transformer) {
      transformer = new LanguageTransformer();
      transformer.addDescriptor(descriptor.languageTransforms);
      transformers.set(descriptor.iso, transformer);
    }
    return transformer;
  }
  function getVariants(text, processors, maxVariants = 128) {
    let variants = /* @__PURE__ */ new Map([[text, [[]]]]);
    for (const [id, processor] of Object.entries(processors)) {
      const next = /* @__PURE__ */ new Map();
      for (const [variant, chains] of variants) {
        const processedValues = processor.process(variant).slice(0, maxVariants);
        for (const processed of processedValues) {
          const existing = next.get(processed) || [];
          const nextChains = processed === variant ? chains : chains.map((chain) => [...chain, id]);
          next.set(processed, [...existing, ...nextChains].slice(0, maxVariants));
          if (next.size >= maxVariants) break;
        }
        if (next.size >= maxVariants) break;
      }
      variants = next;
    }
    return variants;
  }
  function rawSources(text, scanLength) {
    const characters = Array.from(text).slice(0, scanLength);
    const sources = [];
    const wordCharacter = /[\p{Letter}\p{Number}\p{Mark}'\u2019]/u;
    for (let length = characters.length; length > 0; --length) {
      const next = characters[length];
      if (typeof next === "undefined" || !wordCharacter.test(next)) {
        const source = characters.slice(0, length).join("").trimEnd();
        if (source.length > 0 && !sources.includes(source)) sources.push(source);
      }
    }
    return sources;
  }
  function traceDetails(descriptor, processorIds, transformTrace) {
    const details = [];
    for (const id of processorIds) {
      const processor = descriptor.textPreprocessors[id] || descriptor.textPostprocessors[id];
      details.push({ name: processor?.name || id, description: processor?.description || "" });
    }
    for (const frame of transformTrace) {
      const transform = descriptor.languageTransforms?.transforms?.[frame.transform];
      details.push({ name: transform?.name || frame.transform, description: transform?.description || "" });
    }
    return details;
  }
  function candidates(language, text, scanLength, maxCandidates) {
    const descriptor = descriptors.get(language);
    if (!descriptor || language === "ja" || language === "ko") return [];
    const transformer = getTransformer(descriptor);
    const results = /* @__PURE__ */ new Map();
    let sourcePriority = 0;
    for (const rawSource of rawSources(text, scanLength)) {
      const preprocessed = getVariants(rawSource, descriptor.textPreprocessors);
      for (const [source, preprocessorChains] of preprocessed) {
        const transformedValues = transformer ? transformer.transform(source) : [{ text: source, trace: [] }];
        for (const transformed of transformedValues) {
          const postprocessed = getVariants(transformed.text, descriptor.textPostprocessors);
          for (const [lemma, postprocessorChains] of postprocessed) {
            for (const preprocessorChain of preprocessorChains) {
              for (const postprocessorChain of postprocessorChains) {
                const processorIds = [...preprocessorChain, ...postprocessorChain];
                if (lemma === rawSource) continue;
                const trace = traceDetails(descriptor, processorIds, transformed.trace);
                const priority = sourcePriority * 100 + trace.length * 5 + Math.max(0, source.length - lemma.length);
                const existing = results.get(lemma);
                if (!existing || priority < existing.priority) {
                  results.set(lemma, { surface: rawSource, lemma, trace, priority });
                }
              }
            }
          }
        }
      }
      sourcePriority += 1;
    }
    return [...results.values()].sort((a, b) => a.priority - b.priority || b.lemma.length - a.lemma.length).slice(0, maxCandidates);
  }
  globalThis.mangatanYomitanCandidatesJson = (language, text, scanLength, maxCandidates = 64) => JSON.stringify(
    candidates(language, text, scanLength, maxCandidates)
  );
  globalThis.mangatanRegisterYomitanTransforms = (language, languageTransforms) => {
    const descriptor = descriptors.get(language);
    if (!descriptor) return false;
    descriptor.languageTransforms = languageTransforms;
    transformers.delete(language);
    return true;
  };
})();
