//
//  DashboardView.swift
//  FriSpeak
//

import AVFoundation
import Combine
import SwiftUI
import Carbon.HIToolbox

private let intelligencePromptPlaceholder = """
Optional extra instructions, for example:
• Keep it terse
• Make it slightly more professional
• Format as a short bullet
• Translate to Spanish
• Convert to sentence case
"""

private let builtInPromptingSummary = "Use FriSpeak's built-in cleanup instructions to remove filler words like um and ah, fix obvious grammar and punctuation, and keep the speaker's meaning intact."

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                SettingsView()
            } else {
                OnboardingFlowView()
            }
        }
        .frame(minWidth: 650, minHeight: 450)
    }
}

// MARK: - Settings View (Main Dashboard)

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: SettingsTab = .general
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        selectedTab = tab
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .intelligence:
                    IntelligenceSettingsView()
                case .history:
                    HistoryView()
                case .about:
                    AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(tab.title, systemImage: tab.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .background(backgroundFill)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .foregroundStyle(isSelected ? Color.primary : (isHovered ? Color.primary : Color.secondary))
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.14)
                    : (isHovered ? Color.secondary.opacity(0.12) : Color.clear)
            )
    }
}

private enum SettingsTab: CaseIterable, Identifiable {
    case general
    case intelligence
    case history
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .intelligence:
            return "Configuration"
        case .history:
            return "History"
        case .about:
            return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .intelligence:
            return "switch.2"
        case .history:
            return "text.page.badge.magnifyingglass"
        case .about:
            return "info.circle"
        }
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Image(systemName: appState.statusItemSymbolName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(appState.captureState == .idle ? Color.accentColor : Color.orange)
                            .symbolEffect(.pulse, isActive: appState.captureState != .idle)
                            .frame(width: 40, height: 40)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 4) {
                            Label("General", systemImage: "slider.horizontal.3")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("FriSpeak")
                                .font(.title2.weight(.bold))
                            Text(appState.statusSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        GeneralMetricCard(
                            title: "Shortcut",
                            value: appState.hotkey.displayLabel,
                            symbol: "command"
                        )
                        GeneralMetricCard(
                            title: "Mode",
                            value: appState.dictationMode.title,
                            symbol: "brain.head.profile"
                        )
                        GeneralMetricCard(
                            title: "Path",
                            value: processingPathLabel,
                            symbol: appState.dictationMode.systemImage
                        )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    Label("Push-to-Talk Shortcut", systemImage: "command.square")
                        .font(.headline)

                    Text("Hold this shortcut to record your voice, then release to transcribe and insert the text.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HotkeyEditor(hotkey: $appState.hotkey)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    Label("Last Transcription", systemImage: "waveform.badge.mic")
                        .font(.headline)

                    if appState.lastTranscript.isEmpty {
                        Text("Your most recent transcription will appear here after a capture.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(appState.lastTranscript)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    Label("Actions", systemImage: "bolt.horizontal.circle")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button {
                            appState.reopenOnboarding()
                        } label: {
                            Label("Run Setup Again", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            NSApp.terminate(nil)
                        } label: {
                            Label("Quit FriSpeak", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 14) {
                    Label("Listening Audio", systemImage: "speaker.wave.2")
                        .font(.headline)

                    Toggle("Dim System Audio While Listening", isOn: $appState.dimSystemAudioWhileListeningEnabled)
                        .disabled(!appState.canControlSystemOutputVolume)

                    if appState.canControlSystemOutputVolume {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Listening Volume")
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text("\(Int((appState.dimSystemAudioTargetVolume * 100).rounded()))%")
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $appState.dimSystemAudioTargetVolume, in: 0...1)
                                .disabled(!appState.dimSystemAudioWhileListeningEnabled)

                            Text("FriSpeak will temporarily lower the current output-device volume while the push-to-talk key is held, then restore it when listening ends.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .opacity(appState.dimSystemAudioWhileListeningEnabled ? 1 : 0.65)
                    } else {
                        Text("This Mac's current output device does not expose a controllable master volume to FriSpeak.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 14) {
                    Label("System", systemImage: "macwindow.badge.plus")
                        .font(.headline)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Startup")
                                .font(.body.weight(.medium))
                            Text("Automatically start FriSpeak when you log in.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Toggle("", isOn: $appState.launchAtStartupEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                            
                            #if DEBUG
                            Text("Disabled in Debug")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                            #endif
                        }
                        #if DEBUG
                        .disabled(true)
                        #endif
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(20)
        }
    }

    private var processingPathLabel: String {
        switch appState.dictationMode {
        case .localNative:
            return "Apple ASR"
        case .localGenerative:
            return "Qwen3-ASR"
        case .remote:
            return "OpenRouter"
        }
    }
}

private struct GeneralMetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Intelligence Settings

private struct IntelligenceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ConfigurationOverviewCard()
                    SpeechConfigurationCard()
                    IntelligenceFeaturesConfigurationCard()
                }
                .padding(20)
            }
            .frame(minWidth: 420, idealWidth: 620, maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    OpenRouterConfigurationCard()
                }
                .padding(20)
            }
            .frame(minWidth: 320, idealWidth: 420, maxWidth: 520, maxHeight: .infinity)
        }
        .background(Color.secondary.opacity(0.04))
    }
}

private struct ConfigurationOverviewCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Configuration", systemImage: "switch.2")
                .font(.title3.weight(.semibold))

            Text("Choose a speech pipeline, configure OpenRouter once, then optionally layer intelligence on top for cleanup and rewriting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                GeneralMetricCard(
                    title: "Speech",
                    value: appState.dictationMode.title,
                    symbol: appState.dictationMode.systemImage
                )
                GeneralMetricCard(
                    title: "Intelligence",
                    value: appState.intelligenceFeaturesEnabled ? appState.intelligenceModel.title : "Disabled",
                    symbol: appState.intelligenceFeaturesEnabled ? appState.intelligenceModel.systemImage : "sparkles.slash"
                )
                GeneralMetricCard(
                    title: "OpenRouter",
                    value: appState.hasConfiguredOpenRouter ? "Configured" : "Not Set Up",
                    symbol: "network"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SpeechConfigurationCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Speech Model")
                .font(.headline)

            Text("Pick the pipeline that handles transcription before any optional intelligence pass.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                SpeechModeOptionButton(
                    title: DictationMode.localNative.title,
                    summary: "Apple Speech Recognition on device",
                    icon: DictationMode.localNative.systemImage,
                    isSelected: appState.dictationMode == .localNative,
                    isDisabled: false
                ) {
                    appState.dictationMode = .localNative
                }

                SpeechModeOptionButton(
                    title: DictationMode.localGenerative.title,
                    summary: "Qwen3-ASR-1.7B through speech-swift",
                    icon: DictationMode.localGenerative.systemImage,
                    isSelected: appState.dictationMode == .localGenerative,
                    isDisabled: false
                ) {
                    appState.dictationMode = .localGenerative
                }

                SpeechModeOptionButton(
                    title: DictationMode.remote.title,
                    summary: appState.hasConfiguredOpenRouter ? "OpenRouter speech pipeline" : "Requires OpenRouter setup below",
                    icon: DictationMode.remote.systemImage,
                    isSelected: appState.dictationMode == .remote,
                    isDisabled: !appState.hasConfiguredOpenRouter
                ) {
                    appState.dictationMode = .remote
                }
            }

            if appState.dictationMode == .localGenerative {
                LocalGenerativeModelSection()
            } else if appState.dictationMode == .localNative {
                Text("Apple native speech runs fully on-device and inserts the local transcript directly unless a separate intelligence model is enabled below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !appState.hasConfiguredOpenRouter {
                Text("Remote speech is unavailable until OpenRouter is configured.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct LocalGenerativeModelSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task {
                    await appState.downloadLocalQwenModel()
                }
            } label: {
                Label(
                    appState.localQwenModelCached ? "Redownload Local Model" : "Download Local Model",
                    systemImage: appState.localQwenDownloadInProgress ? "arrow.down.circle.fill" : "square.and.arrow.down"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.localQwenDownloadInProgress)

            if appState.localQwenDownloadInProgress {
                ProgressView(value: appState.localQwenDownloadProgress)
                Text(appState.localQwenDownloadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if appState.localQwenPreloadInProgress {
                ProgressView()
                Text(appState.localQwenDownloadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(appState.localQwenModelCached ? "Model cached locally and ready." : "Model is not downloaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let localQwenLastError = appState.localQwenLastError, !localQwenLastError.isEmpty {
                Text(localQwenLastError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("If intelligence is disabled below, FriSpeak feeds the prompt area directly into the local Qwen speech model.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OpenRouterConfigurationCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OpenRouter")
                .font(.headline)

            OpenRouterAPIKeyHelp()

            SecureField("OpenRouter API key", text: $appState.openRouterAPIKey)
                .textFieldStyle(.roundedBorder)

            OpenRouterModelPicker(model: $appState.openRouterModel)

            Text("The selected OpenRouter model is used for remote speech mode and, when enabled below, remote intelligence features.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: appState.openRouterModelSupportsAudioInput ? "waveform.badge.mic" : "info.circle")
                        .foregroundStyle(appState.openRouterModelSupportsAudioInput ? .green : .secondary)
                    Text(appState.openRouterCapabilityStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(appState.openRouterModelSupportsAudioInput
                     ? "FriSpeak will automatically use direct remote audio transcription for remote speech mode when the selected model supports it."
                     : "If the selected model does not support audio input, FriSpeak falls back to local Apple transcription before any intelligence pass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(appState.openRouterModelSupportsAudioInput ? 0.06 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct LocalBonsaiModelSection: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task {
                    await appState.downloadLocalBonsaiModel()
                }
            } label: {
                Label(
                    appState.localBonsaiModelCached ? "Redownload Local Bonsai Model" : "Download Local Bonsai Model",
                    systemImage: appState.localBonsaiDownloadInProgress ? "arrow.down.circle.fill" : "square.and.arrow.down"
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(appState.localBonsaiDownloadInProgress || appState.localBonsaiCompatibilityIssue != nil)

            if appState.localBonsaiDownloadInProgress {
                ProgressView(value: appState.localBonsaiDownloadProgress)
                Text(appState.localBonsaiDownloadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if appState.localBonsaiPreloadInProgress {
                ProgressView()
                Text(appState.localBonsaiDownloadStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let localBonsaiCompatibilityIssue = appState.localBonsaiCompatibilityIssue {
                Text(localBonsaiCompatibilityIssue)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(appState.localBonsaiModelCached ? "Model cached locally and ready." : "Model is not downloaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let localBonsaiLastError = appState.localBonsaiLastError, !localBonsaiLastError.isEmpty {
                Text(localBonsaiLastError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text("This uses `prism-ml/Bonsai-8B-mlx-1bit` through MLX for fully local text cleanup and prompting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct IntelligenceFeaturesConfigurationCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Intelligence Features")
                .font(.headline)

            Toggle("Enable intelligence features", isOn: $appState.intelligenceFeaturesEnabled)

            Text("Use a second model to clean up the transcript, apply custom prompting, and optionally do context-aware insertion with the selected intelligence model.")
                .font(.caption)
                .foregroundStyle(.secondary)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var content: some View {
        if appState.intelligenceFeaturesEnabled {
            HStack(spacing: 12) {
                IntelligenceModelOptionButton(
                    title: IntelligenceModel.apple.title,
                    summary: appState.appleIntelligenceStatus,
                    icon: IntelligenceModel.apple.systemImage,
                    isSelected: appState.intelligenceModel == .apple,
                    isDisabled: false
                ) {
                    appState.intelligenceModel = .apple
                }

                IntelligenceModelOptionButton(
                    title: IntelligenceModel.local.title,
                    summary: appState.localBonsaiCompatibilityIssue ?? (appState.localBonsaiModelCached ? "Bonsai-8B-mlx-1bit on device" : "Download Bonsai below"),
                    icon: IntelligenceModel.local.systemImage,
                    isSelected: appState.intelligenceModel == .local,
                    isDisabled: appState.localBonsaiCompatibilityIssue != nil
                ) {
                    appState.intelligenceModel = .local
                }

                IntelligenceModelOptionButton(
                    title: IntelligenceModel.remote.title,
                    summary: appState.hasConfiguredOpenRouter ? "Uses the selected OpenRouter model" : "Requires OpenRouter setup above",
                    icon: IntelligenceModel.remote.systemImage,
                    isSelected: appState.intelligenceModel == .remote,
                    isDisabled: !appState.hasConfiguredOpenRouter
                ) {
                    appState.intelligenceModel = .remote
                }
            }

            if appState.intelligenceModel == .apple {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Apple Intelligence works best with simple prompts", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.orange)

                    Text("Keep prompts short and concrete. Apple Intelligence can misinterpret complex instructions, layered formatting requests, or nuanced editing behavior.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if appState.intelligenceModel == .local {
                LocalBonsaiModelSection()
            }

            Toggle("Use built-in cleanup prompting", isOn: $appState.builtInIntelligencePromptingEnabled)

            Text(builtInPromptingSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            intelligencePromptEditor

            if appState.canUseAppleIntelligence || appState.localBonsaiModelCached || appState.hasConfiguredOpenRouter {
                cursorAwarenessSection
            }
        } else {
            Text("With intelligence disabled, FriSpeak inserts the speech transcript directly. In local generative mode, the prompt area is fed into the Qwen speech model instead.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var intelligencePromptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intelligence Prompt")
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $appState.intelligencePrompt)
                    .frame(minHeight: 120)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if appState.intelligencePrompt.isEmpty {
                    Text(intelligencePromptPlaceholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 18)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }

            Text("Use this to steer cleanup, tone, translation, or formatting. With Apple Intelligence, keep the prompt simple. Cursor awareness can now be used with Apple Intelligence, the local Bonsai model, or the remote model.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cursorAwarenessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Use Cursor Location Awareness", isOn: $appState.cursorAwarenessEnabled)
                .disabled(!appState.canUseSelectedIntelligenceModel)

            Text(appState.canUseSelectedIntelligenceModel
                 ? "When enabled, FriSpeak sends nearby text around the caret to the selected intelligence model so it can fit the result more naturally."
                 : "Cursor awareness becomes available when the selected intelligence model is ready.")
                .font(.caption)
                .foregroundStyle(appState.canUseSelectedIntelligenceModel ? Color.secondary : Color.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SpeechModeOptionButton: View {
    let title: String
    let summary: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var backgroundFill: Color {
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }

        return Color.secondary.opacity(0.08)
    }
}

private struct IntelligenceModelOptionButton: View {
    let title: String
    let summary: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }
}

private struct IntelligenceInstructionsPane: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label(headerTitle, systemImage: "text.badge.sparkles")
                    .font(.title3.weight(.semibold))

                Text(headerDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if appState.dictationMode == .remote || appState.dictationMode == .localGenerative {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $appState.intelligencePrompt)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if appState.intelligencePrompt.isEmpty {
                        Text(intelligencePromptPlaceholder)
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 20)
                            .padding(.leading, 18)
                            .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(promptHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label(localModeTitle, systemImage: appState.dictationMode.systemImage)
                        .font(.headline)
                    Text(localModeDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.secondary.opacity(0.04))
    }

    private var headerTitle: String {
        switch appState.dictationMode {
        case .localNative:
            return "Local Native Mode"
        case .localGenerative:
            return "Local Generative Mode"
        case .remote:
            return "OpenRouter Instructions"
        }
    }

    private var headerDescription: String {
        switch appState.dictationMode {
        case .localNative:
            return "Local native mode uses direct Apple Speech Recognition and inserts the local transcript without cloud processing."
        case .localGenerative:
            return "Local generative mode uses the on-device Qwen3-ASR-1.7B model. Prompt instructions are sent directly to the local speech model."
        case .remote:
            return "These instructions are applied before OpenRouter produces the final inserted text."
        }
    }

    private var localModeTitle: String {
        switch appState.dictationMode {
        case .localNative:
            return "Apple Speech on device"
        case .localGenerative:
            return "Qwen3-ASR on device"
        case .remote:
            return "OpenRouter"
        }
    }

    private var localModeDescription: String {
        switch appState.dictationMode {
        case .localNative:
            return "FriSpeak records audio locally, transcribes it with Apple Speech Recognition, and inserts the result directly. Only local caret formatting is applied."
        case .localGenerative:
            return "FriSpeak records audio locally, runs the Qwen3-ASR-1.7B model on-device, and inserts the result directly. Download the local model once before using this mode, then use the prompt box to steer formatting, translation, or cleanup."
        case .remote:
            return ""
        }
    }

    private var promptHelpText: String {
        switch appState.dictationMode {
        case .localNative:
            return ""
        case .localGenerative:
            return "Leave this blank to use the default local transcription behavior, or add local instructions like tone, translation, formatting, or romanization."
        case .remote:
            return "Leave this blank to use the default cleanup behavior, or add extra instructions like tone, translation, or formatting."
        }
    }
}

private struct IntelligenceSidebarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IntelligenceStatusCard()
                IntelligenceProviderCard()
                IntelligenceContextCard()
            }
            .padding(20)
        }
        .background(.background)
    }
}

private struct IntelligenceStatusCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.dictationMode.summary)
                        .font(.headline)
                    Text(appState.intelligenceAvailabilityStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: statusIsHealthy ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(statusIsHealthy ? .green : .orange)
            }

            Text("FriSpeak uses the text already in the focused field, when available through Accessibility, to help the selected model fit the insertion into the current sentence or selection.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusIsHealthy: Bool {
        switch appState.dictationMode {
        case .localNative:
            return true
        case .localGenerative:
            return appState.localQwenModelCached || appState.localQwenDownloadInProgress
        case .remote:
            return appState.canUseRemoteMode
        }
    }
}

private struct IntelligenceProviderCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode")
                .font(.headline)

            Picker("Mode", selection: $appState.dictationMode) {
                ForEach(DictationMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("Choose between Apple’s local speech pipeline, the local Qwen3-ASR model, or remote OpenRouter processing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.dictationMode == .remote {
                OpenRouterAPIKeyHelp()

                SecureField("OpenRouter API key", text: $appState.openRouterAPIKey)
                    .textFieldStyle(.roundedBorder)

                OpenRouterModelPicker(model: $appState.openRouterModel)

                Text("FriSpeak will transcribe speech locally first, then send your instructions, optional caret context, and transcript to OpenRouter. Pick a preset for convenience or choose Custom to paste any model ID.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: appState.openRouterModelSupportsAudioInput ? "waveform.badge.mic" : "info.circle")
                            .foregroundStyle(appState.openRouterModelSupportsAudioInput ? .green : .secondary)
                        Text(appState.openRouterCapabilityStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.openRouterModelSupportsAudioInput
                             ? "FriSpeak automatically sends recorded audio directly to the selected OpenRouter model when it supports audio input."
                             : "FriSpeak will use built-in local Apple transcription first because this OpenRouter model does not report audio input support.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !appState.openRouterModelSupportsAudioInput {
                            Label("Unavailable for the selected model", systemImage: "slash.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(appState.openRouterModelSupportsAudioInput ? 0.06 : 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .opacity(appState.openRouterModelSupportsAudioInput ? 1 : 0.65)
                }
            } else if appState.dictationMode == .localGenerative {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Local Qwen3-ASR-1.7B", systemImage: "cpu")
                        .font(.subheadline.weight(.semibold))
                    Text("This mode runs a local generative speech model on-device through `speech-swift`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await appState.downloadLocalQwenModel()
                        }
                    } label: {
                        Label(
                            appState.localQwenModelCached ? "Redownload Model" : "Download Model",
                            systemImage: appState.localQwenDownloadInProgress ? "arrow.down.circle.fill" : "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.localQwenDownloadInProgress)

                    if appState.localQwenDownloadInProgress {
                        ProgressView(value: appState.localQwenDownloadProgress)
                        Text(appState.localQwenDownloadStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if appState.localQwenPreloadInProgress {
                        ProgressView()
                        Text(appState.localQwenDownloadStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(appState.localQwenModelCached ? "Model cached locally and ready to use." : "Model is not downloaded yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let localQwenLastError = appState.localQwenLastError, !localQwenLastError.isEmpty {
                        Text(localQwenLastError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local Qwen Instructions")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $appState.intelligencePrompt)
                            .frame(height: 110)
                            .font(.body)
                            .border(Color.secondary.opacity(0.3))

                        Text("These instructions are sent to the on-device Qwen transcriber. Example: \"Fix grammar but keep my wording\", \"Keep product names exactly as spoken\", or \"Format as a concise sentence\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("Local native mode keeps transcription on-device through Apple Speech Recognition and does not require an API key, model selection, or network connectivity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Intelligence Model")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 12) {
                    IntelligenceModelOptionButton(
                        title: IntelligenceModel.apple.title,
                        summary: appState.appleIntelligenceStatus,
                        icon: IntelligenceModel.apple.systemImage,
                        isSelected: appState.intelligenceModel == .apple,
                        isDisabled: false
                    ) {
                        appState.intelligenceModel = .apple
                    }

                    IntelligenceModelOptionButton(
                        title: IntelligenceModel.local.title,
                        summary: appState.localBonsaiCompatibilityIssue ?? (appState.localBonsaiModelCached ? "Bonsai-8B-mlx-1bit on device" : "Download required"),
                        icon: IntelligenceModel.local.systemImage,
                        isSelected: appState.intelligenceModel == .local,
                        isDisabled: appState.localBonsaiCompatibilityIssue != nil
                    ) {
                        appState.intelligenceModel = .local
                    }

                    IntelligenceModelOptionButton(
                        title: IntelligenceModel.remote.title,
                        summary: appState.hasConfiguredOpenRouter ? "Uses the selected OpenRouter model" : "Requires OpenRouter setup",
                        icon: IntelligenceModel.remote.systemImage,
                        isSelected: appState.intelligenceModel == .remote,
                        isDisabled: !appState.hasConfiguredOpenRouter
                    ) {
                        appState.intelligenceModel = .remote
                    }
                }

                if appState.intelligenceModel == .local {
                    LocalBonsaiModelSection()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct OpenRouterAPIKeyHelp: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To get an OpenRouter API key, sign in to OpenRouter, create a key in the Keys section, then paste it here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Open OpenRouter Keys") {
                guard let url = URL(string: "https://openrouter.ai/keys") else { return }
                openURL(url)
            }
            .buttonStyle(.link)
            .font(.caption.weight(.semibold))
        }
    }
}

private struct IntelligenceContextCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Context")
                .font(.headline)

            Toggle("Use Cursor Location Awareness", isOn: $appState.cursorAwarenessEnabled)
                .disabled(!appState.canUseSelectedIntelligenceModel)

            if !appState.canUseSelectedIntelligenceModel {
                Text("Cursor awareness is available when the selected intelligence model is ready.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("When enabled, FriSpeak sends nearby text around the caret to the model so it can better understand context and tone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct OpenRouterModelPicker: View {
    @Binding var model: String
    @State private var selectedPreset: OpenRouterModelPreset = .custom

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Model Preset", selection: $selectedPreset) {
                ForEach(OpenRouterModelPreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedPreset) { _, newValue in
                if newValue != .custom {
                    model = newValue.modelID
                }
            }

            if selectedPreset == .custom {
                TextField("Custom model ID", text: $model)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(selectedPreset.modelID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .onAppear {
            selectedPreset = inferredPreset
        }
        .onChange(of: model) { _, _ in
            if selectedPreset != .custom {
                selectedPreset = inferredPreset
            }
        }
    }

    private var inferredPreset: OpenRouterModelPreset {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return OpenRouterModelPreset.allCases.first(where: { $0.modelID == trimmedModel }) ?? .custom
    }
}

private enum OpenRouterModelPreset: String, CaseIterable, Identifiable {
    case gemini31FlashLitePreview
    case gemini3FlashPreview
    case gemini31ProPreview
    case mimoV2Omni
    case gptOss120b
    case gptOss20b
    case minimaxM27
    case gpt54Mini
    case mercury2
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini31FlashLitePreview:
            return "Gemini 3.1 Flash Lite Preview"
        case .mercury2:
            return "Inception Mercury 2"
        case .gemini3FlashPreview:
            return "Gemini 3 Flash Preview"
        case .gemini31ProPreview:
            return "Gemini 3.1 Pro Preview"
        case .mimoV2Omni:
            return "Xiaomi MiMo v2 Omni"
        case .gptOss120b:
            return "GPT OSS 120B"
        case .gptOss20b:
            return "GPT OSS 20B"
        case .minimaxM27:
            return "MiniMax M2.7"
        case .gpt54Mini:
            return "GPT 5.4 Mini"
        case .custom:
            return "Custom"
        }
    }

    var modelID: String {
        switch self {
        case .gemini31FlashLitePreview:
            return "google/gemini-3.1-flash-lite-preview"
        case .mercury2:
            return "inception/mercury-2"
        case .gemini3FlashPreview:
            return "google/gemini-3-flash-preview"
        case .gemini31ProPreview:
            return "google/gemini-3.1-pro-preview"
        case .mimoV2Omni:
            return "xiaomi/mimo-v2-omni"
        case .gptOss120b:
            return "openai/gpt-oss-120b"
        case .gptOss20b:
            return "openai/gpt-oss-20b"
        case .minimaxM27:
            return "minimax/minimax-m2.7"
        case .gpt54Mini:
            return "openai/gpt-5.4-mini"
        case .custom:
            return ""
        }
    }
}

// MARK: - About View

private struct AboutView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Logo and Name
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor.gradient)
                        .padding(.bottom, 8)
                    
                    Text("FriSpeak")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                // Creator Info
                VStack(spacing: 16) {
                    Text("Created by Kaushal Subedi & FriDev")
                        .font(.title3.weight(.medium))

                    Text("FriSpeak was built to provide a seamless, privacy-first dictation experience for macOS. It combines high-speed on-device transcription with the power of modern Large Language Models.")
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)

                    Button(action: {
                        if let url = URL(string: "https://ksubedi.com") {
                            openURL(url)
                        }
                    }) {
                        Label("Visit ksubedi.com", systemImage: "link")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .glassEffect(in: .capsule)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.horizontal, 60)

                // Status Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Status")
                        .font(.headline)
                    
                    StatusRow(
                        title: "Permissions",
                        status: appState.permissionStatus.allRequiredGranted ? "Granted" : "Required",
                        isOk: appState.permissionStatus.allRequiredGranted
                    )
                    
                    StatusRow(
                        title: "Mode",
                        status: appState.intelligenceAvailabilityStatus,
                        isOk: onboardingModeIsReady
                    )
                }
                .padding(20)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 60)
            }
            .padding(.bottom, 40)
        }
    }

    private var onboardingModeIsReady: Bool {
        switch appState.dictationMode {
        case .localNative:
            return true
        case .localGenerative:
            return appState.localQwenModelCached || appState.localQwenDownloadInProgress
        case .remote:
            return appState.canUseRemoteMode
        }
    }
}

private struct StatusRow: View {
    let title: String
    let status: String
    let isOk: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: isOk ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(isOk ? .green : .orange)
                Text(status)
                    .fontWeight(.medium)
            }
        }
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedEntryID: CaptureHistoryEntry.ID?

    var body: some View {
        HSplitView {
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                List(appState.history, selection: $selectedEntryID) { entry in
                    HistoryListRow(entry: entry)
                        .tag(entry.id)
                        .listRowBackground(Color(nsColor: .windowBackgroundColor))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            Group {
                if appState.history.isEmpty {
                    ContentUnavailableView(
                        "No Capture History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Run a capture to inspect the transcript, inserted text, and focused text context.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let selectedEntry = selectedEntry {
                    HistoryEntryDetailView(entry: selectedEntry)
                } else {
                    ContentUnavailableView(
                        "No Log Selected",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Select a history entry from the sidebar to inspect its details.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)

            HistoryConfigurationView()
                .environmentObject(appState)
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
        }
        .onAppear {
            if selectedEntryID == nil {
                selectedEntryID = appState.history.first?.id
            }
        }
        .onChange(of: appState.history) { _, newHistory in
            guard !newHistory.isEmpty else {
                selectedEntryID = nil
                return
            }

            if selectedEntry == nil {
                selectedEntryID = newHistory.first?.id
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Copy All Logs") {
                    copyToPasteboard(appState.history.map(\.debugDump).joined(separator: "\n\n----------------------------------------\n\n"))
                }
                .disabled(appState.history.isEmpty)

                Spacer()
                Button("Clear History") {
                    appState.clearHistory()
                }
                .disabled(appState.history.isEmpty)
            }
            .padding()
            .background(.bar)
        }
    }

    private var selectedEntry: CaptureHistoryEntry? {
        guard let selectedEntryID else {
            return nil
        }

        return appState.history.first(where: { $0.id == selectedEntryID })
    }
}

private struct HistoryConfigurationView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Configuration")
                    .font(.title3.weight(.semibold))

                VStack(alignment: .leading, spacing: 10) {
                    Text("History entries to retain")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Stepper(value: $appState.historyRetentionLimit, in: 1...1_000) {
                        HStack {
                            Text("Retain")
                            Spacer()
                            Text("\(appState.historyRetentionLimit)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("FriSpeak keeps the most recent captures for debugging. This view stores the selected log details, the prompt sent to the model, the model response, and excerpted input-box context.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Log Audio With History", isOn: $appState.historyAudioLoggingEnabled)

                    Text("When enabled, FriSpeak saves a replayable audio file with each history entry. In direct OpenRouter audio mode, this stores the converted audio artifact sent to the model. Disable this if you do not want recordings retained on disk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding()
        }
        .background(.background)
    }
}

private struct HistoryListRow: View {
    let entry: CaptureHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                .font(.headline)

            Text(entry.applicationName ?? "Unknown App")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(entry.finalInsertedText.isEmpty ? "Empty" : entry.finalInsertedText)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct HistoryEntryDetailView: View {
    @EnvironmentObject private var appState: AppState
    let entry: CaptureHistoryEntry
    @StateObject private var audioPlayer = HistoryAudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                            .font(.title3.weight(.semibold))
                        
                        Text(entry.applicationName ?? "Unknown App")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Copy Log") {
                        copyToPasteboard(entry.debugDump)
                    }
                }
                
                HistoryTextSection(
                    title: "AI Status",
                    text: "Attempted: \(entry.aiAttempted ? "Yes" : "No") | Succeeded: \(entry.aiSucceeded ? "Yes" : "No")"
                )
                HistoryAudioSection(
                    entry: entry,
                    audioURL: appState.historyAudioURL(for: entry),
                    audioPlayer: audioPlayer
                )
                HistoryTextSection(title: "Effective Instructions", text: entry.effectiveInstructions)
                HistoryTextSection(title: "Prompt Sent To Model", text: entry.modelPrompt ?? "Unavailable")
                HistoryTextSection(title: "Raw Model Response", text: entry.rawModelResponse ?? "Unavailable")
                HistoryTextSection(title: "Model Transport Log", text: entry.modelTransportLog ?? "Unavailable")
                HistoryTextSection(title: "AI Error", text: entry.aiErrorMessage ?? "Unavailable")
                HistoryTextSection(title: "Raw Transcript", text: entry.rawTranscript)
                HistoryTextSection(title: "Inserted Text", text: entry.finalInsertedText)
                HistoryTextSection(title: "Focused Field Excerpt", text: entry.focusedFieldExcerpt ?? "Unavailable")
                HistoryTextSection(title: "Focused Field Was Truncated", text: entry.focusedFieldWasTruncated ? "Yes" : "No")
                HistoryTextSection(title: "Text Before Selection Excerpt", text: entry.textBeforeSelectionExcerpt ?? "Unavailable")
                HistoryTextSection(title: "Text Before Was Truncated", text: entry.textBeforeSelectionWasTruncated ? "Yes" : "No")
                HistoryTextSection(title: "Selected Text", text: entry.selectedText ?? "Unavailable")
                HistoryTextSection(title: "Text After Selection Excerpt", text: entry.textAfterSelectionExcerpt ?? "Unavailable")
                HistoryTextSection(title: "Text After Was Truncated", text: entry.textAfterSelectionWasTruncated ? "Yes" : "No")
            }
            .padding()
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
}

private struct HistoryAudioSection: View {
    let entry: CaptureHistoryEntry
    let audioURL: URL?
    @ObservedObject var audioPlayer: HistoryAudioPlayer

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Logged Audio")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                if let audioURL {
                    HStack(spacing: 10) {
                        Button(audioPlayer.isPlaying ? "Stop" : "Play Audio") {
                            if audioPlayer.isPlaying {
                                audioPlayer.stop()
                            } else {
                                audioPlayer.play(url: audioURL)
                            }
                        }

                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([audioURL])
                        }
                        .buttonStyle(.borderless)
                    }

                    Text(audioURL.lastPathComponent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else if entry.historyAudioFilename != nil {
                    Text("Audio file is no longer available on disk.")
                        .font(.body.monospaced())
                } else {
                    Text("Unavailable")
                        .font(.body.monospaced())
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct HistoryTextSection: View {
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Text(text.isEmpty ? "Empty" : text)
                .font(.body.monospaced())
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private func copyToPasteboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

@MainActor
private final class HistoryAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?

    func play(url: URL) {
        stop()

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        isPlaying = false
    }
}

private struct PermissionRowForm: View {
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(granted ? .green : .red)
                .symbolEffect(.bounce, value: granted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if !granted {
                Button("Grant Access") {
                    action()
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Onboarding Flow

private struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var stepIndex = 0
    
    private var steps: [SetupStep] {
        var allSteps: [SetupStep] = [.welcome, .permissions, .hotkey]
        allSteps.append(.intelligence)
        allSteps.append(.ready)
        return allSteps
    }
    
    private var currentStep: SetupStep {
        guard steps.indices.contains(stepIndex) else { return steps.last ?? .ready }
        return steps[stepIndex]
    }

    private var canFinishSetup: Bool {
        appState.permissionStatus.allRequiredGranted && onboardingModeIsReady
    }

    private var onboardingModeIsReady: Bool {
        switch appState.dictationMode {
        case .localNative:
            return true
        case .localGenerative:
            return appState.localQwenModelCached || appState.localQwenDownloadInProgress
        case .remote:
            return appState.canUseRemoteMode
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to FriSpeak")
                    .font(.largeTitle.weight(.bold))
                Text(currentStep.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeCard()
                    case .permissions:
                        PermissionsCard()
                    case .hotkey:
                        HotkeyCard()
                    case .intelligence:
                        IntelligenceCard()
                    case .ready:
                        ReadyCard()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .padding(32)
            }
            
            Divider()
            
            // Navigation footer
            HStack(spacing: 12) {
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if stepIndex > 0 {
                    Button("Back") {
                        withAnimation(.snappy) { stepIndex = max(stepIndex - 1, 0) }
                    }
                    .controlSize(.large)
                }
                
                if currentStep == .ready {
                    Button("Finish Setup") {
                        appState.completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canFinishSetup)
                } else {
                    Button("Continue") {
                        withAnimation(.snappy) {
                            stepIndex = min(stepIndex + 1, steps.count - 1)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(20)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

private struct WelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Push to talk, anywhere.")
                .font(.largeTitle.weight(.bold))
            
            Text("Hold your shortcut, speak, and release. FriSpeak instantly transcribes and inserts the text for you.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(symbol: "waveform.badge.mic", title: "Push-to-Talk", description: "Hold shortcut to record")
                FeatureRow(symbol: "doc.on.clipboard", title: "Instant Insert", description: "Transcribes and pastes automatically")
                FeatureRow(symbol: "bolt.circle", title: "Always Ready", description: "Works in any app")
            }
            .padding(.top, 8)
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PermissionsCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionRow(
                title: "Microphone",
                granted: appState.permissionStatus.microphone,
                action: appState.openMicrophonePreferences
            )
            PermissionRow(
                title: "Speech Recognition",
                granted: appState.permissionStatus.speechRecognition,
                action: appState.openSpeechPreferences
            )
            PermissionRow(
                title: "Accessibility",
                granted: appState.permissionStatus.accessibility,
                action: appState.promptForAccessibility
            )
            
            if !appState.permissionStatus.allRequiredGranted {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Please grant all permissions to continue.")
                        .font(.callout)
                }
                .padding(.top, 8)
            }
        }
    }
}

private struct HotkeyCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a comfortable shortcut for push-to-talk.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            HotkeyEditor(hotkey: $appState.hotkey)
        }
    }
}

private struct IntelligenceCard: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "switch.2")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuration")
                        .font(.title2.weight(.bold))
                    Text(appState.intelligenceAvailabilityStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Choose a speech model first, then optionally add intelligence features for cleanup, prompting, and remote context fitting.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 20) {
                    SpeechConfigurationCard()
                    IntelligenceFeaturesConfigurationCard()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                OpenRouterConfigurationCard()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .animation(.default, value: appState.dictationMode)
    }
}

private struct ReadyCard: View {
    @EnvironmentObject private var appState: AppState

    private var onboardingModeIsReady: Bool {
        switch appState.dictationMode {
        case .localNative:
            return true
        case .localGenerative:
            return appState.localQwenModelCached || appState.localQwenDownloadInProgress
        case .remote:
            return appState.canUseRemoteMode
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                Image(systemName: (appState.permissionStatus.allRequiredGranted && onboardingModeIsReady) ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle((appState.permissionStatus.allRequiredGranted && onboardingModeIsReady) ? Color.green : Color.orange)
                    .symbolEffect(.bounce, value: appState.permissionStatus.allRequiredGranted && onboardingModeIsReady)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text((appState.permissionStatus.allRequiredGranted && onboardingModeIsReady) ? "Ready to Go!" : "Almost There")
                        .font(.title.bold())
                    Text(readySubtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Shortcut")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.hotkey.displayLabel)
                        .font(.body.weight(.semibold).monospaced())
                }
                
                HStack {
                    Text("Processing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.dictationMode.summary)
                        .font(.body)
                }

                HStack {
                    Text("Configuration")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.intelligenceAvailabilityStatus)
                        .font(.body)
                }
            }
            .padding(.vertical, 8)
            
            Text("Hold the shortcut to record, release to transcribe and insert.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var readySubtitle: String {
        if !appState.permissionStatus.allRequiredGranted {
            return "Please grant all permissions."
        }

        if !onboardingModeIsReady {
            switch appState.dictationMode {
            case .localNative:
                return "Apple Speech is ready."
            case .localGenerative:
                return "Download the local Qwen model or wait for the current download to finish."
            case .remote:
                return "Configure OpenRouter to use remote speech."
            }
        }

        return "FriSpeak is ready to use."
    }
}

private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(granted ? .green : .red)
                .symbolEffect(.bounce, value: granted)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                if !granted {
                    Text("Required for FriSpeak to work")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if !granted {
                Button("Grant Access") {
                    action()
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct PermissionStatusPill: View {
    let title: String
    let granted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(granted ? Color.green : Color.orange)
                    .symbolEffect(.pulse, isActive: !granted)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .disabled(granted)
        .opacity(granted ? 0.6 : 1.0)
    }
}

struct HotkeyEditor: View {
    @Binding var hotkey: PushToTalkHotkey

    @State private var selection = HotkeyPreset.rightOption
    @State private var comboKeyCode = UInt16(0)
    @State private var comboModifiersRaw = NSEvent.ModifierFlags.command.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Preset", selection: $selection) {
                ForEach(HotkeyPreset.allCases) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .onAppear(perform: syncFromHotkey)
            .onChange(of: hotkey) { _, _ in
                syncFromHotkey()
            }
            .onChange(of: selection) { _, newValue in
                applyPreset(newValue)
            }

            if selection == .customCombo {
                HStack(spacing: 12) {
                    Picker("Modifiers", selection: $comboModifiersRaw) {
                        Text("⌘").tag(NSEvent.ModifierFlags.command.rawValue)
                        Text("⌥").tag(NSEvent.ModifierFlags.option.rawValue)
                        Text("⌃").tag(NSEvent.ModifierFlags.control.rawValue)
                        Text("⇧").tag(NSEvent.ModifierFlags.shift.rawValue)
                        Text("⌘⇧").tag(NSEvent.ModifierFlags([.command, .shift]).rawValue)
                        Text("⌘⌥").tag(NSEvent.ModifierFlags([.command, .option]).rawValue)
                        Text("⌃⌥").tag(NSEvent.ModifierFlags([.control, .option]).rawValue)
                    }
                    .frame(maxWidth: .infinity)

                    Picker("Key", selection: $comboKeyCode) {
                        ForEach(HotkeyKeyOption.defaultOptions) { option in
                            Text(option.title).tag(option.keyCode)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: comboKeyCode) { _, _ in
                    applyCustomCombo()
                }
                .onChange(of: comboModifiersRaw) { _, _ in
                    applyCustomCombo()
                }
            }

            // Active shortcut display
            HStack {
                Image(systemName: "command.circle.fill")
                    .foregroundStyle(.blue)
                Text(hotkey.displayLabel)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .glassEffect(in: .capsule)
        }
    }

    private func syncFromHotkey() {
        switch hotkey.kind {
        case .modifierOnly(.rightOption):
            selection = .rightOption
        case .modifierOnly(.rightCommand):
            selection = .rightCommand
        case .modifierOnly(.rightControl):
            selection = .rightControl
        case .modifierOnly:
            selection = .rightOption
        case .keyCombo:
            selection = .customCombo
            comboKeyCode = hotkey.keyCode
            comboModifiersRaw = hotkey.modifiers.normalizedForHotkey.rawValue
        }
    }

    private func applyPreset(_ preset: HotkeyPreset) {
        switch preset {
        case .rightOption:
            hotkey = PushToTalkHotkey(kind: .modifierOnly(.rightOption), keyCode: SidedModifier.rightOption.keyCode, modifiers: [])
        case .rightCommand:
            hotkey = PushToTalkHotkey(kind: .modifierOnly(.rightCommand), keyCode: SidedModifier.rightCommand.keyCode, modifiers: [])
        case .rightControl:
            hotkey = PushToTalkHotkey(kind: .modifierOnly(.rightControl), keyCode: SidedModifier.rightControl.keyCode, modifiers: [])
        case .customCombo:
            if comboKeyCode == 0 {
                comboKeyCode = UInt16(kVK_ANSI_S)
            }
            applyCustomCombo()
        }
    }

    private func applyCustomCombo() {
        hotkey = PushToTalkHotkey(
            kind: .keyCombo,
            keyCode: comboKeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: comboModifiersRaw).normalizedForHotkey
        )
    }
}

enum HotkeyPreset: String, CaseIterable, Identifiable {
    case rightOption
    case rightCommand
    case rightControl
    case customCombo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightOption: return "Right ⌥"
        case .rightCommand: return "Right ⌘"
        case .rightControl: return "Right ⌃"
        case .customCombo: return "Custom"
        }
    }
}

struct HotkeyKeyOption: Identifiable {
    let keyCode: UInt16
    let title: String

    var id: UInt16 { keyCode }

    static let defaultOptions: [HotkeyKeyOption] = [
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_A), title: "A"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_S), title: "S"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_D), title: "D"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_F), title: "F"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_G), title: "G"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_R), title: "R"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_T), title: "T"),
        HotkeyKeyOption(keyCode: UInt16(kVK_ANSI_V), title: "V"),
        HotkeyKeyOption(keyCode: UInt16(kVK_Space), title: "Space")
    ]
}

private enum SetupStep: Int, CaseIterable {
    case welcome
    case permissions
    case hotkey
    case intelligence
    case ready

    var subtitle: String {
        switch self {
        case .welcome: return "Set up background dictation."
        case .permissions: return "Grant system access."
        case .hotkey: return "Choose your shortcut."
        case .intelligence: return "Configure speech and intelligence."
        case .ready: return "Start using FriSpeak."
        }
    }

    var progressLabel: String {
        "\(rawValue + 1) / \(SetupStep.allCases.count)"
    }

    var previous: SetupStep {
        SetupStep(rawValue: max(rawValue - 1, 0)) ?? .welcome
    }

    var next: SetupStep {
        SetupStep(rawValue: min(rawValue + 1, SetupStep.allCases.count - 1)) ?? .ready
    }
}
