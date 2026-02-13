import Foundation
import WhisperKit

@Observable
final class ModelDownloader {
    var isDownloading = false
    var progress: Double = 0
    var error: String?

    private var downloadTask: Task<Void, Never>?

    func download(model: WhisperModel, to folder: URL) async throws {
        isDownloading = true
        progress = 0
        error = nil

        defer {
            isDownloading = false
        }

        do {
            // WhisperKit downloads models from HuggingFace Hub
            // Use WhisperKit's built-in download which handles CoreML model variants
            let modelFolder = try await WhisperKit.download(
                variant: model.modelName,
                from: WhisperModel.modelRepo,
                progressCallback: { prog in
                    Task { @MainActor in
                        self.progress = prog.fractionCompleted
                    }
                }
            )

            // Move downloaded files to our managed directory if needed
            let targetFolder = folder.appendingPathComponent(model.modelName)
            let fm = FileManager.default
            let sourcePath = modelFolder.path
            let targetPath = targetFolder.path

            if sourcePath != targetPath {
                try? fm.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
                let contents = try fm.contentsOfDirectory(atPath: sourcePath)
                for item in contents {
                    let src = modelFolder.appendingPathComponent(item).path
                    let dst = targetFolder.appendingPathComponent(item).path
                    if fm.fileExists(atPath: dst) {
                        try fm.removeItem(atPath: dst)
                    }
                    try fm.copyItem(atPath: src, toPath: dst)
                }
            }

            progress = 1.0
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        progress = 0
    }
}
