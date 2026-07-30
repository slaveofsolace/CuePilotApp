import CoreMedia
import CoreVideo
import CueGeometry
import CuePhysics
import CuePresentation
import CueStrategy
import CueVision
import Foundation
import ImageIO
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let worker = BroadcastAnalysisWorker()
    private let frameGate = BroadcastFrameGate()

    override func broadcastStarted(
        withSetupInfo setupInfo: [String: NSObject]?
    ) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier:
                "group.com.slaveofsolace.cuepilot"
        ) else {
            finishBroadcastWithError(BroadcastFailure.appGroupUnavailable)
            return
        }

        let fileURL = container
            .appendingPathComponent("Live", isDirectory: true)
            .appendingPathComponent("guidance.bin", isDirectory: false)
        Task { [worker] in
            await worker.start(fileURL: fileURL)
        }
    }

    override func broadcastPaused() {
        Task { [worker] in
            await worker.setPaused(true)
        }
    }

    override func broadcastResumed() {
        Task { [worker] in
            await worker.setPaused(false)
        }
    }

    override func broadcastFinished() {
        Task { [worker] in
            await worker.stop()
        }
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        guard sampleBufferType == .video,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let timestamp = DispatchTime.now().uptimeNanoseconds
        guard frameGate.beginFrame(timestampNanoseconds: timestamp) else {
            return
        }
        guard let image = RGBAImage(
            pixelBuffer: pixelBuffer,
            maximumDimension: 720
        ) else {
            frameGate.endFrame()
            return
        }
        let orientation = LiveOrientation(sampleBuffer: sampleBuffer)
        Task { [worker, frameGate] in
            defer { frameGate.endFrame() }
            await worker.submit(
                image,
                timestampNanoseconds: timestamp,
                orientation: orientation
            )
        }
    }
}

private final class BroadcastFrameGate: @unchecked Sendable {
    private let lock = NSLock()
    private var frameInFlight = false
    private var lastAcceptedTimestamp: UInt64 = 0
    private let minimumFrameInterval: UInt64 = 100_000_000

    func beginFrame(timestampNanoseconds: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !frameInFlight,
              timestampNanoseconds >= lastAcceptedTimestamp,
              timestampNanoseconds - lastAcceptedTimestamp
                >= minimumFrameInterval else {
            return false
        }
        frameInFlight = true
        lastAcceptedTimestamp = timestampNanoseconds
        return true
    }

    func endFrame() {
        lock.lock()
        frameInFlight = false
        lock.unlock()
    }
}

private actor BroadcastAnalysisWorker {
    private let analyzer = VisionAnalyzer()
    private let strategy = StrategyEngine()
    private let stabilizer = GuidanceStabilizer()
    private var transport: LiveStateFileTransport?
    private var sharedDefaults: UserDefaults?
    private var isPaused = false
    private var cachedGameState: EightBallGameState?
    private var cachedRecommendation: ShotRecommendation?

    func start(fileURL: URL) {
        transport = LiveStateFileTransport(fileURL: fileURL)
        sharedDefaults = UserDefaults(
            suiteName: "group.com.slaveofsolace.cuepilot"
        )
        isPaused = false
        cachedGameState = nil
        cachedRecommendation = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    func stop() async {
        isPaused = true
        transport = nil
        sharedDefaults = nil
        cachedGameState = nil
        cachedRecommendation = nil
        await analyzer.reset()
        await stabilizer.reset()
    }

    func submit(
        _ image: RGBAImage,
        timestampNanoseconds: UInt64,
        orientation: LiveOrientation
    ) async {
        guard !isPaused else {
            return
        }

        let analysis = await analyzer.analyze(
            image,
            timestampNanoseconds: timestampNanoseconds
        )
        let group = configuredGroup
        let turn = configuredTurn
        let requiredEightBallPocket = configuredEightBallPocket
        let state = makeGameState(
            from: analysis,
            group: group,
            turn: turn,
            requiredEightBallPocket: requiredEightBallPocket
        )
        let recommendation: ShotRecommendation?
        if state == cachedGameState {
            recommendation = cachedRecommendation
        } else {
            recommendation = state.flatMap {
                strategy.recommendShot(
                    in: $0,
                    seed: analysis.frameFingerprint
                )
            }
            cachedGameState = state
            cachedRecommendation = recommendation
        }

        var warnings: GuidanceWarning = []
        if analysis.overallConfidence < 0.62 {
            warnings.insert(.lowConfidence)
        }
        if recommendation?.candidate.scratch.level == .high {
            warnings.insert(.scratchRisk)
        }
        if recommendation?.candidate.rejections.contains(.pathBlocked) == true
            || recommendation?.candidate.rejections
                .contains(.targetPathBlocked) == true {
            warnings.insert(.pathBlocked)
        }

        let currentAngle = analysis.cueLine?.angleRadians
        let currentPower = analysis.powerTrack?.normalizedPower
        let guidance = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: currentAngle,
            currentPower: currentPower,
            isPlayersTurn: turn == .player,
            detectionConfidence: analysis.overallConfidence,
            warnings: warnings,
            timestampNanoseconds: timestampNanoseconds
        )
        let compact = CompactLiveState.make(
            sequence: analysis.sequence,
            timestampNanoseconds: timestampNanoseconds,
            orientation: orientation,
            tableConfidence: analysis.table?.confidence ?? 0,
            turn: turn,
            group: group,
            recommendation: recommendation,
            stabilizedGuidance: guidance,
            currentCueAngle: currentAngle,
            currentVisiblePower: currentPower
        )
        try? await transport?.write(compact)
    }

    private func makeGameState(
        from analysis: VisionAnalysis,
        group: GroupAssignment,
        turn: MatchTurn,
        requiredEightBallPocket: PocketID?
    ) -> EightBallGameState? {
        guard let table = analysis.table,
              analysis.balls.contains(where: {
                  $0.ball.kind == .cue && !$0.ball.isPocketed
              }),
              analysis.balls.contains(where: {
                  $0.ball.isObjectBall && !$0.ball.isPocketed
              }) else {
            return nil
        }
        var state = EightBallGameState(
            table: table.geometry,
            balls: analysis.balls.map(\.ball),
            groupAssignment: group,
            turn: turn,
            phase: group == .open ? .openTable : .groupPlay,
            requiredEightBallPocket: requiredEightBallPocket
        )
        if EightBallRules.canShootEightBall(in: state) {
            state.phase = .eightBall
        }
        return state
    }

    private var configuredGroup: GroupAssignment {
        guard let rawValue = sharedDefaults?.string(
            forKey: "live.group"
        ) else {
            return .open
        }
        return GroupAssignment(rawValue: rawValue) ?? .open
    }

    private var configuredTurn: MatchTurn {
        guard let rawValue = sharedDefaults?.string(
            forKey: "live.turn"
        ) else {
            return .player
        }
        return MatchTurn(rawValue: rawValue) ?? .player
    }

    private var configuredEightBallPocket: PocketID? {
        guard let rawValue = sharedDefaults?.string(
            forKey: "live.requiredEightBallPocket"
        ) else {
            return nil
        }
        return PocketID(rawValue: rawValue)
    }
}

private extension RGBAImage {
    init?(
        pixelBuffer: CVPixelBuffer,
        maximumDimension: Int
    ) {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer)
                == kCVPixelFormatType_32BGRA else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        let source = baseAddress.assumingMemoryBound(to: UInt8.self)
        let largest = max(sourceWidth, sourceHeight)
        let ratio = min(
            1,
            Double(maximumDimension) / Double(max(1, largest))
        )
        let width = max(
            1,
            Int((Double(sourceWidth) * ratio).rounded())
        )
        let height = max(
            1,
            Int((Double(sourceHeight) * ratio).rounded())
        )
        var rgba = Array(repeating: UInt8(0), count: width * height * 4)
        for row in 0..<height {
            let destinationOffset = row * width * 4
            let sourceRowIndex = min(
                sourceHeight - 1,
                row * sourceHeight / height
            )
            let sourceRow = source.advanced(
                by: sourceRowIndex * bytesPerRow
            )
            for column in 0..<width {
                let sourceColumn = min(
                    sourceWidth - 1,
                    column * sourceWidth / width
                )
                let sourceOffset = sourceColumn * 4
                let destination = destinationOffset + column * 4
                rgba[destination] = sourceRow[sourceOffset + 2]
                rgba[destination + 1] = sourceRow[sourceOffset + 1]
                rgba[destination + 2] = sourceRow[sourceOffset]
                rgba[destination + 3] = sourceRow[sourceOffset + 3]
            }
        }

        try? self.init(width: width, height: height, bytes: rgba)
    }
}

private extension LiveOrientation {
    init(sampleBuffer: CMSampleBuffer) {
        guard let value = CMGetAttachment(
            sampleBuffer,
            key: RPVideoSampleOrientationKey as CFString,
            attachmentModeOut: nil
        ) as? NSNumber,
        let orientation = CGImagePropertyOrientation(
            rawValue: value.uint32Value
        ) else {
            self = .unknown
            return
        }

        switch orientation {
        case .right, .rightMirrored:
            self = .portrait
        case .left, .leftMirrored:
            self = .portraitUpsideDown
        case .down, .downMirrored:
            self = .landscapeLeft
        case .up, .upMirrored:
            self = .landscapeRight
        @unknown default:
            self = .unknown
        }
    }
}

private enum BroadcastFailure {
    static let appGroupUnavailable = NSError(
        domain: "com.slaveofsolace.cuepilot.broadcast",
        code: 1,
        userInfo: [
            NSLocalizedDescriptionKey:
                "The shared live-guidance container is unavailable.",
        ]
    )
}
