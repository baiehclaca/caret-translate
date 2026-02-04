# NLLB Translation Integration Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add support for 200+ languages via NLLB (No Language Left Behind) model while keeping Apple Translation as the fast primary translator.

**Architecture:** A Python helper binary using CTranslate2 runs as a subprocess. Swift app communicates via stdin/stdout JSON protocol. Apple Translation handles its 20 supported languages; NLLB handles everything else.

**Tech Stack:** Python 3, CTranslate2, NLLB-200-distilled-600M (int8), Swift Process/Pipe APIs

---

## Task 1: Create Python Helper Binary

**Files:**
- Create: `CaretTranslate/Resources/nllb-translate/translate.py`
- Create: `CaretTranslate/Resources/nllb-translate/requirements.txt`

**Step 1: Create the requirements file**

```txt
ctranslate2>=4.0.0
transformers>=4.35.0
sentencepiece>=0.1.99
```

**Step 2: Create the translation helper script**

```python
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
```

**Step 3: Test the helper manually (after model download)**

```bash
cd CaretTranslate/Resources/nllb-translate
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
echo '{"text": "Hello world", "source": "en", "target": "sv"}' | python translate.py
```

Expected output: `{"translation": "Hej världen"}` (after model is downloaded)

---

## Task 2: Create Model Download Script

**Files:**
- Create: `CaretTranslate/Resources/nllb-translate/download_model.py`

**Step 1: Create the download script**

```python
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
```

---

## Task 3: Create NLLBTranslator Swift Class

**Files:**
- Create: `CaretTranslate/Core/NLLBTranslator.swift`
- Test: `CaretTranslateTests/NLLBTranslatorTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import CaretTranslate

final class NLLBTranslatorTests: XCTestCase {

    func testTranslatorConformsToProtocol() {
        // Verify NLLBTranslator can be used as a Translator
        let translator: Translator = NLLBTranslator()
        XCTAssertNotNil(translator)
    }

    func testLanguageCodeMapping() {
        XCTAssertEqual(NLLBLanguageCodes.nllbCode(for: "sv"), "swe_Latn")
        XCTAssertEqual(NLLBLanguageCodes.nllbCode(for: "fi"), "fin_Latn")
        XCTAssertEqual(NLLBLanguageCodes.nllbCode(for: "unknown"), nil)
    }

    func testIsNLLBLanguage() {
        // Swedish is NLLB-only (not in Apple Translation)
        XCTAssertTrue(NLLBLanguageCodes.isNLLBOnlyLanguage("sv"))
        XCTAssertTrue(NLLBLanguageCodes.isNLLBOnlyLanguage("fi"))
        // English is Apple Translation supported
        XCTAssertFalse(NLLBLanguageCodes.isNLLBOnlyLanguage("en"))
        XCTAssertFalse(NLLBLanguageCodes.isNLLBOnlyLanguage("ja"))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' test 2>&1 | grep -A 5 "NLLBTranslator"`
Expected: Compilation error - NLLBTranslator not found

**Step 3: Write minimal implementation**

```swift
import Foundation

/// Language code mappings for NLLB model.
public enum NLLBLanguageCodes {
    /// Apple Translation supported language codes.
    static let appleSupported: Set<String> = [
        "ar", "zh-hans", "zh-hant", "nl", "en", "fr", "de", "hi", "id",
        "it", "ja", "ko", "pl", "pt", "ru", "es", "th", "tr", "uk", "vi"
    ]

    /// NLLB language code mapping (ISO 639-1 to NLLB format).
    static let mapping: [String: String] = [
        // Scandinavian
        "sv": "swe_Latn", "no": "nob_Latn", "da": "dan_Latn",
        "fi": "fin_Latn", "is": "isl_Latn",
        // Eastern European
        "cs": "ces_Latn", "hu": "hun_Latn", "ro": "ron_Latn",
        "bg": "bul_Cyrl", "el": "ell_Grek", "sr": "srp_Cyrl",
        "hr": "hrv_Latn", "sk": "slk_Latn",
        // Other European
        "he": "heb_Hebr", "ca": "cat_Latn", "lv": "lvs_Latn",
        "lt": "lit_Latn", "et": "est_Latn",
        // South/Southeast Asian
        "bn": "ben_Beng", "ta": "tam_Taml", "tl": "tgl_Latn",
        "ms": "zsm_Latn", "my": "mya_Mymr",
        // African
        "sw": "swh_Latn", "am": "amh_Ethi", "yo": "yor_Latn",
        // Other
        "fa": "pes_Arab", "ur": "urd_Arab",
        // Additional languages
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
        // Apple-supported languages (for completeness)
        "ar": "arb_Arab", "zh-hans": "zho_Hans", "zh-hant": "zho_Hant",
        "nl": "nld_Latn", "en": "eng_Latn", "fr": "fra_Latn",
        "de": "deu_Latn", "hi": "hin_Deva", "id": "ind_Latn",
        "it": "ita_Latn", "ja": "jpn_Jpan", "ko": "kor_Hang",
        "pl": "pol_Latn", "pt": "por_Latn", "ru": "rus_Cyrl",
        "es": "spa_Latn", "th": "tha_Thai", "tr": "tur_Latn",
        "uk": "ukr_Cyrl", "vi": "vie_Latn",
    ]

    /// Returns the NLLB language code for a given ISO code.
    public static func nllbCode(for isoCode: String) -> String? {
        mapping[isoCode.lowercased()]
    }

    /// Returns true if the language is only supported by NLLB (not Apple Translation).
    public static func isNLLBOnlyLanguage(_ code: String) -> Bool {
        let normalized = code.lowercased()
        return mapping[normalized] != nil && !appleSupported.contains(normalized)
    }

    /// Returns true if NLLB supports this language.
    public static func isSupported(_ code: String) -> Bool {
        mapping[code.lowercased()] != nil
    }
}

/// Errors that can occur during NLLB translation.
public enum NLLBTranslatorError: Error {
    case helperNotFound
    case helperStartFailed(String)
    case modelNotReady
    case timeout
    case invalidResponse
    case translationFailed(String)
}

/// Translator implementation using NLLB via a Python helper process.
public final class NLLBTranslator: Translator, @unchecked Sendable {
    private let logger: (@Sendable (String) -> Void)?
    private let helperPath: String
    private let timeoutSeconds: Double

    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var isReady = false
    private let lock = NSLock()

    public init(
        helperPath: String? = nil,
        timeoutSeconds: Double = 30,
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        self.helperPath = helperPath ?? Self.defaultHelperPath()
        self.timeoutSeconds = timeoutSeconds
        self.logger = logger
    }

    deinit {
        shutdown()
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        try ensureHelperRunning()

        let request = NLLBRequest(
            text: text,
            source: from.code,
            target: to.code
        )

        guard let requestData = try? JSONEncoder().encode(request),
              var requestString = String(data: requestData, encoding: .utf8) else {
            throw NLLBTranslatorError.invalidResponse
        }

        requestString += "\n"

        lock.lock()
        guard let stdin = stdin, let stdout = stdout else {
            lock.unlock()
            throw NLLBTranslatorError.modelNotReady
        }
        lock.unlock()

        stdin.write(requestString.data(using: .utf8)!)

        // Read response with timeout
        let responseData = try await withTimeout(seconds: timeoutSeconds) {
            self.readLine(from: stdout)
        }

        guard let responseData,
              let response = try? JSONDecoder().decode(NLLBResponse.self, from: responseData) else {
            throw NLLBTranslatorError.invalidResponse
        }

        if let error = response.error {
            throw NLLBTranslatorError.translationFailed(error)
        }

        if let translation = response.translation {
            logger?("NLLBTranslator: '\(text)' -> '\(translation)'")
            return translation
        }

        return nil
    }

    /// Starts the helper process if not already running.
    private func ensureHelperRunning() throws {
        lock.lock()
        defer { lock.unlock() }

        if process?.isRunning == true && isReady {
            return
        }

        // Clean up any existing process
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
        isReady = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", helperPath]
        process.environment = ProcessInfo.processInfo.environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw NLLBTranslatorError.helperStartFailed(error.localizedDescription)
        }

        self.process = process
        self.stdin = stdinPipe.fileHandleForWriting
        self.stdout = stdoutPipe.fileHandleForReading

        // Wait for ready signal
        if let readyData = readLine(from: stdoutPipe.fileHandleForReading),
           let ready = try? JSONDecoder().decode(NLLBResponse.self, from: readyData),
           ready.status == "ready" {
            isReady = true
            logger?("NLLBTranslator: Helper ready")
        } else {
            process.terminate()
            throw NLLBTranslatorError.modelNotReady
        }
    }

    /// Reads a single line from the file handle.
    private func readLine(from handle: FileHandle) -> Data? {
        var buffer = Data()
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                return buffer.isEmpty ? nil : buffer
            }
            buffer.append(chunk)
            if chunk.contains(UInt8(ascii: "\n")) {
                break
            }
        }
        // Remove trailing newline
        if buffer.last == UInt8(ascii: "\n") {
            buffer.removeLast()
        }
        return buffer
    }

    /// Executes a closure with a timeout.
    private func withTimeout<T>(seconds: Double, operation: @escaping () -> T?) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NLLBTranslatorError.timeout
            }

            let result = try await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }

    /// Shuts down the helper process.
    public func shutdown() {
        lock.lock()
        defer { lock.unlock() }

        stdin?.closeFile()
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
        isReady = false
    }

    /// Returns the default path to the helper script.
    private static func defaultHelperPath() -> String {
        if let bundlePath = Bundle.main.path(forResource: "translate", ofType: "py", inDirectory: "nllb-translate") {
            return bundlePath
        }
        // Fallback for development
        return "CaretTranslate/Resources/nllb-translate/translate.py"
    }
}

// MARK: - Request/Response Types

private struct NLLBRequest: Codable {
    let text: String
    let source: String
    let target: String
}

private struct NLLBResponse: Codable {
    let translation: String?
    let error: String?
    let status: String?
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add CaretTranslate/Core/NLLBTranslator.swift CaretTranslateTests/NLLBTranslatorTests.swift
git add CaretTranslate/Resources/nllb-translate/
git commit -m "feat: add NLLB translator with Python helper

- Add NLLBTranslator conforming to Translator protocol
- Add Python helper using CTranslate2 for fast inference
- Add language code mapping for 50+ languages
- Add model download script

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Create Routing Translator

**Files:**
- Create: `CaretTranslate/Core/RoutingTranslator.swift`
- Test: `CaretTranslateTests/RoutingTranslatorTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import CaretTranslate

final class RoutingTranslatorTests: XCTestCase {

    func testRoutesToAppleForSupportedLanguages() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator
        )

        // English to Japanese - Apple supported
        let result = try await router.translate("Hello", from: Language(code: "en"), to: Language(code: "ja"))
        XCTAssertEqual(result, "Apple result")
        XCTAssertEqual(appleTranslator.callCount, 1)
        XCTAssertEqual(nllbTranslator.callCount, 0)
    }

    func testRoutesToNLLBForUnsupportedLanguages() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator
        )

        // English to Swedish - NLLB only
        let result = try await router.translate("Hello", from: Language(code: "en"), to: Language(code: "sv"))
        XCTAssertEqual(result, "NLLB result")
        XCTAssertEqual(appleTranslator.callCount, 0)
        XCTAssertEqual(nllbTranslator.callCount, 1)
    }

    func testRoutesToNLLBWhenSourceIsUnsupported() async throws {
        let appleTranslator = MockTranslator(result: "Apple result")
        let nllbTranslator = MockTranslator(result: "NLLB result")

        let router = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator
        )

        // Swedish to English - NLLB (source not Apple supported)
        let result = try await router.translate("Hej", from: Language(code: "sv"), to: Language(code: "en"))
        XCTAssertEqual(result, "NLLB result")
        XCTAssertEqual(appleTranslator.callCount, 0)
        XCTAssertEqual(nllbTranslator.callCount, 1)
    }
}

private final class MockTranslator: Translator, @unchecked Sendable {
    let result: String?
    var callCount = 0

    init(result: String?) {
        self.result = result
    }

    func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        callCount += 1
        return result
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' test 2>&1 | grep -A 5 "RoutingTranslator"`
Expected: Compilation error - RoutingTranslator not found

**Step 3: Write minimal implementation**

```swift
import Foundation

/// A translator that routes requests to Apple Translation or NLLB based on language support.
public struct RoutingTranslator: Translator {
    private let appleTranslator: Translator
    private let nllbTranslator: Translator
    private let logger: (@Sendable (String) -> Void)?

    public init(
        appleTranslator: Translator,
        nllbTranslator: Translator,
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        self.appleTranslator = appleTranslator
        self.nllbTranslator = nllbTranslator
        self.logger = logger
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        if shouldUseApple(from: from, to: to) {
            logger?("RoutingTranslator: Using Apple for \(from.code) -> \(to.code)")
            return try await appleTranslator.translate(text, from: from, to: to)
        } else {
            logger?("RoutingTranslator: Using NLLB for \(from.code) -> \(to.code)")
            return try await nllbTranslator.translate(text, from: from, to: to)
        }
    }

    /// Returns true if Apple Translation supports this language pair.
    private func shouldUseApple(from: Language, to: Language) -> Bool {
        let appleSupported = NLLBLanguageCodes.appleSupported

        // For auto-detect, check if target is Apple supported
        if from == .auto {
            return appleSupported.contains(to.code.lowercased())
        }

        // Both source and target must be Apple supported
        return appleSupported.contains(from.code.lowercased()) &&
               appleSupported.contains(to.code.lowercased())
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' test`
Expected: PASS

**Step 5: Commit**

```bash
git add CaretTranslate/Core/RoutingTranslator.swift CaretTranslateTests/RoutingTranslatorTests.swift
git commit -m "feat: add RoutingTranslator for Apple/NLLB selection

Routes translation requests to Apple Translation for supported
language pairs, falls back to NLLB for extended languages.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Update TranslationCoordinator to Use Routing

**Files:**
- Modify: `CaretTranslate/App/TranslationCoordinator.swift`

**Step 1: Update the coordinator initialization**

Replace lines 12-24 in `TranslationCoordinator.swift`:

```swift
@available(macOS 15.0, *)
@MainActor
final class TranslationCoordinator {
    private let settings: SettingsStore
    private let textClient: AccessibilityTextClient
    private let privacyFilter: PrivacyFilter
    private let historyStore: TranslationHistoryStore
    private let previewController = TranslationPreviewWindowController()
    private let sentenceTranslator: Translator
    private let wordTranslator: Translator
    private let languageIdentifier: WordLanguageIdentifying?
    private let nllbTranslator: NLLBTranslator
    private var prefetchTask: Task<PreparedTranslation?, Error>?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.textClient = AccessibilityTextClient()
        self.privacyFilter = PrivacyFilter(settings: settings)
        self.historyStore = TranslationHistoryStore(settings: settings)

        let appleTranslator = AppleTranslator(logger: DebugLogger.log)
        self.nllbTranslator = NLLBTranslator(logger: DebugLogger.log)

        let routingTranslator = RoutingTranslator(
            appleTranslator: appleTranslator,
            nllbTranslator: nllbTranslator,
            logger: DebugLogger.log
        )

        self.sentenceTranslator = routingTranslator
        self.wordTranslator = routingTranslator
        self.languageIdentifier = NaturalLanguageWordLanguageIdentifier(logger: DebugLogger.log)
    }

    // ... rest of the file unchanged
}
```

**Step 2: Add cleanup on app termination**

In `AppDelegate.swift`, add to `applicationWillTerminate`:

```swift
func applicationWillTerminate(_ notification: Notification) {
    doubleTabMonitor?.stop()
    hotkeyMonitor?.stop()
    if let settingsObserver {
        NotificationCenter.default.removeObserver(settingsObserver)
    }
    // Shutdown NLLB helper
    coordinator.shutdown()
}
```

Add shutdown method to TranslationCoordinator:

```swift
func shutdown() {
    nllbTranslator.shutdown()
}
```

**Step 3: Build and verify**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' build`
Expected: Build succeeded

**Step 4: Commit**

```bash
git add CaretTranslate/App/TranslationCoordinator.swift CaretTranslate/App/AppDelegate.swift
git commit -m "feat: integrate RoutingTranslator into TranslationCoordinator

Uses RoutingTranslator for both sentence and word translation,
automatically selecting Apple or NLLB based on language pair.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Expand Language List in UI

**Files:**
- Modify: `CaretTranslate/App/SettingsLabels.swift`

**Step 1: Update SupportedLanguages enum**

Replace the entire `SupportedLanguages` enum:

```swift
/// Languages supported by the application (Apple Translation + NLLB).
enum SupportedLanguages {
    /// Apple Translation languages (fastest, on-device).
    static let appleLanguages: [LanguageOption] = [
        LanguageOption(code: "ar", name: "Arabic"),
        LanguageOption(code: "zh-Hans", name: "Chinese (Simplified)"),
        LanguageOption(code: "zh-Hant", name: "Chinese (Traditional)"),
        LanguageOption(code: "nl", name: "Dutch"),
        LanguageOption(code: "en", name: "English"),
        LanguageOption(code: "fr", name: "French"),
        LanguageOption(code: "de", name: "German"),
        LanguageOption(code: "hi", name: "Hindi"),
        LanguageOption(code: "id", name: "Indonesian"),
        LanguageOption(code: "it", name: "Italian"),
        LanguageOption(code: "ja", name: "Japanese"),
        LanguageOption(code: "ko", name: "Korean"),
        LanguageOption(code: "pl", name: "Polish"),
        LanguageOption(code: "pt", name: "Portuguese"),
        LanguageOption(code: "ru", name: "Russian"),
        LanguageOption(code: "es", name: "Spanish"),
        LanguageOption(code: "th", name: "Thai"),
        LanguageOption(code: "tr", name: "Turkish"),
        LanguageOption(code: "uk", name: "Ukrainian"),
        LanguageOption(code: "vi", name: "Vietnamese"),
    ]

    /// Extended languages via NLLB (requires model download).
    static let nllbLanguages: [LanguageOption] = [
        // Scandinavian
        LanguageOption(code: "sv", name: "Swedish"),
        LanguageOption(code: "no", name: "Norwegian"),
        LanguageOption(code: "da", name: "Danish"),
        LanguageOption(code: "fi", name: "Finnish"),
        LanguageOption(code: "is", name: "Icelandic"),
        // Eastern European
        LanguageOption(code: "cs", name: "Czech"),
        LanguageOption(code: "hu", name: "Hungarian"),
        LanguageOption(code: "ro", name: "Romanian"),
        LanguageOption(code: "bg", name: "Bulgarian"),
        LanguageOption(code: "el", name: "Greek"),
        LanguageOption(code: "sr", name: "Serbian"),
        LanguageOption(code: "hr", name: "Croatian"),
        LanguageOption(code: "sk", name: "Slovak"),
        LanguageOption(code: "sl", name: "Slovenian"),
        // Other European
        LanguageOption(code: "he", name: "Hebrew"),
        LanguageOption(code: "ca", name: "Catalan"),
        LanguageOption(code: "lv", name: "Latvian"),
        LanguageOption(code: "lt", name: "Lithuanian"),
        LanguageOption(code: "et", name: "Estonian"),
        LanguageOption(code: "af", name: "Afrikaans"),
        LanguageOption(code: "sq", name: "Albanian"),
        LanguageOption(code: "hy", name: "Armenian"),
        LanguageOption(code: "az", name: "Azerbaijani"),
        LanguageOption(code: "eu", name: "Basque"),
        LanguageOption(code: "be", name: "Belarusian"),
        LanguageOption(code: "bs", name: "Bosnian"),
        LanguageOption(code: "cy", name: "Welsh"),
        LanguageOption(code: "gl", name: "Galician"),
        LanguageOption(code: "ka", name: "Georgian"),
        LanguageOption(code: "mk", name: "Macedonian"),
        // South Asian
        LanguageOption(code: "bn", name: "Bengali"),
        LanguageOption(code: "ta", name: "Tamil"),
        LanguageOption(code: "gu", name: "Gujarati"),
        LanguageOption(code: "kn", name: "Kannada"),
        LanguageOption(code: "ml", name: "Malayalam"),
        LanguageOption(code: "mr", name: "Marathi"),
        LanguageOption(code: "ne", name: "Nepali"),
        LanguageOption(code: "pa", name: "Punjabi"),
        LanguageOption(code: "si", name: "Sinhala"),
        LanguageOption(code: "te", name: "Telugu"),
        LanguageOption(code: "ur", name: "Urdu"),
        // Southeast Asian
        LanguageOption(code: "tl", name: "Tagalog"),
        LanguageOption(code: "ms", name: "Malay"),
        LanguageOption(code: "my", name: "Burmese"),
        LanguageOption(code: "km", name: "Khmer"),
        LanguageOption(code: "lo", name: "Lao"),
        // Central Asian
        LanguageOption(code: "kk", name: "Kazakh"),
        LanguageOption(code: "mn", name: "Mongolian"),
        LanguageOption(code: "uz", name: "Uzbek"),
        // Middle Eastern
        LanguageOption(code: "fa", name: "Persian"),
        // African
        LanguageOption(code: "sw", name: "Swahili"),
        LanguageOption(code: "am", name: "Amharic"),
        LanguageOption(code: "yo", name: "Yoruba"),
        LanguageOption(code: "ha", name: "Hausa"),
        LanguageOption(code: "so", name: "Somali"),
        LanguageOption(code: "zu", name: "Zulu"),
    ]

    /// All supported languages combined.
    static let all: [LanguageOption] = {
        var languages = [LanguageOption.auto]
        languages.append(contentsOf: appleLanguages.sorted())
        languages.append(contentsOf: nllbLanguages.sorted())
        return languages
    }()
}
```

**Step 2: Build and verify**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' build`
Expected: Build succeeded

**Step 3: Commit**

```bash
git add CaretTranslate/App/SettingsLabels.swift
git commit -m "feat: expand language list with 50+ NLLB languages

Adds Scandinavian, Eastern European, South Asian, Southeast Asian,
African, and other languages via NLLB integration.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Add Model Download UI (Settings)

**Files:**
- Create: `CaretTranslate/App/ModelManagerView.swift`
- Modify: `CaretTranslate/App/SettingsView.swift`

**Step 1: Create ModelManagerView**

```swift
import SwiftUI

struct ModelManagerView: View {
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    @State private var modelInstalled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Extended Languages (NLLB)")
                .font(.headline)

            Text("Download the NLLB model to enable 50+ additional languages including Swedish, Finnish, Greek, Hebrew, and more.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if modelInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Model installed (~300 MB)")
                        .foregroundColor(.secondary)
                } else if isDownloading {
                    ProgressView(value: downloadProgress)
                        .frame(width: 150)
                    Text("\(Int(downloadProgress * 100))%")
                        .foregroundColor(.secondary)
                } else {
                    Button("Download Model") {
                        downloadModel()
                    }
                    Text("~1.5 GB download, ~300 MB on disk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .onAppear {
            checkModelStatus()
        }
    }

    private func checkModelStatus() {
        let modelPath = Self.modelPath()
        modelInstalled = FileManager.default.fileExists(atPath: modelPath)
    }

    private func downloadModel() {
        isDownloading = true
        downloadError = nil

        Task {
            do {
                try await runDownloadScript()
                await MainActor.run {
                    isDownloading = false
                    checkModelStatus()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func runDownloadScript() async throws {
        let scriptPath = Bundle.main.path(
            forResource: "download_model",
            ofType: "py",
            inDirectory: "nllb-translate"
        ) ?? "CaretTranslate/Resources/nllb-translate/download_model.py"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", scriptPath]

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ModelDownload",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Download failed with exit code \(process.terminationStatus)"]
            )
        }
    }

    static func modelPath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("CaretTranslate")
            .appendingPathComponent("models")
            .appendingPathComponent("nllb-200-distilled-600M-ct2-int8")
            .path
    }
}
```

**Step 2: Add ModelManagerView to SettingsView**

In `SettingsView.swift`, add a new tab:

```swift
TabView {
    GeneralSettingsView(viewModel: viewModel)
        .tabItem { Label("General", systemImage: "gearshape") }

    ModelManagerView()
        .tabItem { Label("Models", systemImage: "arrow.down.circle") }

    PrivacySettingsView(viewModel: viewModel)
        .tabItem { Label("Privacy", systemImage: "hand.raised") }

    HistorySettingsView(viewModel: viewModel)
        .tabItem { Label("History", systemImage: "clock") }
}
```

**Step 3: Build and verify**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' build`
Expected: Build succeeded

**Step 4: Commit**

```bash
git add CaretTranslate/App/ModelManagerView.swift CaretTranslate/App/SettingsView.swift
git commit -m "feat: add model download UI in Settings

Adds a Models tab in Settings to download the NLLB model
for extended language support.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Bundle Python Helper in Xcode Project

**Files:**
- Modify: Xcode project to include Resources/nllb-translate folder

**Step 1: Add folder reference in Xcode**

1. Open CaretTranslate.xcodeproj in Xcode
2. Right-click on CaretTranslate target folder
3. Select "Add Files to CaretTranslate..."
4. Navigate to Resources/nllb-translate
5. Select "Create folder references" (NOT "Create groups")
6. Ensure "Copy items if needed" is unchecked
7. Ensure CaretTranslate target is checked
8. Click Add

**Step 2: Verify bundle includes files**

Run: `xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' build`

Then check:
```bash
ls "$(xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -showBuildSettings | grep -m 1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/CaretTranslate.app/Contents/Resources/nllb-translate/"
```

Expected: translate.py, requirements.txt, download_model.py

**Step 3: Commit**

```bash
git add CaretTranslate.xcodeproj
git commit -m "build: bundle NLLB Python helper in app resources

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Integration Test

**Step 1: Download the model (one-time setup)**

```bash
cd /Users/teodorwaltervido/Documents/caret/CaretTranslate/CaretTranslate/Resources/nllb-translate
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python download_model.py
```

**Step 2: Test the helper manually**

```bash
source venv/bin/activate
echo '{"text": "Hello, how are you?", "source": "en", "target": "sv"}' | python translate.py
```

Expected: `{"translation": "Hej, hur mår du?"}`

**Step 3: Build and run the app**

```bash
xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' build
open "$(xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -showBuildSettings | grep -m 1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/CaretTranslate.app"
```

**Step 4: Manual testing**

1. Open Settings → Models tab
2. Verify model status shows installed
3. Set source language to English, target to Swedish
4. Open a text editor, type "Hello world"
5. Position caret near text, trigger translation
6. Verify "Hej världen" appears

**Step 5: Run all tests**

```bash
xcodebuild -project CaretTranslate.xcodeproj -scheme CaretTranslate -destination 'platform=macOS' test
```

Expected: All tests pass

---

## Summary

This plan adds NLLB support to CaretTranslate with:

1. **Python helper binary** using CTranslate2 for fast inference (~50-150ms)
2. **RoutingTranslator** that automatically selects Apple or NLLB
3. **50+ new languages** including Scandinavian, Eastern European, Asian, and African
4. **Model download UI** in Settings
5. **Seamless integration** - users just select a language and it works

The Apple Translation path remains untouched for its 20 languages, ensuring the fastest possible experience for common language pairs.
