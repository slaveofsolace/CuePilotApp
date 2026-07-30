import AppIntents

struct StartLiveAssistIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Live Assist"
    static let description = IntentDescription(
        "Opens CuePilot so you can explicitly start a system screen broadcast."
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(
            dialog: "CuePilot is ready. Start the broadcast from the system control."
        )
    }
}

struct OpenScreenshotAnalysisIntent: AppIntent {
    static let title: LocalizedStringResource = "Analyze a Screenshot"
    static let description = IntentDescription(
        "Opens CuePilot to choose a screenshot for local analysis."
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Choose the screenshot you want to analyze.")
    }
}

struct CuePilotShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLiveAssistIntent(),
            phrases: [
                "Start live assist in \(.applicationName)",
                "Open live assist in \(.applicationName)",
            ],
            shortTitle: "Start Live Assist",
            systemImageName: "scope"
        )
        AppShortcut(
            intent: OpenScreenshotAnalysisIntent(),
            phrases: [
                "Analyze a screenshot in \(.applicationName)",
            ],
            shortTitle: "Analyze Screenshot",
            systemImageName: "photo.badge.magnifyingglass"
        )
    }
}
