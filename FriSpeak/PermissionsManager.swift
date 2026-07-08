//
//  PermissionsManager.swift
//  FriSpeak
//

import AppKit
import AVFoundation
import ApplicationServices
import Speech

/// Outcome of requesting a TCC permission that may already be decided.
enum PermissionRequestOutcome: Equatable {
    /// Already granted, or the user just approved the system dialog.
    case granted
    /// Status was undetermined; system dialog was shown and the user declined.
    case deniedByDialog
    /// Already denied/restricted; app must open System Settings for the user to re-enable.
    case needsSystemSettings
}

struct PermissionsManager {
    func refreshStatus() async -> PermissionStatus {
        let microphoneGranted = await checkMicrophonePermission()
        
        return PermissionStatus(
            microphone: microphoneGranted,
            speechRecognition: SFSpeechRecognizer.authorizationStatus() == .authorized,
            accessibility: AXIsProcessTrusted()
        )
    }

    func requestMissingPermissions(promptForAccessibility: Bool) async -> PermissionStatus {
        let microphone = await requestMicrophoneIfNeeded()
        let speech = await requestSpeechIfNeeded()
        let accessibility = requestAccessibilityIfNeeded(prompt: promptForAccessibility)

        return PermissionStatus(
            microphone: microphone.granted,
            speechRecognition: speech.granted,
            accessibility: accessibility
        )
    }

    /// Requests microphone access via the system dialog when undetermined.
    /// Returns `.needsSystemSettings` only when already denied (dialog cannot be shown again).
    func requestMicrophoneIfNeeded() async -> PermissionRequestOutcome {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .needsSystemSettings
            case .undetermined:
                let granted = await AVAudioApplication.requestRecordPermission()
                return granted ? .granted : .deniedByDialog
            @unknown default:
                return .needsSystemSettings
            }
        } else {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                return .granted
            case .denied, .restricted:
                return .needsSystemSettings
            case .notDetermined:
                let granted = await withCheckedContinuation { continuation in
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        continuation.resume(returning: granted)
                    }
                }
                return granted ? .granted : .deniedByDialog
            @unknown default:
                return .needsSystemSettings
            }
        }
    }

    /// Requests speech recognition via the system dialog when undetermined.
    /// Returns `.needsSystemSettings` only when already denied (dialog cannot be shown again).
    func requestSpeechIfNeeded() async -> PermissionRequestOutcome {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .needsSystemSettings
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            return granted ? .granted : .deniedByDialog
        @unknown default:
            return .needsSystemSettings
        }
    }

    private func checkMicrophonePermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    func requestAccessibilityIfNeeded(prompt: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        guard prompt else {
            return false
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

private extension PermissionRequestOutcome {
    var granted: Bool { self == .granted }
}
