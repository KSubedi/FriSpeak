//
//  DashboardView.swift
//  FriSpeak
//

import AVFoundation
import Combine
import SwiftUI
import Carbon.HIToolbox

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = 16, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }

    func liquidGlassChrome() -> some View {
        self
            .padding(20)
            .background(.ultraThinMaterial)
    }
}

private let intelligencePromptPlaceholder = """
Optional extra instructions, for example:
• Keep it terse
• Make it slightly more professional
• Format as a short bullet
• Translate to Spanish
• Convert to sentence case
"""

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            LiquidAuroraBackground()

            Group {
                if appState.hasCompletedOnboarding {
                    SettingsView()
                } else {
                    OnboardingFlowView()
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

private struct LiquidAuroraBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark
                ? Color(red: 0.07, green: 0.08, blue: 0.12)
                : Color(red: 0.94, green: 0.95, blue: 0.99))

            Canvas { context, size in
                let blobs: [(Color, CGPoint, CGFloat)] = colorScheme == .dark ? [
                    (Color(red: 0.35, green: 0.25, blue: 0.85), CGPoint(x: size.width * 0.15, y: size.height * 0.20), max(size.width, size.height) * 0.55),
                    (Color(red: 0.95, green: 0.30, blue: 0.55), CGPoint(x: size.width * 0.85, y: size.height * 0.15), max(size.width, size.height) * 0.50),
                    (Color(red: 0.20, green: 0.65, blue: 0.95), CGPoint(x: size.width * 0.30, y: size.height * 0.85), max(size.width, size.height) * 0.60),
                    (Color(red: 0.55, green: 0.30, blue: 0.95), CGPoint(x: size.width * 0.90, y: size.height * 0.90), max(size.width, size.height) * 0.55),
                ] : [
                    (Color(red: 0.55, green: 0.65, blue: 1.00), CGPoint(x: size.width * 0.10, y: size.height * 0.10), max(size.width, size.height) * 0.55),
                    (Color(red: 1.00, green: 0.55, blue: 0.75), CGPoint(x: size.width * 0.90, y: size.height * 0.20), max(size.width, size.height) * 0.50),
                    (Color(red: 0.55, green: 0.90, blue: 0.95), CGPoint(x: size.width * 0.25, y: size.height * 0.85), max(size.width, size.height) * 0.60),
                    (Color(red: 0.80, green: 0.65, blue: 1.00), CGPoint(x: size.width * 0.85, y: size.height * 0.95), max(size.width, size.height) * 0.55),
                ]

                for (color, center, radius) in blobs {
                    let gradient = Gradient(stops: [
                        .init(color: color.opacity(0.85), location: 0.0),
                        .init(color: color.opacity(0.0), location: 1.0)
                    ])
                    context.fill(
                        Circle().path(in: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .radialGradient(
                            gradient,
                            center: center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                }
            }
            .blur(radius: 70)
        }
    }
}

// MARK: - Settings View (Main Dashboard)

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            LiquidTabBar(selection: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)

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

private struct LiquidTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var tabNamespace

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                            selection = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.22))
                                    .matchedGeometryEffect(id: "liquidTab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
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
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))

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
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

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
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

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
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

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
                        .buttonStyle(.glass)
                        .controlSize(.large)

                        Button {
                            NSApp.terminate(nil)
                        } label: {
                            Label("Quit FriSpeak", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

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
                .glassEffect(.regular, in: .rect(cornerRadius: 16))

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
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
            .padding(20)
        }
    }

    private var processingPathLabel: String {
        switch appState.dictationMode {
        case .localNative:
            return "Apple ASR"
        case .localGenerative:
            return "Local Speech"
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
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

// MARK: - Intelligence Settings

private struct IntelligenceSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ConfigurationOverviewCard()
                SpeechConfigurationCard()
                IntelligenceFeaturesConfigurationCard()
                OpenRouterConfigurationCard()
            }
            .padding(20)
        }
        .background(.ultraThinMaterial)
    }
}

private struct ConfigurationOverviewCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Configuration", systemImage: "switch.2")
                .font(.title3.weight(.semibold))

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
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

private struct SpeechConfigurationCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Speech Model", systemImage: "waveform.and.mic")
                    .font(.headline)
                Spacer()
            }

            SpeechModeSegmentedPicker(selection: $appState.dictationMode)
                .disabled(!appState.hasConfiguredOpenRouter && appState.dictationMode == .remote)
                .opacity((!appState.hasConfiguredOpenRouter && appState.dictationMode == .remote) ? 0.6 : 1)

            Group {
                switch appState.dictationMode {
                case .localNative:
                    SpeechModeDetail(
                        icon: "internaldrive",
                        title: "Apple Speech",
                        message: "On-device speech recognition. No model download required.",
                        tint: .blue
                    )
                case .localGenerative:
                    LocalGenerativeModelSection()
                case .remote:
                    if appState.hasConfiguredOpenRouter {
                        SpeechModeDetail(
                            icon: "network",
                            title: "OpenRouter Pipeline",
                            message: "Cloud speech through the selected OpenRouter model. Requires an active API key.",
                            tint: .pink
                        )
                    } else {
                        SpeechModeDetail(
                            icon: "exclamationmark.triangle.fill",
                            title: "Setup Required",
                            message: "Configure your OpenRouter API key below to enable remote speech.",
                            tint: .orange
                        )
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.dictationMode)
    }
}

private struct SpeechModeSegmentedPicker: View {
    @Binding var selection: DictationMode
    @Namespace private var pickerNamespace

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(DictationMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                            selection = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                            Text(mode.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selection == mode ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selection == mode {
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.22))
                                    .matchedGeometryEffect(id: "speechMode", in: pickerNamespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
    }
}

private struct SpeechModeDetail: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .glassEffect(.regular, in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

private struct LocalGenerativeModelSection: View {
    @EnvironmentObject private var appState: AppState
    @Namespace private var modelNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 4) {
                    ForEach(LocalSpeechBackend.allCases) { backend in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                appState.localSpeechBackend = backend
                            }
                        } label: {
                            Text(backend.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(appState.localSpeechBackend == backend ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background {
                                    if appState.localSpeechBackend == backend {
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.22))
                                            .matchedGeometryEffect(id: "localModel", in: modelNamespace)
                                    }
                                }
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "cpu")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(appState.localSpeechBackend.acceleratorLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(appState.localSpeechBackend.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    Task { await appState.downloadLocalQwenModel() }
                } label: {
                    Label(
                        appState.localQwenModelCached ? "Redownload" : "Download",
                        systemImage: appState.localQwenDownloadInProgress ? "arrow.down.circle.fill" : "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(appState.localQwenDownloadInProgress)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: 28)
                .glassEffect(.regular, in: .capsule)
            }

            if appState.localQwenDownloadInProgress {
                ProgressView(value: appState.localQwenDownloadProgress)
            } else if appState.localQwenPreloadInProgress {
                ProgressView()
            }

            if let localQwenLastError = appState.localQwenLastError, !localQwenLastError.isEmpty {
                Text(localQwenLastError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusColor: Color {
        if appState.localQwenDownloadInProgress || appState.localQwenPreloadInProgress {
            return .orange
        }
        return appState.localQwenModelCached ? .green : .secondary
    }

    private var statusLabel: String {
        if appState.localQwenDownloadInProgress || appState.localQwenPreloadInProgress {
            return appState.localQwenDownloadStatus.isEmpty ? "Working…" : appState.localQwenDownloadStatus
        }
        return appState.localQwenModelCached ? "Ready" : "Not downloaded"
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

            HStack(spacing: 8) {
                Image(systemName: appState.openRouterModelSupportsAudioInput ? "waveform.badge.mic" : "info.circle")
                    .foregroundStyle(appState.openRouterModelSupportsAudioInput ? .green : .secondary)
                Text(appState.openRouterCapabilityStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
            .buttonStyle(.glassProminent)
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

            Text("Runs Bonsai-8B-mlx-1bit locally via MLX for text cleanup and prompting.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

private struct IntelligenceFeaturesConfigurationCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Intelligence Features")
                .font(.headline)

            Toggle("Enable intelligence features", isOn: $appState.intelligenceFeaturesEnabled)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
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

            if appState.intelligenceModel == .local {
                LocalBonsaiModelSection()
            }

            Toggle("Use built-in cleanup prompting", isOn: $appState.builtInIntelligencePromptingEnabled)

            intelligencePromptEditor

            if appState.canUseAppleIntelligence || appState.localBonsaiModelCached || appState.hasConfiguredOpenRouter {
                cursorAwarenessSection
            }
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
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))

                if appState.intelligencePrompt.isEmpty {
                    Text(intelligencePromptPlaceholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 18)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }

        }
    }

    private var cursorAwarenessSection: some View {
        Toggle("Use Cursor Location Awareness", isOn: $appState.cursorAwarenessEnabled)
            .disabled(!appState.canUseSelectedIntelligenceModel)
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
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.18))
                }
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
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
        .background(.ultraThinMaterial)
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
        }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
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

            if appState.dictationMode == .remote {
                OpenRouterAPIKeyHelp()

                SecureField("OpenRouter API key", text: $appState.openRouterAPIKey)
                    .textFieldStyle(.roundedBorder)

                OpenRouterModelPicker(model: $appState.openRouterModel)

                HStack(spacing: 8) {
                    Image(systemName: appState.openRouterModelSupportsAudioInput ? "waveform.badge.mic" : "info.circle")
                        .foregroundStyle(appState.openRouterModelSupportsAudioInput ? .green : .secondary)
                    Text(appState.openRouterCapabilityStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if appState.dictationMode == .localGenerative {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Local model", selection: $appState.localSpeechBackend) {
                        ForEach(LocalSpeechBackend.allCases) { backend in
                            Text(backend.title).tag(backend)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appState.localSpeechBackend.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await appState.downloadLocalQwenModel()
                        }
                    } label: {
                        Label(
                            appState.localQwenModelCached ? "Redownload \(appState.localSpeechBackend.title)" : "Download \(appState.localSpeechBackend.title)",
                            systemImage: appState.localQwenDownloadInProgress ? "arrow.down.circle.fill" : "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.glassProminent)
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
                        Text(appState.localQwenModelCached ? "\(appState.localSpeechBackend.title) cached locally and ready to use." : "\(appState.localSpeechBackend.title) is not downloaded yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let localQwenLastError = appState.localQwenLastError, !localQwenLastError.isEmpty {
                        Text(localQwenLastError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local Speech Instructions")
                            .font(.subheadline.weight(.semibold))

                        TextEditor(text: $appState.intelligencePrompt)
                            .frame(height: 110)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                }
            } else {
                Text("Apple native speech. No setup required.")
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
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
            Toggle("Use Cursor Location Awareness", isOn: $appState.cursorAwarenessEnabled)
                .disabled(!appState.canUseSelectedIntelligenceModel)

            if !appState.canUseSelectedIntelligenceModel {
                Text("Available when the selected intelligence model is ready.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.history) { entry in
                            Button {
                                selectedEntryID = entry.id
                            } label: {
                                HistoryListRow(
                                    entry: entry,
                                    isSelected: selectedEntryID == entry.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(minWidth: 170, idealWidth: 240, maxWidth: 300)

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
            .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)

            HistoryConfigurationView()
                .environmentObject(appState)
                .frame(minWidth: 170, idealWidth: 240, maxWidth: 300)
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
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Log Audio With History", isOn: $appState.historyAudioLoggingEnabled)

                    Text("When enabled, FriSpeak saves a replayable audio file with each history entry. In direct OpenRouter audio mode, this stores the converted audio artifact sent to the model. Disable this if you do not want recordings retained on disk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
            }
            .padding()
        }
        .background(.ultraThinMaterial)
    }
}

private struct HistoryListRow: View {
    let entry: CaptureHistoryEntry
    let isSelected: Bool

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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .modifier(HistoryRowGlassModifier(isSelected: isSelected))
    }
}

private struct HistoryRowGlassModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        if isSelected {
            content
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.18))
                }
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        } else {
            content
        }
    }
}

private struct HistoryEntryDetailView: View {
    @EnvironmentObject private var appState: AppState
    let entry: CaptureHistoryEntry
    @StateObject private var audioPlayer = HistoryAudioPlayer()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
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

                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.timestamp, format: Date.FormatStyle(date: .abbreviated, time: .standard))
                                .font(.title3.weight(.semibold))

                            Text(entry.applicationName ?? "Unknown App")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Copy Log") {
                            copyToPasteboard(entry.debugDump)
                        }
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
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                Text("Logged Audio")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)

                audioContent
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Logged Audio")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                audioContent
            }
        }
    }

    private var audioContent: some View {
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
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }
}

private struct HistoryTextSection: View {
    let title: String
    let text: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 150, alignment: .leading)

                contentView
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                contentView
            }
        }
    }

    private var contentView: some View {
        Text(text.isEmpty ? "Empty" : text)
            .font(.body.monospaced())
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 8))
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

// MARK: - Onboarding Flow

private struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var stepIndex = 0

    private let steps = SetupStep.allCases

    private var currentStep: SetupStep {
        steps[min(max(stepIndex, 0), steps.count - 1)]
    }

    private var canAdvance: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .permissions:
            return appState.permissionStatus.allRequiredGranted
        case .ready:
            return appState.permissionStatus.allRequiredGranted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentStep.title)
                    .font(.largeTitle.weight(.bold))
                Text(currentStep.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(32)
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                Group {
                    switch currentStep {
                    case .welcome:
                        OnboardingWelcomeCard()
                    case .permissions:
                        OnboardingPermissionsCard()
                    case .ready:
                        OnboardingReadyCard()
                    }
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .padding(32)
            }

            Divider()

            HStack(spacing: 12) {
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer()

                if stepIndex > 0 {
                    Button("Back") {
                        withAnimation(.snappy) { stepIndex -= 1 }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                }

                if currentStep == .ready {
                    Button("Start Using FriSpeak") {
                        appState.completeOnboarding()
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(!canAdvance)
                } else {
                    Button("Continue") {
                        withAnimation(.snappy) {
                            stepIndex = min(stepIndex + 1, steps.count - 1)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(!canAdvance)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
        }
    }
}

private struct OnboardingWelcomeCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Hold a shortcut, speak, release.")
                    .font(.title2.weight(.semibold))
                Text("FriSpeak transcribes your voice and inserts the text wherever your cursor is — in any app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                OnboardingFeatureRow(
                    symbol: "waveform.badge.mic",
                    title: "Push-to-talk",
                    description: "Hold your shortcut to record"
                )
                OnboardingFeatureRow(
                    symbol: "text.insert",
                    title: "Instant insert",
                    description: "Text lands at the cursor automatically"
                )
                OnboardingFeatureRow(
                    symbol: "lock.shield",
                    title: "On-device by default",
                    description: "Apple Speech — private, no setup needed"
                )
            }

            Text("Speech models, AI cleanup, and OpenRouter can be configured later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct OnboardingFeatureRow: View {
    let symbol: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

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

private struct OnboardingPermissionsCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FriSpeak needs three system permissions to hear you and type for you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                OnboardingPermissionRow(
                    title: "Microphone",
                    detail: "Capture your voice",
                    granted: appState.permissionStatus.microphone,
                    action: appState.requestMicrophoneThenOpenPreferences
                )
                Divider().padding(.leading, 44)
                OnboardingPermissionRow(
                    title: "Speech Recognition",
                    detail: "Turn speech into text",
                    granted: appState.permissionStatus.speechRecognition,
                    action: appState.requestSpeechThenOpenPreferences
                )
                Divider().padding(.leading, 44)
                OnboardingPermissionRow(
                    title: "Accessibility",
                    detail: "Insert text at the cursor",
                    granted: appState.permissionStatus.accessibility,
                    action: appState.promptForAccessibility
                )
            }
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))

            if appState.permissionStatus.allRequiredGranted {
                Label("All permissions granted", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button {
                    appState.requestAllRequiredPermissions()
                } label: {
                    Text("Enable Permissions")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
    }
}

private struct OnboardingPermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(granted ? .green : .secondary)
                .symbolEffect(.bounce, value: granted)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !granted {
                Button("Grant") {
                    action()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct OnboardingReadyCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: appState.permissionStatus.allRequiredGranted)

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're ready")
                        .font(.title2.weight(.bold))
                    Text("Hold the shortcut to dictate. Release to insert.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Push-to-talk shortcut")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HotkeyEditor(hotkey: $appState.hotkey)

                Text("Default is Right Option — change anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
    }
}

private enum SetupStep: Int, CaseIterable {
    case welcome
    case permissions
    case ready

    var title: String {
        switch self {
        case .welcome: return "Welcome to FriSpeak"
        case .permissions: return "Permissions"
        case .ready: return "Almost done"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "Background dictation for Mac."
        case .permissions: return "Allow access so FriSpeak can work."
        case .ready: return "Confirm your shortcut and start."
        }
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


