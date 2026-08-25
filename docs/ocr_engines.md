# OCR engines and what leaves your device

Mangatan can read text off a manga page with several OCR ("optical character
recognition") back-ends. You pick one under **Reader settings → OCR engine**.
This page documents, grounded in the current code, **where each engine runs**
and **what data leaves your device**, so you can choose one that matches your
privacy expectations.

> Every claim below is tied to the source that proves it. The dispatch order
> lives in `recognizeGeneratedOcr()` in
> `lib/services/mining/generated_ocr.dart`; the engine list is
> `OcrEnginePreference` in
> `lib/services/mining/mining_preferences.dart`.

## The engines

| Engine (setting) | Where inference runs | Network request it can make |
| --- | --- | --- |
| **Automatic** (default) | Mixed — Google Lens first, then a platform-local fallback | Google Lens, and Mokuro-website (see below) |
| **Apple Vision** | On-device (iOS and macOS) | None for inference; Mokuro-website may still fire |
| **ScreenAI (local Chrome)** | On-device (Windows only) | None for inference; Mokuro-website may still fire (see below) |
| **Hayai OCR v2.1** | The user-configured Hayai server | Sends each AnimeText crop to that server |
| **Google Lens** | Remote Google endpoint | Google Lens, and Mokuro-website (see below) |
| **Mokuro only** | Local pre-generated data | None for inference; Mokuro-website may still fire (see below) |

### Automatic — NOT isolated; can silently use the cloud

`Automatic` is a cascade, not a single engine. For a page with no local Mokuro
data it tries **Google Lens first**, then falls back to Apple Vision or ScreenAI
when that platform-local engine is available. There is no upload prompt, so
choosing `Automatic` means page images may be sent to Google.

Proof: `generatedOcrEngineOrder()` returns Google Lens before Apple Vision or
ScreenAI for the automatic preference (`generated_ocr.dart`).

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

### Apple Vision — on-device on Apple platforms

Apple Vision performs recognition through the native Vision framework on iOS
and macOS. It does not upload page images for inference.

### Hayai OCR v2.1 — crop-level recognition through your server

Hayai is a custom ~150M-parameter Transformers model and its current v2.1
checkpoint is about 622 MB. Mangatan therefore talks to the included
`tool/hayai_ocr_server.py` adapter instead of embedding PyTorch in the app.
The helper pins revision `53d4723f2d9a748a4d8b2c1b50c12e53093e9cf2`.
Each detected text crop is sent to the URL configured in OCR settings. Use
`127.0.0.1` when the server and Mangatan run on the same computer, or an
authenticated LAN URL when an iPhone uses a computer-hosted server.

Desktop setup:

```sh
python -m pip install fastapi "uvicorn[standard]" python-multipart pillow \
  torch "transformers<5" accelerate
python tool/hayai_ocr_server.py
```

For another device on the LAN, bind explicitly and set an API key. Prefer a
shell secret prompt or environment manager so the real value is not retained
in shell history:

```sh
HAYAI_API_KEY="replace-me" python tool/hayai_ocr_server.py --host 0.0.0.0
```

Enter the computer's LAN URL and the same API key in Mangatan. Do not expose
this development server directly to the public internet.

## Shared AnimeText textbox detection

The optional AnimeText layer runs before any generated OCR engine. It detects
text blocks locally, crops them, invokes the selected OCR engine per crop, and
maps results back onto the full page. This is required for Hayai because Hayai
is crop-level rather than full-page OCR; it is optional for Apple Vision,
ScreenAI, and Google Lens. With Google Lens enabled, each crop is uploaded to
Google separately.

The upstream `deepghs/AnimeText_yolo` model is gated and GPL-3.0, so Mangatan
does not redistribute it. After accepting the Hugging Face terms, run
`tool/export_animetext_litert.py` with a read-only `HF_TOKEN`, then import the
resulting `.tflite` file in OCR settings. The helper pins the nano checkpoint
at revision `a180c191bfdb9f0e31b57e7de567e7b6bac50f84`.

```sh
python -m pip install huggingface_hub ultralytics tensorflow
HF_TOKEN="your-read-token" python tool/export_animetext_litert.py
```

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
