//
//  LocalQwenTranscriber.swift
//  FriSpeak
//

@preconcurrency import AVFoundation
import Foundation
import Qwen3ASR

actor LocalQwenTranscriber {
    static let modelID = "aufklarer/Qwen3-ASR-1.7B-MLX-8bit"
    private static let targetSampleRate = 16_000

    private var model: Qwen3ASRModel?
    private var loadTask: Task<Qwen3ASRModel, Error>?

    func transcribeFile(at url: URL, prompt: String = "") async throws -> String {
        let audio = try await Self.loadAudioSamples(from: url)
        let model = try await loadModel()
        let promptContext = Self.normalizedPromptContext(from: prompt)
        let transcript = await Task.detached(priority: .userInitiated) {
            model.transcribe(
                audio: audio,
                sampleRate: 16_000,
                language: nil,
                context: promptContext
            )
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.value

        guard !transcript.isEmpty else {
            throw TranscriptionError.noResult
        }

        return transcript
    }

    func prepareModel(progressHandler: ((Double, String) -> Void)? = nil) async throws {
        _ = try await loadModel(progressHandler: progressHandler)
    }

    func preloadCachedModel() async throws -> Bool {
        guard Self.isModelCached() else {
            return false
        }

        _ = try await loadModel()
        return true
    }

    private func loadModel(progressHandler: ((Double, String) -> Void)? = nil) async throws -> Qwen3ASRModel {
        if let model {
            progressHandler?(1.0, "Ready")
            return model
        }

        if let loadTask {
            return try await loadTask.value
        }

        let task = Task<Qwen3ASRModel, Error> {
            try await Qwen3ASRModel.fromPretrained(
                modelId: Self.modelID,
                progressHandler: progressHandler
            )
        }
        loadTask = task

        do {
            let loadedModel = try await task.value
            model = loadedModel
            loadTask = nil
            return loadedModel
        } catch {
            loadTask = nil
            throw error
        }
    }

    nonisolated static func isModelCached() -> Bool {
        let fileManager = FileManager.default
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches", isDirectory: true)

        let legacyDirectory = cacheRoot
            .appendingPathComponent("qwen3-speech", isDirectory: true)
            .appendingPathComponent("aufklarer_Qwen3-ASR-1.7B-MLX-8bit", isDirectory: true)
        let hubDirectory = cacheRoot
            .appendingPathComponent("qwen3-speech", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("aufklarer", isDirectory: true)
            .appendingPathComponent("Qwen3-ASR-1.7B-MLX-8bit", isDirectory: true)

        return containsModelArtifacts(in: legacyDirectory) || containsModelArtifacts(in: hubDirectory)
    }

    nonisolated private static func containsModelArtifacts(in directory: URL) -> Bool {
        let fileManager = FileManager.default
        let requiredFiles = ["vocab.json", "tokenizer_config.json"]
        return requiredFiles.allSatisfy { fileManager.fileExists(atPath: directory.appendingPathComponent($0).path) }
    }

    nonisolated private static func normalizedPromptContext(from prompt: String) -> String? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return """
        You are transcribing dictated speech into clean text.

        Follow these extra instructions while transcribing:
        \(trimmed)

        Return only the transcription.
        """
    }

    nonisolated private static func loadAudioSamples(from url: URL) async throws -> [Float] {
        try await Task.detached(priority: .userInitiated) {
            do {
                return try loadWithAVAudioFile(from: url)
            } catch {
                guard url.pathExtension.lowercased() == "wav" else {
                    throw error
                }

                let wavAudio = try loadWAVSamples(from: url)
                let normalized = wavAudio.sampleRate == targetSampleRate
                    ? wavAudio.samples
                    : resample(wavAudio.samples, from: wavAudio.sampleRate, to: targetSampleRate)
                guard !normalized.isEmpty else {
                    throw TranscriptionError.noResult
                }
                return normalized
            }
        }.value
    }

    nonisolated private static func loadWithAVAudioFile(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw LocalQwenTranscriberError.audioConversionFailed
        }
        try file.read(into: buffer)

        let samples: [Float]
        switch format.commonFormat {
        case .pcmFormatFloat32:
            guard let floatData = buffer.floatChannelData else {
                throw LocalQwenTranscriberError.audioConversionFailed
            }
            samples = Array(UnsafeBufferPointer(start: floatData[0], count: Int(buffer.frameLength)))
        case .pcmFormatInt16:
            guard let int16Data = buffer.int16ChannelData else {
                throw LocalQwenTranscriberError.audioConversionFailed
            }
            let raw = UnsafeBufferPointer(start: int16Data[0], count: Int(buffer.frameLength))
            samples = raw.map { Float($0) / 32768.0 }
        case .pcmFormatInt32:
            guard let int32Data = buffer.int32ChannelData else {
                throw LocalQwenTranscriberError.audioConversionFailed
            }
            let raw = UnsafeBufferPointer(start: int32Data[0], count: Int(buffer.frameLength))
            samples = raw.map { Float($0) / Float(Int32.max) }
        default:
            throw LocalQwenTranscriberError.audioConversionFailed
        }

        guard !samples.isEmpty else {
            throw TranscriptionError.noResult
        }

        let inputSampleRate = Int(format.sampleRate)
        return inputSampleRate == targetSampleRate
            ? samples
            : resample(samples, from: inputSampleRate, to: targetSampleRate)
    }

    nonisolated private static func loadWAVSamples(from url: URL) throws -> (samples: [Float], sampleRate: Int) {
        let data = try Data(contentsOf: url)

        guard data.count > 44 else {
            throw LocalQwenTranscriberError.audioDecodingFailed
        }
        guard String(data: data[0..<4], encoding: .ascii) == "RIFF" else {
            throw LocalQwenTranscriberError.audioDecodingFailed
        }
        guard String(data: data[8..<12], encoding: .ascii) == "WAVE" else {
            throw LocalQwenTranscriberError.audioDecodingFailed
        }

        let audioFormat = data[20..<22].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
        let numChannels = data[22..<24].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
        let sampleRate = Int(data[24..<28].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
        let bitsPerSample = data[34..<36].withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }

        guard audioFormat == 1, numChannels > 0, bitsPerSample == 16 else {
            throw LocalQwenTranscriberError.audioDecodingFailed
        }

        var dataOffset = 36
        var dataChunkSize: UInt32?
        while dataOffset < data.count - 8 {
            let chunkID = String(data: data[dataOffset..<(dataOffset + 4)], encoding: .ascii)
            let chunkSize = data[(dataOffset + 4)..<(dataOffset + 8)].withUnsafeBytes {
                $0.loadUnaligned(as: UInt32.self)
            }

            if chunkID == "data" {
                dataOffset += 8
                dataChunkSize = chunkSize
                break
            }

            let nextOffset = dataOffset + 8 + Int(chunkSize)
            guard nextOffset >= dataOffset, nextOffset <= data.count else {
                throw LocalQwenTranscriberError.audioDecodingFailed
            }
            dataOffset = nextOffset
        }

        guard let chunkSize = dataChunkSize else {
            throw LocalQwenTranscriberError.audioDecodingFailed
        }

        let chunkSizeInt = Int(chunkSize)
        guard dataOffset + chunkSizeInt <= data.count else {
            throw LocalQwenTranscriberError.audioDecodingFailed
        }

        let sampleData = data[dataOffset..<(dataOffset + chunkSizeInt)]
        let channels = Int(numChannels)
        let sampleCount = sampleData.count / (2 * channels)
        var samples = [Float](repeating: 0, count: sampleCount)

        sampleData.withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for index in 0..<sampleCount {
                let sampleIndex = index * channels
                if sampleIndex < int16Ptr.count {
                    samples[index] = Float(int16Ptr[sampleIndex]) / 32768.0
                }
            }
        }

        return (samples, sampleRate)
    }

    nonisolated private static func resample(_ samples: [Float], from inputRate: Int, to outputRate: Int) -> [Float] {
        guard inputRate != outputRate, !samples.isEmpty else { return samples }

        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(inputRate),
            channels: 1,
            interleaved: false
        )!
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(outputRate),
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return samples
        }

        let sourceBuffer = AVAudioPCMBuffer(
            pcmFormat: sourceFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        )!
        sourceBuffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            sourceBuffer.floatChannelData?[0].update(from: source.baseAddress!, count: samples.count)
        }

        let ratio = Double(outputRate) / Double(inputRate)
        let outputFrameCount = AVAudioFrameCount(Double(samples.count) * ratio)
        let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount)!

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: targetBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }

            inputConsumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        guard error == nil, targetBuffer.frameLength > 0 else {
            return samples
        }

        return Array(
            UnsafeBufferPointer(
                start: targetBuffer.floatChannelData![0],
                count: Int(targetBuffer.frameLength)
            )
        )
    }
}

enum LocalQwenTranscriberError: LocalizedError {
    case audioConversionFailed
    case audioDecodingFailed

    var errorDescription: String? {
        switch self {
        case .audioConversionFailed:
            return "Failed to prepare audio for the local Qwen model."
        case .audioDecodingFailed:
            return "Failed to decode the recorded audio for the local Qwen model."
        }
    }
}
