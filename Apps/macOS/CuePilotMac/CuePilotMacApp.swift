import AppKit
import SwiftUI

@main
struct CuePilotMacApp: App {
    @NSApplicationDelegateAdaptor(CuePilotApplicationDelegate.self)
    private var applicationDelegate
    @StateObject private var model = CuePilotMacModel()

    var body: some Scene {
        WindowGroup {
            CuePilotRootView(model: model)
        }
        .defaultSize(width: 1_280, height: 820)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandMenu("Capture") {
                Button(model.analysisEnabled ? "Stop Analysis" : "Start Analysis") {
                    model.toggleAnalysis()
                }
                .keyboardShortcut("a", modifiers: [.command, .option])

                Button("Refresh Windows") {
                    Task {
                        await model.refreshWindows()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Divider()

                Button("Calibration") {
                    model.showCalibration()
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
            }
        }

        Settings {
            CuePilotSettingsView(model: model)
        }
    }
}

@MainActor
final class CuePilotApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        true
    }
}
