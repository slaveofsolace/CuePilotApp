import SwiftUI

@main
struct CuePilotApp: App {
    @State private var state = CuePilotState()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            CuePilotRootView()
                .environment(state)
                .environment(router)
        }
    }
}

private struct CuePilotRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CuePilotState.self) private var state

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .liveSetup:
                        LiveAssistSetupView()
                    case .detectionReview:
                        DetectionReviewView()
                    case .shotResult:
                        ShotResultView()
                    case .matchSession:
                        MatchSessionView()
                    case .calibration:
                        CalibrationView()
                    case .secondaryTools:
                        SecondaryToolsView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .cuePilotCanvas()
        .task {
            state.startLiveStateMonitoring()
        }
    }
}
