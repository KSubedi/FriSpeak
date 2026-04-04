//
//  FriSpeakApp.swift
//  FriSpeak
//

import AppKit
import SwiftUI

@main
struct FriSpeakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Window("FriSpeak", id: "main") {
            DashboardView()
                .environmentObject(appState)
                .onOpenURL { url in
                    if url.scheme == "frispeak" && url.host == "show-main" {
                        appState.showMainWindow()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentSize)

        MenuBarExtra("FriSpeak", systemImage: appState.statusItemSymbolName) {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState

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
                    appState.showMainWindow()
                }

                MenuButton(title: "Quit FriSpeak", symbol: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 240)
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
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
