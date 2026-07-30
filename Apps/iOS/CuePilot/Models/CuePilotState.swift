import CueGeometry
import CuePresentation
import CueStrategy
import CueVision
import Foundation
import Observation
import UIKit

enum BallAppearance: String, CaseIterable, Codable, Sendable {
    case cue
    case eight
    case solid
    case stripe
    case unknown
}

struct DisplayBall: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var number: Int
    var appearance: BallAppearance
    var x: Double
    var y: Double
    var confidence: Double

    init(
        id: UUID = UUID(),
        number: Int,
        appearance: BallAppearance,
        x: Double,
        y: Double,
        confidence: Double = 1
    ) {
        self.id = id
        self.number = number
        self.appearance = appearance
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

struct ReviewMarker: Identifiable, Hashable, Codable, Sendable {
    var id: Int
    var x: Double
    var y: Double
}

enum PlayerGroup: String, CaseIterable, Codable, Sendable {
    case open = "Open table"
    case solids = "Solids"
    case stripes = "Stripes"
}

enum AlignmentDisplayState: String, Codable, Sendable {
    case searching = "SEARCHING"
    case analyzing = "ANALYZING"
    case rotateLeft = "ROTATE LEFT"
    case rotateRight = "ROTATE RIGHT"
    case fineAlignment = "FINE ALIGNMENT"
    case aimLocked = "AIM LOCKED"
    case morePower = "MORE POWER"
    case lessPower = "LESS POWER"
    case ready = "READY"
    case waiting = "WAITING FOR TURN"
    case doNotShoot = "DO NOT SHOOT"
}

struct ShotHistoryItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
    let result: String
    let successful: Bool
}

@MainActor
@Observable
final class CuePilotState {
    var screenshot: UIImage?
    var balls: [DisplayBall] = []
    var selectedBallID: DisplayBall.ID?
    var detectionConfidence = 0.0
    var detectionStatus = "Select a screenshot"
    var screenshotAnalysisInProgress = false
    var reviewMode = 1
    var tableCornerMarkers: [ReviewMarker] = []
    var pocketMarkers: [ReviewMarker] = []

    var group: PlayerGroup = .solids {
        didSet { synchronizeLiveConfiguration() }
    }
    var isUsersTurn = true {
        didSet { synchronizeLiveConfiguration() }
    }
    var requiredEightBallPocket: PocketID? {
        didSet { synchronizeLiveConfiguration() }
    }
    var alignment: AlignmentDisplayState = .searching
    var angularCorrection = 0.0
    var currentPower = 0.0
    var recommendedPower = 0.0 ... 0.0
    var shotConfidence = 0.0
    var overlayOpacity = 0.72
    var analysisMode = 1
    var confidenceThreshold = 0.75
    var audioGuidance = true
    var isCalibrated = true
    var broadcastActive = false
    var liveStateSequence: UInt64 = 0
    var liveLatencyMilliseconds: Double?
    var recommendation: ShotRecommendation?

    var history: [ShotHistoryItem] = []

    let pictureInPicture = PictureInPictureGuide()
    @ObservationIgnored private let screenshotAnalyzer = VisionAnalyzer()
    @ObservationIgnored private var liveStateTask: Task<Void, Never>?
    @ObservationIgnored private var screenshotRequestID = 0
    @ObservationIgnored private var lastLiveTimestampNanoseconds: UInt64 = 0
    @ObservationIgnored private var reviewSnapshot:
        CueVision.DetectionReview?
    @ObservationIgnored private var reviewImageSize = (width: 1, height: 1)
    private var automaticTableDetectionSucceeded = true
    private var manualGeometryConfirmed = false

    var pictureInPictureReady: Bool {
        pictureInPicture.isPossible
    }

    var pictureInPictureActive: Bool {
        pictureInPicture.isActive
    }

    var selectedBall: DisplayBall? {
        guard let selectedBallID else { return nil }
        return balls.first { $0.id == selectedBallID }
    }

    var needsManualGeometryConfirmation: Bool {
        reviewSnapshot != nil
            && !automaticTableDetectionSucceeded
            && !manualGeometryConfirmed
    }

    var requiresEightBallPocket: Bool {
        guard let analysis = reviewSnapshot?.analysis,
              let table = analysis.table else {
            return false
        }
        return needsCalledPocket(
            balls: analysis.balls.map(\.ball),
            table: table.geometry
        )
    }

    var detectionValidationMessage: String? {
        guard screenshot != nil else {
            return "Select a screenshot before continuing."
        }
        guard !screenshotAnalysisInProgress else {
            return "Analysis is still running."
        }
        guard let analysis = reviewSnapshot?.analysis,
              let table = analysis.table,
              table.corners.count == 4 else {
            return "Confirm the table boundary."
        }
        guard automaticTableDetectionSucceeded || manualGeometryConfirmed else {
            return "Adjust and confirm the manual table geometry."
        }
        let pocketIDs = Set(analysis.pockets.map(\.geometry.id))
        guard pocketIDs.count == PocketID.allCases.count,
              table.geometry.pockets.count == PocketID.allCases.count else {
            return "Confirm all six pocket centers."
        }
        let detectedBalls = analysis.balls.map(\.ball)
        guard !detectedBalls.isEmpty else {
            return "Add the visible balls."
        }
        guard detectedBalls.filter({ $0.kind == .cue }).count == 1 else {
            return "Classify exactly one cue ball."
        }
        guard detectedBalls.contains(where: { $0.isObjectBall }) else {
            return "Add at least one object ball."
        }
        guard !detectedBalls.contains(where: { $0.kind == .unknown }) else {
            return "Classify every detected ball."
        }
        guard Set(detectedBalls.map(\.id)).count == detectedBalls.count else {
            return "Each ball must have a unique identifier."
        }
        guard detectedBalls.allSatisfy({
            table.geometry.containsBall(
                center: $0.center,
                radius: $0.radius
            )
        }) else {
            return "Move every ball inside the playable table."
        }
        guard !requiresEightBallPocket || requiredEightBallPocket != nil else {
            return "Choose the called pocket for the 8-ball."
        }
        return nil
    }

    var canFinishDetectionReview: Bool {
        detectionValidationMessage == nil
    }

    func loadScreenshot(data: Data) {
        screenshotRequestID += 1
        let requestID = screenshotRequestID
        resetDetectionReview()

        guard let image = UIImage(data: data) else {
            detectionStatus = "Could not read image"
            return
        }
        screenshot = image
        alignment = .analyzing
        screenshotAnalysisInProgress = true
        detectionStatus = "Analyzing on device"

        guard let rgbaImage = ScreenshotImageConverter.rgbaImage(from: image)
        else {
            screenshotAnalysisInProgress = false
            detectionStatus = "Could not prepare image"
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let analysis = await screenshotAnalyzer.analyze(rgbaImage)
            guard requestID == screenshotRequestID else { return }
            screenshotAnalysisInProgress = false
            apply(
                analysis,
                imageWidth: rgbaImage.width,
                imageHeight: rgbaImage.height,
                resetReview: true
            )
        }
    }

    func failScreenshotLoad() {
        screenshotRequestID += 1
        resetDetectionReview()
        detectionStatus = "Could not load screenshot"
    }

    func moveTableCorner(
        index: Int,
        x: Double,
        y: Double
    ) {
        guard let reviewSnapshot else { return }
        if !automaticTableDetectionSucceeded {
            manualGeometryConfirmed = false
        }
        let point = Point2D(
            x: x * Double(reviewImageSize.width),
            y: y * Double(reviewImageSize.height)
        )
        let corrected = reviewSnapshot.applying(
            .setTableCorner(index: index, pixelPoint: point)
        )
        self.reviewSnapshot = corrected
        apply(
            corrected.analysis,
            imageWidth: reviewImageSize.width,
            imageHeight: reviewImageSize.height,
            resetReview: false
        )
    }

    func moveBall(
        id: DisplayBall.ID,
        x: Double,
        y: Double
    ) {
        guard let reviewSnapshot,
              let table = reviewSnapshot.analysis.table,
              let displayBall = balls.first(where: { $0.id == id }) else {
            return
        }
        let canonical = Point2D(
            x: min(max(x, 0), 1) * 2,
            y: min(max(y, 0), 1)
        )
        guard let pixelPoint = pixelPoint(
            for: canonical,
            table: table
        ) else {
            return
        }
        let corrected = reviewSnapshot.applying(
            .moveBall(
                id: displayBall.number,
                canonicalCenter: canonical,
                pixelCenter: pixelPoint
            )
        )
        self.reviewSnapshot = corrected
        apply(
            corrected.analysis,
            imageWidth: reviewImageSize.width,
            imageHeight: reviewImageSize.height,
            resetReview: false
        )
    }

    func classifyBall(
        id: DisplayBall.ID,
        as appearance: BallAppearance
    ) {
        guard let reviewSnapshot,
              let displayBall = balls.first(where: { $0.id == id }) else {
            return
        }
        let corrected = reviewSnapshot.applying(
            .classifyBall(
                id: displayBall.number,
                kind: appearance.ballKind
            )
        )
        self.reviewSnapshot = corrected
        apply(
            corrected.analysis,
            imageWidth: reviewImageSize.width,
            imageHeight: reviewImageSize.height,
            resetReview: false
        )
    }

    func confirmManualGeometry() {
        guard reviewSnapshot?.analysis.table != nil,
              pocketMarkers.count == PocketID.allCases.count else {
            return
        }
        manualGeometryConfirmed = true
        detectionStatus = "\(balls.count) balls ready for review"
    }

    func movePocket(
        index: Int,
        x: Double,
        y: Double
    ) {
        guard let reviewSnapshot,
              reviewSnapshot.analysis.pockets.indices.contains(index) else {
            return
        }
        if !automaticTableDetectionSucceeded {
            manualGeometryConfirmed = false
        }
        let pocketID = reviewSnapshot.analysis.pockets[index].geometry.id
        let point = Point2D(
            x: x * Double(reviewImageSize.width),
            y: y * Double(reviewImageSize.height)
        )
        let corrected = reviewSnapshot.applying(
            .setPocket(pocketID, pixelPoint: point)
        )
        self.reviewSnapshot = corrected
        apply(
            corrected.analysis,
            imageWidth: reviewImageSize.width,
            imageHeight: reviewImageSize.height,
            resetReview: false
        )
    }

    func startLiveStateMonitoring() {
        guard liveStateTask == nil,
              let container = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier:
                      "group.com.slaveofsolace.cuepilot"
              ) else {
            return
        }
        let fileURL = container
            .appendingPathComponent("Live", isDirectory: true)
            .appendingPathComponent("guidance.bin", isDirectory: false)
        let transport = LiveStateFileTransport(fileURL: fileURL)
        synchronizeLiveConfiguration()
        liveStateTask = Task { [weak self] in
            while !Task.isCancelled {
                if let compact = try? await transport.readLatest(),
                   compact.sequence != self?.liveStateSequence {
                    self?.apply(compact)
                }
                self?.markLiveStateStaleIfNeeded()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    func stopLiveStateMonitoring() {
        liveStateTask?.cancel()
        liveStateTask = nil
        liveStateSequence = 0
        lastLiveTimestampNanoseconds = 0
        neutralizeLiveState()
    }

    @discardableResult
    func finishDetectionReview() -> Bool {
        guard canFinishDetectionReview,
              let analysis = reviewSnapshot?.analysis,
              let table = analysis.table?.geometry else {
            recommendation = nil
            alignment = .searching
            shotConfidence = 0
            return false
        }
        let detectedBalls = analysis.balls.map(\.ball)
        var gameState = EightBallGameState(
            table: table,
            balls: detectedBalls,
            groupAssignment: group.strategyGroup,
            turn: isUsersTurn ? .player : .opponent,
            phase: group == .open ? .openTable : .groupPlay,
            requiredEightBallPocket: requiredEightBallPocket
        )
        if EightBallRules.canShootEightBall(in: gameState) {
            gameState.phase = .eightBall
        }
        recommendation = StrategyEngine().recommendShot(
            in: gameState,
            seed: UInt64(detectedBalls.count)
        )
        guard let recommendation else {
            alignment = isUsersTurn ? .doNotShoot : .waiting
            shotConfidence = 0
            return true
        }
        recommendedPower = recommendation.candidate.powerRange.minimum
            ... recommendation.candidate.powerRange.maximum
        currentPower = recommendation.candidate.powerRange.midpoint
        shotConfidence = min(
            detectionConfidence,
            recommendation.corridor.confidence
        )
        alignment = AlignmentDisplayState(
            recommendation.guidance(
                currentAngle: nil,
                currentPower: nil,
                isPlayersTurn: isUsersTurn
            ).state
        )
        return true
    }

    func addBall() {
        guard let reviewSnapshot,
              let table = reviewSnapshot.analysis.table else {
            return
        }
        let usedIDs = Set(reviewSnapshot.analysis.balls.map(\.ball.id))
        let nextNumber = usedIDs.firstMissing(in: 0 ... 15)
            ?? ((usedIDs.max() ?? 99) + 1)
        let canonical = Point2D(x: 1, y: 0.5)
        guard let pixelCenter = pixelPoint(
            for: canonical,
            table: table
        ) else {
            return
        }
        let added = DetectedBall(
            ball: BallState(
                id: nextNumber,
                kind: .unknown,
                center: canonical,
                radius: table.geometry.defaultBallRadius,
                confidence: 1
            ),
            pixelCenter: pixelCenter,
            pixelRadius: Double(
                max(4, min(reviewImageSize.width, reviewImageSize.height) / 40)
            ),
            classificationConfidence: 0,
            uncertainty: VisionUncertainty(positionSigma: 0.25)
        )
        let corrected = reviewSnapshot.applying(.upsertBall(added))
        self.reviewSnapshot = corrected
        apply(
            corrected.analysis,
            imageWidth: reviewImageSize.width,
            imageHeight: reviewImageSize.height,
            resetReview: false
        )
        selectedBallID = balls.first {
            $0.number == nextNumber
        }?.id
    }

    func removeSelectedBall() {
        guard let reviewSnapshot,
              let selectedBallID,
              let displayBall = balls.first(where: {
                  $0.id == selectedBallID
              }) else {
            return
        }
        let corrected = reviewSnapshot.applying(
            .removeBall(id: displayBall.number)
        )
        self.reviewSnapshot = corrected
        apply(
            corrected.analysis,
            imageWidth: reviewImageSize.width,
            imageHeight: reviewImageSize.height,
            resetReview: false
        )
        self.selectedBallID = nil
    }

    func resetCalibration() {
        isCalibrated = false
        angularCorrection = 0
    }

    private func resetDetectionReview() {
        screenshot = nil
        balls = []
        selectedBallID = nil
        detectionConfidence = 0
        detectionStatus = "Preparing screenshot"
        screenshotAnalysisInProgress = false
        tableCornerMarkers = []
        pocketMarkers = []
        reviewSnapshot = nil
        reviewImageSize = (width: 1, height: 1)
        automaticTableDetectionSucceeded = true
        manualGeometryConfirmed = false
        recommendation = nil
        alignment = .searching
        shotConfidence = 0
    }

    private func pixelPoint(
        for canonicalPoint: Point2D,
        table: DetectedTable
    ) -> Point2D? {
        guard table.corners.count == 4,
              let canonicalToImage = try? ProjectiveTransform2D.mapping(
                  source: [
                      Point2D(x: 0, y: 0),
                      Point2D(x: 2, y: 0),
                      Point2D(x: 2, y: 1),
                      Point2D(x: 0, y: 1),
                  ],
                  destination: table.corners
              ) else {
            return nil
        }
        return canonicalToImage.applying(to: canonicalPoint)
    }

    private func needsCalledPocket(
        balls: [BallState],
        table: TableGeometry
    ) -> Bool {
        guard group != .open else { return false }
        let state = EightBallGameState(
            table: table,
            balls: balls,
            groupAssignment: group.strategyGroup,
            turn: isUsersTurn ? .player : .opponent,
            phase: .groupPlay,
            requiredEightBallPocket: requiredEightBallPocket
        )
        return EightBallRules.canShootEightBall(in: state)
    }

    private func apply(
        _ analysis: VisionAnalysis,
        imageWidth: Int,
        imageHeight: Int,
        resetReview: Bool
    ) {
        reviewImageSize = (
            width: max(1, imageWidth),
            height: max(1, imageHeight)
        )
        if resetReview {
            automaticTableDetectionSucceeded = analysis.table != nil
            manualGeometryConfirmed = automaticTableDetectionSucceeded
        }
        let presentedAnalysis = analysis.table != nil
            ? analysis
            : manualFallbackAnalysis(
                from: analysis,
                imageWidth: reviewImageSize.width,
                imageHeight: reviewImageSize.height
            )
        if resetReview {
            reviewSnapshot = CueVision.DetectionReview(
                analysis: presentedAnalysis
            )
        }
        let existingIDs = Dictionary(
            uniqueKeysWithValues: balls.map { ($0.number, $0.id) }
        )
        let detected = presentedAnalysis.balls.map { detected -> DisplayBall in
            let center = detected.ball.center
            return DisplayBall(
                id: existingIDs[detected.ball.id] ?? UUID(),
                number: detected.ball.id,
                appearance: BallAppearance(detected.ball.kind),
                x: min(max(center.x / 2, 0), 1),
                y: min(max(center.y, 0), 1),
                confidence: detected.ball.confidence
            )
        }
        balls = detected
        detectionConfidence = analysis.overallConfidence
        if automaticTableDetectionSucceeded {
            detectionStatus = "\(detected.count) balls found"
        } else if manualGeometryConfirmed {
            detectionStatus = "\(detected.count) balls ready for review"
        } else {
            detectionStatus = "Table not found — adjust and confirm geometry"
        }
        alignment = .searching
        if let corners = presentedAnalysis.table?.corners,
           corners.count == 4 {
            tableCornerMarkers = corners.enumerated().map {
                normalizedMarker(id: $0.offset, point: $0.element)
            }
        }
        if !presentedAnalysis.pockets.isEmpty {
            pocketMarkers = presentedAnalysis.pockets.enumerated().map {
                normalizedMarker(
                    id: $0.offset,
                    point: $0.element.pixelCenter
                )
            }
        }
        if let selectedBallID,
           !balls.contains(where: { $0.id == selectedBallID }) {
            self.selectedBallID = nil
        }
    }

    private func manualFallbackAnalysis(
        from analysis: VisionAnalysis,
        imageWidth: Int,
        imageHeight: Int
    ) -> VisionAnalysis {
        let width = Double(max(1, imageWidth))
        let height = Double(max(1, imageHeight))
        let corners = [
            Point2D(x: width * 0.08, y: height * 0.08),
            Point2D(x: width * 0.92, y: height * 0.08),
            Point2D(x: width * 0.92, y: height * 0.92),
            Point2D(x: width * 0.08, y: height * 0.92),
        ]
        guard let transform = try? ProjectiveTransform2D.mapping(
            source: corners,
            destination: [
                Point2D(x: 0, y: 0),
                Point2D(x: 2, y: 0),
                Point2D(x: 2, y: 1),
                Point2D(x: 0, y: 1),
            ]
        ) else {
            return analysis
        }

        var result = analysis
        let geometry = TableGeometry.standard()
        result.table = DetectedTable(
            corners: corners,
            imageToCanonical: transform,
            geometry: geometry,
            confidence: 0.15,
            uncertainty: VisionUncertainty(positionSigma: 12)
        )
        let locations = [
            Point2D(x: width * 0.08, y: height * 0.08),
            Point2D(x: width * 0.50, y: height * 0.08),
            Point2D(x: width * 0.92, y: height * 0.08),
            Point2D(x: width * 0.08, y: height * 0.92),
            Point2D(x: width * 0.50, y: height * 0.92),
            Point2D(x: width * 0.92, y: height * 0.92),
        ]
        result.pockets = zip(geometry.pockets, locations).map {
            DetectedPocket(
                geometry: $0.0,
                pixelCenter: $0.1,
                confidence: 0.15,
                uncertainty: VisionUncertainty(positionSigma: 12)
            )
        }
        return result
    }

    private func normalizedMarker(
        id: Int,
        point: Point2D
    ) -> ReviewMarker {
        ReviewMarker(
            id: id,
            x: min(
                max(point.x / Double(reviewImageSize.width), 0),
                1
            ),
            y: min(
                max(point.y / Double(reviewImageSize.height), 0),
                1
            )
        )
    }

    private func apply(_ compact: CompactLiveState) {
        let now = DispatchTime.now().uptimeNanoseconds
        liveStateSequence = compact.sequence
        guard compact.timestampNanoseconds > 0,
              now >= compact.timestampNanoseconds,
              now - compact.timestampNanoseconds <= 1_500_000_000,
              compact.recommendedPowerMinimum.isFinite,
              compact.recommendedPowerMaximum.isFinite,
              compact.recommendedPowerMinimum
                <= compact.recommendedPowerMaximum,
              compact.confidence.isFinite else {
            neutralizeLiveState()
            return
        }
        lastLiveTimestampNanoseconds = compact.timestampNanoseconds
        broadcastActive = true
        alignment = AlignmentDisplayState(compact.alignment)
        angularCorrection =
            Double(compact.signedAngularError) * 180 / .pi
        currentPower = Double(
            compact.currentVisiblePower
                ?? (compact.recommendedPowerMinimum
                    + compact.recommendedPowerMaximum) / 2
        )
        recommendedPower = Double(compact.recommendedPowerMinimum)
            ... Double(compact.recommendedPowerMaximum)
        shotConfidence = Double(compact.confidence)
        liveLatencyMilliseconds =
            Double(now - compact.timestampNanoseconds) / 1_000_000
        pictureInPicture.render(liveState: compact)
    }

    private func markLiveStateStaleIfNeeded() {
        guard broadcastActive, lastLiveTimestampNanoseconds > 0 else {
            return
        }
        let now = DispatchTime.now().uptimeNanoseconds
        guard now >= lastLiveTimestampNanoseconds,
              now - lastLiveTimestampNanoseconds > 1_500_000_000 else {
            return
        }
        neutralizeLiveState()
    }

    private func synchronizeLiveConfiguration() {
        let defaults = UserDefaults(
            suiteName: "group.com.slaveofsolace.cuepilot"
        )
        defaults?.set(group.strategyGroup.rawValue, forKey: "live.group")
        defaults?.set(
            isUsersTurn
                ? MatchTurn.player.rawValue
                : MatchTurn.opponent.rawValue,
            forKey: "live.turn"
        )
        if let requiredEightBallPocket {
            defaults?.set(
                requiredEightBallPocket.rawValue,
                forKey: "live.requiredEightBallPocket"
            )
        } else {
            defaults?.removeObject(
                forKey: "live.requiredEightBallPocket"
            )
        }
    }

    private func neutralizeLiveState() {
        broadcastActive = false
        alignment = .searching
        angularCorrection = 0
        currentPower = 0
        recommendedPower = 0 ... 0
        shotConfidence = 0
        liveLatencyMilliseconds = nil
        pictureInPicture.clearLiveData()
    }
}

extension BallAppearance {
    init(_ kind: BallKind) {
        switch kind {
        case .cue:
            self = .cue
        case .eight:
            self = .eight
        case .stripe:
            self = .stripe
        case .solid, .unknown:
            self = kind == .unknown ? .unknown : .solid
        }
    }

    var ballKind: BallKind {
        switch self {
        case .cue:
            .cue
        case .eight:
            .eight
        case .solid:
            .solid
        case .stripe:
            .stripe
        case .unknown:
            .unknown
        }
    }

    var displayName: String {
        switch self {
        case .cue:
            "Cue"
        case .eight:
            "8-ball"
        case .solid:
            "Solid"
        case .stripe:
            "Stripe"
        case .unknown:
            "Unclassified"
        }
    }
}

private extension DisplayBall {
    var ballKind: BallKind {
        appearance.ballKind
    }
}

extension PocketID {
    var displayName: String {
        switch self {
        case .topLeft:
            "Top left"
        case .topCenter:
            "Top side"
        case .topRight:
            "Top right"
        case .bottomLeft:
            "Bottom left"
        case .bottomCenter:
            "Bottom side"
        case .bottomRight:
            "Bottom right"
        }
    }
}

private extension PlayerGroup {
    var strategyGroup: GroupAssignment {
        switch self {
        case .open:
            .open
        case .solids:
            .solids
        case .stripes:
            .stripes
        }
    }
}

private extension AlignmentDisplayState {
    init(_ state: GuidanceState) {
        switch state {
        case .searching:
            self = .searching
        case .analyzing:
            self = .analyzing
        case .rotateLeft:
            self = .rotateLeft
        case .rotateRight:
            self = .rotateRight
        case .fineAlignment:
            self = .fineAlignment
        case .morePower:
            self = .morePower
        case .lessPower:
            self = .lessPower
        case .aimLocked:
            self = .aimLocked
        case .ready:
            self = .ready
        case .doNotShoot:
            self = .doNotShoot
        case .waitingForTurn:
            self = .waiting
        }
    }
}

private extension Set<Int> {
    func firstMissing(in range: ClosedRange<Int>) -> Int? {
        range.first { !contains($0) }
    }
}
