import CueGeometry
import CueStrategy
import XCTest

final class RulesTests: XCTestCase {
    func testOpenTableExcludesEightBall() {
        let state = makeState(group: .open)
        let targets = EightBallRules.legalTargets(in: state)
        XCTAssertEqual(Set(targets.map(\.id)), [1, 9])
        XCTAssertFalse(targets.contains { $0.kind == .eight })
    }

    func testAssignedGroupTargetsEightOnlyAfterClearance() {
        var state = makeState(group: .solids)
        XCTAssertEqual(EightBallRules.legalTargets(in: state).map(\.id), [1])
        let solidIndex = state.balls.firstIndex { $0.id == 1 }!
        state.balls[solidIndex].isPocketed = true
        XCTAssertEqual(EightBallRules.legalTargets(in: state).map(\.id), [8])
        XCTAssertTrue(EightBallRules.canShootEightBall(in: state))
    }

    func testIllegalEarlyEightBallLosesMatch() {
        let state = makeState(group: .solids)
        let resolution = EightBallRules.resolve(
            ShotObservation(
                firstContactBallID: 8,
                pocketedBallIDs: [8],
                calledPocket: .topLeft
            ),
            in: state
        )
        XCTAssertFalse(resolution.legality.isLegal)
        XCTAssertTrue(resolution.legality.violations.contains(.earlyEightBall))
        XCTAssertEqual(resolution.state.outcome, .lost)
    }

    func testRequiredPocketControlsFinalEightBall() {
        var state = makeState(group: .solids)
        state.balls[state.balls.firstIndex { $0.id == 1 }!].isPocketed = true
        state.requiredEightBallPocket = .bottomRight
        state.phase = .eightBall

        let wrong = EightBallRules.resolve(
            ShotObservation(
                firstContactBallID: 8,
                pocketedBallIDs: [8],
                calledPocket: .topLeft
            ),
            in: state
        )
        XCTAssertEqual(wrong.state.outcome, .lost)
        XCTAssertTrue(wrong.legality.violations.contains(.wrongEightBallPocket))

        let correct = EightBallRules.resolve(
            ShotObservation(
                firstContactBallID: 8,
                pocketedBallIDs: [8],
                calledPocket: .bottomRight
            ),
            in: state
        )
        XCTAssertTrue(correct.legality.isLegal)
        XCTAssertEqual(correct.state.outcome, .won)
    }

    func testScratchChangesTurnAndAwardsBallInHand() {
        let state = makeState(group: .solids)
        let result = EightBallRules.resolve(
            ShotObservation(
                firstContactBallID: 1,
                cueBallPocketed: true
            ),
            in: state
        )
        XCTAssertFalse(result.legality.isLegal)
        XCTAssertEqual(result.state.turn, .opponent)
        XCTAssertTrue(result.state.ballInHand)
        XCTAssertFalse(result.keepsTurn)
    }

    func testLegalOpenTablePotAssignsGroupAndKeepsTurn() {
        let state = makeState(group: .open)
        let result = EightBallRules.resolve(
            ShotObservation(
                firstContactBallID: 9,
                pocketedBallIDs: [9]
            ),
            in: state
        )
        XCTAssertTrue(result.legality.isLegal)
        XCTAssertEqual(result.state.groupAssignment, .stripes)
        XCTAssertEqual(result.state.turn, .player)
        XCTAssertTrue(result.keepsTurn)
    }

    private func makeState(group: GroupAssignment) -> EightBallGameState {
        let radius = 0.028
        return EightBallGameState(
            table: .standard(ballRadius: radius),
            balls: [
                BallState(
                    id: 0,
                    kind: .cue,
                    center: Point2D(x: 0.4, y: 0.6),
                    radius: radius
                ),
                BallState(
                    id: 1,
                    kind: .solid,
                    center: Point2D(x: 0.9, y: 0.5),
                    radius: radius
                ),
                BallState(
                    id: 8,
                    kind: .eight,
                    center: Point2D(x: 1.2, y: 0.5),
                    radius: radius
                ),
                BallState(
                    id: 9,
                    kind: .stripe,
                    center: Point2D(x: 1.5, y: 0.5),
                    radius: radius
                ),
            ],
            groupAssignment: group
        )
    }
}
