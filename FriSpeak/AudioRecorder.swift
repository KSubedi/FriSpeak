//
//  AudioRecorder.swift
//  FriSpeak
//

import AVFoundation

actor AudioRecorder {
    private let shortUtterancePaddingNanoseconds: UInt64 = 180_000_000
    private let mediumUtterancePaddingNanoseconds: UInt64 = 120_000_000
    private let longUtterancePaddingNanoseconds: UInt64 = 60_000_000
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var isRecording = false

    func start() async throws {
        guard !isRecording else { return }

        recorder?.stop()
        recorder = nil

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording-\(UUID().uuidString).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = false
        recorder.prepareToRecord()

        guard recorder.record() else {
            throw RecorderError.recordingFailed
        }

        self.recorder = recorder
        self.outputURL = url
        isRecording = true
    }

    func stop() async throws -> URL {
        guard isRecording, let recorder, let url = outputURL else {
            throw RecorderError.noActiveRecording
        }

        let recordingDuration = recorder.currentTime
        try? await Task.sleep(nanoseconds: adaptiveStopPadding(for: recordingDuration))
        isRecording = false

        recorder.stop()
        self.recorder = nil
        self.outputURL = nil

        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attrs?[.size] as? UInt64 ?? 0
        guard size > 44 else {
            throw RecorderError.recordingFailed
        }

        return url
    }

    private func adaptiveStopPadding(for duration: TimeInterval) -> UInt64 {
        switch duration {
        case ..<0.35:
            return shortUtterancePaddingNanoseconds
        case ..<1.0:
            return mediumUtterancePaddingNanoseconds
        default:
            return longUtterancePaddingNanoseconds
        }
    }

    func cancel() {
        guard isRecording || outputURL != nil || recorder != nil else {
            return
        }

        isRecording = false
        recorder?.stop()
        recorder = nil

        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }

        self.outputURL = nil
    }
}

enum RecorderError: LocalizedError {
    case noActiveRecording
    case recordingFailed
    case hardwareError

    var errorDescription: String? {
        switch self {
        case .noActiveRecording:
            return "No active recording."
        case .recordingFailed:
            return "Recording failed to save."
        case .hardwareError:
            return "Microphone is unavailable."
        }
    }
}
