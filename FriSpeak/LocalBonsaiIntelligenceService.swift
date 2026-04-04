//
//  LocalBonsaiIntelligenceService.swift
//  FriSpeak
//

import Foundation
import MLXLLM
import MLXLMCommon

actor LocalBonsaiIntelligenceService {
    static let modelID = "prism-ml/Bonsai-8B-mlx-1bit"
    private static let supportedQuantizationBits: Set<Int> = [1, 2, 3, 4, 5, 6, 8]

    enum TaskKind {
        case cleanup
        case insertionAdaptation
    }

    private var modelContainer: ModelContainer?
    private var loadTask: Task<ModelContainer, Error>?
    private var hasCompletedWarmup = false
    private var warmupTask: Task<Void, Error>?

    func process(
        systemInstructions: String,
        prompt: String,
        taskKind: TaskKind = .cleanup
    ) async throws -> IntelligenceProcessingResult {
        try Self.validateCompatibility()
        let container = try await loadModel()
        let session = ChatSession(
            container,
            instructions: systemInstructions,
            generateParameters: GenerateParameters(
                maxTokens: Self.maxTokens(for: prompt, taskKind: taskKind),
                temperature: 0,
                topP: 1,
                topK: 0
            )
        )

        let response = try await session.respond(to: prompt)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !response.isEmpty else {
            throw IntelligenceError.processingFailed
        }

        return IntelligenceProcessingResult(
            insertedText: response,
            rawModelResponse: response,
            promptSentToModel: """
            System Instructions:
            \(systemInstructions)

            Prompt:
            \(prompt)
            """,
            audioDebugSourceURL: nil,
            transportLog: "Provider: Local MLX Bonsai"
        )
    }

    func prepareModel(progressHandler: ((Double, String) -> Void)? = nil) async throws {
        try Self.validateCompatibility()
        let container = try await loadModel(progressHandler: progressHandler)
        try await ensureWarmedUp(using: container, progressHandler: progressHandler)
    }

    func preloadCachedModel() async throws -> Bool {
        try Self.validateCompatibility()
        guard Self.isModelCached() else {
            return false
        }

        let container = try await loadModel()
        try await ensureWarmedUp(using: container)
        return true
    }

    private func loadModel(
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws -> ModelContainer {
        try Self.validateCompatibility()

        if let modelContainer {
            progressHandler?(1.0, "Ready")
            return modelContainer
        }

        if let loadTask {
            return try await loadTask.value
        }

        let task = Task<ModelContainer, Error> {
            try await loadModelContainer(
                id: Self.modelID,
                revision: "main"
            ) { progress in
                progressHandler?(
                    progress.fractionCompleted,
                    self.downloadStatus(from: progress)
                )
            }
        }
        loadTask = task

        do {
            let container = try await task.value
            modelContainer = container
            loadTask = nil
            return container
        } catch {
            loadTask = nil
            throw error
        }
    }

    nonisolated static func compatibilityIssue() -> String? {
        if let bits = cachedQuantizationBits() {
            guard supportedQuantizationBits.contains(bits) else {
                return unsupportedBitsMessage(bits: bits)
            }
            return nil
        }

        if let bits = quantizationBitsFromModelIdentifier() {
            guard supportedQuantizationBits.contains(bits) else {
                return unsupportedBitsMessage(bits: bits)
            }
        }

        return nil
    }

    nonisolated static func isModelCached() -> Bool {
        let snapshotRoot = huggingFaceCacheRoot()
            .appendingPathComponent("models--prism-ml--Bonsai-8B-mlx-1bit", isDirectory: true)
            .appendingPathComponent("snapshots", isDirectory: true)

        guard let enumerator = FileManager.default.enumerator(
            at: snapshotRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return false
        }

        let requiredFiles = Set(["config.json", "tokenizer.json", "tokenizer_config.json"])
        for case let url as URL in enumerator {
            if containsRequiredArtifacts(at: url, requiredFiles: requiredFiles) {
                return true
            }
        }

        return false
    }

    nonisolated private static func containsRequiredArtifacts(
        at directory: URL,
        requiredFiles: Set<String>
    ) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let contentSet = Set(contents)
        guard requiredFiles.isSubset(of: contentSet) else {
            return false
        }

        return contents.contains(where: { $0.hasPrefix("model") && $0.hasSuffix(".safetensors") })
            || contentSet.contains("model.safetensors.index.json")
    }

    nonisolated private static func huggingFaceCacheRoot() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("huggingface", isDirectory: true)
            .appendingPathComponent("hub", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Caches/huggingface/hub", isDirectory: true)
    }

    nonisolated private static func validateCompatibility() throws {
        if let compatibilityIssue = compatibilityIssue() {
            throw IntelligenceError.localModelUnavailable(compatibilityIssue)
        }
    }

    nonisolated private static func cachedQuantizationBits() -> Int? {
        guard let configURL = cachedConfigURL(),
              let data = try? Data(contentsOf: configURL),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let quantization = jsonObject["quantization"] as? [String: Any],
           let bits = quantization["bits"] as? Int {
            return bits
        }

        return nil
    }

    nonisolated private static func cachedConfigURL() -> URL? {
        let snapshotRoot = huggingFaceCacheRoot()
            .appendingPathComponent("models--prism-ml--Bonsai-8B-mlx-1bit", isDirectory: true)
            .appendingPathComponent("snapshots", isDirectory: true)

        let snapshotDirectories = (try? FileManager.default.contentsOfDirectory(
            at: snapshotRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let sortedDirectories = snapshotDirectories.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        for directory in sortedDirectories {
            let configURL = directory.appendingPathComponent("config.json")
            if FileManager.default.fileExists(atPath: configURL.path) {
                return configURL
            }
        }

        return nil
    }

    nonisolated private static func quantizationBitsFromModelIdentifier() -> Int? {
        let identifier = modelID.lowercased()
        guard let range = identifier.range(of: #"(\d+)bit"#, options: .regularExpression) else {
            return nil
        }

        let digits = identifier[range].replacingOccurrences(of: "bit", with: "")
        return Int(digits)
    }

    nonisolated private static func unsupportedBitsMessage(bits: Int) -> String {
        "This local Bonsai model uses \(bits)-bit weights, but the bundled MLX runtime does not support that quantization. FriSpeak expects the Prism MLX fork for 1-bit Bonsai support."
    }

    nonisolated private func downloadStatus(from progress: Progress) -> String {
        if let description = progress.localizedAdditionalDescription, !description.isEmpty {
            return description
        }

        if progress.totalUnitCount > 0 {
            return "Downloading model..."
        }

        return "Preparing model..."
    }

    private func ensureWarmedUp(
        using container: ModelContainer,
        progressHandler: ((Double, String) -> Void)? = nil
    ) async throws {
        if hasCompletedWarmup {
            progressHandler?(1.0, "Ready")
            return
        }

        if let warmupTask {
            try await warmupTask.value
            progressHandler?(1.0, "Ready")
            return
        }

        progressHandler?(1.0, "Loading model into memory...")
        let task = Task<Void, Error> {
            let session = ChatSession(
                container,
                instructions: "Reply with only OK.",
                generateParameters: GenerateParameters(
                    maxTokens: 4,
                    temperature: 0,
                    topP: 1,
                    topK: 0
                )
            )
            _ = try await session.respond(to: "OK")
        }
        warmupTask = task

        do {
            try await task.value
            hasCompletedWarmup = true
            warmupTask = nil
            progressHandler?(1.0, "Ready")
        } catch {
            warmupTask = nil
            throw error
        }
    }

    nonisolated static func maxTokens(for prompt: String, taskKind: TaskKind) -> Int {
        let wordCount = prompt.split(whereSeparator: \.isWhitespace).count

        switch taskKind {
        case .cleanup:
            let estimated = 24 + (wordCount * 2)
            return min(max(estimated, 64), 192)
        case .insertionAdaptation:
            let estimated = 12 + wordCount
            return min(max(estimated, 32), 96)
        }
    }
}
