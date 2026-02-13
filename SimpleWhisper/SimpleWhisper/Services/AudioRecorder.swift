import AVFoundation
import Foundation

@Observable
final class AudioRecorder {
    /// Reuse a single engine to avoid -10877 (kAudioUnitErr_NoConnection) errors
    /// that occur when rapidly creating and destroying AVAudioEngine instances.
    private let audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let targetSampleRate: Double = 16000

    var isRecording: Bool = false

    enum MicrophonePermissionStatus: String {
        case undetermined
        case denied
        case granted
    }

    static func microphonePermissionStatus() -> MicrophonePermissionStatus {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            case .undetermined: return .undetermined
            @unknown default: return .undetermined
            }
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: return .granted
            case .denied, .restricted: return .denied
            case .notDetermined: return .undetermined
            @unknown default: return .undetermined
            }
        }
    }

    static func requestMicrophonePermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
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
        // If a previous recording is still active, stop it first.
        if isRecording {
            _ = stopRecording()
        }

        // Preflight permission to avoid AVAudioEngine triggering a permission prompt
        // at unexpected times (e.g. when started from a global hotkey).
        guard Self.microphonePermissionStatus() == .granted else {
            throw RecordingError.noMicrophonePermission
        }

        bufferLock.lock()
        audioBuffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()

        let engine = audioEngine
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
                let ptr = UnsafeBufferPointer(start: channelData[0], count: Int(outputBuffer.frameLength))
                // Avoid per-buffer Array allocations; append directly under a lock for thread safety.
                self.bufferLock.lock()
                self.audioBuffer.append(contentsOf: ptr)
                self.bufferLock.unlock()
            }
        }

        engine.prepare()
        try engine.start()

        isRecording = true
    }

    func stopRecording() -> [Float] {
        let engine = audioEngine
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false

        bufferLock.lock()
        let samples = audioBuffer
        audioBuffer.removeAll(keepingCapacity: true)
        bufferLock.unlock()
        return samples
    }

    enum RecordingError: LocalizedError {
        case noMicrophonePermission
        case noMicrophone
        case formatError

        var errorDescription: String? {
            switch self {
            case .noMicrophonePermission: return "Microphone permission required"
            case .noMicrophone: return "No microphone available"
            case .formatError: return "Audio format error"
            }
        }
    }
}
