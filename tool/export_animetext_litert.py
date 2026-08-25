#!/usr/bin/env python3
r"""Export the gated AnimeText YOLO12n checkpoint to a Mangatan LiteRT model.

Install requirements with:
  python -m pip install huggingface_hub ultralytics tensorflow

Log in once with ``hf auth login`` or expose a read-only ``HF_TOKEN``.
"""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path

from huggingface_hub import hf_hub_download
from ultralytics import YOLO


REPOSITORY = "deepghs/AnimeText_yolo"
REVISION = "a180c191bfdb9f0e31b57e7de567e7b6bac50f84"
CHECKPOINT = "yolo12n_animetext/model.pt"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export the AnimeText model for Mangatan."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("animetext_yolo12n.tflite"),
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("HF_TOKEN"),
        help="Hugging Face read token; otherwise use the cached CLI login.",
    )
    args = parser.parse_args()
    checkpoint = hf_hub_download(
        repo_id=REPOSITORY,
        filename=CHECKPOINT,
        revision=REVISION,
        token=args.token or True,
    )
    exported = Path(
        YOLO(checkpoint).export(
            format="tflite",
            imgsz=640,
            half=True,
            nms=False,
        )
    )
    candidates = [exported] if exported.suffix == ".tflite" else []
    if exported.is_dir():
        candidates.extend(exported.rglob("*.tflite"))
    candidates = [item for item in candidates if "float16" in item.name] or candidates
    if not candidates:
        raise RuntimeError(f"Ultralytics produced no TFLite model under {exported}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(candidates[0], args.output)
    print(f"Created {args.output.resolve()}")
    print("Import this file from Settings > OCR & panel navigation.")


if __name__ == "__main__":
    main()
