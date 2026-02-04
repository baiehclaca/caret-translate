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
        "bn": "ben_Beng", "ta": "tam_Taml", "tl": "tgl_Latn", "fil": "tgl_Latn",
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

/// Actor to manage the helper process state.
private actor HelperProcessManager {
    private var process: Process?
    private var stdin: FileHandle?
    private var stdout: FileHandle?
    private var isReady = false
    private let helperCommand: HelperCommand
    private let logger: (@Sendable (String) -> Void)?

    init(helperCommand: HelperCommand, logger: (@Sendable (String) -> Void)?) {
        self.helperCommand = helperCommand
        self.logger = logger
    }

    func ensureRunning() throws {
        if process?.isRunning == true && isReady {
            return
        }

        // Clean up any existing process
        shutdownInternal()

        let newProcess = Process()
        newProcess.executableURL = helperCommand.executableURL
        newProcess.arguments = helperCommand.arguments
        newProcess.environment = helperCommand.environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        newProcess.standardInput = stdinPipe
        newProcess.standardOutput = stdoutPipe
        newProcess.standardError = stderrPipe

        do {
            try newProcess.run()
        } catch {
            throw NLLBTranslatorError.helperStartFailed(error.localizedDescription)
        }

        self.process = newProcess
        self.stdin = stdinPipe.fileHandleForWriting
        self.stdout = stdoutPipe.fileHandleForReading

        // Wait for ready signal
        if let readyData = readLineSync(from: stdoutPipe.fileHandleForReading),
           let ready = try? JSONDecoder().decode(NLLBResponse.self, from: readyData),
           ready.status == "ready" {
            isReady = true
            logger?("NLLBTranslator: Helper ready (\(helperCommand.displayName))")
        } else {
            // Capture error details
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
            
            logger?("NLLBTranslator: Failed to start (\(helperCommand.displayName)). Stderr: \(stderrStr)")
            
            newProcess.terminate()
            throw NLLBTranslatorError.helperStartFailed("Script failed to start. Error: \(stderrStr)")
        }
    }

    func sendRequest(_ requestString: String) throws -> Data {
        guard let stdin = stdin, let stdout = stdout else {
            throw NLLBTranslatorError.modelNotReady
        }

        stdin.write(requestString.data(using: .utf8)!)

        guard let responseData = readLineSync(from: stdout) else {
            throw NLLBTranslatorError.invalidResponse
        }

        return responseData
    }

    func shutdown() {
        shutdownInternal()
    }

    private func shutdownInternal() {
        stdin?.closeFile()
        process?.terminate()
        process = nil
        stdin = nil
        stdout = nil
        isReady = false
    }

    private func readLineSync(from handle: FileHandle) -> Data? {
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
}

/// Represents the command used to launch the NLLB helper process.
private struct HelperCommand: Sendable {
    /// The executable to run.
    let executableURL: URL
    /// Arguments to pass to the executable.
    let arguments: [String]
    /// Environment variables for the helper.
    let environment: [String: String]
    /// Human-readable descriptor for logging.
    let displayName: String
}

/// Translator implementation using NLLB via a helper process (native or Python).
public final class NLLBTranslator: Translator, Sendable {
    private let helperManager: HelperProcessManager
    private let logger: (@Sendable (String) -> Void)?
    private let timeoutSeconds: Double

    public init(
        helperPath: String? = nil,
        timeoutSeconds: Double = 30,
        logger: (@Sendable (String) -> Void)? = nil
    ) {
        let command = Self.resolveHelperCommand(helperPath: helperPath)
        self.helperManager = HelperProcessManager(helperCommand: command, logger: logger)
        self.timeoutSeconds = timeoutSeconds
        self.logger = logger
    }

    public func translate(_ text: String, from: Language, to: Language) async throws -> String? {
        try await helperManager.ensureRunning()

        let request = NLLBRequest(
            text: text,
            source: from.code,
            target: to.code
        )

        guard let requestData = try? JSONEncoder().encode(request),
              let requestString = String(data: requestData, encoding: .utf8) else {
            throw NLLBTranslatorError.invalidResponse
        }

        let finalRequestString = requestString + "\n"

        // Send request with timeout
        let responseData = try await withTimeout(seconds: timeoutSeconds) { [helperManager] in
            try await helperManager.sendRequest(finalRequestString)
        }

        guard let response = try? JSONDecoder().decode(NLLBResponse.self, from: responseData) else {
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

    /// Executes a closure with a timeout.
    private func withTimeout(seconds: Double, operation: @Sendable @escaping () async throws -> Data) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NLLBTranslatorError.timeout
            }

            guard let result = try await group.next() else {
                throw NLLBTranslatorError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    /// Shuts down the helper process.
    public func shutdown() async {
        await helperManager.shutdown()
    }

    /// Resolves the helper command, preferring native CTranslate2 if available.
    private static func resolveHelperCommand(helperPath: String?) -> HelperCommand {
        if let overridePath = helperPath {
            return makeCommand(from: overridePath)
        }

        if let envOverride = ProcessInfo.processInfo.environment["NLLB_HELPER_PATH"] {
            return makeCommand(from: envOverride)
        }

        if let nativeHelperPath = resolveNativeHelperPath() {
            return makeDirectCommand(executablePath: nativeHelperPath)
        }

        let pythonScriptPath = resolvePythonHelperPath()
        return makePythonCommand(scriptPath: pythonScriptPath)
    }

    /// Builds a helper command from a manually supplied path.
    private static func makeCommand(from path: String) -> HelperCommand {
        if path.lowercased().hasSuffix(".py") {
            return makePythonCommand(scriptPath: path)
        }
        return makeDirectCommand(executablePath: path)
    }

    /// Returns the default path to the native helper binary, if present.
    private static func resolveNativeHelperPath() -> String? {
        if let bundlePath = Bundle.main.path(forResource: "translate-ct2", ofType: nil, inDirectory: "nllb-translate-native") {
            return bundlePath
        }
        if let bundlePath = Bundle.main.path(forResource: "translate-ct2", ofType: nil) {
            return bundlePath
        }
        let appSupport = defaultModelRootURL()
        let localURL = appSupport
            .appendingPathComponent("bin")
            .appendingPathComponent("translate-ct2")
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL.path
        }
        return nil
    }

    /// Returns the default path to the Python helper script.
    private static func resolvePythonHelperPath() -> String {
        if let bundlePath = Bundle.main.path(forResource: "translate", ofType: "py", inDirectory: "nllb-translate") {
            return bundlePath
        }
        if let bundlePath = Bundle.main.path(forResource: "translate", ofType: "py") {
            return bundlePath
        }
        // Fallback for development
        return "CaretTranslate/Resources/nllb-translate/translate.py"
    }

    /// Creates a command to run the native helper directly.
    private static func makeDirectCommand(executablePath: String) -> HelperCommand {
        let executableURL = URL(fileURLWithPath: executablePath)
        let environment = makeHelperEnvironment()
        return HelperCommand(
            executableURL: executableURL,
            arguments: [],
            environment: environment,
            displayName: "native helper \(executablePath)"
        )
    }

    /// Creates a command to run the Python helper script.
    private static func makePythonCommand(scriptPath: String) -> HelperCommand {
        let pythonPath = findPythonExecutable()
        let executableURL = URL(fileURLWithPath: pythonPath)
        let environment = makeHelperEnvironment()
        return HelperCommand(
            executableURL: executableURL,
            arguments: [scriptPath],
            environment: environment,
            displayName: "python helper \(scriptPath)"
        )
    }

    /// Builds the helper environment, including the model path.
    private static func makeHelperEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["NLLB_MODEL_PATH"] = defaultModelPath()
        return environment
    }

    /// Returns the default NLLB model path on disk.
    private static func defaultModelPath() -> String {
        let appSupport = defaultModelRootURL()
        return appSupport
            .appendingPathComponent("models")
            .appendingPathComponent("nllb-200-distilled-600M-ct2-int8")
            .path
    }

    /// Returns the base Application Support directory used by CaretTranslate.
    private static func defaultModelRootURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("CaretTranslate")
    }

    /// Finds the best available Python executable.
    public static func findPythonExecutable() -> String {
        let candidates = [
            // Verified working environment (Homebrew Python 3.11)
            "/opt/homebrew/bin/python3.11",
            "/usr/local/bin/python3.11",

            // Standard framework installs (latest first)
            "/Library/Frameworks/Python.framework/Versions/3.14/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.10/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.9/bin/python3",
            // Homebrew Apple Silicon
            "/opt/homebrew/bin/python3",
            // Homebrew Intel / User local
            "/usr/local/bin/python3",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/python3",
            // System fallback
            "/usr/bin/python3"
        ]
        
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return "/usr/bin/python3"
    }
}

// MARK: - Request/Response Types

private struct NLLBRequest: Codable, Sendable {
    let text: String
    let source: String
    let target: String
}

private struct NLLBResponse: Codable, Sendable {
    let translation: String?
    let error: String?
    let status: String?
}
