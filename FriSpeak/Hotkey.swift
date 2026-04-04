//
//  Hotkey.swift
//  FriSpeak
//

import AppKit
import Carbon.HIToolbox

struct PushToTalkHotkey: Codable, Equatable {
    var kind: Kind
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags

    static let defaultValue = PushToTalkHotkey(kind: .modifierOnly(.rightOption), keyCode: UInt16(kVK_RightOption), modifiers: [])

    var displayLabel: String {
        switch kind {
        case .modifierOnly(let side):
            return side.label
        case .keyCombo:
            let flags = modifiers.displayLabel
            let key = KeyCodeMapper.displayName(for: keyCode)
            return "\(flags)\(key)"
        }
    }

    enum Kind: Codable, Equatable {
        case modifierOnly(SidedModifier)
        case keyCombo
    }
}

enum SidedModifier: String, Codable, CaseIterable, Identifiable {
    case leftOption
    case rightOption
    case leftCommand
    case rightCommand
    case leftControl
    case rightControl
    case leftShift
    case rightShift

    var id: String { rawValue }

    var keyCode: UInt16 {
        switch self {
        case .leftCommand: return UInt16(kVK_Command)
        case .rightCommand: return UInt16(kVK_RightCommand)
        case .leftShift: return UInt16(kVK_Shift)
        case .rightShift: return UInt16(kVK_RightShift)
        case .leftOption: return UInt16(kVK_Option)
        case .rightOption: return UInt16(kVK_RightOption)
        case .leftControl: return UInt16(kVK_Control)
        case .rightControl: return UInt16(kVK_RightControl)
        }
    }

    var label: String {
        switch self {
        case .leftOption: return "Left Option"
        case .rightOption: return "Right Option"
        case .leftCommand: return "Left Command"
        case .rightCommand: return "Right Command"
        case .leftControl: return "Left Control"
        case .rightControl: return "Right Control"
        case .leftShift: return "Left Shift"
        case .rightShift: return "Right Shift"
        }
    }
}

extension NSEvent.ModifierFlags: @retroactive Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var normalizedForHotkey: NSEvent.ModifierFlags {
        intersection([.command, .option, .control, .shift])
    }

    var displayLabel: String {
        var result = ""
        if contains(.control) { result.append("⌃") }
        if contains(.option) { result.append("⌥") }
        if contains(.shift) { result.append("⇧") }
        if contains(.command) { result.append("⌘") }
        return result
    }
}

enum KeyCodeMapper {
    static func displayName(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyNames: [UInt16: String] = [
        UInt16(kVK_ANSI_A): "A",
        UInt16(kVK_ANSI_S): "S",
        UInt16(kVK_ANSI_D): "D",
        UInt16(kVK_ANSI_F): "F",
        UInt16(kVK_ANSI_G): "G",
        UInt16(kVK_ANSI_H): "H",
        UInt16(kVK_ANSI_J): "J",
        UInt16(kVK_ANSI_K): "K",
        UInt16(kVK_ANSI_L): "L",
        UInt16(kVK_ANSI_Z): "Z",
        UInt16(kVK_ANSI_X): "X",
        UInt16(kVK_ANSI_C): "C",
        UInt16(kVK_ANSI_V): "V",
        UInt16(kVK_ANSI_B): "B",
        UInt16(kVK_ANSI_Q): "Q",
        UInt16(kVK_ANSI_W): "W",
        UInt16(kVK_ANSI_E): "E",
        UInt16(kVK_ANSI_R): "R",
        UInt16(kVK_ANSI_Y): "Y",
        UInt16(kVK_ANSI_T): "T",
        UInt16(kVK_ANSI_1): "1",
        UInt16(kVK_ANSI_2): "2",
        UInt16(kVK_ANSI_3): "3",
        UInt16(kVK_ANSI_4): "4",
        UInt16(kVK_ANSI_6): "6",
        UInt16(kVK_ANSI_5): "5",
        UInt16(kVK_ANSI_Equal): "=",
        UInt16(kVK_ANSI_9): "9",
        UInt16(kVK_ANSI_7): "7",
        UInt16(kVK_ANSI_Minus): "-",
        UInt16(kVK_ANSI_8): "8",
        UInt16(kVK_ANSI_0): "0",
        UInt16(kVK_ANSI_RightBracket): "]",
        UInt16(kVK_ANSI_O): "O",
        UInt16(kVK_ANSI_U): "U",
        UInt16(kVK_ANSI_LeftBracket): "[",
        UInt16(kVK_ANSI_I): "I",
        UInt16(kVK_ANSI_P): "P",
        UInt16(kVK_ANSI_Quote): "'",
        UInt16(kVK_ANSI_Semicolon): ";",
        UInt16(kVK_ANSI_Backslash): "\\",
        UInt16(kVK_ANSI_Comma): ",",
        UInt16(kVK_ANSI_Slash): "/",
        UInt16(kVK_ANSI_N): "N",
        UInt16(kVK_ANSI_M): "M",
        UInt16(kVK_ANSI_Period): ".",
        UInt16(kVK_Tab): "Tab",
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Delete): "Delete",
        UInt16(kVK_Escape): "Escape",
        UInt16(kVK_Return): "Return",
        UInt16(kVK_F1): "F1",
        UInt16(kVK_F2): "F2",
        UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4",
        UInt16(kVK_F5): "F5",
        UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7",
        UInt16(kVK_F8): "F8",
        UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10",
        UInt16(kVK_F11): "F11",
        UInt16(kVK_F12): "F12"
    ]
}
