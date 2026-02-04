#!/usr/bin/env python3
"""Download and convert NLLB model to CTranslate2 format with int8 quantization."""

import os
import sys
import subprocess
from pathlib import Path

def install_packages():
    """Install required packages using pip."""
    print("Installing required packages (this may take a few minutes)...")
    print("Installing: ctranslate2, transformers, sentencepiece, torch")

    packages = ["ctranslate2", "transformers", "sentencepiece", "torch"]

    for package in packages:
        print(f"Installing {package}...")
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--user", package],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"Error installing {package}: {result.stderr}")
            raise Exception(f"Failed to install {package}")

    print("All packages installed successfully!")

def check_packages():
    """Check if required packages are installed."""
    try:
        import ctranslate2
        import transformers
        import sentencepiece
        import torch
        return True
    except ImportError as e:
        print(f"Missing package: {e}")
        return False

def main():
    # Check and install packages if needed
    if not check_packages():
        print("Required packages not found. Installing...")
        install_packages()

        # Verify installation
        if not check_packages():
            print("ERROR: Failed to install required packages")
            sys.exit(1)

    # Import after ensuring packages are installed
    import ctranslate2

    output_dir = Path.home() / "Library" / "Application Support" / "CaretTranslate" / "models" / "nllb-200-distilled-600M-ct2-int8"

    if output_dir.exists():
        print(f"Model already exists at {output_dir}")
        return

    print("Downloading and converting NLLB-200-distilled-600M to CTranslate2 int8 format...")
    print("This will download ~1.5 GB and may take several minutes...")

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
