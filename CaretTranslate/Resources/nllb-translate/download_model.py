#!/usr/bin/env python3
"""Download and convert NLLB model to CTranslate2 format with int8 quantization."""

import os
import sys
from pathlib import Path

def main():
    try:
        import ctranslate2
    except ImportError:
        print("Installing ctranslate2...")
        os.system(f"{sys.executable} -m pip install ctranslate2 transformers sentencepiece")
        import ctranslate2

    output_dir = Path.home() / "Library" / "Application Support" / "CaretTranslate" / "models" / "nllb-200-distilled-600M-ct2-int8"

    if output_dir.exists():
        print(f"Model already exists at {output_dir}")
        return

    print("Downloading and converting NLLB-200-distilled-600M to CTranslate2 int8 format...")
    print("This may take several minutes...")

    output_dir.parent.mkdir(parents=True, exist_ok=True)

    converter = ctranslate2.converters.TransformersConverter(
        "facebook/nllb-200-distilled-600M"
    )
    converter.convert(
        str(output_dir),
        quantization="int8",
        force=True
    )

    print(f"Model saved to {output_dir}")
    print("Done!")


if __name__ == "__main__":
    main()
