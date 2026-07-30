import AppKit
import CueGeometry
import CuePresentation
import CueStrategy
import CueVision
import Foundation

enum SidebarDestination: String, CaseIterable, Identifiable {
    case capture
    case calibration
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .capture: "Capture"
        case .calibration: "Calibration"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .capture: "viewfinder"
        case .calibration: "scope"
        case .settings: "gearshape"
        }
    }
}

enum CaptureLifecycle: Equatable, Sendable {
    case discovering
    case noMirroringWindow
    case ready
    case starting
    case capturing
    case paused
    case permissionRequired
    case failed(String)

    var title: String {
        switch self {
        case .discovering: "Finding windows"
        case .noMirroringWindow: "Open iPhone Mirroring"
        case .ready: "Ready"
        case .starting: "Starting capture"
        case .capturing: "Capturing"
        case .paused: "Capture paused"
        case .permissionRequired: "Screen recording required"
        case let .failed(message): message
        }
    }

    var symbol: String {
        switch self {
        case .discovering, .starting: "arrow.trianglehead.2.clockwise.rotate.90"
        case .noMirroringWindow: "iphone.slash"
        case .ready: "circle"
        case .capturing: "record.circle"
        case .paused: "pause.circle"
        case .permissionRequired: "lock.shield"
        case .failed: "exclamationmark.triangle"
        }
    }
}

struct CaptureWindowOption: Identifiable, Hashable, Sendable {
    let id: CGWindowID
    let applicationName: String
    let title: String
    let frame: CGRect
    let isLikelyIPhoneMirroring: Bool

    var displayName: String {
        if isLikelyIPhoneMirroring {
            return title.isEmpty ? "iPhone Mirroring" : title
        }
        if title.isEmpty {
            return applicationName
        }
        return "\(applicationName) — \(title)"
    }
}

struct FrameRegistration: Equatable, Sendable {
    var screenRect: CGRect
    var contentRect: CGRect
    var scaleFactor: Double
    var contentScale: Double
    var isOnScreen: Bool

    static let unavailable = FrameRegistration(
        screenRect: .zero,
        contentRect: .zero,
        scaleFactor: 1,
        contentScale: 1,
        isOnScreen: false
    )

    var hasSurfaceMetadata: Bool {
        contentRect.width > 0 &&
            contentRect.height > 0 &&
            scaleFactor.isFinite &&
            scaleFactor > 0 &&
            contentScale.isFinite &&
            contentScale > 0
    }

    func updatingScreenGeometry(from polled: FrameRegistration) -> FrameRegistration {
        FrameRegistration(
            screenRect: polled.screenRect,
            contentRect: hasSurfaceMetadata ? contentRect : polled.contentRect,
            scaleFactor: hasSurfaceMetadata ? scaleFactor : polled.scaleFactor,
            contentScale: hasSurfaceMetadata ? contentScale : polled.contentScale,
            isOnScreen: polled.isOnScreen
        )
    }
}

struct CapturedFrame: @unchecked Sendable {
    let image: CGImage
    let analysisImage: RGBAImage?
    let registration: FrameRegistration
    let latencyMilliseconds: Double
    let receivedAt: ContinuousClock.Instant
    let isComplete: Bool

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }
}

struct AnalysisPacket: Sendable {
    let analysis: VisionAnalysis
    let recommendation: ShotRecommendation?
    let guidance: StabilizedGuidance?
    let imageSize: CGSize
    let durationMilliseconds: Double
}

struct LiveGameConfiguration: Equatable, Sendable {
    var groupAssignment: GroupAssignment
    var turn: MatchTurn
    var requiredEightBallPocket: PocketID?
    var aimBiasDegrees: Double

    static let initial = LiveGameConfiguration(
        groupAssignment: .open,
        turn: .player,
        requiredEightBallPocket: nil,
        aimBiasDegrees: 0
    )
}

struct OverlayRenderState: Equatable, Sendable {
    var analysis: VisionAnalysis?
    var recommendation: ShotRecommendation?
    var guidanceState: GuidanceState?
    var analysisImageSize: CGSize
    var capturedFramePixelSize: CGSize
    var registration: FrameRegistration
    var usesScreenRegistration: Bool
    var calibrationDisplayScale: Double
    var debugMode: Bool
    var statusText: String
    var powerText: String?

    static let empty = OverlayRenderState(
        analysis: nil,
        recommendation: nil,
        guidanceState: nil,
        analysisImageSize: .zero,
        capturedFramePixelSize: .zero,
        registration: .unavailable,
        usesScreenRegistration: true,
        calibrationDisplayScale: 1,
        debugMode: false,
        statusText: "SEARCHING",
        powerText: nil
    )
}

enum HotKeyChoice: String, CaseIterable, Identifiable {
    case commandOptionA
    case commandShiftA
    case controlOptionA
    case commandOptionSpace

    var id: Self { self }

    var title: String {
        switch self {
        case .commandOptionA: "⌥⌘A"
        case .commandShiftA: "⇧⌘A"
        case .controlOptionA: "⌃⌥A"
        case .commandOptionSpace: "⌥⌘Space"
        }
    }
}

extension GuidanceState {
    var displayTitle: String {
        switch self {
        case .searching: "SEARCHING"
        case .analyzing: "ANALYZING"
        case .rotateLeft: "ROTATE LEFT"
        case .rotateRight: "ROTATE RIGHT"
        case .fineAlignment: "FINE ALIGNMENT"
        case .aimLocked: "AIM LOCKED"
        case .morePower: "MORE POWER"
        case .lessPower: "LESS POWER"
        case .ready: "READY"
        case .doNotShoot: "DO NOT SHOOT"
        case .waitingForTurn: "WAITING FOR TURN"
        }
    }

    var symbol: String {
        switch self {
        case .rotateLeft: "rotate.left"
        case .rotateRight: "rotate.right"
        case .fineAlignment: "scope"
        case .aimLocked, .ready: "target"
        case .morePower: "arrow.up"
        case .lessPower: "arrow.down"
        case .doNotShoot: "hand.raised.fill"
        case .waitingForTurn: "hourglass"
        case .searching, .analyzing: "viewfinder"
        }
    }
}

extension GroupAssignment {
    var displayTitle: String {
        switch self {
        case .open: "Open table"
        case .solids: "Solids"
        case .stripes: "Stripes"
        }
    }
}

extension MatchTurn {
    var displayTitle: String {
        switch self {
        case .player: "My turn"
        case .opponent: "Opponent's turn"
        case .unknown: "Turn unknown"
        }
    }
}

extension PocketID {
    var displayTitle: String {
        switch self {
        case .topLeft: "Top left"
        case .topCenter: "Top center"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomCenter: "Bottom center"
        case .bottomRight: "Bottom right"
        }
    }
}
