import Foundation
import WhisperKit

final class ModelDownloader {
    /// Downloads (via WhisperKit) and ensures the model ends up under `folder/modelName`.
    /// The provided `progressCallback` is called with WhisperKit's download `Progress`.
    func download(
        model: WhisperModel,
        to folder: URL,
        progressCallback: (@Sendable (Progress) -> Void)? = nil
    ) async throws {
        try Task.checkCancellation()

        // WhisperKit downloads models from HuggingFace Hub and handles CoreML variants.
        let modelFolder = try await WhisperKit.download(
            variant: model.modelName,
            from: WhisperModel.modelRepo,
            progressCallback: { prog in
                progressCallback?(prog)
            }
        )

        try Task.checkCancellation()

        // Move/copy downloaded files to our managed directory if needed.
        let targetFolder = folder.appendingPathComponent(model.modelName)
        let fm = FileManager.default
        let sourcePath = modelFolder.path
        let targetPath = targetFolder.path

        if sourcePath != targetPath {
            try? fm.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
            let contents = try fm.contentsOfDirectory(atPath: sourcePath)
            for item in contents {
                try Task.checkCancellation()
                let src = modelFolder.appendingPathComponent(item).path
                let dst = targetFolder.appendingPathComponent(item).path
                if fm.fileExists(atPath: dst) {
                    try fm.removeItem(atPath: dst)
                }
                try fm.copyItem(atPath: src, toPath: dst)
            }
        }
    }
}
