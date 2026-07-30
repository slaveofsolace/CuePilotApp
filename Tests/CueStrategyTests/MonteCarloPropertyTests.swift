import CueGeometry
import CueStrategy
import XCTest

final class MonteCarloPropertyTests: XCTestCase {
    func testIdenticalStateAndSeedProduceIdenticalRecommendation() {
        let state = propertyState(seed: 11, includeRemainingSolid: true)
        let engine = StrategyEngine(configuration: propertyConfiguration())
        let first = engine.recommendShot(in: state, seed: 0xC0FFEE)
        let second = engine.recommendShot(in: state, seed: 0xC0FFEE)
        XCTAssertEqual(first, second)
    }

    func testCorridorNeverExceedsPhysicalBound() throws {
        let state = propertyState(seed: 13, includeRemainingSolid: true)
        let candidate = try XCTUnwrap(
            CandidateGenerator.generate(
                in: state,
                configuration: propertyConfiguration()
            ).filter(\.isLegal).first
        )
        let corridor = AlignmentAnalyzer.corridor(
            for: candidate,
            in: state,
            configuration: propertyConfiguration().monteCarlo,
            seed: 4
        )
        XCTAssertGreaterThanOrEqual(corridor.width, 0)
        XCTAssertLessThanOrEqual(
            corridor.width,
            2 * corridor.physicalHalfWidth + 1e-12
        )
        XCTAssertGreaterThanOrEqual(
            corridor.minimumAngle,
            candidate.requiredCueAngle - corridor.physicalHalfWidth - 1e-12
        )
        XCTAssertLessThanOrEqual(
            corridor.maximumAngle,
            candidate.requiredCueAngle + corridor.physicalHalfWidth + 1e-12
        )
    }

    func testConfidenceDecreasesWithGreaterUncertainty() throws {
        let state = propertyState(seed: 13, includeRemainingSolid: true)
        let candidate = try XCTUnwrap(
            CandidateGenerator.generate(
                in: state,
                configuration: propertyConfiguration()
            ).filter(\.isLegal).first
        )
        let base = MonteCarloConfiguration(
            simulationsPerAngle: 32,
            angleStepCount: 13,
            successThreshold: 0.45
        )
        let low = AlignmentAnalyzer.corridor(
            for: candidate,
            in: state,
            configuration: base.scalingUncertainty(by: 0.5),
            seed: 99
        )
        let high = AlignmentAnalyzer.corridor(
            for: candidate,
            in: state,
            configuration: base.scalingUncertainty(by: 3),
            seed: 99
        )
        XCTAssertLessThan(high.confidence, low.confidence)
    }

    func testRandomizedRecommendationsNeverUseIllegalTargets() {
        let engine = StrategyEngine(configuration: propertyConfiguration())
        for seed in 0..<80 {
            let includeSolid = seed.isMultiple(of: 3) == false
            let state = propertyState(
                seed: UInt64(seed),
                includeRemainingSolid: includeSolid
            )
            let legal = Set(EightBallRules.legalTargets(in: state).map(\.id))
            if let recommendation = engine.recommendShot(
                in: state,
                seed: UInt64(seed) &* 17
            ) {
                XCTAssertTrue(
                    legal.contains(recommendation.candidate.targetBallID),
                    "seed \(seed) recommended \(recommendation.candidate.targetBallID), legal \(legal)"
                )
                if includeSolid {
                    XCTAssertNotEqual(recommendation.candidate.targetBallID, 8)
                }
            }
        }
    }

    func testEveryClearRandomDirectCandidateActuallyClearsObstacles() {
        let configuration = propertyConfiguration()
        for seed in 0..<60 {
            let state = propertyState(
                seed: UInt64(seed),
                includeRemainingSolid: true
            )
            let cue = state.cueBall!
            let legal = CandidateGenerator.generate(
                in: state,
                configuration: configuration
            ).filter { $0.isLegal && $0.kind == .direct }

            for candidate in legal {
                let target = state.ball(id: candidate.targetBallID)!
                let cueClearance = PathClearance.evaluate(
                    path: candidate.cuePath,
                    movingRadius: cue.radius,
                    obstacles: state.balls,
                    excluding: [cue.id, target.id],
                    margin: configuration.pathMargin
                )
                XCTAssertTrue(cueClearance.isClear, candidate.id)

                for path in candidate.objectPaths {
                    let objectClearance = PathClearance.evaluate(
                        path: path,
                        movingRadius: target.radius,
                        obstacles: state.balls,
                        excluding: [cue.id, target.id],
                        margin: configuration.pathMargin
                    )
                    XCTAssertTrue(objectClearance.isClear, candidate.id)
                }

                for ghost in candidate.ghostCenters {
                    for obstacle in state.balls where
                        !obstacle.isPocketed &&
                            obstacle.id != cue.id &&
                            obstacle.id != target.id {
                        XCTAssertGreaterThanOrEqual(
                            ghost.distance(to: obstacle.center) + 1e-12,
                            cue.radius + obstacle.radius +
                                configuration.pathMargin,
                            candidate.id
                        )
                    }
                }
            }
        }
    }

    private func propertyConfiguration() -> StrategyConfiguration {
        StrategyConfiguration(
            includeCombinations: false,
            includeBanks: false,
            maximumMonteCarloCandidates: 2,
            maximumAlternatives: 1,
            minimumRecommendationProbability: 0.15,
            monteCarlo: MonteCarloConfiguration(
                simulationsPerAngle: 16,
                angleStepCount: 9,
                successThreshold: 0.40
            )
        )
    }

    private func propertyState(
        seed: UInt64,
        includeRemainingSolid: Bool
    ) -> EightBallGameState {
        var random = TestRandom(seed: seed)
        let table = TableGeometry.standard()
        let radius = table.defaultBallRadius
        let cue = BallState(
            id: 0,
            kind: .cue,
            center: Point2D(
                x: 0.32 + random.unit() * 0.28,
                y: 0.28 + random.unit() * 0.44
            ),
            radius: radius
        )
        let solid = BallState(
            id: 3,
            kind: .solid,
            center: Point2D(
                x: 0.88 + random.unit() * 0.34,
                y: 0.28 + random.unit() * 0.44
            ),
            radius: radius,
            isPocketed: !includeRemainingSolid
        )
        let eight = BallState(
            id: 8,
            kind: .eight,
            center: Point2D(
                x: 1.36 + random.unit() * 0.30,
                y: 0.25 + random.unit() * 0.50
            ),
            radius: radius
        )
        let stripe = BallState(
            id: 11,
            kind: .stripe,
            center: Point2D(
                x: 0.72 + random.unit() * 0.78,
                y: 0.15 + random.unit() * 0.70
            ),
            radius: radius
        )
        return EightBallGameState(
            table: table,
            balls: [cue, solid, eight, stripe],
            groupAssignment: .solids,
            requiredEightBallPocket: includeRemainingSolid ? nil : .bottomRight
        )
    }
}

private struct TestRandom {
    var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E3779B97F4A7C15
    }

    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / 9_007_199_254_740_992
    }
}
