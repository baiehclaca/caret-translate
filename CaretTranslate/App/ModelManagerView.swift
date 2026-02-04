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
        var scriptPath = Bundle.main.path(
            forResource: "download_model",
            ofType: "py",
            inDirectory: "nllb-translate"
        )

        if scriptPath == nil {
            scriptPath = Bundle.main.path(forResource: "download_model", ofType: "py")
        }

        guard let finalPath = scriptPath else {
            throw NSError(
                domain: "ModelDownload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Download script not found in app bundle"]
            )
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
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            var errorMessage = "Download failed. "

            if errorOutput.contains("Failed to install") {
                errorMessage += "Could not install required packages. The app will automatically install them, but it needs internet access and may take several minutes."
            } else if errorOutput.contains("command not found") || pythonPath.isEmpty {
                errorMessage += "Python 3 not found. Please install Python 3 from python.org"
            } else {
                errorMessage += errorOutput.prefix(200).description
            }

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
}
