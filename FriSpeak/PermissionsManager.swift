//
//  PermissionsManager.swift
//  FriSpeak
//

import AppKit
import AVFoundation
import ApplicationServices
import Speech

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
            microphone: microphone,
            speechRecognition: speech,
            accessibility: accessibility
        )
    }

    private func checkMicrophonePermission() async -> Bool {
        if #available(macOS 14.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        } else {
            return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    private func requestMicrophoneIfNeeded() async -> Bool {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                return await AVAudioApplication.requestRecordPermission()
            @unknown default:
                return false
            }
        } else {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            switch status {
            case .authorized:
                return true
            case .denied, .restricted:
                return false
            case .notDetermined:
                return await withCheckedContinuation { continuation in
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        continuation.resume(returning: granted)
                    }
                }
            @unknown default:
                return false
            }
        }
    }

    private func requestSpeechIfNeeded() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
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
