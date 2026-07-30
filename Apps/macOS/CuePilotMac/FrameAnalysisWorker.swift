import CueGeometry
import CuePhysics
import CuePresentation
import CueStrategy
import CueVision
import Foundation

actor FrameAnalysisWorker {
    private let analyzer = VisionAnalyzer()
    private let strategy = StrategyEngine()
    private let stabilizer = GuidanceStabilizer(
        minimumStableFrames: 3,
        minimumStableDurationMilliseconds: 220,
        minimumConfidence: 0.62
    )

    func analyze(
        _ image: RGBAImage,
        configuration: LiveGameConfiguration
    ) async -> AnalysisPacket {
        let clock = ContinuousClock()
        let started = clock.now
        let analysis = await analyzer.analyze(image)

        let recommendation: ShotRecommendation?
        if let table = analysis.table,
           analysis.balls.contains(where: { $0.ball.kind == .cue }),
           analysis.balls.contains(where: { $0.ball.isObjectBall }) {
            var state = EightBallGameState(
                table: table.geometry,
                balls: analysis.balls.map(\.ball),
                groupAssignment: configuration.groupAssignment,
                turn: configuration.turn,
                phase: configuration.groupAssignment == .open
                    ? .openTable
                    : .groupPlay,
                requiredEightBallPocket: configuration.requiredEightBallPocket
            )
            if configuration.groupAssignment != .open,
               EightBallRules.canShootEightBall(in: state) {
                state.phase = .eightBall
            }
            recommendation = strategy.recommend(
                in: state,
                seed: analysis.frameFingerprint
            )
        } else {
            recommendation = nil
        }

        var warnings: GuidanceWarning = []
        if analysis.overallConfidence < 0.55 {
            warnings.insert(.lowConfidence)
        }
        if let recommendation {
            if recommendation.candidate.scratch.level == .high {
                warnings.insert(.scratchRisk)
            }
            if recommendation.candidate.rejections.contains(.pathBlocked) {
                warnings.insert(.pathBlocked)
            }
        }

        let aimBiasRadians = AngleMath.radians(
            min(15, max(-15, configuration.aimBiasDegrees))
        )
        let correctedCueAngle = (analysis.cueLine?.angleRadians).map {
            AngleMath.normalized($0 + aimBiasRadians)
        }
        let guidance = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: correctedCueAngle,
            currentPower: analysis.powerTrack?.normalizedPower,
            isPlayersTurn: configuration.turn == .player,
            detectionConfidence: analysis.overallConfidence,
            warnings: warnings,
            timestampNanoseconds: analysis.timestampNanoseconds
        )
        let duration = started.duration(to: clock.now)

        return AnalysisPacket(
            analysis: analysis,
            recommendation: recommendation,
            guidance: guidance,
            imageSize: CGSize(width: image.width, height: image.height),
            durationMilliseconds: duration.milliseconds
        )
    }

    func reset() async {
        await analyzer.reset()
        await stabilizer.reset()
    }
}

private extension Duration {
    var milliseconds: Double {
        let components = self.components
        return Double(components.seconds) * 1_000 +
            Double(components.attoseconds) / 1_000_000_000_000_000
    }
}
