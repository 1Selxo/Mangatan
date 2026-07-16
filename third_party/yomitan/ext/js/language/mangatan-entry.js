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
import {disassembleHangul, reassembleHangul} from './ko/korean-text-processors.js';
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
add('ko', {disassembleHangul}, null, {reassembleHangul});
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

function addCandidate(results, rawSource, lemma, trace, priority) {
    if (!lemma || lemma === rawSource || lemma === '다') return;
    const existing = results.get(lemma);
    if (!existing || priority < existing.priority) {
        results.set(lemma, {surface: rawSource, lemma, trace, priority});
    }
}

function withoutFinalConsonant(text, expectedJongseong) {
    if (text.length === 0) return null;
    const codePoint = text.codePointAt(text.length - 1);
    const offset = codePoint - 0xac00;
    if (offset < 0 || offset > 11171) return null;
    const jongseong = offset % 28;
    if (jongseong !== expectedJongseong) return null;
    return `${text.slice(0, -1)}${String.fromCodePoint(codePoint - jongseong)}`;
}

function withFinalConsonant(text, jongseong) {
    if (text.length === 0) return null;
    const codePoint = text.codePointAt(text.length - 1);
    const offset = codePoint - 0xac00;
    if (offset < 0 || offset > 11171 || offset % 28 !== 0) return null;
    return `${text.slice(0, -1)}${String.fromCodePoint(codePoint + jongseong)}`;
}

function addKoreanSupplementalCandidates(results, rawSource, priorityBase) {
    const trace = [{name: 'Supplemental Korean deinflection', description: 'Mangatan Korean compatibility rule.'}];
    const add = (lemma, priorityOffset = 0) => addCandidate(results, rawSource, lemma, trace, priorityBase + priorityOffset);

    if (rawSource === '누가') add('누구');
    const topicBase = withoutFinalConsonant(rawSource, 4);
    if (topicBase) add(topicBase, 1);
    const objectBase = withoutFinalConsonant(rawSource, 8);
    if (objectBase) add(objectBase, 2);
    for (const suffix of ['데', '가', '지', '들', '요', '은', '는', '만', '도', '까']) {
        if (!rawSource.endsWith(suffix)) continue;
        const prefix = rawSource.slice(0, -suffix.length);
        const topicPrefix = withoutFinalConsonant(prefix, 4);
        if (topicPrefix) add(topicPrefix, 1);
        const objectPrefix = withoutFinalConsonant(prefix, 8);
        if (objectPrefix) add(objectPrefix, 2);
    }

    let match = rawSource.match(/^(.+)걸로$/u);
    if (match) add(`${match[1]}거`, 3);

    match = rawSource.match(/^(.+)러네$/u);
    if (match) {
        add(`${match[1]}러다`, 4);
        add(`${match[1]}렇다`, 5);
    }

    match = rawSource.match(/^(.+르)러(?:서|도|니|면|야|요)?$/u);
    if (match) add(`${match[1]}다`, 6);
    match = rawSource.match(/^(.+르)렀(?:다|어|어요|으니|으면)?$/u);
    if (match) add(`${match[1]}다`, 7);

    for (const suffix of ['오니', '소니', '옵', '오', '소']) {
        if (!rawSource.endsWith(suffix)) continue;
        const stem = withFinalConsonant(rawSource.slice(0, -suffix.length), 8);
        if (stem) add(`${stem}다`, 8);
    }

    match = rawSource.match(/^(.+)예(?:서|도|요)?$/u);
    if (match) add(`${match[1]}옇다`, 9);
    match = rawSource.match(/^(.+)얬(?:다|어|어요)?$/u);
    if (match) add(`${match[1]}얗다`, 10);

    const determinerLike = new Map([
        ['이래', ['이렇다', '이러다']],
        ['그래', ['그렇다', '그러다']],
        ['저래', ['저렇다', '저러다']],
        ['아무래', ['아무렇다']],
        ['어때', ['어떻다']],
        ['어땠', ['어떻다']],
        ['어쨌', ['어쩌다']],
        ['저쨌', ['저쩌다']],
        ['그랬', ['그렇다', '그러다']],
        ['이랬', ['이렇다', '이러다']],
        ['저랬', ['저렇다', '저러다']],
    ]);
    for (const [stem, lemmas] of determinerLike) {
        if (!rawSource.startsWith(stem)) continue;
        for (const lemma of lemmas) add(lemma, 11);
    }

    if (/^설(?:운|워(?:서|도|요)?|웠(?:다|어|어요)?)$/u.test(rawSource)) add('섧다', 12);
    if (/^퍼(?:서|도|요)?$/u.test(rawSource) || /^펐(?:다|어|어요)?$/u.test(rawSource)) add('푸다', 13);
}

function candidates(language, text, scanLength, maxCandidates) {
    const descriptor = descriptors.get(language);
    if (!descriptor || language === 'ja') return [];
    const transformer = getTransformer(descriptor);
    const results = new Map();
    let sourcePriority = 0;
    for (const rawSource of rawSources(text, scanLength)) {
        if (language === 'ko') {
            addKoreanSupplementalCandidates(results, rawSource, sourcePriority * 100 + 1);
        }
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
                            addCandidate(results, rawSource, lemma, trace, priority);
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
