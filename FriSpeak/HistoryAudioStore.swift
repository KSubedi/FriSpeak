//
//  HistoryAudioStore.swift
//  FriSpeak
//

import Foundation

final class HistoryAudioStore {
    static let shared = HistoryAudioStore()

    private let fileManager = FileManager.default

    private var baseDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport
            .appendingPathComponent("FriSpeak", isDirectory: true)
            .appendingPathComponent("HistoryAudio", isDirectory: true)
    }

    func storeAudioFile(at sourceURL: URL) throws -> String {
        try ensureDirectoryExists()

        let fileExtension = sourceURL.pathExtension.isEmpty ? "caf" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = baseDirectoryURL.appendingPathComponent(filename, isDirectory: false)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return filename
    }

    func url(for filename: String) -> URL? {
        guard !filename.isEmpty else {
            return nil
        }

        let fileURL = baseDirectoryURL.appendingPathComponent(filename, isDirectory: false)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func removeAll() {
        let directoryURL = baseDirectoryURL
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return
        }

        try? fileManager.removeItem(at: directoryURL)
    }

    func removeUnreferencedAudio(retaining filenames: Set<String>) {
        let directoryURL = baseDirectoryURL
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in fileURLs where !filenames.contains(fileURL.lastPathComponent) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func ensureDirectoryExists() throws {
        try fileManager.createDirectory(
            at: baseDirectoryURL,
            withIntermediateDirectories: true
        )
    }
}
