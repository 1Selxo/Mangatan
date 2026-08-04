# OCR engines and what leaves your device

Mangatan can read text off a manga page with several OCR ("optical character
recognition") back-ends. You pick one under **Reader settings → OCR engine**.
This page documents, grounded in the current code, **where each engine runs**
and **what data leaves your device**, so you can choose one that matches your
privacy expectations.

> Every claim below is tied to the source that proves it. The dispatch order
> lives in `_recognize()` in
> `lib/modules/mining/widgets/reader_ocr_overlay.dart`; the engine list is
> `enum OcrEnginePreference { automatic, screenAi, googleLens, mokuroOnly }` in
> `lib/services/mining/mining_preferences.dart`.

## The engines

| Engine (setting) | Where inference runs | Network request it can make |
| --- | --- | --- |
| **Automatic** (default) | Mixed — prefers local, **falls back to the cloud** | Google Lens, and Mokuro-website (see below) |
| **ScreenAI (local Chrome)** | On-device (Windows only) | None for inference; Mokuro-website may still fire (see below) |
| **Google Lens** | Remote Google endpoint | Google Lens, and Mokuro-website (see below) |
| **Mokuro only** | Local pre-generated data | None for inference; Mokuro-website may still fire (see below) |

### Automatic — NOT isolated; can silently use the cloud

`Automatic` is a cascade, not a single engine. For a page with no local Mokuro
data it tries **ScreenAI** if it is installed, and **if ScreenAI is
unavailable or returns nothing it falls through to Google Lens**, which uploads
the page image to Google. This fall-through is unconditional — there is no
prompt — so choosing `Automatic` means page images **may be sent to Google**
without any further confirmation.

Proof: after the local Mokuro checks, `_recognize()` computes
`shouldTryScreenAi = engine == screenAi || (engine == automatic && await
ScreenAiOcrClient.isAvailable())`. When that is false (or ScreenAI throws and
the engine is *not* `screenAi`, so the error is swallowed), control reaches the
final unconditional `ChromeLensOcrClient().recognize(...)` block
(`reader_ocr_overlay.dart`, `_recognize`).

### ScreenAI (local Chrome) — on-device, Windows only, no OCR upload

ScreenAI runs Chrome's/Edge's bundled `chrome_screen_ai.dll` locally through
FFI; the page image is decoded and recognized on your machine and **no page
image is uploaded for recognition**. If ScreenAI is unavailable or fails, this
engine **rethrows the error instead of falling back to Google Lens** — so
selecting it explicitly does not silently send your page to the cloud.

Proof: `ScreenAiOcrClient.recognize()` calls a native DLL via
`_ScreenAiBridge` inside an isolate and makes no HTTP call
(`lib/services/mining/screen_ai_ocr.dart`). In `_recognize()`, the ScreenAI
`catch (_)` block does `if (engine == screenAi) rethrow;`, and the success path
returns for `screenAi` even when zero blocks are found — neither reaches the
Google Lens block.

Requirements/limits, from the code:

- **Windows only.** `ScreenAiOcrClient.isAvailable()` returns
  `Platform.isWindows && _ScreenAiBridge.isAvailable && _findComponentDirectory() != null`;
  `recognize()` throws `UnsupportedError` off Windows.
- **No manual DLL install.** The component is located automatically by scanning
  Chrome / Chrome SxS / Edge `User Data\screen_ai\<version>` for
  `chrome_screen_ai.dll` + `manifest.json` (`_findComponentDirectory()`). If it
  is missing you get "ScreenAI is not installed. Open Chrome once or select
  Google Lens." — you do not copy any file by hand.

### Google Lens — remote, page image is uploaded

Selecting Google Lens sends the page image to a Google endpoint and returns the
recognized text. The image (downscaled, see below) leaves your device on every
recognition.

Proof: `ChromeLensOcrClient` POSTs the encoded image to
`https://lensfrontend-pa.googleapis.com/v1/crupload` with an API key and a
Chrome user-agent (`lib/services/mining/chrome_lens_ocr.dart`). Before upload
the image is capped at `_maxDimension = 1500` px, but the **page pixels
themselves are transmitted** to Google. No text besides the image is sent, and
the response is parsed locally.

### Mokuro only — local pre-generated data, no OCR service

`Mokuro only` uses OCR text that was generated ahead of time (a `.mokuro`
sidecar). It **never** calls ScreenAI or Google Lens: if no local Mokuro data
resolves for the page, it returns **no** OCR blocks rather than falling back.

Proof: in `_recognize()`, `if (engine == mokuroOnly)` returns an empty
`_ReaderOcrPage` after the Mokuro checks, before the image bytes are read and
before either the ScreenAI or Google Lens block.

## The shared caveat: the Mokuro website fetch

Independently of the engine you pick, a separate toggle **"Mokuro website OCR"**
(`getMokuroWebsiteOcrEnabled()`, **default `true`**) can make Mangatan download
a pre-generated `.mokuro` volume from **`https://mokuro.moe`**. This runs for
*every* engine — including `ScreenAI` and `Mokuro only` — **but only when the
manga's source is named `mokuro`** (`MokuroExtensionOcrClient.volumeUri()`
returns `null` for any other source, so no request is made).

Proof: `_recognize()` runs `if (useMokuroWebsiteOcr) { MokuroExtensionOcrClient().fetchVolume(...) }`
before the engine-specific ScreenAI/Lens branches;
`MokuroExtensionOcrClient` targets `https://mokuro.moe/...` and short-circuits
to `null` unless `sourceName.trim().toLowerCase() == 'mokuro'`
(`lib/services/mining/mokuro_extension_ocr.dart`). So "local" engines are local
for *inference*, but this separate feature can still contact `mokuro.moe` for a
Mokuro source unless you turn it off.

## Choosing an engine for privacy

- **No page images to any third party:** pick **ScreenAI** (Windows) or
  **Mokuro only**, and — if you read a `mokuro` source — turn **Mokuro website
  OCR** off.
- **Best coverage, cloud is acceptable:** **Automatic** or **Google Lens**;
  both can upload page images to Google.
- Note that **Automatic is not a private choice**: it uploads to Google Lens
  whenever local recognition is unavailable or empty.

The sync layer classifies only the two unambiguous engines: Google Lens exports
as `cloud` and ScreenAI as `local`; `automatic` and `mokuroOnly` are left
unset because they are not a single fixed location
(`lib/services/sync/chimahon_mining_settings_adapter.dart`).

Refs #31.
