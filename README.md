# CaretTranslate

## Purpose
CaretTranslate is a macOS menu bar app that replaces the word or sentence nearest the caret with a translation. It’s built for fast, keyboard‑first translation without switching apps.

## Highlights
- Menu‑bar UX with a single shortcut to translate in place.
- Apple Translation for supported languages (fast, on‑device).
- NLLB‑200 + CTranslate2 for extended language coverage.
- Optional preview before applying replacements.
- Secure‑field protection (password fields are always blocked).
- Local‑only translation path by default (no API keys required).

## Usage
1. Launch the app and grant the requested permissions.
2. Choose source and target languages in Settings.
3. Double‑tap `Tab` (or your custom hotkey) to translate the nearest word or sentence.
4. Confirm in the preview (if enabled) and the replacement is applied.

## Parameters
These are the primary user‑configurable settings:
- `Source language`: `Auto` or a specific language.
- `Target language`: the output language.
- `Shortcut`: double‑tap `Tab` or a custom hotkey.
- `Preview`: show a confirmation dialog before applying the replacement.
- `History`: enable/disable translated history entries.

## Examples
- Translate a German word to English while typing:
  - Source: `Auto`
  - Target: `en`
  - Action: double‑tap `Tab`
- Translate a full sentence to Spanish with confirmation:
  - Source: `en`
  - Target: `es`
  - Preview: on
  - Action: double‑tap `Tab` and confirm

## How It Works
- For Apple‑supported languages, CaretTranslate uses Apple’s Translation framework.
- For extended languages, it uses the NLLB‑200 distilled model via CTranslate2.
- A warm‑up translation runs on launch to reduce first‑use latency.

Terminology:
- **NLLB** (No Language Left Behind): a multilingual translation model.
- **CTranslate2**: an optimized inference engine for Transformer models.
- **SentencePiece**: a subword tokenizer used by NLLB.

## Model Download (Extended Languages)
To enable extended language support:
1. Open Settings → Models.
2. Click `Download Model`.
3. The app downloads the CTranslate2 model files and tokenizer (~350 MB + tokenizer).

The model is stored in:
`~/Library/Application Support/CaretTranslate/models/nllb-200-distilled-600M-ct2-int8`

## Optional Native Helper (Faster Startup)
The app can use a native helper instead of the Python helper.
1. Build the helper in `CaretTranslate/Resources/nllb-translate-native` using CMake.
2. Copy `translate-ct2` to:
   `~/Library/Application Support/CaretTranslate/bin/translate-ct2`
3. On launch, the app will prefer the native helper if present.

## Permissions
CaretTranslate requests:
- **Accessibility**: to read and replace text in the focused app.
- **Input Monitoring**: to detect the translation shortcut.

Secure fields (passwords, etc.) are always blocked from translation.

## Data & Privacy
- Translation text is only captured after the shortcut is triggered.
- Apple Translation runs on device according to Apple’s framework behavior.
- NLLB translations run locally using the downloaded model.
- No external API keys are required for the default translation path.

## Build From Source
```bash
xcodebuild -scheme CaretTranslate -destination 'platform=macOS'
```
Or open `CaretTranslate.xcodeproj` in Xcode and build the app.

## Tests
```bash
xcodebuild test -scheme CaretTranslate -destination 'platform=macOS'
```

## Release (GitHub)
1. Build a Release app in Xcode.
2. Zip the app:
```bash
ditto -c -k --sequesterRsrc --keepParent CaretTranslate.app CaretTranslate.app.zip
```
3. Create a tag and release, then upload the zip as a release asset.

## Troubleshooting
- If the model isn’t detected, re‑download it in Settings → Models.
- If a translation fails for an extended language, verify the model folder exists and contains:
  - `config.json`
  - `model.bin`
  - `shared_vocabulary.json`
  - `sentencepiece.bpe.model`

## Roadmap
- Optional GPU‑backed translation for lower latency on extended languages.
- Language‑specific quality tuning for short‑text translations.
