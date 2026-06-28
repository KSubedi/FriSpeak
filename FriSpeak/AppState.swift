//
//  AppState.swift
//  FriSpeak
//

import AVFoundation
import AppKit
import Combine
import FoundationModels
import Speech
import ServiceManagement

enum DictationMode: String, CaseIterable, Identifiable {
    case localNative
    case localGenerative
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localNative:
            return "Local Native"
        case .localGenerative:
            return "Local Generative"
        case .remote:
            return "Remote"
        }
    }

    var summary: String {
        switch self {
        case .localNative:
            return "Apple Speech Recognition"
        case .localGenerative:
            return "Local on-device speech model"
        case .remote:
            return "OpenRouter cleanup and insertion assistance"
        }
    }

    var systemImage: String {
        switch self {
        case .localNative:
            return "internaldrive"
        case .localGenerative:
            return "cpu"
        case .remote:
            return "network"
        }
    }
}

enum LocalSpeechBackend: String, CaseIterable, Identifiable {
    case coreML300M
    case mlx1B4bit
    case parakeetTDT

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coreML300M:
            return "300M Core ML"
        case .mlx1B4bit:
            return "1B MLX 4-bit"
        case .parakeetTDT:
            return "Parakeet TDT"
        }
    }

    var detailTitle: String {
        switch self {
        case .coreML300M:
            return "Omnilingual ASR 300M Core ML"
        case .mlx1B4bit:
            return "Omnilingual ASR 1B MLX 4-bit"
        case .parakeetTDT:
            return "Parakeet TDT 0.6B Core ML"
        }
    }

    var summary: String {
        switch self {
        case .coreML300M:
            return "Runs with Core ML on the Neural Engine. Smallest memory footprint."
        case .mlx1B4bit:
            return "Runs with MLX on the Metal GPU. Larger model, more unified memory."
        case .parakeetTDT:
            return "Runs with Core ML on the Neural Engine. 25 European languages, less multilingual drift."
        }
    }

    var acceleratorLabel: String {
        switch self {
        case .coreML300M:
            return "NPU / Neural Engine"
        case .mlx1B4bit:
            return "GPU / Metal"
        case .parakeetTDT:
            return "NPU / Neural Engine"
        }
    }

    var expectedMemoryLabel: String {
        switch self {
        case .coreML300M:
            return "~312 MB model; expect ~0.5-0.8 GB runtime memory"
        case .mlx1B4bit:
            return "~576 MB model; expect ~1.0-1.5 GB unified memory"
        case .parakeetTDT:
            return "~500 MB model; expect ~0.7-1.0 GB runtime memory"
        }
    }

    var modelID: String {
        switch self {
        case .coreML300M:
            return "aufklarer/Omnilingual-ASR-CTC-300M-CoreML-INT8-10s"
        case .mlx1B4bit:
            return "aufklarer/Omnilingual-ASR-CTC-1B-MLX-4bit"
        case .parakeetTDT:
            return "aufklarer/Parakeet-TDT-v3-CoreML-INT8-30s"
        }
    }

    var cacheRepositoryName: String {
        switch self {
        case .coreML300M:
            return "Omnilingual-ASR-CTC-300M-CoreML-INT8-10s"
        case .mlx1B4bit:
            return "Omnilingual-ASR-CTC-1B-MLX-4bit"
        case .parakeetTDT:
            return "Parakeet-TDT-v3-CoreML-INT8-30s"
        }
    }

    var requiredCacheFiles: [String] {
        switch self {
        case .coreML300M:
            return ["config.json", "tokenizer.model", "omnilingual-ctc-300m-int8.mlmodelc"]
        case .mlx1B4bit:
            return ["config.json", "tokenizer.model", "model.safetensors"]
        case .parakeetTDT:
            return ["config.json", "vocab.json", "encoder.mlmodelc", "decoder.mlmodelc", "joint.mlmodelc"]
        }
    }
}

enum IntelligenceModel: String, CaseIterable, Identifiable {
    case apple
    case local
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:
            return "Apple Intelligence"
        case .local:
            return "Local MLX"
        case .remote:
            return "Remote"
        }
    }

    var summary: String {
        switch self {
        case .apple:
            return "On-device text cleanup"
        case .local:
            return "Bonsai-8B local model"
        case .remote:
            return "OpenRouter text cleanup"
        }
    }

    var systemImage: String {
        switch self {
        case .apple:
            return "apple.intelligence"
        case .local:
            return "brain"
        case .remote:
            return "network"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var hotkey: PushToTalkHotkey
    @Published var dictationMode: DictationMode
    @Published var localSpeechBackend: LocalSpeechBackend
    @Published var intelligenceFeaturesEnabled: Bool
    @Published var intelligenceModel: IntelligenceModel
    @Published var builtInIntelligencePromptingEnabled: Bool
    @Published var intelligencePrompt: String
    @Published var openRouterAPIKey: String
    @Published var openRouterModel: String
    @Published var cursorAwarenessEnabled: Bool
    @Published var historyRetentionLimit: Int
    @Published var historyAudioLoggingEnabled: Bool
    @Published var launchAtStartupEnabled: Bool
    @Published var dimSystemAudioWhileListeningEnabled: Bool
    @Published var dimSystemAudioTargetVolume: Double
    @Published private(set) var openRouterModelSupportsAudioInput = false
    @Published private(set) var openRouterCapabilityStatus = "Model capabilities unavailable"
    @Published private(set) var appleIntelligenceStatus = IntelligenceService.appleIntelligenceAvailabilityDescription()
    @Published private(set) var localQwenModelCached = false
    @Published private(set) var localQwenPreloadInProgress = false
    @Published private(set) var localQwenDownloadInProgress = false
    @Published private(set) var localQwenDownloadProgress: Double = 0
    @Published private(set) var localQwenDownloadStatus = "Model not downloaded"
    @Published private(set) var localQwenLastError: String?
    @Published private(set) var localBonsaiModelCached = LocalBonsaiIntelligenceService.isModelCached()
    @Published private(set) var localBonsaiPreloadInProgress = false
    @Published private(set) var localBonsaiDownloadInProgress = false
    @Published private(set) var localBonsaiDownloadProgress: Double = 0
    @Published private(set) var localBonsaiDownloadStatus = "Model not downloaded"
    @Published private(set) var localBonsaiLastError: String?
    @Published private(set) var localBonsaiCompatibilityIssue = LocalBonsaiIntelligenceService.compatibilityIssue()
    @Published private(set) var history: [CaptureHistoryEntry]
    @Published private(set) var captureState: CaptureState = .idle
    @Published private(set) var lastTranscript = ""
    @Published private(set) var permissionStatus: PermissionStatus = .unknown
    @Published private(set) var lastError: String?
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var testCaptureState: TestCaptureState = .idle

    private let preferences: PreferencesStore
    private let networkMonitor = NetworkMonitor.shared
    private let permissionsManager = PermissionsManager()
    private lazy var audioRecorder = AudioRecorder()
    private lazy var transcriber = SpeechTranscriber()
    private lazy var localQwenTranscriber = LocalQwenTranscriber()
    private lazy var intelligenceService = IntelligenceService()
    private lazy var localBonsaiIntelligenceService = LocalBonsaiIntelligenceService()
    private let focusedTextContextService = FocusedTextContextService()
    private let textInserter = TextInsertionService()
    private let hudController = HUDWindowController()
    private let historyAudioStore = HistoryAudioStore.shared
    private let systemVolumeController = SystemVolumeController()
    private let intelligenceWarningDelayNanoseconds: UInt64 = 10 * 1_000_000_000
    private let openRouterTimeoutNanoseconds: UInt64 = 30 * 1_000_000_000
    private var hotkeyMonitor: HotkeyMonitor?
    private var cancellables: Set<AnyCancellable> = []
    private var captureSessionID = 0
    private var activeIntelligenceTask: Task<IntelligenceProcessingResult, Error>?
    private var activeIntelligenceTaskToken = UUID()
    private var capturedSystemVolumeBeforeListening: Float32?

    private var permissionPollingTask: Task<Void, Never>?

    init(preferences: PreferencesStore? = nil) {
        let resolvedPreferences = preferences ?? .shared
        self.preferences = resolvedPreferences
        self.hotkey = resolvedPreferences.loadHotkey()
        self.hasCompletedOnboarding = resolvedPreferences.loadOnboardingCompleted()
        
        self.dictationMode = resolvedPreferences.loadDictationMode()
        self.localSpeechBackend = resolvedPreferences.loadLocalSpeechBackend()
        self.intelligenceFeaturesEnabled = resolvedPreferences.loadIntelligenceFeaturesEnabled()
        self.intelligenceModel = resolvedPreferences.loadIntelligenceModel()
        self.builtInIntelligencePromptingEnabled = resolvedPreferences.loadBuiltInIntelligencePromptingEnabled()
        self.intelligencePrompt = resolvedPreferences.loadIntelligencePrompt()
        self.openRouterAPIKey = resolvedPreferences.loadOpenRouterAPIKey()
        self.openRouterModel = resolvedPreferences.loadOpenRouterModel()
        self.cursorAwarenessEnabled = resolvedPreferences.loadCursorAwarenessEnabled()
        self.historyRetentionLimit = resolvedPreferences.loadHistoryRetentionLimit()
        self.historyAudioLoggingEnabled = resolvedPreferences.loadHistoryAudioLoggingEnabled()
        self.launchAtStartupEnabled = resolvedPreferences.loadLaunchAtStartupEnabled()
        self.dimSystemAudioWhileListeningEnabled = resolvedPreferences.loadDimSystemAudioWhileListeningEnabled()
        self.dimSystemAudioTargetVolume = resolvedPreferences.loadDimSystemAudioTargetVolume()
        self.history = resolvedPreferences.loadHistory()
        let initialHistoryLimit = min(max(self.historyRetentionLimit, 1), 1_000)
        if self.history.count > initialHistoryLimit {
            self.history = Array(self.history.prefix(initialHistoryLimit))
        }
        
        hudController.onCancel = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.cancelCapture()
            }
        }

        $hotkey
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(hotkey: newValue)
                self?.installHotkeyMonitor()
            }
            .store(in: &cancellables)
        
        $dictationMode
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(dictationMode: newValue)
            }
            .store(in: &cancellables)

        $localSpeechBackend
            .dropFirst()
            .sink { [weak self] newValue in
                guard let self else { return }
                self.preferences.save(localSpeechBackend: newValue)
                self.refreshLocalQwenModelState()
                if self.dictationMode == .localGenerative {
                    Task { @MainActor in
                        await self.preloadLocalQwenModelIfAvailable()
                    }
                }
            }
            .store(in: &cancellables)

        $intelligenceFeaturesEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(intelligenceFeaturesEnabled: newValue)
            }
            .store(in: &cancellables)

        $intelligenceModel
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(intelligenceModel: newValue)
            }
            .store(in: &cancellables)

        $builtInIntelligencePromptingEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(builtInIntelligencePromptingEnabled: newValue)
            }
            .store(in: &cancellables)
        
        $intelligencePrompt
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.preferences.save(intelligencePrompt: newValue)
            }
            .store(in: &cancellables)

        $openRouterAPIKey
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.preferences.save(openRouterAPIKey: newValue)
            }
            .store(in: &cancellables)

        $openRouterModel
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.preferences.save(openRouterModel: newValue)
                Task { @MainActor in
                    await self?.refreshOpenRouterModelCapabilities()
                }
            }
            .store(in: &cancellables)

        $openRouterAPIKey
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshOpenRouterModelCapabilities()
                }
            }
            .store(in: &cancellables)

        $dictationMode
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshOpenRouterModelCapabilities()
                }
            }
            .store(in: &cancellables)

        // React to network status changes: update computed properties and
        // refresh the HUD in real-time if a capture is active.
        networkMonitor.$isOnline
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOnline in
                guard let self else { return }
                self.objectWillChange.send()
                self.updateHUDForNetworkChange(isOnline: isOnline)
            }
            .store(in: &cancellables)

        $cursorAwarenessEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(cursorAwarenessEnabled: newValue)
            }
            .store(in: &cancellables)

        $historyRetentionLimit
            .dropFirst()
            .map { min(max($0, 1), 1_000) }
            .sink { [weak self] newValue in
                guard let self else { return }
                if self.historyRetentionLimit != newValue {
                    self.historyRetentionLimit = newValue
                    return
                }
                self.preferences.save(historyRetentionLimit: newValue)
                self.trimHistory()
            }
            .store(in: &cancellables)

        $historyAudioLoggingEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(historyAudioLoggingEnabled: newValue)
                if !newValue {
                    self?.historyAudioStore.removeAll()
                    self?.clearHistoryAudioReferences()
                }
            }
            .store(in: &cancellables)

        $launchAtStartupEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(launchAtStartupEnabled: newValue)
                self?.updateLaunchAtStartup()
            }
            .store(in: &cancellables)

        $dimSystemAudioWhileListeningEnabled
            .dropFirst()
            .sink { [weak self] newValue in
                self?.preferences.save(dimSystemAudioWhileListeningEnabled: newValue)
            }
            .store(in: &cancellables)

        $dimSystemAudioTargetVolume
            .dropFirst()
            .map { min(max($0, 0), 1) }
            .sink { [weak self] newValue in
                guard let self else { return }
                if self.dimSystemAudioTargetVolume != newValue {
                    self.dimSystemAudioTargetVolume = newValue
                    return
                }

                self.preferences.save(dimSystemAudioTargetVolume: newValue)

                if self.captureState == .listening, self.capturedSystemVolumeBeforeListening != nil {
                    do {
                        try self.systemVolumeController.setOutputVolume(Float32(newValue))
                    } catch {
                        print("Failed to update dimmed system volume: \(error)")
                    }
                }
            }
            .store(in: &cancellables)

        // Handle audio device changes (plugging/unplugging headphones)
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.clearError()
                    // Restarting capture state if it was idle but hardware changed
                    if self?.captureState == .idle {
                        await self?.refreshPermissions()
                    }
                }
            }
            .store(in: &cancellables)

        Task {
            refreshLocalQwenModelState()
            localBonsaiModelCached = LocalBonsaiIntelligenceService.isModelCached()
            localBonsaiCompatibilityIssue = LocalBonsaiIntelligenceService.compatibilityIssue()
            localBonsaiDownloadStatus = localBonsaiCompatibilityIssue ?? (localBonsaiModelCached ? "Ready" : "Model not downloaded")
            appleIntelligenceStatus = IntelligenceService.appleIntelligenceAvailabilityDescription()
            await refreshPermissions()
            await refreshOpenRouterModelCapabilities()
            installHotkeyMonitor()
            updateActivationPolicy()
            updateLaunchAtStartup()
            Task(priority: .utility) { @MainActor in
                await self.preloadLocalQwenModelIfAvailable()
                await self.preloadLocalBonsaiModelIfAvailable()
            }
            
            if !hasCompletedOnboarding || !permissionStatus.allRequiredGranted {
                startPollingPermissions()
                if !hasCompletedOnboarding {
                    showMainWindow()
                }
            }
        }

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshPermissions()
                }
            }
            .store(in: &cancellables)
    }

    func showMainWindow() {
        // This triggers the 'launcher' window in FriSpeakApp
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Fallback for settings link if main window isn't found
            NSWorkspace.shared.open(URL(string: "frispeak://show-main")!)
        }
    }

    private func updateActivationPolicy() {
        let policy: NSApplication.ActivationPolicy = hasCompletedOnboarding ? .accessory : .regular
        NSApp.setActivationPolicy(policy)
        if policy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func updateLaunchAtStartup() {
        #if DEBUG
        // Disable launch at startup for development builds to avoid cluttering system settings
        return
        #else
        do {
            if launchAtStartupEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at startup: \(error)")
        }
        #endif
    }

    func startPollingPermissions() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                await refreshPermissions()
                if permissionStatus.allRequiredGranted {
                    break
                }
            }
        }
    }

    func stopPollingPermissions() {
        permissionPollingTask?.cancel()
        permissionPollingTask = nil
    }

    var statusSummary: String {
        switch captureState {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening while shortcut is held"
        case .transcribing:
            return "Transcribing last recording"
        case .injecting:
            return "Inserting text at the cursor"
        case .error(let message):
            return message
        }
    }

    var statusItemSymbolName: String {
        switch captureState {
        case .idle:
            return "mic"
        case .listening:
            return "waveform"
        case .transcribing:
            return "text.bubble"
        case .injecting:
            return "cursorarrow.motionlines"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    var isDeviceOnline: Bool {
        networkMonitor.isCurrentlyReachable
    }

    var usingRemoteMode: Bool {
        dictationMode == .remote
    }

    var hasConfiguredOpenRouter: Bool {
        !openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canUseRemoteMode: Bool {
        usingRemoteMode
            && isDeviceOnline
            && hasConfiguredOpenRouter
    }

    var shouldUseOpenRouterSingleModelAudioMode: Bool {
        canUseRemoteMode
            && openRouterModelSupportsAudioInput
    }

    var canUseAppleIntelligence: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var canUseLocalIntelligence: Bool {
        localBonsaiModelCached && localBonsaiCompatibilityIssue == nil
    }

    var canUseRemoteIntelligence: Bool {
        hasConfiguredOpenRouter && isDeviceOnline
    }

    var canUseSelectedIntelligenceModel: Bool {
        switch intelligenceModel {
        case .apple:
            return canUseAppleIntelligence
        case .local:
            return canUseLocalIntelligence
        case .remote:
            return canUseRemoteIntelligence
        }
    }

    var canUseCursorAwarenessForIntelligence: Bool {
        intelligenceFeaturesEnabled && canUseSelectedIntelligenceModel
    }

    var activeTextIntelligenceBackend: IntelligenceBackend {
        guard intelligenceFeaturesEnabled else {
            return .none
        }

        switch intelligenceModel {
        case .apple:
            return canUseAppleIntelligence ? .appleIntelligence : .none
        case .local:
            return canUseLocalIntelligence ? .localMLX : .none
        case .remote:
            return canUseRemoteIntelligence ? .openRouter : .none
        }
    }

    var intelligenceAvailabilityStatus: String {
        switch dictationMode {
        case .localNative:
            return "Speech: Apple Speech Recognition"
        case .localGenerative:
            if localQwenDownloadInProgress {
                return "Speech: \(Int((localQwenDownloadProgress * 100).rounded()))% — \(localQwenDownloadStatus)"
            }
            if localQwenPreloadInProgress {
                return "Speech: Loading \(localSpeechBackend.title) into memory"
            }
            if localQwenModelCached {
                return "Speech: \(localSpeechBackend.title) is ready"
            }
            if let localQwenLastError, !localQwenLastError.isEmpty {
                return "Speech: \(localSpeechBackend.title) needs download: \(localQwenLastError)"
            }
            return "Speech: \(localSpeechBackend.title) requires a model download"
        case .remote:
            if !isDeviceOnline {
                return "Speech: Remote mode selected, but this Mac is offline"
            }

            return canUseRemoteMode ? "Speech: Configured via OpenRouter" : "Speech: OpenRouter API key required"
        }
    }

    var needsSetupAttention: Bool {
        !hasCompletedOnboarding || !permissionStatus.allRequiredGranted
    }

    var setupCallToActionTitle: String {
        needsSetupAttention ? "Open Setup" : "Open Settings"
    }

    var canControlSystemOutputVolume: Bool {
        systemVolumeController.canControlOutputVolume()
    }

    func openAccessibilityPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func resetAccessibilityPermissions() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.fridev.FriSpeak"]
        try? process.run()
        process.waitUntilExit()
        
        Task {
            await refreshPermissions()
        }
    }

    func promptForAccessibility() {
        permissionStatus.accessibility = permissionsManager.requestAccessibilityIfNeeded(prompt: true)
        openAccessibilityPreferences()
    }

    func requestMicrophoneThenOpenPreferences() {
        Task {
            _ = await permissionsManager.requestMissingPermissions(promptForAccessibility: false)
            await refreshPermissions()
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

    func requestSpeechThenOpenPreferences() {
        Task {
            _ = await permissionsManager.requestMissingPermissions(promptForAccessibility: false)
            await refreshPermissions()
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") else {
                return
            }
            NSWorkspace.shared.open(url)
        }
    }

    func clearError() {
        lastError = nil
        if case .error = captureState {
            captureState = .idle
        }
    }

    func clearTranscript() {
        lastTranscript = ""
    }

    func clearHistory() {
        history.removeAll()
        historyAudioStore.removeAll()
        preferences.save(history: history)
    }

    func refreshPermissions() async {
        permissionStatus = await permissionsManager.refreshStatus()
    }

    func requestMediaPermissions() async {
        permissionStatus = await permissionsManager.requestMissingPermissions(promptForAccessibility: false)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        preferences.save(onboardingCompleted: true)
        stopPollingPermissions()
        updateActivationPolicy()
    }

    func reopenOnboarding() {
        hasCompletedOnboarding = false
        preferences.save(onboardingCompleted: false)
        startPollingPermissions()
        updateActivationPolicy()
    }

    func downloadLocalQwenModel() async {
        guard !localQwenDownloadInProgress else { return }
        let backend = localSpeechBackend

        localQwenDownloadInProgress = true
        localQwenDownloadProgress = 0
        localQwenDownloadStatus = "Preparing \(backend.title) download..."
        localQwenLastError = nil

        do {
            try await localQwenTranscriber.prepareModel(backend: backend) { [weak self] progress, status in
                Task { @MainActor in
                    guard let self else { return }
                    self.localQwenDownloadProgress = progress
                    self.localQwenDownloadStatus = status.isEmpty ? "Downloading model..." : status
                }
            }
            if localSpeechBackend == backend {
                localQwenModelCached = true
            }
            localQwenDownloadProgress = 1
            localQwenDownloadStatus = "Ready"
        } catch {
            localQwenModelCached = LocalQwenTranscriber.isModelCached(backend: localSpeechBackend)
            localQwenLastError = error.localizedDescription
            localQwenDownloadStatus = "Download failed"
        }

        localQwenDownloadInProgress = false
    }

    func downloadLocalBonsaiModel() async {
        guard !localBonsaiDownloadInProgress else { return }

        localBonsaiCompatibilityIssue = LocalBonsaiIntelligenceService.compatibilityIssue()
        if let localBonsaiCompatibilityIssue {
            localBonsaiLastError = localBonsaiCompatibilityIssue
            localBonsaiDownloadStatus = localBonsaiCompatibilityIssue
            return
        }

        localBonsaiDownloadInProgress = true
        localBonsaiDownloadProgress = 0
        localBonsaiDownloadStatus = "Preparing download..."
        localBonsaiLastError = nil

        do {
            try await localBonsaiIntelligenceService.prepareModel { [weak self] progress, status in
                Task { @MainActor in
                    guard let self else { return }
                    self.localBonsaiDownloadProgress = progress
                    self.localBonsaiDownloadStatus = status.isEmpty ? "Downloading model..." : status
                }
            }
            localBonsaiModelCached = true
            localBonsaiCompatibilityIssue = LocalBonsaiIntelligenceService.compatibilityIssue()
            localBonsaiDownloadProgress = 1
            localBonsaiDownloadStatus = "Ready"
        } catch {
            localBonsaiModelCached = LocalBonsaiIntelligenceService.isModelCached()
            localBonsaiCompatibilityIssue = LocalBonsaiIntelligenceService.compatibilityIssue()
            localBonsaiLastError = error.localizedDescription
            localBonsaiDownloadStatus = "Download failed"
        }

        localBonsaiDownloadInProgress = false
    }

    private func preloadLocalQwenModelIfAvailable() async {
        let backend = localSpeechBackend
        guard localQwenModelCached else { return }
        guard !localQwenDownloadInProgress, !localQwenPreloadInProgress else { return }

        localQwenPreloadInProgress = true
        localQwenDownloadStatus = "Loading \(backend.title) into memory..."
        localQwenLastError = nil

        defer {
            localQwenPreloadInProgress = false
        }

        do {
            let loaded = try await localQwenTranscriber.preloadCachedModel(backend: backend)
            if loaded {
                if localSpeechBackend == backend {
                    localQwenModelCached = true
                }
                localQwenDownloadStatus = "Ready"
            }
        } catch {
            localQwenLastError = error.localizedDescription
            localQwenDownloadStatus = "Model cached, but failed to load"
        }
    }

    private func refreshLocalQwenModelState() {
        localQwenModelCached = LocalQwenTranscriber.isModelCached(backend: localSpeechBackend)
        if localQwenDownloadInProgress || localQwenPreloadInProgress {
            return
        }
        localQwenDownloadProgress = localQwenModelCached ? 1 : 0
        localQwenDownloadStatus = localQwenModelCached ? "Ready" : "Model not downloaded"
        localQwenLastError = nil
    }

    private func preloadLocalBonsaiModelIfAvailable() async {
        guard localBonsaiModelCached else { return }
        guard localBonsaiCompatibilityIssue == nil else { return }
        guard !localBonsaiDownloadInProgress, !localBonsaiPreloadInProgress else { return }

        localBonsaiPreloadInProgress = true
        localBonsaiDownloadStatus = "Loading model into memory..."
        localBonsaiLastError = nil

        defer {
            localBonsaiPreloadInProgress = false
        }

        do {
            let loaded = try await localBonsaiIntelligenceService.preloadCachedModel()
            if loaded {
                localBonsaiModelCached = true
                localBonsaiDownloadStatus = "Ready"
            }
        } catch {
            localBonsaiLastError = error.localizedDescription
            localBonsaiDownloadStatus = "Model cached, but failed to load"
        }
    }

    func startCapture(forceRestart: Bool = false) async {
        guard await prepareForCapture(requiresAccessibility: true) else {
            return
        }

        if forceRestart && captureState != .idle {
            await invalidateCurrentCaptureSession()
        }

        guard captureState == .idle else {
            return
        }

        do {
            lastError = nil
            let sessionID = beginCaptureSession()
            captureState = .listening
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown App"
            let detail = isDeviceOnline ? appName : "\(appName) — Offline"
            hudController.show(
                text: "Listening",
                detail: detail,
                state: .listening
            )
            applyListeningVolumeDimIfNeeded()
            try await audioRecorder.start()

            guard isCaptureSessionActive(sessionID) else {
                restoreSystemVolumeAfterListeningIfNeeded()
                await audioRecorder.cancel()
                return
            }
        } catch {
            restoreSystemVolumeAfterListeningIfNeeded()
            showError(error.localizedDescription)
        }
    }

    func stopCapture() async {
        guard captureState == .listening else {
            return
        }

        do {
            let sessionID = captureSessionID
            restoreSystemVolumeAfterListeningIfNeeded()
            captureState = .transcribing
            let localMode = dictationMode != .remote
            hudController.show(
                text: localMode ? "Transcribing locally" : "Transcribing",
                state: .transcribing
            )
            let recordingURL = try await audioRecorder.stop()
            guard isCaptureSessionActive(sessionID) else {
                return
            }

            // Always fetch editor context for programmatic formatting (spacing, casing).
            // Cursor awareness for Apple is applied during insertion adaptation, not
            // during the main cleanup pass, because Apple may rewrite against the
            // surrounding text instead of just cleaning the dictated transcript.
            let editorContext = focusedTextContextService.currentContext()
            let llmEditorContext = textIntelligenceEditorContext(from: editorContext)
            let useDirectAudioModel = shouldUseOpenRouterSingleModelAudioMode
            let usingTextIntelligence = activeTextIntelligenceBackend != .none
            let rawTranscript: String
            var transcript: String
            let aiAttempted = dictationMode != .localNative || intelligenceFeaturesEnabled
            var aiSucceeded = !usingTextIntelligence && dictationMode != .localNative
            var rawModelResponse: String?
            var modelPrompt: String?
            var historyAudioFilename: String?
            var modelTransportLog: String?
            var aiErrorMessage: String?

            if dictationMode == .localGenerative {
                hudController.show(text: "Transcribing with \(localSpeechBackend.title)", state: .transcribing)
                do {
                    let localTranscript = try await processLocalGenerativeTranscriptionWithTimeout(
                        audioURL: recordingURL,
                        prompt: localGenerativeTranscriptionPrompt()
                    )
                    guard isCaptureSessionActive(sessionID) else {
                        return
                    }

                    rawTranscript = localTranscript
                    transcript = localTranscript
                    modelPrompt = localQwenPromptSummary()
                    localQwenModelCached = true
                    localQwenLastError = nil
                    localQwenDownloadStatus = "Ready"
                    historyAudioFilename = persistHistoryAudioIfNeeded(from: recordingURL)
                } catch {
                    print("Local speech transcription failed: \(error.frispeakReadableMessage)")
                    localQwenModelCached = LocalQwenTranscriber.isModelCached(backend: localSpeechBackend)
                    localQwenLastError = error.frispeakReadableMessage
                    if !localQwenDownloadInProgress {
                        localQwenDownloadStatus = "Model needs attention"
                    }
                    aiErrorMessage = error.frispeakReadableMessage
                    throw error
                }
            } else if useDirectAudioModel {
                hudController.show(text: "Transcribing with remote audio model", state: .transcribing)
                do {
                    let intelligenceResult = try await processRemoteAudioTranscriptionWithTimeout(
                        audioURL: recordingURL,
                        editorContext: nil
                    )
                    guard isCaptureSessionActive(sessionID) else {
                        return
                    }

                    rawTranscript = intelligenceResult.insertedText
                    transcript = intelligenceResult.insertedText
                    rawModelResponse = intelligenceResult.rawModelResponse
                    modelPrompt = intelligenceResult.promptSentToModel
                    modelTransportLog = intelligenceResult.transportLog
                    aiSucceeded = true
                    historyAudioFilename = persistHistoryAudioIfNeeded(
                        from: intelligenceResult.audioDebugSourceURL ?? recordingURL
                    )
                } catch {
                    print("Direct audio intelligence processing failed: \(error.frispeakReadableMessage)")
                    if let diagnostic = error as? IntelligenceFailureDiagnostic {
                        modelPrompt = diagnostic.promptSentToModel
                        modelTransportLog = diagnostic.transportLog
                    }
                    aiErrorMessage = error.frispeakReadableMessage
                    hudController.show(text: "Falling back to built-in transcription", state: .transcribing)

                    let fallbackTranscript = try await transcriber.transcribeFile(at: recordingURL)
                    guard isCaptureSessionActive(sessionID) else {
                        return
                    }

                    rawTranscript = fallbackTranscript
                    transcript = fallbackTranscript
                    historyAudioFilename = persistHistoryAudioIfNeeded(from: recordingURL)
                }
            } else {
                let fallbackTranscript = try await transcriber.transcribeFile(at: recordingURL)
                guard isCaptureSessionActive(sessionID) else {
                    return
                }

                rawTranscript = fallbackTranscript
                transcript = fallbackTranscript
                historyAudioFilename = persistHistoryAudioIfNeeded(from: recordingURL)
            }

            if usingTextIntelligence && !useDirectAudioModel {
                hudController.show(text: textIntelligenceHUDTitle, state: .transcribing)
                do {
                    let intelligenceResult = try await processTextIntelligenceWithTimeout(
                        transcript: transcript,
                        editorContext: llmEditorContext
                    )
                    guard isCaptureSessionActive(sessionID) else {
                        return
                    }
                    transcript = intelligenceResult.insertedText
                    rawModelResponse = intelligenceResult.rawModelResponse
                    modelPrompt = combinedDiagnosticSection(
                        existing: modelPrompt,
                        additionLabel: "Text Intelligence Prompt",
                        addition: intelligenceResult.promptSentToModel
                    )
                    modelTransportLog = combinedDiagnosticSection(
                        existing: modelTransportLog,
                        additionLabel: "Text Intelligence Transport",
                        addition: intelligenceResult.transportLog
                    )
                    aiSucceeded = true
                } catch {
                    print("Intelligence processing failed: \(error.frispeakReadableMessage)")
                    if let diagnostic = error as? IntelligenceFailureDiagnostic {
                        modelPrompt = combinedDiagnosticSection(
                            existing: modelPrompt,
                            additionLabel: "Text Intelligence Prompt",
                            addition: diagnostic.promptSentToModel
                        )
                        modelTransportLog = combinedDiagnosticSection(
                            existing: modelTransportLog,
                            additionLabel: "Text Intelligence Transport",
                            addition: diagnostic.transportLog
                        )
                    }
                    aiErrorMessage = error.frispeakReadableMessage
                }
            }
            
            var finalText = transcript
            var insertionModelResponse = rawModelResponse
            var insertionPrompt = modelPrompt
            var insertionTransportLog = modelTransportLog

            if let editorContext {
                do {
                    let adaptedResult = try await adaptTextForInsertionWithTimeout(
                        text: finalText,
                        editorContext: editorContext,
                        userPrompt: intelligencePrompt
                    )
                    guard isCaptureSessionActive(sessionID) else {
                        return
                    }

                    finalText = adaptedResult.insertedText
                    insertionModelResponse = combinedDiagnosticSection(
                        existing: rawModelResponse,
                        additionLabel: "Insertion Adaptation Response",
                        addition: adaptedResult.rawModelResponse
                    )
                    insertionPrompt = combinedDiagnosticSection(
                        existing: modelPrompt,
                        additionLabel: "Insertion Adaptation Prompt",
                        addition: adaptedResult.promptSentToModel
                    )
                    insertionTransportLog = combinedDiagnosticSection(
                        existing: modelTransportLog,
                        additionLabel: "Insertion Adaptation Transport",
                        addition: adaptedResult.transportLog
                    )
                } catch {
                    print("Insertion adaptation failed: \(error.frispeakReadableMessage)")
                    finalText = editorContext.formatForInsertion(finalText)
                    insertionPrompt = combinedDiagnosticSection(
                        existing: modelPrompt,
                        additionLabel: "Insertion Adaptation Error",
                        addition: error.frispeakReadableMessage
                    )
                }
            }

            lastTranscript = finalText
            appendHistoryEntry(
                rawTranscript: rawTranscript,
                finalText: finalText,
                editorContext: editorContext,
                aiAttempted: aiAttempted,
                aiSucceeded: aiSucceeded,
                effectiveInstructions: effectiveInstructionsForCurrentMode(),
                rawModelResponse: insertionModelResponse,
                modelPrompt: insertionPrompt,
                historyAudioFilename: historyAudioFilename,
                modelTransportLog: insertionTransportLog,
                aiErrorMessage: aiErrorMessage
            )

            let insertedText: String
            if let ctx = editorContext {
                insertedText = ctx.formatForInsertion(finalText)
            } else {
                insertedText = fallbackInsertionTextWithoutContext(from: finalText)
            }

            guard !insertedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if isCaptureSessionActive(sessionID) {
                    hudController.hide()
                    captureState = .idle
                }
                return
            }

            guard isCaptureSessionActive(sessionID) else {
                return
            }
            captureState = .injecting
            hudController.show(text: "Inserting text", state: .injecting)
            try await textInserter.insert(text: insertedText)

            guard isCaptureSessionActive(sessionID) else {
                return
            }
            hudController.hide(after: 0.6)
            captureState = .idle
        } catch {
            restoreSystemVolumeAfterListeningIfNeeded()
            showError(error.localizedDescription)
        }
    }

    func startTestCapture() async {
        guard await prepareForCapture(requiresAccessibility: false) else {
            return
        }

        guard testCaptureState == .idle, captureState == .idle else {
            return
        }

        do {
            lastError = nil
            testCaptureState = .recording
            try await audioRecorder.start()
        } catch {
            testCaptureState = .idle
            showError(error.localizedDescription)
        }
    }

    func stopTestCapture() async {
        guard testCaptureState == .recording else {
            return
        }

        do {
            testCaptureState = .transcribing
            let recordingURL = try await audioRecorder.stop()
            let transcript = try await transcriber.transcribeFile(at: recordingURL)
            lastTranscript = transcript
            testCaptureState = .idle
        } catch {
            testCaptureState = .idle
            showError(error.localizedDescription)
        }
    }

    private func installHotkeyMonitor() {
        hotkeyMonitor?.invalidate()
        hotkeyMonitor = nil

        hotkeyMonitor = HotkeyMonitor(hotkey: hotkey) { [weak self] isPressed in
            guard let self else { return }
            Task { @MainActor in
                guard self.testCaptureState == .idle else {
                    return
                }

                if isPressed {
                    await self.startCapture(forceRestart: true)
                } else {
                    await self.stopCapture()
                }
            }
        }
    }

    private func updateHUDForNetworkChange(isOnline: Bool) {
        switch captureState {
        case .listening:
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown App"
            let detail = isOnline ? appName : "\(appName) — Offline"
            hudController.show(text: "Listening", detail: detail, state: .listening)
        case .transcribing:
            if !isOnline || dictationMode != .remote {
                hudController.show(text: "Transcribing locally", state: .transcribing)
            }
        default:
            break
        }
    }

    private func showError(_ message: String) {
        restoreSystemVolumeAfterListeningIfNeeded()
        lastError = message
        captureState = .error(message)
        hudController.show(text: message, state: .error)
        hudController.hide(after: 2.0)
    }

    private func prepareForCapture(requiresAccessibility: Bool) async -> Bool {
        if requiresAccessibility {
            if !permissionStatus.allRequiredGranted {
                permissionStatus = await permissionsManager.requestMissingPermissions(promptForAccessibility: false)
                guard permissionStatus.allRequiredGranted else {
                    showError("FriSpeak needs microphone, speech recognition, and accessibility permissions.")
                    return false
                }
            }
        } else {
            if !permissionStatus.microphone || !permissionStatus.speechRecognition {
                permissionStatus = await permissionsManager.requestMissingPermissions(promptForAccessibility: false)
                guard permissionStatus.microphone && permissionStatus.speechRecognition else {
                    showError("FriSpeak needs microphone and speech recognition permissions for transcription testing.")
                    return false
                }
            }
        }

        return true
    }

    private func appendHistoryEntry(
        rawTranscript: String,
        finalText: String,
        editorContext: FocusedTextContext?,
        aiAttempted: Bool,
        aiSucceeded: Bool,
        effectiveInstructions: String,
        rawModelResponse: String?,
        modelPrompt: String?,
        historyAudioFilename: String?,
        modelTransportLog: String?,
        aiErrorMessage: String?
    ) {
        history.insert(
            CaptureHistoryEntry(
                timestamp: Date(),
                applicationName: editorContext?.applicationName,
                aiAttempted: aiAttempted,
                aiSucceeded: aiSucceeded,
                effectiveInstructions: effectiveInstructions,
                modelPrompt: modelPrompt,
                rawModelResponse: rawModelResponse,
                rawTranscript: rawTranscript,
                finalInsertedText: finalText,
                focusedFieldExcerpt: editorContext?.fullTextExcerpt,
                focusedFieldWasTruncated: editorContext?.hasOmittedFullText ?? false,
                textBeforeSelectionExcerpt: editorContext?.textBeforeSelectionExcerpt,
                textBeforeSelectionWasTruncated: editorContext?.hasOmittedTextBeforeSelection ?? false,
                selectedText: editorContext?.selectedText,
                textAfterSelectionExcerpt: editorContext?.textAfterSelectionExcerpt,
                textAfterSelectionWasTruncated: editorContext?.hasOmittedTextAfterSelection ?? false,
                historyAudioFilename: historyAudioFilename,
                modelTransportLog: modelTransportLog,
                aiErrorMessage: aiErrorMessage
            ),
            at: 0
        )
        trimHistory()
    }

    private func trimHistory() {
        let limit = min(max(historyRetentionLimit, 1), 1_000)
        if history.count > limit {
            history.removeLast(history.count - limit)
        }
        pruneHistoryAudioFiles()
        preferences.save(history: history)
    }

    func historyAudioURL(for entry: CaptureHistoryEntry) -> URL? {
        guard let filename = entry.historyAudioFilename else {
            return nil
        }

        return historyAudioStore.url(for: filename)
    }

    private func processTextIntelligenceWithTimeout(
        transcript: String,
        editorContext: FocusedTextContext?
    ) async throws -> IntelligenceProcessingResult {
        let configuration = currentIntelligenceConfiguration()
        let warningMessage = configuration.backend == .appleIntelligence
            ? "Apple Intelligence is taking longer than expected"
            : "OpenRouter is taking longer than expected"
        let timeoutMessage = configuration.backend == .appleIntelligence
            ? "Apple Intelligence request timed out after 30 seconds."
            : "Intelligence request timed out after 30 seconds."

        let warningTask = Task { @MainActor [hudController] in
            try? await Task.sleep(nanoseconds: intelligenceWarningDelayNanoseconds)
            guard !Task.isCancelled else { return }
            hudController.show(text: warningMessage, state: .transcribing)
        }

        let workTask = Task<IntelligenceProcessingResult, Error> {
            try await intelligenceService.processText(
                transcript,
                withPrompt: intelligencePrompt,
                editorContext: editorContext,
                configuration: configuration
            )
        }
        let taskToken = UUID()
        activeIntelligenceTaskToken = taskToken
        activeIntelligenceTask = workTask

        defer {
            warningTask.cancel()
            workTask.cancel()
            if activeIntelligenceTaskToken == taskToken {
                activeIntelligenceTask = nil
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func resume(with result: Result<IntelligenceProcessingResult, Error>) {
                lock.lock()
                let shouldResume = !resumed
                resumed = true
                lock.unlock()
                if shouldResume {
                    continuation.resume(with: result)
                }
            }

            Task {
                do {
                    let result = try await workTask.value
                    resume(with: .success(result))
                } catch {
                    resume(with: .failure(error))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: openRouterTimeoutNanoseconds)
                workTask.cancel()
                resume(with: .failure(
                    IntelligenceError.remoteError(timeoutMessage)
                ))
            }
        }
    }

    private func processLocalGenerativeTranscriptionWithTimeout(
        audioURL: URL,
        prompt: String
    ) async throws -> String {
        let timeoutNanoseconds: UInt64 = 5 * 60 * 1_000_000_000
        let warningTask = Task { @MainActor [hudController] in
            try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            hudController.show(text: "Loading or running local speech model", state: .transcribing)
        }

        let workTask = Task<String, Error> {
            try await localQwenTranscriber.transcribeFile(
                at: audioURL,
                backend: localSpeechBackend,
                prompt: prompt
            )
        }

        defer {
            warningTask.cancel()
            workTask.cancel()
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func resume(with result: Result<String, Error>) {
                lock.lock()
                let shouldResume = !resumed
                resumed = true
                lock.unlock()
                if shouldResume {
                    continuation.resume(with: result)
                }
            }

            Task {
                do {
                    resume(with: .success(try await workTask.value))
                } catch {
                    resume(with: .failure(error))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                workTask.cancel()
                resume(with: .failure(
                    IntelligenceError.remoteError("Local speech transcription timed out after 300 seconds.")
                ))
            }
        }
    }

    private func processRemoteAudioTranscriptionWithTimeout(
        audioURL: URL,
        editorContext: FocusedTextContext?
    ) async throws -> IntelligenceProcessingResult {
        let configuration = IntelligenceConfiguration(
            backend: .openRouter,
            openRouterAPIKey: openRouterAPIKey,
            openRouterModel: openRouterModel,
            useBuiltInPrompting: false
        )

        let warningTask = Task { @MainActor [hudController] in
            try? await Task.sleep(nanoseconds: intelligenceWarningDelayNanoseconds)
            guard !Task.isCancelled else { return }
            hudController.show(text: "Model audio processing is taking longer than expected", state: .transcribing)
        }

        let workTask = Task<IntelligenceProcessingResult, Error> {
            try await intelligenceService.processAudioFile(
                at: audioURL,
                withPrompt: "",
                editorContext: editorContext,
                configuration: configuration
            )
        }
        let taskToken = UUID()
        activeIntelligenceTaskToken = taskToken
        activeIntelligenceTask = workTask

        defer {
            warningTask.cancel()
            workTask.cancel()
            if activeIntelligenceTaskToken == taskToken {
                activeIntelligenceTask = nil
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func resume(with result: Result<IntelligenceProcessingResult, Error>) {
                lock.lock()
                let shouldResume = !resumed
                resumed = true
                lock.unlock()
                if shouldResume {
                    continuation.resume(with: result)
                }
            }

            Task {
                do {
                    let result = try await workTask.value
                    resume(with: .success(result))
                } catch {
                    resume(with: .failure(error))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: self.openRouterTimeoutNanoseconds)
                workTask.cancel()
                resume(with: .failure(
                    IntelligenceError.remoteError("Intelligence request timed out after 30 seconds.")
                ))
            }
        }
    }

    private func adaptTextForInsertionWithTimeout(
        text: String,
        editorContext: FocusedTextContext,
        userPrompt: String
    ) async throws -> IntelligenceProcessingResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return IntelligenceProcessingResult(
                insertedText: "",
                rawModelResponse: "",
                promptSentToModel: "",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        let configuration = IntelligenceConfiguration(
            backend: insertionAdaptationBackend,
            openRouterAPIKey: openRouterAPIKey,
            openRouterModel: openRouterModel,
            useBuiltInPrompting: builtInIntelligencePromptingEnabled
        )

        guard configuration.backend != .none else {
            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(trimmedText),
                rawModelResponse: "",
                promptSentToModel: "",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        if editorContext.lacksUsableVisibleBoundaryContext {
            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(trimmedText),
                rawModelResponse: "",
                promptSentToModel: "Skipped insertion adaptation because the editor exposed hidden surrounding text without usable visible boundary context.",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        if editorContext.shouldSkipModelInsertionAdaptation {
            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(trimmedText),
                rawModelResponse: "",
                promptSentToModel: "Skipped insertion adaptation because the caret boundary is straightforward enough for local formatting.",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        if configuration.backend == .none {
            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(trimmedText),
                rawModelResponse: "",
                promptSentToModel: "Skipped insertion adaptation and used local caret fitting.",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        guard configuration.hasUsableOpenRouterConfiguration else {
            return IntelligenceProcessingResult(
                insertedText: editorContext.formatForInsertion(trimmedText),
                rawModelResponse: "",
                promptSentToModel: "",
                audioDebugSourceURL: nil,
                transportLog: nil
            )
        }

        let timeoutNanoseconds = openRouterTimeoutNanoseconds
        let timeoutSeconds = 30

        let workTask = Task<IntelligenceProcessingResult, Error> {
            try await intelligenceService.adaptTextForInsertion(
                trimmedText,
                editorContext: editorContext,
                userPrompt: userPrompt,
                configuration: configuration
            )
        }
        let taskToken = UUID()
        activeIntelligenceTaskToken = taskToken
        activeIntelligenceTask = workTask

        defer {
            workTask.cancel()
            if activeIntelligenceTaskToken == taskToken {
                activeIntelligenceTask = nil
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let lock = NSLock()

            func resume(with result: Result<IntelligenceProcessingResult, Error>) {
                lock.lock()
                let shouldResume = !resumed
                resumed = true
                lock.unlock()
                if shouldResume {
                    continuation.resume(with: result)
                }
            }

            Task {
                do {
                    let result = try await workTask.value
                    resume(with: .success(result))
                } catch {
                    resume(with: .failure(error))
                }
            }

            Task {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                workTask.cancel()
                resume(with: .failure(
                    IntelligenceError.remoteError("Insertion adaptation timed out after \(timeoutSeconds) seconds.")
                ))
            }
        }
    }

    private func combinedDiagnosticSection(
        existing: String?,
        additionLabel: String,
        addition: String?
    ) -> String? {
        let trimmedAddition = addition?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedAddition.isEmpty else {
            return existing
        }

        let trimmedExisting = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedExisting.isEmpty else {
            return "\(additionLabel):\n\(trimmedAddition)"
        }

        return "\(trimmedExisting)\n\n\(additionLabel):\n\(trimmedAddition)"
    }

    private func normalizedInstructions(from prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No additional instructions." : trimmed
    }

    private func currentIntelligenceConfiguration() -> IntelligenceConfiguration {
        IntelligenceConfiguration(
            backend: activeTextIntelligenceBackend,
            openRouterAPIKey: openRouterAPIKey,
            openRouterModel: openRouterModel,
            useBuiltInPrompting: builtInIntelligencePromptingEnabled
        )
    }

    private func localGenerativeTranscriptionPrompt() -> String {
        guard dictationMode == .localGenerative else {
            return ""
        }

        // When a separate intelligence model is active, keep the speech stage focused on transcription.
        guard !intelligenceFeaturesEnabled else {
            return ""
        }

        var parts = [String]()
        if builtInIntelligencePromptingEnabled {
            parts.append("""
            Clean up the dictated speech while transcribing.
            Remove filler words like um, uh, and ah when they do not carry meaning.
            Fix obvious grammar, casing, and punctuation.
            Return only the final text.
            """)
        }

        let trimmedPrompt = intelligencePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPrompt.isEmpty {
            parts.append(trimmedPrompt)
        }

        return parts.joined(separator: "\n\n")
    }

    private func effectiveInstructionsForCurrentMode() -> String {
        var sections = ["Speech Model: \(dictationMode.title)"]

        if dictationMode == .localGenerative {
            sections.append(localQwenPromptSummary())
        }

        if intelligenceFeaturesEnabled {
            let builtInLabel = builtInIntelligencePromptingEnabled ? "Built-in cleanup enabled." : "Built-in cleanup disabled."
            sections.append("Intelligence Model: \(intelligenceModel.title). \(builtInLabel) Prompt: \(normalizedInstructions(from: intelligencePrompt))")
        } else {
            sections.append("Intelligence features disabled.")
        }

        return sections.joined(separator: " ")
    }

    private func localQwenPromptSummary() -> String {
        let normalized = normalizedInstructions(from: localGenerativeTranscriptionPrompt())
        if normalized == "No additional instructions." {
            return "\(localSpeechBackend.detailTitle) transcription."
        }

        return "\(localSpeechBackend.detailTitle) transcription. Prompt instructions require the text intelligence step: \(normalized)"
    }

    private var textIntelligenceHUDTitle: String {
        switch intelligenceModel {
        case .apple:
            return "Processing with Apple Intelligence"
        case .local:
            return "Processing with Local Bonsai"
        case .remote:
            return "Processing with OpenRouter"
        }
    }

    private var insertionAdaptationBackend: IntelligenceBackend {
        guard cursorAwarenessEnabled else {
            return .none
        }

        switch intelligenceModel {
        case .apple:
            return canUseAppleIntelligence ? .appleIntelligence : .none
        case .local:
            return canUseLocalIntelligence ? .localMLX : .none
        case .remote:
            return canUseRemoteIntelligence ? .openRouter : .none
        }
    }

    private func textIntelligenceEditorContext(from editorContext: FocusedTextContext?) -> FocusedTextContext? {
        guard cursorAwarenessEnabled, canUseCursorAwarenessForIntelligence else {
            return nil
        }

        switch intelligenceModel {
        case .apple:
            // Apple Intelligence is more reliable when it only sees the dictated
            // text during cleanup. We still use cursor-aware insertion adaptation
            // later in the pipeline.
            return nil
        case .local:
            return nil
        case .remote:
            return editorContext
        }
    }

    private func fallbackInsertionTextWithoutContext(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return trimmed
        }

        if first.isLetter || first.isNumber || first == "\"" || first == "'" || first == "(" {
            return " " + trimmed
        }

        return trimmed
    }

    private func beginCaptureSession() -> Int {
        captureSessionID += 1
        return captureSessionID
    }

    private func isCaptureSessionActive(_ sessionID: Int) -> Bool {
        captureSessionID == sessionID
    }

    func cancelCapture() async {
        guard captureState != .idle else { return }
        await invalidateCurrentCaptureSession()
    }

    private func invalidateCurrentCaptureSession() async {
        captureSessionID += 1
        activeIntelligenceTask?.cancel()
        activeIntelligenceTask = nil
        restoreSystemVolumeAfterListeningIfNeeded()

        if captureState == .listening {
            await audioRecorder.cancel()
        }

        hudController.hide()
        captureState = .idle
    }

    private func applyListeningVolumeDimIfNeeded() {
        guard dimSystemAudioWhileListeningEnabled else { return }
        guard capturedSystemVolumeBeforeListening == nil else { return }

        do {
            let currentVolume = try systemVolumeController.currentOutputVolume()
            capturedSystemVolumeBeforeListening = currentVolume
            try systemVolumeController.setOutputVolume(Float32(dimSystemAudioTargetVolume))
        } catch {
            capturedSystemVolumeBeforeListening = nil
            print("Failed to dim system audio while listening: \(error)")
        }
    }

    private func restoreSystemVolumeAfterListeningIfNeeded() {
        guard let originalVolume = capturedSystemVolumeBeforeListening else { return }
        capturedSystemVolumeBeforeListening = nil

        do {
            try systemVolumeController.setOutputVolume(originalVolume)
        } catch {
            print("Failed to restore system audio volume: \(error)")
        }
    }

    private func refreshOpenRouterModelCapabilities() async {
        let trimmedAPIKey = openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = openRouterModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty, !trimmedModel.isEmpty else {
            openRouterModelSupportsAudioInput = false
            openRouterCapabilityStatus = "Enter an API key and model to inspect capabilities."
            return
        }

        openRouterCapabilityStatus = "Checking model capabilities..."

        do {
            let capabilities = try await intelligenceService.fetchOpenRouterModelCapabilities(
                apiKey: trimmedAPIKey,
                modelID: trimmedModel
            )
            openRouterModelSupportsAudioInput = capabilities.supportsAudioInput
            openRouterCapabilityStatus = capabilities.supportsAudioInput
                ? "This model reports audio input support."
                : "This model does not report audio input support."
        } catch {
            openRouterModelSupportsAudioInput = false
            openRouterCapabilityStatus = "Could not load model capabilities."
        }
    }

    private func persistHistoryAudioIfNeeded(from sourceURL: URL) -> String? {
        guard historyAudioLoggingEnabled else {
            return nil
        }

        return try? historyAudioStore.storeAudioFile(at: sourceURL)
    }

    private func pruneHistoryAudioFiles() {
        let referencedFilenames = Set(history.compactMap(\.historyAudioFilename))
        historyAudioStore.removeUnreferencedAudio(retaining: referencedFilenames)
    }

    private func clearHistoryAudioReferences() {
        history = history.map { entry in
            CaptureHistoryEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                applicationName: entry.applicationName,
                aiAttempted: entry.aiAttempted,
                aiSucceeded: entry.aiSucceeded,
                effectiveInstructions: entry.effectiveInstructions,
                modelPrompt: entry.modelPrompt,
                rawModelResponse: entry.rawModelResponse,
                rawTranscript: entry.rawTranscript,
                finalInsertedText: entry.finalInsertedText,
                focusedFieldExcerpt: entry.focusedFieldExcerpt,
                focusedFieldWasTruncated: entry.focusedFieldWasTruncated,
                textBeforeSelectionExcerpt: entry.textBeforeSelectionExcerpt,
                textBeforeSelectionWasTruncated: entry.textBeforeSelectionWasTruncated,
                selectedText: entry.selectedText,
                textAfterSelectionExcerpt: entry.textAfterSelectionExcerpt,
                textAfterSelectionWasTruncated: entry.textAfterSelectionWasTruncated,
                historyAudioFilename: nil,
                modelTransportLog: entry.modelTransportLog,
                aiErrorMessage: entry.aiErrorMessage
            )
        }
        preferences.save(history: history)
    }
}

enum CaptureState: Equatable {
    case idle
    case listening
    case transcribing
    case injecting
    case error(String)
}

struct PermissionStatus: Equatable {
    var microphone = false
    var speechRecognition = false
    var accessibility = false

    static let unknown = PermissionStatus()

    var allRequiredGranted: Bool {
        microphone && speechRecognition && accessibility
    }
}

enum TestCaptureState: Equatable {
    case idle
    case recording
    case transcribing
}

struct CaptureHistoryEntry: Identifiable, Equatable, Codable {
    let id: UUID
    let timestamp: Date
    let applicationName: String?
    let aiAttempted: Bool
    let aiSucceeded: Bool
    let effectiveInstructions: String
    let modelPrompt: String?
    let rawModelResponse: String?
    let rawTranscript: String
    let finalInsertedText: String
    let focusedFieldExcerpt: String?
    let focusedFieldWasTruncated: Bool
    let textBeforeSelectionExcerpt: String?
    let textBeforeSelectionWasTruncated: Bool
    let selectedText: String?
    let textAfterSelectionExcerpt: String?
    let textAfterSelectionWasTruncated: Bool
    let historyAudioFilename: String?
    let modelTransportLog: String?
    let aiErrorMessage: String?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        applicationName: String?,
        aiAttempted: Bool,
        aiSucceeded: Bool,
        effectiveInstructions: String,
        modelPrompt: String?,
        rawModelResponse: String?,
        rawTranscript: String,
        finalInsertedText: String,
        focusedFieldExcerpt: String?,
        focusedFieldWasTruncated: Bool,
        textBeforeSelectionExcerpt: String?,
        textBeforeSelectionWasTruncated: Bool,
        selectedText: String?,
        textAfterSelectionExcerpt: String?,
        textAfterSelectionWasTruncated: Bool,
        historyAudioFilename: String?,
        modelTransportLog: String?,
        aiErrorMessage: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.applicationName = applicationName
        self.aiAttempted = aiAttempted
        self.aiSucceeded = aiSucceeded
        self.effectiveInstructions = effectiveInstructions
        self.modelPrompt = modelPrompt
        self.rawModelResponse = rawModelResponse
        self.rawTranscript = rawTranscript
        self.finalInsertedText = finalInsertedText
        self.focusedFieldExcerpt = focusedFieldExcerpt
        self.focusedFieldWasTruncated = focusedFieldWasTruncated
        self.textBeforeSelectionExcerpt = textBeforeSelectionExcerpt
        self.textBeforeSelectionWasTruncated = textBeforeSelectionWasTruncated
        self.selectedText = selectedText
        self.textAfterSelectionExcerpt = textAfterSelectionExcerpt
        self.textAfterSelectionWasTruncated = textAfterSelectionWasTruncated
        self.historyAudioFilename = historyAudioFilename
        self.modelTransportLog = modelTransportLog
        self.aiErrorMessage = aiErrorMessage
    }

    var debugDump: String {
        """
        Timestamp: \(timestamp)
        Application: \(applicationName ?? "Unknown")
        AI Attempted: \(aiAttempted ? "Yes" : "No")
        AI Succeeded: \(aiSucceeded ? "Yes" : "No")
        Effective Instructions:
        \(effectiveInstructions)

        Prompt Sent To Model:
        \(modelPrompt ?? "Unavailable")

        Raw Model Response:
        \(rawModelResponse ?? "Unavailable")

        Model Transport Log:
        \(modelTransportLog ?? "Unavailable")

        AI Error:
        \(aiErrorMessage ?? "Unavailable")

        Raw Transcript:
        \(rawTranscript)

        Logged Audio File:
        \(historyAudioFilename ?? "Unavailable")

        Inserted Text:
        \(finalInsertedText)

        Focused Field Excerpt:
        \(focusedFieldExcerpt ?? "Unavailable")

        Focused Field Was Truncated:
        \(focusedFieldWasTruncated ? "Yes" : "No")

        Text Before Selection Excerpt:
        \(textBeforeSelectionExcerpt ?? "Unavailable")

        Text Before Selection Was Truncated:
        \(textBeforeSelectionWasTruncated ? "Yes" : "No")

        Selected Text:
        \(selectedText ?? "Unavailable")

        Text After Selection Excerpt:
        \(textAfterSelectionExcerpt ?? "Unavailable")

        Text After Selection Was Truncated:
        \(textAfterSelectionWasTruncated ? "Yes" : "No")
        """
    }
}
