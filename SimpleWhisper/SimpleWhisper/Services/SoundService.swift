import AppKit
import Foundation

/// Generates and plays short tonal sound effects for recording feedback.
/// Sounds are synthesized in-memory as WAV data — no audio files needed.
final class SoundService {
    static let shared = SoundService()

    private var startSound: NSSound?
    private var stopSound: NSSound?

    private init() {
        // Start recording: bright, crisp rising tone
        startSound = Self.makeTone(frequency: 880, duration: 0.07, volume: 0.25)

        // Stop recording: softer, lower confirmation tone
        stopSound = Self.makeTone(frequency: 660, duration: 0.09, volume: 0.2)
    }

    func playStart() {
        startSound?.stop()
        startSound?.currentTime = 0
        startSound?.play()
    }

    func playStop() {
        stopSound?.stop()
        stopSound?.currentTime = 0
        stopSound?.play()
    }

    // MARK: - WAV Synthesis

    /// Generate a short sine-wave tone as an in-memory WAV.
    private static func makeTone(frequency: Double, duration: Double, volume: Double) -> NSSound? {
        let sampleRate: Double = 44100
        let numSamples = Int(sampleRate * duration)
        let bytesPerSample = 2 // 16-bit
        let dataSize = numSamples * bytesPerSample

        // --- PCM samples with fade-out envelope ---
        var pcm = Data(capacity: dataSize)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            // Smooth fade-out so it doesn't click at the end
            let env = 1.0 - pow(Double(i) / Double(numSamples), 2)
            let sample = sin(2.0 * .pi * frequency * t) * volume * env
            var s16 = Int16(clamping: Int(sample * Double(Int16.max)))
            pcm.append(Data(bytes: &s16, count: 2))
        }

        // --- WAV header (44 bytes) ---
        var wav = Data(capacity: 44 + dataSize)
        wav.append(contentsOf: [UInt8]("RIFF".utf8))
        wav.appendLE(UInt32(36 + dataSize))
        wav.append(contentsOf: [UInt8]("WAVE".utf8))
        wav.append(contentsOf: [UInt8]("fmt ".utf8))
        wav.appendLE(UInt32(16))       // fmt chunk size
        wav.appendLE(UInt16(1))        // PCM
        wav.appendLE(UInt16(1))        // mono
        wav.appendLE(UInt32(44100))    // sample rate
        wav.appendLE(UInt32(44100 * 2)) // byte rate
        wav.appendLE(UInt16(2))        // block align
        wav.appendLE(UInt16(16))       // bits per sample
        wav.append(contentsOf: [UInt8]("data".utf8))
        wav.appendLE(UInt32(dataSize))
        wav.append(pcm)

        return NSSound(data: wav)
    }
}

// MARK: - Little-endian helpers

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
