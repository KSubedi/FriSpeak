//
//  HUDWindowController.swift
//  FriSpeak
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class HUDWindowController {
    private let panelWidth: CGFloat = 360

    private let viewModel = HUDViewModel()
    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        
        let hostingView = NSHostingView(rootView: DynamicIslandView().environmentObject(viewModel))
        panel.contentView = hostingView
        return panel
    }()

    private var hideTask: Task<Void, Never>?

    /// Set a handler that is called when the user taps the cancel button.
    var onCancel: (() -> Void)? {
        get { viewModel.onCancel }
        set { viewModel.onCancel = newValue }
    }

    func show(text: String, detail: String? = nil, state: HUDViewModel.DisplayState) {
        hideTask?.cancel()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            viewModel.text = text
            viewModel.detailText = detail
            viewModel.state = state
            viewModel.isExpanded = true
        }

        positionPanel()
        panel.orderFrontRegardless()
    }

    func hide(after delay: TimeInterval? = nil) {
        hideTask?.cancel()

        guard let delay else {
            viewModel.isExpanded = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.panel.orderOut(nil)
            }
            return
        }

        hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                viewModel.isExpanded = false
            }
            
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let frame = panel.frame
        let screenFrame = screen.frame
        
        // Detect notch: if safeAreaInsets.top > 0 (macOS 12+) or checking visibleFrame
        let hasNotch = screen.safeAreaInsets.top > 0
        
        let x = screenFrame.midX - (frame.width / 2)
        let y: CGFloat
        
        if hasNotch {
            // Position below the notch with comfortable padding
            // safeAreaInsets.top gives the height of the menu bar + notch area
            y = screenFrame.maxY - screen.safeAreaInsets.top - frame.height - 8
        } else {
            // Position slightly below the top of the screen
            y = screenFrame.maxY - frame.height - 10
        }
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
final class HUDViewModel: ObservableObject {
    enum DisplayState {
        case listening
        case transcribing
        case injecting
        case error
    }

    @Published var text = ""
    @Published var detailText: String?
    @Published var state: DisplayState = .listening
    @Published var isExpanded = false

    /// Called when the user taps the cancel button.
    var onCancel: (() -> Void)?

    var isCancellable: Bool {
        state == .listening || state == .transcribing
    }

    var symbolName: String {
        switch state {
        case .listening: return "waveform"
        case .transcribing: return "ellipsis.bubble.fill"
        case .injecting: return "arrow.down.doc.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch state {
        case .listening: return .orange
        case .transcribing: return .blue
        case .injecting: return .green
        case .error: return .red
        }
    }
}

struct DynamicIslandView: View {
    @EnvironmentObject private var viewModel: HUDViewModel
    private let panelWidth: CGFloat = 360
    
    var body: some View {
        Group {
            if viewModel.isExpanded {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(viewModel.tint)
                        .symbolEffect(.pulse, isActive: viewModel.state == .listening)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.text)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)

                        if let detailText = viewModel.detailText, !detailText.isEmpty {
                            Text(detailText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if viewModel.state == .listening {
                        WaveformView(color: viewModel.tint)
                            .frame(width: 40, height: 16)
                    }

                    if viewModel.isCancellable {
                        Button {
                            viewModel.onCancel?()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(width: panelWidth, alignment: .leading)
                .glassEffect(.regular.tint(viewModel.tint.opacity(0.15)), in: .capsule)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WaveformView: View {
    let color: Color
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: CGFloat.random(in: 4...16))
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.1), value: phase)
            }
        }
        .onAppear {
            phase = 1
        }
    }
}
