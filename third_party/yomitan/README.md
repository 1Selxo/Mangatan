# Yomitan language support

This directory contains the non-Japanese, non-Korean language-processing
sources used by Mangatan's multilingual dictionary lookup.

- Upstream: https://github.com/yomidevs/yomitan
- Upstream revision: `2eae7e7`
- License: GPL-3.0-or-later (see `LICENSE`)
- Local changes: `mangatan-entry.js` adapts Yomitan's processors and transform
  descriptors into a small JSON candidate API suitable for Mangatan's embedded
  QuickJS runtime. Japanese and Korean modules are deliberately excluded.

To rebuild the Flutter assets after changing these sources, run:

```text
npx --yes esbuild@0.25.1 third_party/yomitan/ext/js/language/mangatan-entry.js --bundle --format=iife --platform=browser --target=es2020 --outfile=assets/yomitan_language_bundle.js
npx --yes esbuild@0.25.1 third_party/yomitan/ext/js/language/transform-entries/*.js --bundle --format=iife --platform=browser --target=es2020 --outdir=assets/yomitan_transforms --entry-names=[name]
```

The shared bundle contains lightweight text normalization only. Transform
tables are split by language and loaded lazily so selecting English does not
construct French, Spanish, Arabic, and every other language's regular
expressions in QuickJS.
