//
//  LocalQwenTranscriber.swift
//  FriSpeak
//

@preconcurrency import AVFoundation
import Darwin
import Foundation
import OmnilingualASR
import ParakeetASR

actor LocalQwenTranscriber {
    private static let targetSampleRate = 16_000

    private var coreMLModel: OmnilingualASRModel?
    private var coreMLLoadTask: Task<OmnilingualASRModel, Error>?
    private var mlxModel: OmnilingualASRMLXModel?
    private var mlxLoadTask: Task<OmnilingualASRMLXModel, Error>?
    private var parakeetModel: ParakeetASRModel?
    private var parakeetLoadTask: Task<ParakeetASRModel, Error>?

    func transcribeFile(
        at url: URL,
        backend: LocalSpeechBackend,
        prompt: String = ""
    ) async throws -> String {
        let audio = try await Self.loadAudioSamples(from: url)
        let transcript: String
        switch backend {
        case .coreML300M:
            let model = try await loadCoreMLModel()
            transcript = await Task.detached(priority: .userInitiated) {
                model.transcribe(audio: audio, sampleRate: 16_000, language: nil)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }.value
        case .mlx1B4bit:
            let model = try await loadMLXModel()
            transcript = try await Task.detached(priority: .userInitiated) {
                try model.transcribeAudio(audio, sampleRate: 16_000, language: nil)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }.value
        case .parakeetTDT:
            let model = try await loadParakeetModel()
            transcript = try await Task.detached(priority: .userInitiated) {
                try model.transcribeAudio(audio, sampleRate: 16_000, language: "en")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }.value
        }

        guard !transcript.isEmpty else {
            throw TranscriptionError.noResult
        }

        return transcript
    }

    func prepareModel(
        backend: LocalSpeechBackend,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws {
        switch backend {
        case .coreML300M:
            _ = try await loadCoreMLModel(progressHandler: progressHandler)
        case .mlx1B4bit:
            _ = try await loadMLXModel(progressHandler: progressHandler)
        case .parakeetTDT:
            _ = try await loadParakeetModel(progressHandler: progressHandler)
        }
    }

    func preloadCachedModel(backend: LocalSpeechBackend) async throws -> Bool {
        guard Self.isModelCached(backend: backend) else {
            return false
        }

        try await prepareModel(backend: backend)
        return true
    }

    private func loadCoreMLModel(progressHandler: ((Double, String) -> Void)? = nil) async throws -> OmnilingualASRModel {
        if let coreMLModel {
            progressHandler?(1.0, "Ready")
            return coreMLModel
        }

        if let coreMLLoadTask {
            return try await coreMLLoadTask.value
        }

        let task = Task<OmnilingualASRModel, Error> {
            setenv("SPEECH_COREML_COMPUTE_UNITS", "ane", 1)
            return try await OmnilingualASRModel.fromPretrained(
                modelId: LocalSpeechBackend.coreML300M.modelID,
                progressHandler: progressHandler
            )
        }
        coreMLLoadTask = task

        do {
            let loadedModel = try await task.value
            coreMLModel = loadedModel
            coreMLLoadTask = nil
            return loadedModel
        } catch {
            coreMLLoadTask = nil
            throw error
        }
    }

    private func loadMLXModel(progressHandler: ((Double, String) -> Void)? = nil) async throws -> OmnilingualASRMLXModel {
        if let mlxModel {
            progressHandler?(1.0, "Ready")
            return mlxModel
        }

        if let mlxLoadTask {
            return try await mlxLoadTask.value
        }

        let task = Task<OmnilingualASRMLXModel, Error> {
            try await OmnilingualASRMLXModel.fromPretrained(
                variant: .b1,
                bits: 4,
                modelId: LocalSpeechBackend.mlx1B4bit.modelID,
                progressHandler: progressHandler
            )
        }
        mlxLoadTask = task

        do {
            let loadedModel = try await task.value
            mlxModel = loadedModel
            mlxLoadTask = nil
            return loadedModel
        } catch {
            mlxLoadTask = nil
            throw error
        }
    }

    private func loadParakeetModel(progressHandler: ((Double, String) -> Void)? = nil) async throws -> ParakeetASRModel {
        if let parakeetModel {
            progressHandler?(1.0, "Ready")
            return parakeetModel
        }

        if let parakeetLoadTask {
            return try await parakeetLoadTask.value
        }

        let task = Task<ParakeetASRModel, Error> {
            setenv("SPEECH_COREML_COMPUTE_UNITS", "ane", 1)
            return try await ParakeetASRModel.fromPretrained(
                modelId: LocalSpeechBackend.parakeetTDT.modelID,
                progressHandler: progressHandler
            )
        }
        parakeetLoadTask = task

        do {
            let loadedModel = try await task.value
            parakeetModel = loadedModel
            parakeetLoadTask = nil
            return loadedModel
        } catch {
            parakeetLoadTask = nil
            throw error
        }
    }

    nonisolated static func isModelCached(backend: LocalSpeechBackend = .coreML300M) -> Bool {
        let fileManager = FileManager.default
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches", isDirectory: true)

        let legacyDirectory = cacheRoot
            .appendingPathComponent("qwen3-speech", isDirectory: true)
            .appendingPathComponent("aufklarer_\(backend.cacheRepositoryName)", isDirectory: true)
        let hubDirectory = cacheRoot
            .appendingPathComponent("qwen3-speech", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("aufklarer", isDirectory: true)
            .appendingPathComponent(backend.cacheRepositoryName, isDirectory: true)

        return containsModelArtifacts(in: legacyDirectory, requiredFiles: backend.requiredCacheFiles)
            || containsModelArtifacts(in: hubDirectory, requiredFiles: backend.requiredCacheFiles)
    }

    nonisolated private static func containsModelArtifacts(in directory: URL, requiredFiles: [String]) -> Bool {
        let fileManager = FileManager.default
        return requiredFiles.allSatisfy { fileManager.fileExists(atPath: directory.appendingPathComponent($0).path) }
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
            return "Failed to prepare audio for the local speech model."
        case .audioDecodingFailed:
            return "Failed to decode the recorded audio for the local speech model."
        }
    }
}
