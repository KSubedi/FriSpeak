//
//  SpeechTranscriber.swift
//  FriSpeak
//

import Foundation
import Speech

actor SpeechTranscriber {
    private let transcriptionTimeoutNanoseconds: UInt64 = 30 * 1_000_000_000
    private var activeTask: SFSpeechRecognitionTask?

    func transcribeFile(at url: URL) async throws -> String {
        // Validate file exists and has content
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs?[.size] as? UInt64 ?? 0
        
        // Small recordings (silence or just header) often cause hallucinations
        guard fileSize > 4096 else {
            throw TranscriptionError.tooShort
        }

        let recognizer = SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            var hasFinished = false
            
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: transcriptionTimeoutNanoseconds)
                if !hasFinished {
                    hasFinished = true
                    activeTask?.cancel()
                    self.clearActiveTask()
                    continuation.resume(throwing: TranscriptionError.timeout)
                }
            }

            activeTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if hasFinished { return }

                if let error = error {
                    hasFinished = true
                    timeoutTask.cancel()
                    Task { await self?.clearActiveTask() }
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    hasFinished = true
                    timeoutTask.cancel()
                    Task { await self?.clearActiveTask() }
                    let transcript = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Hallucination check for the specific weird phrase
                    if transcript.lowercased().contains("not a man") && transcript.count < 20 {
                        continuation.resume(throwing: TranscriptionError.noResult)
                    } else {
                        continuation.resume(returning: transcript)
                    }
                }
            }
        }
    }

    private func clearActiveTask() {
        activeTask?.cancel()
        activeTask = nil
    }
}

enum TranscriptionError: LocalizedError {
    case recognizerUnavailable
    case noResult
    case timeout
    case tooShort

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition is not available right now."
        case .noResult:
            return "No clear speech detected."
        case .timeout:
            return "Transcription timed out."
        case .tooShort:
            return "Recording was too short to transcribe."
        }
    }
}
