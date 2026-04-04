//
//  HotkeyMonitor.swift
//  FriSpeak
//

import AppKit

final class HotkeyMonitor {
    private let hotkey: PushToTalkHotkey
    private let onPressedChange: @MainActor (Bool) -> Void
    private var isPressed = false
    private var localMonitors: [Any] = []
    private var globalMonitors: [Any] = []

    init(hotkey: PushToTalkHotkey, onPressedChange: @escaping @MainActor (Bool) -> Void) {
        self.hotkey = hotkey
        self.onPressedChange = onPressedChange
        installMonitors()
    }

    deinit {
        removeMonitors()
    }

    @MainActor
    func invalidate() {
        guard isPressed else {
            removeMonitors()
            return
        }

        isPressed = false
        onPressedChange(false)
        removeMonitors()
    }

    private func installMonitors() {
        localMonitors = [
            NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                guard let self else { return event }
                let shouldSuppress = self.shouldSuppress(event)
                self.handle(event)
                return shouldSuppress ? nil : event
            }
        ].compactMap { $0 }

        globalMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
                self?.handle(event)
            },
            NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                self?.handle(event)
            },
            NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
                self?.handle(event)
            }
        ].compactMap { $0 }
    }

    private func handle(_ event: NSEvent) {
        let newValue: Bool

        switch hotkey.kind {
        case .modifierOnly(let side):
            newValue = event.type == .flagsChanged && event.keyCode == side.keyCode && event.modifierFlags.contains(baseModifier(for: side))
        case .keyCombo:
            if event.type == .keyDown {
                newValue = event.keyCode == hotkey.keyCode && event.modifierFlags.normalizedForHotkey == hotkey.modifiers.normalizedForHotkey
            } else if event.type == .keyUp {
                newValue = false
            } else {
                return
            }
        }

        guard newValue != isPressed else {
            return
        }

        isPressed = newValue
        Task { @MainActor in
            onPressedChange(newValue)
        }
    }

    private func shouldSuppress(_ event: NSEvent) -> Bool {
        switch hotkey.kind {
        case .modifierOnly(let side):
            return event.type == .flagsChanged && event.keyCode == side.keyCode
        case .keyCombo:
            guard event.keyCode == hotkey.keyCode else {
                return false
            }

            if event.type == .keyDown {
                return event.modifierFlags.normalizedForHotkey == hotkey.modifiers.normalizedForHotkey
            }

            if event.type == .keyUp {
                return true
            }

            return false
        }
    }

    private func baseModifier(for side: SidedModifier) -> NSEvent.ModifierFlags {
        switch side {
        case .leftOption, .rightOption:
            return .option
        case .leftCommand, .rightCommand:
            return .command
        case .leftControl, .rightControl:
            return .control
        case .leftShift, .rightShift:
            return .shift
        }
    }

    private func removeMonitors() {
        localMonitors.forEach(NSEvent.removeMonitor)
        globalMonitors.forEach(NSEvent.removeMonitor)
        localMonitors.removeAll()
        globalMonitors.removeAll()
    }
}
