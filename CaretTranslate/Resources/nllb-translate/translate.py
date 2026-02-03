#!/usr/bin/env python3
"""NLLB translation helper for CaretTranslate.

Reads JSON requests from stdin, writes JSON responses to stdout.
Keeps model loaded in memory for fast subsequent translations.

Protocol:
  Input:  {"text": "Hello", "source": "en", "target": "sv"}
  Output: {"translation": "Hej"}
  Error:  {"error": "message"}
"""

import json
import sys
import os
from pathlib import Path

# Suppress tokenizer parallelism warning
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import ctranslate2
from transformers import AutoTokenizer

# NLLB language code mapping (ISO 639-1 to NLLB format)
LANG_CODE_MAP = {
    # Apple Translation supported (for reference)
    "ar": "arb_Arab", "zh-hans": "zho_Hans", "zh-hant": "zho_Hant",
    "nl": "nld_Latn", "en": "eng_Latn", "fr": "fra_Latn",
    "de": "deu_Latn", "hi": "hin_Deva", "id": "ind_Latn",
    "it": "ita_Latn", "ja": "jpn_Jpan", "ko": "kor_Hang",
    "pl": "pol_Latn", "pt": "por_Latn", "ru": "rus_Cyrl",
    "es": "spa_Latn", "th": "tha_Thai", "tr": "tur_Latn",
    "uk": "ukr_Cyrl", "vi": "vie_Latn",
    # Extended languages
    "sv": "swe_Latn", "no": "nob_Latn", "da": "dan_Latn",
    "fi": "fin_Latn", "is": "isl_Latn",
    "cs": "ces_Latn", "hu": "hun_Latn", "ro": "ron_Latn",
    "bg": "bul_Cyrl", "el": "ell_Grek", "sr": "srp_Cyrl",
    "hr": "hrv_Latn", "sk": "slk_Latn",
    "he": "heb_Hebr", "ca": "cat_Latn", "lv": "lvs_Latn",
    "lt": "lit_Latn", "et": "est_Latn",
    "bn": "ben_Beng", "ta": "tam_Taml", "tl": "tgl_Latn",
    "ms": "zsm_Latn", "my": "mya_Mymr",
    "sw": "swh_Latn", "am": "amh_Ethi", "yo": "yor_Latn",
    "fa": "pes_Arab", "ur": "urd_Arab",
    "af": "afr_Latn", "sq": "als_Latn", "hy": "hye_Armn",
    "az": "azj_Latn", "eu": "eus_Latn", "be": "bel_Cyrl",
    "bs": "bos_Latn", "cy": "cym_Latn", "eo": "epo_Latn",
    "gl": "glg_Latn", "ka": "kat_Geor", "gu": "guj_Gujr",
    "ha": "hau_Latn", "kn": "kan_Knda", "kk": "kaz_Cyrl",
    "km": "khm_Khmr", "lo": "lao_Laoo", "mk": "mkd_Cyrl",
    "ml": "mal_Mlym", "mr": "mar_Deva", "mn": "khk_Cyrl",
    "ne": "npi_Deva", "pa": "pan_Guru", "si": "sin_Sinh",
    "sl": "slv_Latn", "so": "som_Latn", "te": "tel_Telu",
    "uz": "uzn_Latn", "zu": "zul_Latn",
}


class NLLBTranslator:
    """Manages NLLB model and tokenizer for translation."""

    def __init__(self, model_path: str):
        self.tokenizer = AutoTokenizer.from_pretrained(
            "facebook/nllb-200-distilled-600M",
            src_lang="eng_Latn"
        )
        self.model = ctranslate2.Translator(
            model_path,
            device="cpu",
            compute_type="int8",
            inter_threads=1,
            intra_threads=4
        )

    def translate(self, text: str, source: str, target: str) -> str:
        """Translate text from source to target language."""
        src_lang = LANG_CODE_MAP.get(source.lower(), source)
        tgt_lang = LANG_CODE_MAP.get(target.lower(), target)

        self.tokenizer.src_lang = src_lang
        inputs = self.tokenizer(text, return_tensors="pt")
        input_tokens = inputs["input_ids"][0].tolist()
        input_tokens = self.tokenizer.convert_ids_to_tokens(input_tokens)

        target_prefix = [tgt_lang]
        results = self.model.translate_batch(
            [input_tokens],
            target_prefix=[target_prefix],
            beam_size=1,
            max_decoding_length=256
        )

        output_tokens = results[0].hypotheses[0]
        # Remove target language prefix token
        if output_tokens and output_tokens[0] == tgt_lang:
            output_tokens = output_tokens[1:]

        translation = self.tokenizer.decode(
            self.tokenizer.convert_tokens_to_ids(output_tokens),
            skip_special_tokens=True
        )
        return translation


def get_model_path() -> str:
    """Get path to the NLLB model directory."""
    # Check environment variable first
    if env_path := os.environ.get("NLLB_MODEL_PATH"):
        return env_path

    # Default to Application Support
    app_support = Path.home() / "Library" / "Application Support" / "CaretTranslate" / "models" / "nllb-200-distilled-600M-ct2-int8"
    return str(app_support)


def main():
    """Main loop: read JSON from stdin, write JSON to stdout."""
    model_path = get_model_path()

    if not Path(model_path).exists():
        print(json.dumps({"error": f"Model not found at {model_path}"}), flush=True)
        sys.exit(1)

    try:
        translator = NLLBTranslator(model_path)
        print(json.dumps({"status": "ready"}), flush=True)
    except Exception as e:
        print(json.dumps({"error": f"Failed to load model: {e}"}), flush=True)
        sys.exit(1)

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
            text = request.get("text", "")
            source = request.get("source", "en")
            target = request.get("target", "en")

            if not text:
                print(json.dumps({"error": "Empty text"}), flush=True)
                continue

            translation = translator.translate(text, source, target)
            print(json.dumps({"translation": translation}), flush=True)

        except json.JSONDecodeError as e:
            print(json.dumps({"error": f"Invalid JSON: {e}"}), flush=True)
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)


if __name__ == "__main__":
    main()
