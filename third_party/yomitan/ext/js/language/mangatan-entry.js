/*
 * Mangatan adapter for Yomitan's language processors.
 *
 * Copyright (C) 2024-2026 Yomitan Authors
 * Copyright (C) 2026 Mangatan contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import {removeSyriacScriptDiacritics} from './aii/assyrian-neo-aramaic-text-preprocessors.js';
import {
    addHamzaBottom,
    addHamzaTop,
    convertAlifMaqsuraToYaa,
    convertHaToTaMarbuta,
    normalizeUnicode,
    removeArabicScriptDiacritics,
    removeTatweel,
} from './ar/arabic-text-preprocessors.js';
import {normalizeRadicalCharacters} from './CJK-util.js';
import {eszettPreprocessor} from './de/german-text-preprocessors.js';
import {removeDoubleAcuteAccents} from './el/modern-greek-processors.js';
import {apostropheVariants} from './fr/french-text-preprocessors.js';
import {convertLatinToGreek} from './grc/ancient-greek-processors.js';
import {removeApostrophedWords} from './it/italian-processors.js';
import {processDiphtongs} from './la/latin-text-preprocessors.js';
import {LanguageTransformer} from './language-transformer.js';
import {removeRussianDiacritics, yoToE} from './ru/russian-text-preprocessors.js';
import {addSerboCroatianDiacritics, removeSerboCroatianAccentMarks} from './sh/serbo-croatian-text-preprocessors.js';
import {capitalizeFirstLetter, decapitalize, removeAlphabeticDiacritics} from './text-processors.js';
import {normalizeDiacritics} from './vi/viet-text-preprocessors.js';
import {convertFinalLetters, convertYiddishLigatures} from './yi/yiddish-text-postprocessors.js';
import {combineYiddishLigatures, removeYiddishDiacritics} from './yi/yiddish-text-preprocessors.js';

const capitalizationPreprocessors = {decapitalize, capitalizeFirstLetter};
const arabicPreprocessors = {
    removeArabicScriptDiacritics,
    removeTatweel,
    normalizeUnicode,
    addHamzaTop,
    addHamzaBottom,
    convertAlifMaqsuraToYaa,
};

const descriptors = new Map();
function add(iso, textPreprocessors = {}, languageTransforms = null, textPostprocessors = {}) {
    descriptors.set(iso, {iso, textPreprocessors, languageTransforms, textPostprocessors});
}

add('aii', {removeSyriacScriptDiacritics});
add('ar', arabicPreprocessors);
add('arz', {...arabicPreprocessors, convertHaToTaMarbuta});
for (const iso of ['be', 'bg', 'cs', 'da', 'et', 'fi', 'gd', 'haw', 'hu', 'lv', 'mn', 'mt', 'nl', 'no', 'pl', 'pt', 'sv', 'tr', 'tok', 'uk', 'cy']) {
    add(iso, capitalizationPreprocessors);
}
add('de', {...capitalizationPreprocessors, eszettPreprocessor});
add('el', {...capitalizationPreprocessors, removeDoubleAcuteAccents});
add('en', capitalizationPreprocessors);
add('eo', capitalizationPreprocessors);
add('es', capitalizationPreprocessors);
add('eu', capitalizationPreprocessors);
add('fa', {removeArabicScriptDiacritics});
add('fr', {...capitalizationPreprocessors, apostropheVariants});
add('ga', capitalizationPreprocessors);
add('grc', {...capitalizationPreprocessors, removeAlphabeticDiacritics, convertLatinToGreek});
for (const iso of ['he', 'hi', 'lo', 'kn', 'km', 'th']) add(iso);
add('id', {...capitalizationPreprocessors, removeAlphabeticDiacritics});
add('it', {...capitalizationPreprocessors, removeAlphabeticDiacritics, removeApostrophedWords});
add('ka');
add('la', {...capitalizationPreprocessors, removeAlphabeticDiacritics, processDiphtongs});
add('ro', {...capitalizationPreprocessors, removeAlphabeticDiacritics});
add('ru', {...capitalizationPreprocessors, yoToE, removeRussianDiacritics});
add('sga', {...capitalizationPreprocessors, removeAlphabeticDiacritics});
add('sh', {...capitalizationPreprocessors, removeSerboCroatianAccentMarks, addSerboCroatianDiacritics});
add('sq', capitalizationPreprocessors);
add('tl', {...capitalizationPreprocessors, removeAlphabeticDiacritics});
add('vi', {...capitalizationPreprocessors, normalizeDiacritics});
add(
    'yi',
    {removeYiddishDiacritics, combineYiddishLigatures},
    null,
    {convertFinalLetters, convertYiddishLigatures},
);
add('yue', {normalizeRadicalCharacters});
add('zh', {normalizeRadicalCharacters});

const transformers = new Map();
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
    let variants = new Map([[text, [[]]]]);
    for (const [id, processor] of Object.entries(processors)) {
        const next = new Map();
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
        if (typeof next === 'undefined' || !wordCharacter.test(next)) {
            const source = characters.slice(0, length).join('').trimEnd();
            if (source.length > 0 && !sources.includes(source)) sources.push(source);
        }
    }
    return sources;
}

function traceDetails(descriptor, processorIds, transformTrace) {
    const details = [];
    for (const id of processorIds) {
        const processor = descriptor.textPreprocessors[id] || descriptor.textPostprocessors[id];
        details.push({name: processor?.name || id, description: processor?.description || ''});
    }
    for (const frame of transformTrace) {
        const transform = descriptor.languageTransforms?.transforms?.[frame.transform];
        details.push({name: transform?.name || frame.transform, description: transform?.description || ''});
    }
    return details;
}

function candidates(language, text, scanLength, maxCandidates) {
    const descriptor = descriptors.get(language);
    if (!descriptor || language === 'ja' || language === 'ko') return [];
    const transformer = getTransformer(descriptor);
    const results = new Map();
    let sourcePriority = 0;
    for (const rawSource of rawSources(text, scanLength)) {
        const preprocessed = getVariants(rawSource, descriptor.textPreprocessors);
        for (const [source, preprocessorChains] of preprocessed) {
            const transformedValues = transformer ? transformer.transform(source) : [{text: source, trace: []}];
            for (const transformed of transformedValues) {
                const postprocessed = getVariants(transformed.text, descriptor.textPostprocessors);
                for (const [lemma, postprocessorChains] of postprocessed) {
                    for (const preprocessorChain of preprocessorChains) {
                        for (const postprocessorChain of postprocessorChains) {
                            const processorIds = [...preprocessorChain, ...postprocessorChain];
                            // Direct lookup already covers this spelling. This also drops
                            // processor chains which return to their original text.
                            if (lemma === rawSource) continue;
                            const trace = traceDetails(descriptor, processorIds, transformed.trace);
                            const priority = sourcePriority * 100 + trace.length * 5 + Math.max(0, source.length - lemma.length);
                            const existing = results.get(lemma);
                            if (!existing || priority < existing.priority) {
                                results.set(lemma, {surface: rawSource, lemma, trace, priority});
                            }
                        }
                    }
                }
            }
        }
        sourcePriority += 1;
    }
    return [...results.values()]
        .sort((a, b) => a.priority - b.priority || b.lemma.length - a.lemma.length)
        .slice(0, maxCandidates);
}

globalThis.mangatanYomitanCandidatesJson = (language, text, scanLength, maxCandidates = 64) => JSON.stringify(
    candidates(language, text, scanLength, maxCandidates),
);

globalThis.mangatanRegisterYomitanTransforms = (language, languageTransforms) => {
    const descriptor = descriptors.get(language);
    if (!descriptor) return false;
    descriptor.languageTransforms = languageTransforms;
    transformers.delete(language);
    return true;
};
