# OCR engines

This document answers the questions raised in
[issue #31](https://github.com/1Selxo/Mangatan/issues/31) ("General
Clarifications") for the current, rewritten Mangatan codebase.

Issue #31 was filed against the old userscript-era setup, which shipped OCR as
a set of separate Python servers (`ocr-server`, `ocr-server-legacy`, a
"combined server", and a Windows Snipping Tool / `oneocr.dll` flow copied into
`.config/oneocr`). **None of those components exist in Mangatan.** OCR is now
performed entirely inside the app; there is no Python server to install, no
`server(local-ocr).py`, no legacy/combined server distinction, and no manual
`oneocr.dll` extraction step. This page documents what replaced them so the
original questions have an accurate, current answer.

## Where OCR is selected

The OCR engine is a single user setting, not a choice of which server binary to
run. It is stored as
[`OcrEnginePreference`](../lib/services/mining/mining_preferences.dart) and
exposed in the reader's settings modal under **OCR engine**
([`reader_settings_modal.dart`](../lib/modules/manga/reader/widgets/reader_settings_modal.dart)).

```dart
enum OcrEnginePreference { automatic, screenAi, googleLens, mokuroOnly }
```

The default is `automatic`.

## The engines

| Setting | Runs | Network | Platform | Notes |
| --- | --- | --- | --- | --- |
| `automatic` | Mokuro → ScreenAI → Google Lens (in that order) | Only if it falls through to Google Lens | Any | Default. Uses whatever is available for each page. |
| `screenAi` | On-device ScreenAI (native DLL over FFI) | None | Windows only | The modern "local OCR". No manual file setup — see below. |
| `googleLens` | Google Lens | Yes (sends the page image to Google) | Any | Cloud OCR. |
| `mokuroOnly` | Pre-computed Mokuro data only | None | Any | Never runs live OCR; shows only pre-generated Mokuro boxes. |

### `automatic` cascade

For a manga reader page, `automatic` resolves in this order
([`reader_ocr_overlay.dart`](../lib/modules/mining/widgets/reader_ocr_overlay.dart),
`_recognize`):

1. **Mokuro sidecar / pre-computed data.** If a matching `.mokuro` volume is
   found for the page, its boxes are used directly. No live OCR runs.
2. **Mokuro website OCR**, when that option is enabled and a volume can be
   fetched for the source.
3. **ScreenAI**, when `ScreenAiOcrClient.isAvailable()` is true (Windows, the
   native bridge is present, and the ScreenAI component directory exists). This
   is on-device and needs no network.
4. **Google Lens**, as the final fallback. This is the only step that leaves the
   device.

`screenAi` and `googleLens` pin the engine to that single backend (skipping the
Mokuro pre-pass); `mokuroOnly` uses pre-computed data and never runs live OCR.

Video OCR follows the same ScreenAI-then-Google-Lens logic and rejects
`mokuroOnly` because there is no pre-computed data for arbitrary video frames
([`video_ocr_overlay.dart`](../lib/modules/anime/widgets/video_ocr_overlay.dart)).

## Local (ScreenAI) vs cloud (Google Lens)

This is the modern form of issue #31's "local OCR vs Google Lens" question. The
Chimahon settings sync even labels them exactly that way
([`chimahon_mining_settings_adapter.dart`](../lib/services/sync/chimahon_mining_settings_adapter.dart)):
`screenAi` exports as `local`, `googleLens` as `cloud`.

- **ScreenAI (local):**
  - Runs on-device; **no image is sent to any server**.
  - Works offline.
  - Avoids depending on / hammering the Google Lens endpoint.
  - **Windows only** in the current build (the FFI bridge in
    [`windows/runner/screen_ai_bridge.cpp`](../windows/runner/screen_ai_bridge.cpp)).
- **Google Lens (cloud):**
  - Cross-platform.
  - Requires network; the page image is uploaded to Google.

Accuracy between the two is comparable for typical manga pages; the practical
difference is privacy/offline capability (ScreenAI) versus availability on every
platform (Google Lens).

### ScreenAI has no manual setup

Unlike the old flow described in issue #31, you do **not** download the Snipping
Tool, extract `oneocr.dll` / `oneocr.onemodel` / `onnxruntime.dll`, or copy
anything into `.config/oneocr`. Mangatan locates the ScreenAI component itself
([`screen_ai_ocr.dart`](../lib/services/mining/screen_ai_ocr.dart),
`_findComponentDirectory`). If the component is not present, `automatic` simply
falls through to Google Lens.

## Keeping this document accurate

`test/services/mining/ocr_engine_docs_test.dart` asserts that every value of
`OcrEnginePreference` is named in this file. If an engine is added or renamed,
that test fails until this document is updated — preventing the code/docs drift
that issue #31 originally reported.
