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
        var scriptPath = Bundle.main.path(
            forResource: "download_model",
            ofType: "py",
            inDirectory: "nllb-translate"
        )
        
        if scriptPath == nil {
            scriptPath = Bundle.main.path(forResource: "download_model", ofType: "py")
        }
        
        let finalPath = scriptPath ?? "CaretTranslate/Resources/nllb-translate/download_model.py"
        let pythonPath = NLLBTranslator.findPythonExecutable()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [finalPath]

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
