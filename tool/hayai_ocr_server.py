#!/usr/bin/env python3
r"""Local HTTP adapter for Hayai OCR v2.1 used by Mangatan.

Install requirements with:
  python -m pip install fastapi "uvicorn[standard]" python-multipart pillow \
    torch "transformers<5" accelerate
"""

from __future__ import annotations

import argparse
import io
import os
import re
import secrets
import unicodedata

import torch
import uvicorn
from fastapi import FastAPI, File, Header, HTTPException, UploadFile
from PIL import Image
from transformers import AutoModel, AutoProcessor, PreTrainedTokenizerFast


MODEL_ID = "JustANormalTinkerer/hayai-ocr-v2"
MODEL_REVISION = "53d4723f2d9a748a4d8b2c1b50c12e53093e9cf2"
PROCESSOR_ID = "google/siglip2-base-patch16-naflex"


def _device() -> str:
    if torch.cuda.is_available():
        return "cuda"
    if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
        return "mps"
    return "cpu"


def _normalize(value: str) -> str:
    text = unicodedata.normalize("NFKC", value or "")
    text = re.sub(r"[\r\n\t]+", " ", text)
    cjk = r"[\u3400-\u9fff\u3040-\u30ff\uac00-\ud7af]"
    text = re.sub(rf"({cjk})\s+({cjk})", r"\1\2", text)
    return re.sub(r"\s+", " ", text).strip()


def create_app(api_key: str = "") -> FastAPI:
    app = FastAPI(title="Mangatan Hayai OCR", version="2.1")
    device = _device()
    model = AutoModel.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
        trust_remote_code=True,
    ).to(device).eval()
    tokenizer = PreTrainedTokenizerFast.from_pretrained(
        MODEL_ID,
        revision=MODEL_REVISION,
    )
    processor = AutoProcessor.from_pretrained(PROCESSOR_ID)

    def authorize(header: str | None) -> None:
        if not api_key:
            return
        supplied = (header or "").removeprefix("Bearer ")
        if not secrets.compare_digest(supplied, api_key):
            raise HTTPException(status_code=401, detail="Invalid API key")

    @app.get("/health")
    def health() -> dict[str, str]:
        return {"status": "ok", "model": "hayai-ocr-v2.1", "device": device}

    @app.post("/v1/ocr")
    async def recognize(
        image: UploadFile = File(...),
        authorization: str | None = Header(default=None),
    ) -> dict[str, str]:
        authorize(authorization)
        raw = await image.read()
        crop = Image.open(io.BytesIO(raw)).convert("RGB")
        inputs = processor(
            images=[crop],
            max_num_patches=384,
            return_tensors="pt",
        ).to(device)
        with torch.inference_mode():
            texts = model.generate(
                pixel_values=inputs["pixel_values"],
                pixel_attention_mask=inputs["pixel_attention_mask"],
                spatial_shapes=inputs["spatial_shapes"],
                tokenizer=tokenizer,
                max_new_tokens=128,
                num_beams=4,
                repetition_penalty=1.0,
            )
        return {"text": _normalize(texts[0])}

    return app


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Hayai OCR v2.1 for Mangatan")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--api-key", default=os.environ.get("HAYAI_API_KEY", ""))
    args = parser.parse_args()
    uvicorn.run(create_app(args.api_key), host=args.host, port=args.port)


if __name__ == "__main__":
    main()
