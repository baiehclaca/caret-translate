import SwiftUI

struct ModelManagerView: View {
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadError: String?
    @State private var modelInstalled = false
    @State private var statusMessage: String?

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
                    ProgressView()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusMessage ?? "Downloading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("This may take 5-10 minutes for first-time setup")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
        statusMessage = "Preparing download..."

        Task {
            do {
                try await runDownloadScript()
                await MainActor.run {
                    isDownloading = false
                    statusMessage = nil
                    checkModelStatus()
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    statusMessage = nil
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func runDownloadScript() async throws {
        // Try multiple possible locations for the script
        var scriptPath: String?

        // Try in nllb-translate subdirectory
        scriptPath = Bundle.main.path(
            forResource: "download_model",
            ofType: "py",
            inDirectory: "nllb-translate"
        )

        // Try in Resources root
        if scriptPath == nil {
            scriptPath = Bundle.main.path(
                forResource: "download_model",
                ofType: "py",
                inDirectory: "Resources/nllb-translate"
            )
        }

        // Try direct resource lookup
        if scriptPath == nil {
            scriptPath = Bundle.main.path(forResource: "download_model", ofType: "py")
        }

        // Try in the app bundle's Resources folder directly
        if scriptPath == nil {
            let resourcePath = Bundle.main.resourcePath
            if let resourcePath = resourcePath {
                let possiblePath = (resourcePath as NSString)
                    .appendingPathComponent("nllb-translate")
                    .appending("/download_model.py")
                if FileManager.default.fileExists(atPath: possiblePath) {
                    scriptPath = possiblePath
                }
            }
        }

        // If script not found in bundle, create it from embedded content
        let finalPath: String
        if let path = scriptPath {
            finalPath = path
        } else {
            // Fallback: write script to temp directory
            finalPath = try createDownloadScriptInTempDir()
        }

        let pythonPath = NLLBTranslator.findPythonExecutable()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["-u", finalPath]  // -u for unbuffered output

        // Capture output for progress and error messages
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Monitor output for status updates
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                // Note: Can't capture self weakly since View is a struct
                print("Download progress: \(output)")
            }
        }

        try process.run()
        process.waitUntilExit()

        // Clean up handler
        outputPipe.fileHandleForReading.readabilityHandler = nil

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            let standardOutput = String(data: outputData, encoding: .utf8) ?? ""

            // Combine both outputs for better error reporting
            let fullOutput = standardOutput + "\n" + errorOutput

            var errorMessage = "Download failed. "

            if fullOutput.contains("Failed to install") || fullOutput.contains("ERROR: Failed to install") {
                errorMessage += "Package installation failed. Please open Terminal and run: pip3 install ctranslate2 transformers sentencepiece torch"
            } else if fullOutput.contains("ModuleNotFoundError") || fullOutput.contains("No module named") {
                errorMessage += "Python packages missing. Please run in Terminal: pip3 install ctranslate2 transformers sentencepiece torch"
            } else if fullOutput.contains("command not found") || pythonPath.isEmpty {
                errorMessage += "Python 3 not found. Please install Python 3 from python.org"
            } else {
                // Show more of the actual error (last 500 chars to see the real issue)
                let relevantError = fullOutput.suffix(500)
                errorMessage += String(relevantError)
            }

            // Also log to console for debugging
            print("Download failed with status \(process.terminationStatus)")
            print("Full output:", fullOutput)

            throw NSError(
                domain: "ModelDownload",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorMessage]
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

    private func createDownloadScriptInTempDir() throws -> String {
        let scriptContent = """
        #!/usr/bin/env python3
        import os, sys, subprocess
        from pathlib import Path

        def install_packages():
            print("Installing required packages...")
            packages = ["ctranslate2", "transformers", "sentencepiece", "torch"]
            for package in packages:
                print(f"Installing {package}...")
                result = subprocess.run([sys.executable, "-m", "pip", "install", "--user", package], capture_output=True, text=True)
                if result.returncode != 0:
                    print(f"Error: {result.stderr}")
                    raise Exception(f"Failed to install {package}")

        def check_packages():
            try:
                import ctranslate2, transformers, sentencepiece, torch
                return True
            except ImportError:
                return False

        if not check_packages():
            install_packages()
            if not check_packages():
                sys.exit(1)

        import ctranslate2
        output_dir = Path.home() / "Library" / "Application Support" / "CaretTranslate" / "models" / "nllb-200-distilled-600M-ct2-int8"

        if output_dir.exists():
            print("Model already exists")
            sys.exit(0)

        print("Downloading NLLB model...")
        output_dir.parent.mkdir(parents=True, exist_ok=True)
        converter = ctranslate2.converters.TransformersConverter("facebook/nllb-200-distilled-600M")
        converter.convert(str(output_dir), quantization="int8", force=True)
        print("Done!")
        """

        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("download_model_\(UUID().uuidString).py")

        try scriptContent.write(to: scriptPath, atomically: true, encoding: .utf8)

        return scriptPath.path
    }
}
