(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));

  // ../../node_modules/hangul-js/hangul.js
  var require_hangul = __commonJS({
    "../../node_modules/hangul-js/hangul.js"(exports, module) {
      (function() {
        "use strict";
        var CHO = [
          "\u3131",
          "\u3132",
          "\u3134",
          "\u3137",
          "\u3138",
          "\u3139",
          "\u3141",
          "\u3142",
          "\u3143",
          "\u3145",
          "\u3146",
          "\u3147",
          "\u3148",
          "\u3149",
          "\u314A",
          "\u314B",
          "\u314C",
          "\u314D",
          "\u314E"
        ], JUNG = [
          "\u314F",
          "\u3150",
          "\u3151",
          "\u3152",
          "\u3153",
          "\u3154",
          "\u3155",
          "\u3156",
          "\u3157",
          ["\u3157", "\u314F"],
          ["\u3157", "\u3150"],
          ["\u3157", "\u3163"],
          "\u315B",
          "\u315C",
          ["\u315C", "\u3153"],
          ["\u315C", "\u3154"],
          ["\u315C", "\u3163"],
          "\u3160",
          "\u3161",
          ["\u3161", "\u3163"],
          "\u3163"
        ], JONG = [
          "",
          "\u3131",
          "\u3132",
          ["\u3131", "\u3145"],
          "\u3134",
          ["\u3134", "\u3148"],
          ["\u3134", "\u314E"],
          "\u3137",
          "\u3139",
          ["\u3139", "\u3131"],
          ["\u3139", "\u3141"],
          ["\u3139", "\u3142"],
          ["\u3139", "\u3145"],
          ["\u3139", "\u314C"],
          ["\u3139", "\u314D"],
          ["\u3139", "\u314E"],
          "\u3141",
          "\u3142",
          ["\u3142", "\u3145"],
          "\u3145",
          "\u3146",
          "\u3147",
          "\u3148",
          "\u314A",
          "\u314B",
          "\u314C",
          "\u314D",
          "\u314E"
        ], HANGUL_OFFSET = 44032, CONSONANTS = [
          "\u3131",
          "\u3132",
          "\u3133",
          "\u3134",
          "\u3135",
          "\u3136",
          "\u3137",
          "\u3138",
          "\u3139",
          "\u313A",
          "\u313B",
          "\u313C",
          "\u313D",
          "\u313E",
          "\u313F",
          "\u3140",
          "\u3141",
          "\u3142",
          "\u3143",
          "\u3144",
          "\u3145",
          "\u3146",
          "\u3147",
          "\u3148",
          "\u3149",
          "\u314A",
          "\u314B",
          "\u314C",
          "\u314D",
          "\u314E"
        ], COMPLETE_CHO = [
          "\u3131",
          "\u3132",
          "\u3134",
          "\u3137",
          "\u3138",
          "\u3139",
          "\u3141",
          "\u3142",
          "\u3143",
          "\u3145",
          "\u3146",
          "\u3147",
          "\u3148",
          "\u3149",
          "\u314A",
          "\u314B",
          "\u314C",
          "\u314D",
          "\u314E"
        ], COMPLETE_JUNG = [
          "\u314F",
          "\u3150",
          "\u3151",
          "\u3152",
          "\u3153",
          "\u3154",
          "\u3155",
          "\u3156",
          "\u3157",
          "\u3158",
          "\u3159",
          "\u315A",
          "\u315B",
          "\u315C",
          "\u315D",
          "\u315E",
          "\u315F",
          "\u3160",
          "\u3161",
          "\u3162",
          "\u3163"
        ], COMPLETE_JONG = [
          "",
          "\u3131",
          "\u3132",
          "\u3133",
          "\u3134",
          "\u3135",
          "\u3136",
          "\u3137",
          "\u3139",
          "\u313A",
          "\u313B",
          "\u313C",
          "\u313D",
          "\u313E",
          "\u313F",
          "\u3140",
          "\u3141",
          "\u3142",
          "\u3144",
          "\u3145",
          "\u3146",
          "\u3147",
          "\u3148",
          "\u314A",
          "\u314B",
          "\u314C",
          "\u314D",
          "\u314E"
        ], COMPLEX_CONSONANTS = [
          ["\u3131", "\u3145", "\u3133"],
          ["\u3134", "\u3148", "\u3135"],
          ["\u3134", "\u314E", "\u3136"],
          ["\u3139", "\u3131", "\u313A"],
          ["\u3139", "\u3141", "\u313B"],
          ["\u3139", "\u3142", "\u313C"],
          ["\u3139", "\u3145", "\u313D"],
          ["\u3139", "\u314C", "\u313E"],
          ["\u3139", "\u314D", "\u313F"],
          ["\u3139", "\u314E", "\u3140"],
          ["\u3142", "\u3145", "\u3144"]
        ], COMPLEX_VOWELS = [
          ["\u3157", "\u314F", "\u3158"],
          ["\u3157", "\u3150", "\u3159"],
          ["\u3157", "\u3163", "\u315A"],
          ["\u315C", "\u3153", "\u315D"],
          ["\u315C", "\u3154", "\u315E"],
          ["\u315C", "\u3163", "\u315F"],
          ["\u3161", "\u3163", "\u3162"]
        ], CONSONANTS_HASH, CHO_HASH, JUNG_HASH, JONG_HASH, COMPLEX_CONSONANTS_HASH, COMPLEX_VOWELS_HASH;
        function _makeHash(array) {
          var length = array.length, hash = { 0: 0 };
          for (var i = 0; i < length; i++) {
            if (array[i])
              hash[array[i].charCodeAt(0)] = i;
          }
          return hash;
        }
        CONSONANTS_HASH = _makeHash(CONSONANTS);
        CHO_HASH = _makeHash(COMPLETE_CHO);
        JUNG_HASH = _makeHash(COMPLETE_JUNG);
        JONG_HASH = _makeHash(COMPLETE_JONG);
        function _makeComplexHash(array) {
          var length = array.length, hash = {}, code1, code2;
          for (var i = 0; i < length; i++) {
            code1 = array[i][0].charCodeAt(0);
            code2 = array[i][1].charCodeAt(0);
            if (typeof hash[code1] === "undefined") {
              hash[code1] = {};
            }
            hash[code1][code2] = array[i][2].charCodeAt(0);
          }
          return hash;
        }
        COMPLEX_CONSONANTS_HASH = _makeComplexHash(COMPLEX_CONSONANTS);
        COMPLEX_VOWELS_HASH = _makeComplexHash(COMPLEX_VOWELS);
        function _isConsonant(c) {
          return typeof CONSONANTS_HASH[c] !== "undefined";
        }
        function _isCho(c) {
          return typeof CHO_HASH[c] !== "undefined";
        }
        function _isJung(c) {
          return typeof JUNG_HASH[c] !== "undefined";
        }
        function _isJong(c) {
          return typeof JONG_HASH[c] !== "undefined";
        }
        function _isHangul(c) {
          return 44032 <= c && c <= 55203;
        }
        function _isJungJoinable(a, b) {
          return COMPLEX_VOWELS_HASH[a] && COMPLEX_VOWELS_HASH[a][b] ? COMPLEX_VOWELS_HASH[a][b] : false;
        }
        function _isJongJoinable(a, b) {
          return COMPLEX_CONSONANTS_HASH[a] && COMPLEX_CONSONANTS_HASH[a][b] ? COMPLEX_CONSONANTS_HASH[a][b] : false;
        }
        var disassemble = function(string, grouped) {
          if (string === null) {
            throw new Error("Arguments cannot be null");
          }
          if (typeof string === "object") {
            string = string.join("");
          }
          var result = [], length = string.length, cho, jung, jong, code, r;
          for (var i = 0; i < length; i++) {
            var temp = [];
            code = string.charCodeAt(i);
            if (_isHangul(code)) {
              code -= HANGUL_OFFSET;
              jong = code % 28;
              jung = (code - jong) / 28 % 21;
              cho = parseInt((code - jong) / 28 / 21);
              temp.push(CHO[cho]);
              if (typeof JUNG[jung] === "object") {
                temp = temp.concat(JUNG[jung]);
              } else {
                temp.push(JUNG[jung]);
              }
              if (jong > 0) {
                if (typeof JONG[jong] === "object") {
                  temp = temp.concat(JONG[jong]);
                } else {
                  temp.push(JONG[jong]);
                }
              }
            } else if (_isConsonant(code)) {
              if (_isCho(code)) {
                r = CHO[CHO_HASH[code]];
              } else {
                r = JONG[JONG_HASH[code]];
              }
              if (typeof r === "string") {
                temp.push(r);
              } else {
                temp = temp.concat(r);
              }
            } else if (_isJung(code)) {
              r = JUNG[JUNG_HASH[code]];
              if (typeof r === "string") {
                temp.push(r);
              } else {
                temp = temp.concat(r);
              }
            } else {
              temp.push(string.charAt(i));
            }
            if (grouped) result.push(temp);
            else result = result.concat(temp);
          }
          return result;
        };
        var disassembleToString = function(str) {
          if (typeof str !== "string") {
            return "";
          }
          str = disassemble(str);
          return str.join("");
        };
        var assemble = function(array) {
          if (typeof array === "string") {
            array = disassemble(array);
          }
          var result = [], length = array.length, code, stage = 0, complete_index = -1, previous_code, jong_joined = false;
          function _makeHangul(index) {
            var code2, cho, jung1, jung2, jong1 = 0, jong2, hangul2 = "";
            jong_joined = false;
            if (complete_index + 1 > index) {
              return;
            }
            for (var step = 1; ; step++) {
              if (step === 1) {
                cho = array[complete_index + step].charCodeAt(0);
                if (_isJung(cho)) {
                  if (complete_index + step + 1 <= index && _isJung(jung1 = array[complete_index + step + 1].charCodeAt(0))) {
                    result.push(String.fromCharCode(_isJungJoinable(cho, jung1)));
                    complete_index = index;
                    return;
                  } else {
                    result.push(array[complete_index + step]);
                    complete_index = index;
                    return;
                  }
                } else if (!_isCho(cho)) {
                  result.push(array[complete_index + step]);
                  complete_index = index;
                  return;
                }
                hangul2 = array[complete_index + step];
              } else if (step === 2) {
                jung1 = array[complete_index + step].charCodeAt(0);
                if (_isCho(jung1)) {
                  cho = _isJongJoinable(cho, jung1);
                  hangul2 = String.fromCharCode(cho);
                  result.push(hangul2);
                  complete_index = index;
                  return;
                } else {
                  hangul2 = String.fromCharCode((CHO_HASH[cho] * 21 + JUNG_HASH[jung1]) * 28 + HANGUL_OFFSET);
                }
              } else if (step === 3) {
                jung2 = array[complete_index + step].charCodeAt(0);
                if (_isJungJoinable(jung1, jung2)) {
                  jung1 = _isJungJoinable(jung1, jung2);
                } else {
                  jong1 = jung2;
                }
                hangul2 = String.fromCharCode((CHO_HASH[cho] * 21 + JUNG_HASH[jung1]) * 28 + JONG_HASH[jong1] + HANGUL_OFFSET);
              } else if (step === 4) {
                jong2 = array[complete_index + step].charCodeAt(0);
                if (_isJongJoinable(jong1, jong2)) {
                  jong1 = _isJongJoinable(jong1, jong2);
                } else {
                  jong1 = jong2;
                }
                hangul2 = String.fromCharCode((CHO_HASH[cho] * 21 + JUNG_HASH[jung1]) * 28 + JONG_HASH[jong1] + HANGUL_OFFSET);
              } else if (step === 5) {
                jong2 = array[complete_index + step].charCodeAt(0);
                jong1 = _isJongJoinable(jong1, jong2);
                hangul2 = String.fromCharCode((CHO_HASH[cho] * 21 + JUNG_HASH[jung1]) * 28 + JONG_HASH[jong1] + HANGUL_OFFSET);
              }
              if (complete_index + step >= index) {
                result.push(hangul2);
                complete_index = index;
                return;
              }
            }
          }
          for (var i = 0; i < length; i++) {
            code = array[i].charCodeAt(0);
            if (!_isCho(code) && !_isJung(code) && !_isJong(code)) {
              _makeHangul(i - 1);
              _makeHangul(i);
              stage = 0;
              continue;
            }
            if (stage === 0) {
              if (_isCho(code)) {
                stage = 1;
              } else if (_isJung(code)) {
                stage = 4;
              }
            } else if (stage == 1) {
              if (_isJung(code)) {
                stage = 2;
              } else {
                if (_isJongJoinable(previous_code, code)) {
                  stage = 5;
                } else {
                  _makeHangul(i - 1);
                }
              }
            } else if (stage == 2) {
              if (_isJong(code)) {
                stage = 3;
              } else if (_isJung(code)) {
                if (_isJungJoinable(previous_code, code)) {
                } else {
                  _makeHangul(i - 1);
                  stage = 4;
                }
              } else {
                _makeHangul(i - 1);
                stage = 1;
              }
            } else if (stage == 3) {
              if (_isJong(code)) {
                if (!jong_joined && _isJongJoinable(previous_code, code)) {
                  jong_joined = true;
                } else {
                  _makeHangul(i - 1);
                  stage = 1;
                }
              } else if (_isCho(code)) {
                _makeHangul(i - 1);
                stage = 1;
              } else if (_isJung(code)) {
                _makeHangul(i - 2);
                stage = 2;
              }
            } else if (stage == 4) {
              if (_isJung(code)) {
                if (_isJungJoinable(previous_code, code)) {
                  _makeHangul(i);
                  stage = 0;
                } else {
                  _makeHangul(i - 1);
                }
              } else {
                _makeHangul(i - 1);
                stage = 1;
              }
            } else if (stage == 5) {
              if (_isJung(code)) {
                _makeHangul(i - 2);
                stage = 2;
              } else {
                _makeHangul(i - 1);
                stage = 1;
              }
            }
            previous_code = code;
          }
          _makeHangul(i - 1);
          return result.join("");
        };
        var search = function(a, b) {
          var ad = disassemble(a).join(""), bd = disassemble(b).join("");
          return ad.indexOf(bd);
        };
        var rangeSearch = function(haystack, needle) {
          var hex = disassemble(haystack).join(""), nex = disassemble(needle).join(""), grouped = disassemble(haystack, true), re = new RegExp(nex, "gi"), indices = [], result;
          if (!needle.length) return [];
          while (result = re.exec(hex)) {
            indices.push(result.index);
          }
          function findStart(index) {
            for (var i = 0, length = 0; i < grouped.length; ++i) {
              length += grouped[i].length;
              if (index < length) return i;
            }
          }
          function findEnd(index) {
            for (var i = 0, length = 0; i < grouped.length; ++i) {
              length += grouped[i].length;
              if (index + nex.length <= length) return i;
            }
          }
          return indices.map(function(i) {
            return [findStart(i), findEnd(i)];
          });
        };
        function Searcher(string) {
          this.string = string;
          this.disassembled = disassemble(string).join("");
        }
        Searcher.prototype.search = function(string) {
          return disassemble(string).join("").indexOf(this.disassembled);
        };
        var endsWithConsonant = function(string) {
          if (typeof string === "object") {
            string = string.join("");
          }
          var code = string.charCodeAt(string.length - 1);
          if (_isHangul(code)) {
            code -= HANGUL_OFFSET;
            var jong = code % 28;
            if (jong > 0) {
              return true;
            }
          } else if (_isConsonant(code)) {
            return true;
          }
          return false;
        };
        var endsWith = function(string, target) {
          return disassemble(string).pop() === target;
        };
        var hangul = {
          disassemble,
          d: disassemble,
          // alias for disassemble
          disassembleToString,
          ds: disassembleToString,
          // alias for disassembleToString
          assemble,
          a: assemble,
          // alias for assemble
          search,
          rangeSearch,
          Searcher,
          endsWithConsonant,
          endsWith,
          isHangul: function(c) {
            if (typeof c === "string")
              c = c.charCodeAt(0);
            return _isHangul(c);
          },
          isComplete: function(c) {
            if (typeof c === "string")
              c = c.charCodeAt(0);
            return _isHangul(c);
          },
          isConsonant: function(c) {
            if (typeof c === "string")
              c = c.charCodeAt(0);
            return _isConsonant(c);
          },
          isVowel: function(c) {
            if (typeof c === "string")
              c = c.charCodeAt(0);
            return _isJung(c);
          },
          isCho: function(c) {
            if (typeof c === "string")
              c = c.charCodeAt(0);
            return _isCho(c);
          },
          isJong: function(c) {
            if (typeof c === "string")
              c = c.charCodeAt(0);
            return _isJong(c);
          },
          isHangulAll: function(str) {
            if (typeof str !== "string") return false;
            for (var i = 0; i < str.length; i++) {
              if (!_isHangul(str.charCodeAt(i))) return false;
            }
            return true;
          },
          isCompleteAll: function(str) {
            if (typeof str !== "string") return false;
            for (var i = 0; i < str.length; i++) {
              if (!_isHangul(str.charCodeAt(i))) return false;
            }
            return true;
          },
          isConsonantAll: function(str) {
            if (typeof str !== "string") return false;
            for (var i = 0; i < str.length; i++) {
              if (!_isConsonant(str.charCodeAt(i))) return false;
            }
            return true;
          },
          isVowelAll: function(str) {
            if (typeof str !== "string") return false;
            for (var i = 0; i < str.length; i++) {
              if (!_isJung(str.charCodeAt(i))) return false;
            }
            return true;
          },
          isChoAll: function(str) {
            if (typeof str !== "string") return false;
            for (var i = 0; i < str.length; i++) {
              if (!_isCho(str.charCodeAt(i))) return false;
            }
            return true;
          },
          isJongAll: function(str) {
            if (typeof str !== "string") return false;
            for (var i = 0; i < str.length; i++) {
              if (!_isJong(str.charCodeAt(i))) return false;
            }
            return true;
          }
        };
        if (typeof define == "function" && define.amd) {
          define(function() {
            return hangul;
          });
        } else if (typeof module !== "undefined") {
          module.exports = hangul;
        } else {
          window.Hangul = hangul;
        }
      })();
    }
  });

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

  // third_party/yomitan/ext/lib/hangul-js.js
  var Hangul = __toESM(require_hangul());

  // third_party/yomitan/ext/js/language/ko/korean-text-processors.js
  var disassembleHangul = {
    name: "Disassemble Hangul",
    description: "Disassemble Hangul characters into jamo.",
    process: (str) => [Hangul.disassemble(str, false).join("")]
  };
  var reassembleHangul = {
    name: "Reassemble Hangul",
    description: "Reassemble Hangul characters from jamo.",
    process: (str) => [Hangul.assemble(str)]
  };

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
  add("ko", { disassembleHangul }, null, { reassembleHangul });
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
  function addCandidate(results, rawSource, lemma, trace, priority) {
    if (!lemma || lemma === rawSource || lemma === "\uB2E4") return;
    if (rawSource.startsWith("\uC544\uBB34\uB798") && lemma === "\uC544\uBB34\uB9AC\uB2E4") return;
    const existing = results.get(lemma);
    if (!existing || priority < existing.priority) {
      results.set(lemma, { surface: rawSource, lemma, trace, priority });
    }
  }
  function withoutFinalConsonant(text, expectedJongseong) {
    if (text.length === 0) return null;
    const codePoint = text.codePointAt(text.length - 1);
    const offset = codePoint - 44032;
    if (offset < 0 || offset > 11171) return null;
    const jongseong = offset % 28;
    if (jongseong !== expectedJongseong) return null;
    return `${text.slice(0, -1)}${String.fromCodePoint(codePoint - jongseong)}`;
  }
  function withFinalConsonant(text, jongseong) {
    if (text.length === 0) return null;
    const codePoint = text.codePointAt(text.length - 1);
    const offset = codePoint - 44032;
    if (offset < 0 || offset > 11171 || offset % 28 !== 0) return null;
    return `${text.slice(0, -1)}${String.fromCodePoint(codePoint + jongseong)}`;
  }
  function addKoreanSupplementalCandidates(results, rawSource, priorityBase) {
    const trace = [{ name: "Supplemental Korean deinflection", description: "Mangatan Korean compatibility rule." }];
    const add2 = (lemma, priorityOffset = 0) => addCandidate(results, rawSource, lemma, trace, priorityBase + priorityOffset);
    if (rawSource === "\uB204\uAC00") add2("\uB204\uAD6C");
    if (rawSource === "\uAC78\uB85C") add2("\uAC70", 0);
    if (/^\uD14C(?:\uB2C8\uAE4C|\uB2C8|\uBA74|\uACE0|\uC11C|\uC694|\uC8E0|\uC9C0|\uB2E4|\uB77C|\uAD70|\uB124)?$/u.test(rawSource) || /^\uD150(?:\uB370|\uAC00|\uC9C0|\uAC78|\uAC70|\uAC00\uC694)?$/u.test(rawSource)) {
      add2("\uD130", 0);
    }
    if (rawSource.startsWith("\uD390") || rawSource.startsWith("\uD37C")) {
      add2("\uD478\uB2E4", 0);
    }
    if (rawSource.startsWith("\uC124\uC6B0")) {
      add2("\uC127\uB2E4", 0);
    }
    const hIrregularColorLike = /* @__PURE__ */ new Map([
      ["\uBFCC\uC608", ["\uBFCC\uC607\uB2E4"]],
      ["\uBFCC\uC598", ["\uBFCC\uC607\uB2E4"]],
      ["\uD30C\uB798", ["\uD30C\uB797\uB2E4", "\uD37C\uB807\uB2E4"]],
      ["\uD37C\uB808", ["\uD30C\uB797\uB2E4", "\uD37C\uB807\uB2E4"]],
      ["\uAE4C\uB9E4", ["\uAE4C\uB9E3\uB2E4", "\uAEBC\uBA93\uB2E4"]],
      ["\uAEBC\uBA54", ["\uAE4C\uB9E3\uB2E4", "\uAEBC\uBA93\uB2E4"]],
      ["\uD558\uC598", ["\uD558\uC597\uB2E4", "\uD5C8\uC607\uB2E4"]],
      ["\uD5C8\uC608", ["\uD558\uC597\uB2E4", "\uD5C8\uC607\uB2E4"]]
    ]);
    for (const [surface, lemmas] of hIrregularColorLike) {
      if (!rawSource.startsWith(surface)) continue;
      for (const lemma of lemmas) add2(lemma, 0);
    }
    if (rawSource.endsWith("\uC544") && rawSource.length > 1) {
      add2(`${rawSource.slice(0, -1)}\uC774`, 1);
    }
    const vocativeNounLike = /* @__PURE__ */ new Map([
      ["\uB108\uAD74\uC544", "\uB108\uAD6C\uB9AC"],
      ["\uB108\uAD6C\uB77C", "\uB108\uAD6C\uB9AC"],
      ["\uAE30\uB7ED\uC544", "\uAE30\uB7EC\uAE30"],
      ["\uAE30\uB7EC\uAC00", "\uAE30\uB7EC\uAE30"],
      ["\uBA70\uB298\uC544", "\uBA70\uB290\uB9AC"],
      ["\uBA70\uB290\uB77C", "\uBA70\uB290\uB9AC"],
      ["\uBED0\uAFB9\uC544", "\uBED0\uAFB8\uAE30"],
      ["\uBED0\uAFB8\uAC00", "\uBED0\uAFB8\uAE30"],
      ["\uAC1C\uAD74\uC544", "\uAC1C\uAD6C\uB9AC"],
      ["\uAC1C\uAD6C\uB77C", "\uAC1C\uAD6C\uB9AC"],
      ["\uAF80\uAF34\uC544", "\uAF80\uAF2C\uB9AC"],
      ["\uAF80\uAF2C\uB77C", "\uAF80\uAF2C\uB9AC"],
      ["\uADC0\uB69C\uB78C\uC544", "\uADC0\uB69C\uB77C\uBBF8"],
      ["\uADC0\uB69C\uB77C\uB9C8", "\uADC0\uB69C\uB77C\uBBF8"],
      ["\uADC0\uB69C\uC544", "\uADC0\uB69C\uB9AC"],
      ["\uADC0\uB69C\uB77C", "\uADC0\uB69C\uB9AC"],
      ["\uC62C\uBE80\uC544", "\uC62C\uBE7C\uBBF8"],
      ["\uC62C\uBE7C\uB9C8", "\uC62C\uBE7C\uBBF8"],
      ["\uC871\uC81D\uC544", "\uC871\uC81C\uBE44"],
      ["\uC871\uC81C\uBC14", "\uC871\uC81C\uBE44"],
      ["\uBE44\uB465\uC544", "\uBE44\uB458\uAE30"],
      ["\uBE44\uB458\uAC00", "\uBE44\uB458\uAE30"],
      ["\uD574\uC624\uB77D\uC544", "\uD574\uC624\uB77C\uAE30"],
      ["\uD574\uC624\uB77C\uAC00", "\uD574\uC624\uB77C\uAE30"]
    ]);
    const vocativeLemma = vocativeNounLike.get(rawSource);
    if (vocativeLemma) add2(vocativeLemma, 0);
    if (rawSource.endsWith("\uB124")) {
      const stem = rawSource.slice(0, -1);
      add2(`${stem}\uB2E4`, 1);
      const hStem = withFinalConsonant(stem, 27);
      if (hStem) add2(`${hStem}\uB2E4`, 1);
    }
    const topicBase = withoutFinalConsonant(rawSource, 4);
    if (topicBase) add2(topicBase, 1);
    const objectBase = withoutFinalConsonant(rawSource, 8);
    if (objectBase) add2(objectBase, 2);
    for (const suffix of ["\uB370", "\uAC00", "\uC9C0", "\uB4E4", "\uC694", "\uC740", "\uB294", "\uB9CC", "\uB3C4", "\uAE4C"]) {
      if (!rawSource.endsWith(suffix)) continue;
      const prefix = rawSource.slice(0, -suffix.length);
      const topicPrefix = withoutFinalConsonant(prefix, 4);
      if (topicPrefix) add2(topicPrefix, 1);
      const objectPrefix = withoutFinalConsonant(prefix, 8);
      if (objectPrefix) add2(objectPrefix, 2);
    }
    let match = rawSource.match(/^(.+)걸로$/u);
    if (match) add2(`${match[1]}\uAC70`, 3);
    match = rawSource.match(/^(.+)러네$/u);
    if (match) {
      add2(`${match[1]}\uB7EC\uB2E4`, 4);
      add2(`${match[1]}\uB807\uB2E4`, 5);
    }
    match = rawSource.match(/^(.+르)러(?:서|도|니|면|야|요)?$/u);
    if (match) add2(`${match[1]}\uB2E4`, 6);
    match = rawSource.match(/^(.+르)렀(?:다|어|어요|으니|으면)?$/u);
    if (match) add2(`${match[1]}\uB2E4`, 7);
    for (const suffix of ["\uC624\uB2C8", "\uC18C\uB2C8", "\uC635", "\uC624", "\uC18C"]) {
      if (!rawSource.endsWith(suffix)) continue;
      const stem = withFinalConsonant(rawSource.slice(0, -suffix.length), 8);
      if (stem) add2(`${stem}\uB2E4`, 8);
    }
    match = rawSource.match(/^(.+)예(?:서|도|요)?$/u);
    if (match) add2(`${match[1]}\uC607\uB2E4`, 9);
    match = rawSource.match(/^(.+)얬(?:다|어|어요)?$/u);
    if (match) add2(`${match[1]}\uC597\uB2E4`, 10);
    const determinerLike = /* @__PURE__ */ new Map([
      ["\uC774\uB798", ["\uC774\uB807\uB2E4", "\uC774\uB7EC\uB2E4"]],
      ["\uADF8\uB798", ["\uADF8\uB807\uB2E4", "\uADF8\uB7EC\uB2E4"]],
      ["\uC800\uB798", ["\uC800\uB807\uB2E4", "\uC800\uB7EC\uB2E4"]],
      ["\uC544\uBB34\uB798", ["\uC544\uBB34\uB807\uB2E4"]],
      ["\uC5B4\uB54C", ["\uC5B4\uB5BB\uB2E4"]],
      ["\uC5B4\uB560", ["\uC5B4\uB5BB\uB2E4"]],
      ["\uC5B4\uCA0C", ["\uC5B4\uCA4C\uB2E4"]],
      ["\uC800\uCA0C", ["\uC800\uCA4C\uB2E4"]],
      ["\uADF8\uB7AC", ["\uADF8\uB807\uB2E4", "\uADF8\uB7EC\uB2E4"]],
      ["\uC774\uB7AC", ["\uC774\uB807\uB2E4", "\uC774\uB7EC\uB2E4"]],
      ["\uC800\uB7AC", ["\uC800\uB807\uB2E4", "\uC800\uB7EC\uB2E4"]]
    ]);
    for (const [stem, lemmas] of determinerLike) {
      if (!rawSource.startsWith(stem)) continue;
      for (const lemma of lemmas) add2(lemma, 11);
    }
    if (/^설(?:운|워(?:서|도|요)?|웠(?:다|어|어요)?)$/u.test(rawSource)) add2("\uC127\uB2E4", 12);
    if (/^퍼(?:서|도|요)?$/u.test(rawSource) || /^펐(?:다|어|어요)?$/u.test(rawSource)) add2("\uD478\uB2E4", 13);
  }
  function candidates(language, text, scanLength, maxCandidates) {
    const descriptor = descriptors.get(language);
    if (!descriptor || language === "ja") return [];
    const transformer = getTransformer(descriptor);
    const results = /* @__PURE__ */ new Map();
    let sourcePriority = 0;
    for (const rawSource of rawSources(text, scanLength)) {
      if (language === "ko") {
        addKoreanSupplementalCandidates(results, rawSource, sourcePriority * 100 + 1);
      }
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
                addCandidate(results, rawSource, lemma, trace, priority);
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
