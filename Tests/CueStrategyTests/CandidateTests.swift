import CueGeometry
import CueStrategy
import XCTest

final class CandidateTests: XCTestCase {
    func testClearDirectShotProducesLegalCandidate() throws {
        let state = directState()
        let candidates = CandidateGenerator.generate(
            in: state,
            configuration: fastConfiguration()
        )
        let candidate = try XCTUnwrap(
            candidates.first {
                $0.kind == .direct &&
                    $0.targetBallID == 1 &&
                    $0.pocketID == .topCenter
            }
        )
        XCTAssertTrue(candidate.isLegal, "\(candidate.rejections)")
        XCTAssertTrue(candidate.rejections.isEmpty)
        XCTAssertGreaterThan(candidate.estimatedSuccessProbability, 0)
        XCTAssertTrue((0...1).contains(candidate.powerRange.minimum))
        XCTAssertTrue((0...1).contains(candidate.powerRange.maximum))
    }

    func testCuePathBlockerRejectsDirectShot() throws {
        var state = directState()
        state.balls.append(
            BallState(
                id: 9,
                kind: .stripe,
                center: Point2D(x: 1, y: 0.68),
                radius: state.table.defaultBallRadius
            )
        )
        let candidate = try XCTUnwrap(
            CandidateGenerator.generate(
                in: state,
                configuration: fastConfiguration()
            ).first {
                $0.kind == .direct &&
                    $0.targetBallID == 1 &&
                    $0.pocketID == .topCenter
            }
        )
        XCTAssertFalse(candidate.isLegal)
        XCTAssertTrue(
            candidate.rejections.contains(.pathBlocked) ||
                candidate.rejections.contains(.ghostOverlapsBall)
        )
    }

    func testObjectPathBlockerRejectsDirectShot() throws {
        var state = directState()
        state.balls.append(
            BallState(
                id: 9,
                kind: .stripe,
                center: Point2D(x: 1, y: 0.28),
                radius: state.table.defaultBallRadius
            )
        )
        let candidate = try XCTUnwrap(
            CandidateGenerator.generate(
                in: state,
                configuration: fastConfiguration()
            ).first {
                $0.kind == .direct &&
                    $0.targetBallID == 1 &&
                    $0.pocketID == .topCenter
            }
        )
        XCTAssertFalse(candidate.isLegal)
        XCTAssertTrue(candidate.rejections.contains(.targetPathBlocked))
    }

    func testStraightTwoBallCombinationIsGenerated() throws {
        let radius = 0.028
        let state = EightBallGameState(
            table: .standard(ballRadius: radius),
            balls: [
                BallState(
                    id: 0,
                    kind: .cue,
                    center: Point2D(x: 1, y: 0.85),
                    radius: radius
                ),
                BallState(
                    id: 1,
                    kind: .solid,
                    center: Point2D(x: 1, y: 0.55),
                    radius: radius
                ),
                BallState(
                    id: 2,
                    kind: .solid,
                    center: Point2D(x: 1, y: 0.25),
                    radius: radius
                ),
                BallState(
                    id: 8,
                    kind: .eight,
                    center: Point2D(x: 1.65, y: 0.65),
                    radius: radius
                ),
            ],
            groupAssignment: .solids
        )
        let candidate = try XCTUnwrap(
            CandidateGenerator.generate(
                in: state,
                configuration: fastConfiguration(includeCombinations: true)
            ).first {
                $0.kind == .combination &&
                    $0.targetBallID == 1 &&
                    $0.secondaryBallID == 2 &&
                    $0.pocketID == .topCenter
            }
        )
        XCTAssertTrue(candidate.isLegal, "\(candidate.rejections)")
        XCTAssertEqual(candidate.ghostCenters.count, 2)
        XCTAssertEqual(candidate.objectPaths.count, 2)
    }

    func testOneRailBankCandidateCarriesRailAndTwoObjectLegs() throws {
        let radius = 0.028
        let state = EightBallGameState(
            table: .standard(ballRadius: radius),
            balls: [
                BallState(
                    id: 0,
                    kind: .cue,
                    center: Point2D(x: 0.3, y: 0.5),
                    radius: radius
                ),
                BallState(
                    id: 1,
                    kind: .solid,
                    center: Point2D(x: 0.8, y: 0.4),
                    radius: radius
                ),
                BallState(
                    id: 8,
                    kind: .eight,
                    center: Point2D(x: 1.5, y: 0.7),
                    radius: radius
                ),
            ],
            groupAssignment: .solids
        )
        let configuration = StrategyConfiguration(
            maximumScratchProbability: 1,
            includeCombinations: false,
            includeBanks: true,
            maximumMonteCarloCandidates: 2,
            monteCarlo: MonteCarloConfiguration(
                simulationsPerAngle: 12,
                angleStepCount: 9,
                successThreshold: 0.35
            )
        )
        let candidate = try XCTUnwrap(
            CandidateGenerator.generate(
                in: state,
                configuration: configuration
            ).first {
                $0.id == "bank:t1:ptopRight:rbottomRight"
            }
        )
        XCTAssertTrue(candidate.isLegal, "\(candidate.rejections)")
        XCTAssertEqual(candidate.bankRailID, .bottomRight)
        XCTAssertEqual(candidate.objectPaths.count, 2)
    }

    func testEarlyEightBallIsNeverGeneratedAsRecommendation() {
        let state = directState()
        let recommendation = StrategyEngine(
            configuration: fastConfiguration()
        ).recommendShot(in: state, seed: 42)
        XCTAssertNotEqual(recommendation?.candidate.targetBallID, 8)
    }

    func testFinalEightBallCandidatesUseOnlyRequiredPocket() {
        var state = directState()
        state.balls[state.balls.firstIndex { $0.id == 1 }!].isPocketed = true
        state.requiredEightBallPocket = .bottomRight
        state.phase = .eightBall

        let eightBallCandidates = CandidateGenerator.generate(
            in: state,
            configuration: fastConfiguration()
        ).filter { $0.targetBallID == 8 }
        XCTAssertFalse(eightBallCandidates.isEmpty)
        XCTAssertTrue(
            eightBallCandidates.allSatisfy {
                $0.pocketID == .bottomRight
            }
        )
    }

    func testGuidanceRequiresLegalAimAndPower() throws {
        let recommendation = try XCTUnwrap(
            StrategyEngine(configuration: fastConfiguration())
                .recommendShot(in: directState(), seed: 7)
        )
        let locked = recommendation.guidance(
            currentAngle: recommendation.corridor.requiredAngle,
            currentPower: recommendation.candidate.powerRange.midpoint,
            minimumLockConfidence: 0
        )
        XCTAssertEqual(locked.state, .ready)

        let weak = recommendation.guidance(
            currentAngle: recommendation.corridor.requiredAngle,
            currentPower: 0,
            minimumLockConfidence: 0
        )
        XCTAssertEqual(weak.state, .morePower)

        let waiting = recommendation.guidance(
            currentAngle: recommendation.corridor.requiredAngle,
            currentPower: recommendation.candidate.powerRange.midpoint,
            isPlayersTurn: false,
            minimumLockConfidence: 0
        )
        XCTAssertEqual(waiting.state, .waitingForTurn)
    }

    private func directState() -> EightBallGameState {
        let radius = 0.028
        return EightBallGameState(
            table: .standard(ballRadius: radius),
            balls: [
                BallState(
                    id: 0,
                    kind: .cue,
                    center: Point2D(x: 1, y: 0.82),
                    radius: radius
                ),
                BallState(
                    id: 1,
                    kind: .solid,
                    center: Point2D(x: 1, y: 0.46),
                    radius: radius
                ),
                BallState(
                    id: 8,
                    kind: .eight,
                    center: Point2D(x: 1.6, y: 0.72),
                    radius: radius
                ),
                BallState(
                    id: 10,
                    kind: .stripe,
                    center: Point2D(x: 1.65, y: 0.25),
                    radius: radius
                ),
            ],
            groupAssignment: .solids
        )
    }

    private func fastConfiguration(
        includeCombinations: Bool = false
    ) -> StrategyConfiguration {
        StrategyConfiguration(
            includeCombinations: includeCombinations,
            includeBanks: false,
            maximumMonteCarloCandidates: 3,
            monteCarlo: MonteCarloConfiguration(
                simulationsPerAngle: 20,
                angleStepCount: 11,
                successThreshold: 0.45
            )
        )
    }
}
