//
//  TextInsertionService.swift
//  FriSpeak
//

import AppKit

struct TextInsertionService {
    func insert(text: String) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            snapshot.restore(to: pasteboard)
            throw TextInsertionError.eventCreationFailed
        }

        commandDown.flags = .maskCommand
        commandUp.flags = .maskCommand

        commandDown.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)

        // Give the target app time to process the paste before restoring the clipboard
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        snapshot.restore(to: pasteboard)
    }
}

private struct PasteboardSnapshot {
    let items: [SnapshotItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            SnapshotItem(typesToData: item.types.reduce(into: [:]) { result, type in
                result[type] = item.data(forType: type)
            })
        }

        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        guard !items.isEmpty else {
            return
        }

        let restoredItems = items.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot.typesToData {
                guard let data else { continue }
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}

private struct SnapshotItem {
    let typesToData: [NSPasteboard.PasteboardType: Data?]
}

enum TextInsertionError: LocalizedError {
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            return "FriSpeak could not synthesize the paste shortcut."
        }
    }
}
