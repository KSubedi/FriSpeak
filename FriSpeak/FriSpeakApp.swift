//
//  FriSpeakApp.swift
//  FriSpeak
//

import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted when something needs the SwiftUI `Window(id: "main")` scene opened.
    static let friSpeakOpenMainWindow = Notification.Name("FriSpeak.openMainWindow")
}

@main
struct FriSpeakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Window("FriSpeak", id: "main") {
            DashboardView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleFriSpeakURL(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        // Min size from content; allow free resize so the dashboard fills larger displays.
        .windowResizability(.contentMinSize)
        .defaultSize(width: 920, height: 640)
        .handlesExternalEvents(matching: Set(arrayLiteral: "show-main"))

        MenuBarExtra("FriSpeak", systemImage: appState.statusItemSymbolName) {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }

    private func handleFriSpeakURL(_ url: URL) {
        guard url.scheme == "frispeak" else { return }
        if url.host == "show-main" || url.path == "/show-main" {
            appState.showMainWindow()
        }
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with status
            HStack(spacing: 12) {
                Image(systemName: appState.statusItemSymbolName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(appState.captureState == .idle ? Color.primary : Color.orange)
                    .symbolEffect(.pulse, isActive: appState.captureState != .idle)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("FriSpeak")
                        .font(.system(size: 15, weight: .semibold))
                    Text(appState.statusSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            // Hotkey indicator with glass effect
            HStack(spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(appState.hotkey.displayLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(in: .capsule)

            Divider()
                .padding(.vertical, 4)

            // Action buttons
            VStack(spacing: 6) {
                MenuButton(title: "Open Dashboard", symbol: "macwindow.on.rectangle") {
                    openDashboard()
                }

                MenuButton(title: "Quit FriSpeak", symbol: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 240)
        .onReceive(NotificationCenter.default.publisher(for: .friSpeakOpenMainWindow)) { _ in
            openDashboard()
        }
    }

    private func openDashboard() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        // After SwiftUI materializes the scene, force it front (LSUIElement apps
        // sometimes leave the new window behind the previous frontmost app).
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { candidate in
                guard !(candidate is NSPanel) else { return false }
                return candidate.identifier?.rawValue == "main" || candidate.title == "FriSpeak"
            }) {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct MenuButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
        .controlSize(.large)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "frispeak" {
            if url.host == "show-main" || url.path == "/show-main" {
                // Avoid re-entering the delayed URL fallback inside showMainWindow.
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .friSpeakOpenMainWindow, object: nil)
                DispatchQueue.main.async {
                    if let window = NSApp.windows.first(where: {
                        ($0.identifier?.rawValue == "main" || $0.title == "FriSpeak") && !($0 is NSPanel)
                    }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
