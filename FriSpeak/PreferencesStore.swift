//
//  PreferencesStore.swift
//  FriSpeak
//

import Foundation

final class PreferencesStore {
    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard
    private let hotkeyKey = "push_to_talk_hotkey"
    private let onboardingCompletedKey = "onboarding_completed"
    private let dictationModeKey = "dictation_mode"
    private let localSpeechBackendKey = "local_speech_backend"
    private let intelligencePromptKey = "intelligence_prompt"
    private let intelligenceFeaturesEnabledKey = "intelligence_features_enabled"
    private let intelligenceModelKey = "intelligence_model"
    private let builtInIntelligencePromptingEnabledKey = "built_in_intelligence_prompting_enabled"
    private let openRouterEnabledKey = "openrouter_enabled"
    private let openRouterAPIKeyKey = "openrouter_api_key"
    private let openRouterModelKey = "openrouter_model"
    private let cursorAwarenessEnabledKey = "cursor_awareness_enabled"
    private let textDeliveryModeKey = "text_delivery_mode"
    private let historyRetentionLimitKey = "history_retention_limit"
    private let historyEntriesKey = "history_entries"
    private let historyAudioLoggingEnabledKey = "history_audio_logging_enabled"
    private let launchAtStartupEnabledKey = "launch_at_startup_enabled"
    private let dimSystemAudioWhileListeningEnabledKey = "dim_system_audio_while_listening_enabled"
    private let dimSystemAudioTargetVolumeKey = "dim_system_audio_target_volume"

    func loadHotkey() -> PushToTalkHotkey {
        guard
            let data = defaults.data(forKey: hotkeyKey),
            let hotkey = try? JSONDecoder().decode(PushToTalkHotkey.self, from: data)
        else {
            return .defaultValue
        }

        return hotkey
    }

    func save(hotkey: PushToTalkHotkey) {
        guard let data = try? JSONEncoder().encode(hotkey) else {
            return
        }

        defaults.set(data, forKey: hotkeyKey)
    }

    func loadOnboardingCompleted() -> Bool {
        defaults.bool(forKey: onboardingCompletedKey)
    }

    func save(onboardingCompleted: Bool) {
        defaults.set(onboardingCompleted, forKey: onboardingCompletedKey)
    }
    
    func loadDictationMode() -> DictationMode {
        if
            let rawValue = defaults.string(forKey: dictationModeKey),
            let mode = DictationMode(rawValue: rawValue)
        {
            return mode
        }

        if let legacyRawValue = defaults.string(forKey: dictationModeKey) {
            switch legacyRawValue {
            case "offline":
                return .localNative
            case "online":
                return .remote
            default:
                break
            }
        }

        if defaults.object(forKey: openRouterEnabledKey) != nil, defaults.bool(forKey: openRouterEnabledKey) {
            return .remote
        }

        return .localGenerative
    }

    func save(dictationMode: DictationMode) {
        defaults.set(dictationMode.rawValue, forKey: dictationModeKey)
    }

    func loadLocalSpeechBackend() -> LocalSpeechBackend {
        guard
            let rawValue = defaults.string(forKey: localSpeechBackendKey),
            let backend = LocalSpeechBackend(rawValue: rawValue)
        else {
            return .coreML300M
        }

        return backend
    }

    func save(localSpeechBackend: LocalSpeechBackend) {
        defaults.set(localSpeechBackend.rawValue, forKey: localSpeechBackendKey)
    }
    
    func loadIntelligencePrompt() -> String {
        defaults.string(forKey: intelligencePromptKey) ?? ""
    }
    
    func save(intelligencePrompt: String) {
        defaults.set(intelligencePrompt, forKey: intelligencePromptKey)
    }

    func loadIntelligenceFeaturesEnabled() -> Bool {
        if defaults.object(forKey: intelligenceFeaturesEnabledKey) != nil {
            return defaults.bool(forKey: intelligenceFeaturesEnabledKey)
        }

        if let rawValue = defaults.string(forKey: dictationModeKey), rawValue == DictationMode.remote.rawValue {
            return true
        }

        return false
    }

    func save(intelligenceFeaturesEnabled: Bool) {
        defaults.set(intelligenceFeaturesEnabled, forKey: intelligenceFeaturesEnabledKey)
    }

    func loadIntelligenceModel() -> IntelligenceModel {
        if
            let rawValue = defaults.string(forKey: intelligenceModelKey),
            let model = IntelligenceModel(rawValue: rawValue)
        {
            return model
        }

        if let rawValue = defaults.string(forKey: dictationModeKey), rawValue == DictationMode.remote.rawValue {
            return .remote
        }

        return .apple
    }

    func save(intelligenceModel: IntelligenceModel) {
        defaults.set(intelligenceModel.rawValue, forKey: intelligenceModelKey)
    }

    func loadBuiltInIntelligencePromptingEnabled() -> Bool {
        if defaults.object(forKey: builtInIntelligencePromptingEnabledKey) == nil {
            return true
        }

        return defaults.bool(forKey: builtInIntelligencePromptingEnabledKey)
    }

    func save(builtInIntelligencePromptingEnabled: Bool) {
        defaults.set(builtInIntelligencePromptingEnabled, forKey: builtInIntelligencePromptingEnabledKey)
    }

    func loadOpenRouterAPIKey() -> String {
        defaults.string(forKey: openRouterAPIKeyKey) ?? ""
    }

    func save(openRouterAPIKey: String) {
        defaults.set(openRouterAPIKey, forKey: openRouterAPIKeyKey)
    }

    func loadOpenRouterModel() -> String {
        let value = defaults.string(forKey: openRouterModelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "google/gemini-3.1-flash-lite-preview" : value
    }

    func save(openRouterModel: String) {
        defaults.set(openRouterModel, forKey: openRouterModelKey)
    }

    func loadCursorAwarenessEnabled() -> Bool {
        if defaults.object(forKey: cursorAwarenessEnabledKey) == nil {
            return true
        }

        return defaults.bool(forKey: cursorAwarenessEnabledKey)
    }

    func save(cursorAwarenessEnabled: Bool) {
        defaults.set(cursorAwarenessEnabled, forKey: cursorAwarenessEnabledKey)
    }

    func loadTextDeliveryMode() -> TextDeliveryMode {
        guard
            let rawValue = defaults.string(forKey: textDeliveryModeKey),
            let mode = TextDeliveryMode(rawValue: rawValue)
        else {
            return .insert
        }

        return mode
    }

    func save(textDeliveryMode: TextDeliveryMode) {
        defaults.set(textDeliveryMode.rawValue, forKey: textDeliveryModeKey)
    }

    func loadHistoryRetentionLimit() -> Int {
        let storedValue = defaults.integer(forKey: historyRetentionLimitKey)
        return storedValue > 0 ? storedValue : 100
    }

    func save(historyRetentionLimit: Int) {
        defaults.set(historyRetentionLimit, forKey: historyRetentionLimitKey)
    }

    func loadHistoryAudioLoggingEnabled() -> Bool {
        defaults.bool(forKey: historyAudioLoggingEnabledKey)
    }

    func save(historyAudioLoggingEnabled: Bool) {
        defaults.set(historyAudioLoggingEnabled, forKey: historyAudioLoggingEnabledKey)
    }

    func loadHistory() -> [CaptureHistoryEntry] {
        guard
            let data = defaults.data(forKey: historyEntriesKey),
            let entries = try? JSONDecoder().decode([CaptureHistoryEntry].self, from: data)
        else {
            return []
        }

        return entries
    }

    func save(history: [CaptureHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(history) else {
            return
        }

        defaults.set(data, forKey: historyEntriesKey)
    }

    func loadLaunchAtStartupEnabled() -> Bool {
        defaults.bool(forKey: launchAtStartupEnabledKey)
    }

    func save(launchAtStartupEnabled: Bool) {
        defaults.set(launchAtStartupEnabled, forKey: launchAtStartupEnabledKey)
    }

    func loadDimSystemAudioWhileListeningEnabled() -> Bool {
        defaults.bool(forKey: dimSystemAudioWhileListeningEnabledKey)
    }

    func save(dimSystemAudioWhileListeningEnabled: Bool) {
        defaults.set(dimSystemAudioWhileListeningEnabled, forKey: dimSystemAudioWhileListeningEnabledKey)
    }

    func loadDimSystemAudioTargetVolume() -> Double {
        if defaults.object(forKey: dimSystemAudioTargetVolumeKey) == nil {
            return 0.2
        }

        let stored = defaults.double(forKey: dimSystemAudioTargetVolumeKey)
        return min(max(stored, 0), 1)
    }

    func save(dimSystemAudioTargetVolume: Double) {
        defaults.set(min(max(dimSystemAudioTargetVolume, 0), 1), forKey: dimSystemAudioTargetVolumeKey)
    }
}
