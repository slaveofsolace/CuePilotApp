import AppKit
import Combine
import CueGeometry
import CuePresentation
import CueStrategy
import Foundation

@MainActor
final class CuePilotMacModel: ObservableObject {
    @Published var destination: SidebarDestination = .capture
    @Published var availableWindows: [CaptureWindowOption] = []
    @Published var selectedWindowID: CGWindowID?
    @Published var lifecycle: CaptureLifecycle = .ready
    @Published var latestFrameImage: NSImage?
    @Published var latestFramePixelSize: CGSize = .zero
    @Published var latestAnalysis: AnalysisPacket?
    @Published var analysisEnabled = false
    @Published var isInspectorPresented = true
    @Published var registration: FrameRegistration = .unavailable
    @Published var frameLatencyMilliseconds = 0.0
    @Published var analysisLatencyMilliseconds = 0.0
    @Published var framesPerSecond = 0.0
    @Published var permissionHelpVisible = false
    @Published var calibrationAimBias = 0.0 {
        didSet {
            let clamped = min(4, max(-4, calibrationAimBias))
            guard clamped == calibrationAimBias else {
                calibrationAimBias = clamped
                return
            }
            UserDefaults.standard.set(
                calibrationAimBias,
                forKey: DefaultsKey.calibrationAimBias
            )
            analysisConfigurationDidChange()
        }
    }
    @Published var calibrationDisplayScale = 1.0 {
        didSet {
            let clamped = min(1.1, max(0.9, calibrationDisplayScale))
            guard clamped == calibrationDisplayScale else {
                calibrationDisplayScale = clamped
                return
            }
            UserDefaults.standard.set(
                calibrationDisplayScale,
                forKey: DefaultsKey.calibrationDisplayScale
            )
            updateOverlayPresentation()
        }
    }
    @Published var groupAssignment: GroupAssignment = .open {
        didSet {
            UserDefaults.standard.set(
                groupAssignment.rawValue,
                forKey: DefaultsKey.groupAssignment
            )
            analysisConfigurationDidChange()
        }
    }
    @Published var matchTurn: MatchTurn = .player {
        didSet {
            UserDefaults.standard.set(
                matchTurn.rawValue,
                forKey: DefaultsKey.matchTurn
            )
            analysisConfigurationDidChange()
        }
    }
    @Published var requiredEightBallPocket: PocketID? {
        didSet {
            UserDefaults.standard.set(
                requiredEightBallPocket?.rawValue,
                forKey: DefaultsKey.requiredEightBallPocket
            )
            analysisConfigurationDidChange()
        }
    }
    @Published var overlayOpacity = 0.72 {
        didSet {
            let clamped = min(1, max(0.2, overlayOpacity))
            guard clamped == overlayOpacity else {
                overlayOpacity = clamped
                return
            }
            UserDefaults.standard.set(
                overlayOpacity,
                forKey: DefaultsKey.overlayOpacity
            )
            updateOverlayPresentation()
        }
    }
    @Published var debugMode = false {
        didSet {
            UserDefaults.standard.set(debugMode, forKey: DefaultsKey.debugMode)
            updateOverlayPresentation()
        }
    }
    @Published var hotKeyChoice: HotKeyChoice = .commandOptionA {
        didSet {
            UserDefaults.standard.set(
                hotKeyChoice.rawValue,
                forKey: DefaultsKey.hotKey
            )
            hotKeyController.register(hotKeyChoice)
        }
    }

    private let captureService = WindowCaptureService()
    private let analysisWorker = FrameAnalysisWorker()
    private let overlayController = OverlayPanelController()
    private var isCaptureAttached = false
    private var analysisInFlightGeneration: UInt64?
    private var analysisGeneration: UInt64 = 0
    private var captureStopTask: Task<Void, Never>?
    private var frameArrivalTimes: [ContinuousClock.Instant] = []
    private var latestFrameRegistration = FrameRegistration.unavailable
    private var missingRegistrationPolls = 0
    private var lastValidFrameAt: ContinuousClock.Instant?
    private var frameWatchdogTask: Task<Void, Never>?
    private lazy var hotKeyController = GlobalHotKeyController { [weak self] in
        Task { @MainActor in
            self?.toggleAnalysis()
        }
    }

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: DefaultsKey.overlayOpacity) != nil {
            overlayOpacity = defaults.double(forKey: DefaultsKey.overlayOpacity)
        }
        debugMode = defaults.bool(forKey: DefaultsKey.debugMode)
        calibrationAimBias = defaults.double(forKey: DefaultsKey.calibrationAimBias)
        if defaults.object(forKey: DefaultsKey.calibrationDisplayScale) != nil {
            calibrationDisplayScale = defaults.double(
                forKey: DefaultsKey.calibrationDisplayScale
            )
        }
        if let rawHotKey = defaults.string(forKey: DefaultsKey.hotKey),
           let savedHotKey = HotKeyChoice(rawValue: rawHotKey) {
            hotKeyChoice = savedHotKey
        }
        if let rawGroup = defaults.string(forKey: DefaultsKey.groupAssignment),
           let savedGroup = GroupAssignment(rawValue: rawGroup) {
            groupAssignment = savedGroup
        }
        if let rawTurn = defaults.string(forKey: DefaultsKey.matchTurn),
           let savedTurn = MatchTurn(rawValue: rawTurn) {
            matchTurn = savedTurn
        }
        if let rawPocket = defaults.string(
            forKey: DefaultsKey.requiredEightBallPocket
        ) {
            requiredEightBallPocket = PocketID(rawValue: rawPocket)
        }

        captureService.onFrame = { [weak self] frame in
            self?.receive(frame)
        }
        captureService.onFailure = { [weak self] message in
            self?.captureDidFail(message)
        }
        captureService.onRegistrationChange = { [weak self] registration in
            self?.registrationDidChange(registration)
        }
        hotKeyController.register(hotKeyChoice)
    }

    var selectedWindow: CaptureWindowOption? {
        availableWindows.first { $0.id == selectedWindowID }
    }

    var liveGameConfiguration: LiveGameConfiguration {
        LiveGameConfiguration(
            groupAssignment: groupAssignment,
            turn: matchTurn,
            requiredEightBallPocket: requiredEightBallPocket,
            aimBiasDegrees: calibrationAimBias
        )
    }

    var hasCapturedFrame: Bool {
        latestFrameImage != nil
    }

    var isAligned: Bool {
        hasCapturedFrame &&
            registration.isOnScreen &&
            registration.screenRect.width > 0 &&
            registration.screenRect.height > 0
    }

    var captureStatusColor: NSColor {
        switch lifecycle {
        case .capturing:
            .systemGreen
        case .starting, .discovering:
            .systemYellow
        case .ready:
            .systemTeal
        case .paused, .noMirroringWindow, .permissionRequired, .failed:
            .systemOrange
        }
    }

    var guidanceTitle: String {
        guard analysisEnabled else { return "ANALYSIS PAUSED" }
        guard let guidance = latestAnalysis?.guidance?.guidance else {
            return hasCapturedFrame ? "ANALYZING" : "WAITING FOR FRAME"
        }
        switch guidance.state {
        case .rotateLeft, .rotateRight:
            let degrees = abs(guidance.signedCorrection) * 180 / .pi
            return "\(guidance.state.displayTitle) \(degrees.formatted(.number.precision(.fractionLength(1))))°"
        default:
            return guidance.state.displayTitle
        }
    }

    var guidanceState: GuidanceState? {
        latestAnalysis?.guidance?.guidance.state
    }

    var powerRecommendation: String? {
        guard let range = latestAnalysis?.recommendation?.candidate.powerRange else {
            return nil
        }
        let lower = Int((range.minimum * 100).rounded())
        let upper = Int((range.maximum * 100).rounded())
        return "POWER \(lower)–\(upper)%"
    }

    var analysisConfidenceText: String {
        guard let analysis = latestAnalysis?.analysis else { return "—" }
        return analysis.overallConfidence.formatted(
            .percent.precision(.fractionLength(0))
        )
    }

    func refreshWindows() async {
        lifecycle = .discovering
        do {
            let windows = try await captureService.discoverWindows()
            availableWindows = windows
            permissionHelpVisible = false

            if let selectedWindowID,
               windows.contains(where: { $0.id == selectedWindowID }) {
                lifecycle = isCaptureAttached ? .capturing : .ready
                return
            }

            selectedWindowID = nil
            guard let mirroring = windows.first(where: \.isLikelyIPhoneMirroring) else {
                lifecycle = .noMirroringWindow
                return
            }
            selectedWindowID = mirroring.id
            lifecycle = .ready
        } catch {
            let message = error.localizedDescription
            if !CGPreflightScreenCaptureAccess() {
                lifecycle = .permissionRequired
                permissionHelpVisible = true
            } else {
                lifecycle = .failed(message)
            }
        }
    }

    func selectWindow(_ id: CGWindowID) {
        guard availableWindows.contains(where: { $0.id == id }),
              id != selectedWindowID else {
            return
        }
        let hadCapture = isCaptureAttached
        analysisEnabled = false
        analysisGeneration &+= 1
        analysisInFlightGeneration = nil
        isCaptureAttached = false
        cancelFrameWatchdog()
        captureService.setAnalysisEnabled(false)
        selectedWindowID = id
        clearLiveFrame()
        lifecycle = .ready

        guard hadCapture else { return }
        scheduleCaptureStop()
    }

    func toggleAnalysis() {
        if analysisEnabled {
            stopAnalysis()
        } else {
            startAnalysis()
        }
    }

    func startAnalysis() {
        guard !analysisEnabled else { return }
        analysisEnabled = true
        analysisGeneration &+= 1
        let generation = analysisGeneration
        lifecycle = .starting
        captureService.setAnalysisEnabled(true)
        overlayController.hide()

        Task { [weak self] in
            await self?.beginAnalysis(generation: generation)
        }
    }

    func stopAnalysis() {
        guard analysisEnabled || isCaptureAttached else { return }
        analysisEnabled = false
        analysisGeneration &+= 1
        analysisInFlightGeneration = nil
        isCaptureAttached = false
        cancelFrameWatchdog()
        captureService.setAnalysisEnabled(false)
        clearLiveFrame()
        lifecycle = .ready
        scheduleCaptureStop()
    }

    func revealScreenRecordingSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openIPhoneMirroring() {
        let locations = [
            "/System/Applications/iPhone Mirroring.app",
            "/Applications/iPhone Mirroring.app",
        ]
        guard let path = locations.first(where: {
            FileManager.default.fileExists(atPath: $0)
        }) else {
            return
        }
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: path),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    func showCalibration() {
        destination = .calibration
        NSApp.activate(ignoringOtherApps: true)
    }

    private func beginAnalysis(generation: UInt64) async {
        if let captureStopTask {
            await captureStopTask.value
        }
        if selectedWindowID == nil {
            await refreshWindows()
        }
        guard analysisEnabled,
              generation == analysisGeneration,
              let selectedWindowID else {
            return
        }
        await attach(to: selectedWindowID, generation: generation)
    }

    private func attach(to id: CGWindowID, generation: UInt64) async {
        guard analysisEnabled, generation == analysisGeneration else { return }
        lifecycle = .starting
        selectedWindowID = id
        clearLiveFrame()
        registration = .unavailable
        latestFrameRegistration = .unavailable
        missingRegistrationPolls = 0
        await analysisWorker.reset()
        guard analysisEnabled, generation == analysisGeneration else { return }

        do {
            try await captureService.startCapture(
                windowID: id,
                analysisEnabled: true
            )
            guard analysisEnabled, generation == analysisGeneration else {
                await captureService.stopCapture()
                return
            }
            isCaptureAttached = true
            lifecycle = .capturing
            permissionHelpVisible = false
            lastValidFrameAt = ContinuousClock().now
            startFrameWatchdog()
        } catch {
            guard generation == analysisGeneration else { return }
            isCaptureAttached = false
            cancelFrameWatchdog()
            if !CGPreflightScreenCaptureAccess() {
                lifecycle = .permissionRequired
                permissionHelpVisible = true
            } else {
                lifecycle = .failed(error.localizedDescription)
            }
        }
    }

    private func receive(_ frame: CapturedFrame) {
        guard analysisEnabled, isCaptureAttached, frame.isComplete else { return }
        lastValidFrameAt = frame.receivedAt
        if analysisEnabled {
            captureService.setAnalysisEnabled(true)
        }
        latestFrameImage = NSImage(cgImage: frame.image, size: .zero)
        latestFramePixelSize = frame.pixelSize
        frameLatencyMilliseconds = frame.latencyMilliseconds
        lifecycle = .capturing
        if registration.isOnScreen {
            latestFrameRegistration = frame.registration.updatingScreenGeometry(
                from: registration
            )
            registration = latestFrameRegistration
        } else if frame.registration.isOnScreen {
            latestFrameRegistration = frame.registration
            registration = frame.registration
        } else {
            latestFrameRegistration = frame.registration
        }
        updateFrameRate(now: frame.receivedAt)
        updateOverlayVisibility()

        guard analysisEnabled,
              analysisInFlightGeneration == nil,
              let analysisImage = frame.analysisImage else {
            return
        }
        let generation = analysisGeneration
        analysisInFlightGeneration = generation
        let configuration = liveGameConfiguration

        Task { [weak self, analysisImage, configuration] in
            guard let self else { return }
            let packet = await analysisWorker.analyze(
                analysisImage,
                configuration: configuration
            )
            if analysisInFlightGeneration == generation {
                analysisInFlightGeneration = nil
            }
            guard generation == analysisGeneration, analysisEnabled else {
                return
            }
            latestAnalysis = packet
            analysisLatencyMilliseconds = packet.durationMilliseconds
            updateOverlayPresentation()
        }
    }

    private func registrationDidChange(_ polled: FrameRegistration) {
        guard let selectedWindowID else {
            overlayController.hide()
            return
        }
        let effective: FrameRegistration
        if polled.isOnScreen {
            missingRegistrationPolls = 0
            effective = latestFrameRegistration.hasSurfaceMetadata
                ? latestFrameRegistration.updatingScreenGeometry(from: polled)
                : polled
        } else if latestFrameRegistration.isOnScreen,
                  missingRegistrationPolls < 2 {
            missingRegistrationPolls += 1
            effective = latestFrameRegistration
        } else {
            missingRegistrationPolls += 1
            effective = polled
        }
        registration = effective

        if effective.isOnScreen {
            overlayController.register(
                to: selectedWindowID,
                registration: effective
            )
            if isCaptureAttached, hasCapturedFrame {
                lifecycle = .capturing
            }
        } else {
            lifecycle = .paused
            overlayController.hide()
        }
    }

    private func captureDidFail(_ message: String) {
        analysisEnabled = false
        analysisGeneration &+= 1
        analysisInFlightGeneration = nil
        lifecycle = .failed(message)
        isCaptureAttached = false
        cancelFrameWatchdog()
        clearLiveFrame()
    }

    private func updateFrameRate(now: ContinuousClock.Instant) {
        frameArrivalTimes.append(now)
        let cutoff = now.advanced(by: .seconds(-1))
        frameArrivalTimes.removeAll { $0 < cutoff }
        framesPerSecond = Double(frameArrivalTimes.count)
    }

    private func updateOverlayVisibility() {
        guard analysisEnabled,
              hasCapturedFrame,
              isAligned,
              selectedWindowID != nil else {
            overlayController.hide()
            return
        }
        updateOverlayPresentation()
        overlayController.setVisible(true)
    }

    private func updateOverlayPresentation() {
        let state = OverlayRenderState(
            analysis: latestAnalysis?.analysis,
            recommendation: latestAnalysis?.recommendation,
            guidanceState: guidanceState,
            analysisImageSize: latestAnalysis?.imageSize ?? .zero,
            capturedFramePixelSize: latestFramePixelSize,
            registration: registration,
            usesScreenRegistration: true,
            calibrationDisplayScale: calibrationDisplayScale,
            debugMode: debugMode,
            statusText: guidanceTitle,
            powerText: powerRecommendation
        )
        overlayController.update(state: state, opacity: overlayOpacity)
        if let selectedWindowID, registration.isOnScreen {
            overlayController.register(
                to: selectedWindowID,
                registration: registration
            )
        }
    }

    private func analysisConfigurationDidChange() {
        analysisGeneration &+= 1
        analysisInFlightGeneration = nil
        latestAnalysis = nil
        updateOverlayPresentation()
        guard analysisEnabled else { return }
        captureService.setAnalysisEnabled(true)
        Task { [analysisWorker] in
            await analysisWorker.reset()
        }
    }

    private func startFrameWatchdog() {
        frameWatchdogTask?.cancel()
        frameWatchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                guard self.analysisEnabled,
                      self.isCaptureAttached,
                      let lastValidFrameAt = self.lastValidFrameAt else {
                    continue
                }
                let age = lastValidFrameAt.duration(to: ContinuousClock().now)
                guard age >= .milliseconds(1_250) else { continue }
                self.captureService.setAnalysisEnabled(false)
                self.analysisGeneration &+= 1
                self.analysisInFlightGeneration = nil
                self.lastValidFrameAt = nil
                self.clearLiveFrame()
                self.lifecycle = .paused
            }
        }
    }

    private func cancelFrameWatchdog() {
        frameWatchdogTask?.cancel()
        frameWatchdogTask = nil
        lastValidFrameAt = nil
    }

    private func scheduleCaptureStop() {
        let priorStop = captureStopTask
        captureStopTask = Task { [captureService] in
            if let priorStop {
                await priorStop.value
            }
            await captureService.stopCapture()
        }
    }

    private func clearLiveFrame() {
        latestFrameImage = nil
        latestFramePixelSize = .zero
        latestAnalysis = nil
        registration = .unavailable
        latestFrameRegistration = .unavailable
        frameArrivalTimes.removeAll()
        framesPerSecond = 0
        overlayController.hide()
    }
}

private enum DefaultsKey {
    static let overlayOpacity = "overlayOpacity"
    static let debugMode = "debugMode"
    static let hotKey = "analysisHotKey"
    static let calibrationAimBias = "calibrationAimBias"
    static let calibrationDisplayScale = "calibrationDisplayScale"
    static let groupAssignment = "groupAssignment"
    static let matchTurn = "matchTurn"
    static let requiredEightBallPocket = "requiredEightBallPocket"
}
