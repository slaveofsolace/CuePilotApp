import Foundation
import Observation

enum AppRoute: Hashable {
    case liveSetup
    case detectionReview
    case shotResult
    case matchSession
    case calibration
    case secondaryTools
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute] = []

    func open(_ route: AppRoute) {
        path.append(route)
    }

    func reset() {
        path.removeAll()
    }
}
