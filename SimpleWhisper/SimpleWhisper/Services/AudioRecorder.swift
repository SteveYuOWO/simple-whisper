import AVFoundation
import Foundation

@Observable
final class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let targetSampleRate: Double = 16000

    var isRecording: Bool = false

    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func availableMicrophones() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    func startRecording() throws {
        guard !isRecording else { return }

        audioBuffer.removeAll()
        let engine = AVAudioEngine()

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0 else {
            throw RecordingError.noMicrophone
        }

        // Create the target format: 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw RecordingError.formatError
        }

        // Create converter from hardware format to target format
        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw RecordingError.formatError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Calculate output frame count for the converter
            let ratio = self.targetSampleRate / hardwareFormat.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
                return
            }

            // AVAudioPCMBuffer starts with frameLength == 0; set it so the converter has space to write into.
            outputBuffer.frameLength = outputBuffer.frameCapacity

            var error: NSError?
            // Provide the tap buffer exactly once for this conversion call.
            var didProvideInput = false
            _ = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                if didProvideInput {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                didProvideInput = true
                outStatus.pointee = .haveData
                return buffer
            }

            if let error {
                // Avoid spamming logs for every buffer; this should be rare.
                print("[AudioRecorder] Converter error: \(error)")
            }

            if outputBuffer.frameLength > 0, let channelData = outputBuffer.floatChannelData {
                let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength)))
                self.audioBuffer.append(contentsOf: samples)
            }
        }

        engine.prepare()
        try engine.start()

        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> [Float] {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false

        let samples = audioBuffer
        audioBuffer.removeAll()
        return samples
    }

    enum RecordingError: LocalizedError {
        case noMicrophone
        case formatError

        var errorDescription: String? {
            switch self {
            case .noMicrophone: return "No microphone available"
            case .formatError: return "Audio format error"
            }
        }
    }
}
