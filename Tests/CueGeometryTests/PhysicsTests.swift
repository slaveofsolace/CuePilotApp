import CueGeometry
import CuePhysics
import XCTest

final class PhysicsTests: XCTestCase {
    func testEqualMassCollisionSeparatesNormalAndTangentialVelocity() {
        let normal = Vector2D(x: 1, y: 1).normalized()
        let result = EqualMassCollision.resolve(
            firstVelocity: .unitX,
            normal: normal,
            restitution: 1
        )
        XCTAssertEqual(result.firstVelocity.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(result.firstVelocity.y, -0.5, accuracy: 1e-12)
        XCTAssertEqual(result.secondVelocity.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(result.secondVelocity.y, 0.5, accuracy: 1e-12)
        XCTAssertEqual(
            result.firstVelocity.dot(result.secondVelocity),
            0,
            accuracy: 1e-12
        )
    }

    func testCushionReflectionPreservesTangentAndDampsNormal() {
        let reflected = CushionCollision.reflectedVelocity(
            incidentVelocity: Vector2D(x: 0.4, y: -1),
            railDirection: .unitX,
            restitution: 0.7
        )
        XCTAssertEqual(reflected.x, 0.4, accuracy: 1e-12)
        XCTAssertEqual(reflected.y, 0.7, accuracy: 1e-12)
    }

    func testMirroredPocketGeometry() throws {
        let vertical = Segment2D(
            start: Point2D(x: 0, y: -2),
            end: Point2D(x: 0, y: 2)
        )
        let reflected = try XCTUnwrap(
            BankShotGeometry.mirrored(
                Point2D(x: 1, y: 0.5),
                across: vertical
            )
        )
        XCTAssertEqual(reflected.x, -1, accuracy: 1e-12)
        XCTAssertEqual(reflected.y, 0.5, accuracy: 1e-12)
    }

    func testOneRailBankContactIsOnPhysicalCushion() throws {
        let table = TableGeometry.standard()
        let target = BallState(
            id: 2,
            kind: .solid,
            center: Point2D(x: 0.55, y: 0.45),
            radius: table.defaultBallRadius
        )
        let pocket = try XCTUnwrap(table.pocket(id: .topRight))
        let cushion = try XCTUnwrap(table.cushion(id: .bottomLeft))
        let bank = try BankShotGeometry.solve(
            objectBall: target,
            pocket: pocket,
            cushion: cushion,
            tableCenter: table.playableBounds.center,
            restitution: 0.78
        )
        XCTAssertGreaterThanOrEqual(
            bank.contactPoint.x,
            min(cushion.segment.start.x, cushion.segment.end.x) - 0.01
        )
        XCTAssertLessThanOrEqual(
            bank.contactPoint.x,
            max(cushion.segment.start.x, cushion.segment.end.x) + 0.01
        )
        XCTAssertEqual(
            bank.contactPoint.y,
            table.playableBounds.maxY - target.radius,
            accuracy: 1e-9
        )
        XCTAssertLessThan(bank.angularError, AngleMath.radians(12))
    }

    func testTwoObjectCombinationIsSolvedBackwardFromPocket() throws {
        let radius = 0.028
        let cue = BallState(
            id: 0,
            kind: .cue,
            center: Point2D(x: 1, y: 0.85),
            radius: radius
        )
        let first = BallState(
            id: 1,
            kind: .solid,
            center: Point2D(x: 1, y: 0.55),
            radius: radius
        )
        let second = BallState(
            id: 2,
            kind: .solid,
            center: Point2D(x: 1, y: 0.25),
            radius: radius
        )
        let solution = try CombinationShotGeometry.solve(
            cue: cue,
            firstObject: first,
            secondObject: second,
            pocketAimPoint: Point2D(x: 1, y: -0.04)
        )
        XCTAssertEqual(solution.requiredCueAngle, -.pi / 2, accuracy: 1e-12)
        XCTAssertEqual(
            solution.secondObjectGhostCenter.distance(to: second.center),
            radius * 2,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            solution.firstObjectGhostCenter.distance(to: first.center),
            radius * 2,
            accuracy: 1e-12
        )
    }

    func testScratchAnalyzerFlagsDirectPocketRoute() {
        let table = TableGeometry.standard()
        let radius = table.defaultBallRadius
        let cue = BallState(
            id: 0,
            kind: .cue,
            center: Point2D(x: 0.20, y: 0.30),
            radius: radius
        )
        let ghost = Point2D(x: 0.70, y: 0.30)
        let target = BallState(
            id: 4,
            kind: .solid,
            center: ghost + Vector2D(x: 1, y: 1).normalized() * radius * 2,
            radius: radius
        )
        let prediction = ScratchAnalyzer.predict(
            cue: cue,
            target: target,
            ghostCenter: ghost,
            incomingSpeed: 1,
            table: table,
            obstacles: [cue, target],
            parameters: PhysicsParameters(
                ballRestitution: 1,
                cushionRestitution: 0.75,
                rollingFriction: 0.08
            )
        )
        XCTAssertEqual(prediction.level, .high)
        XCTAssertEqual(prediction.threatenedPocket, .topCenter)
    }
}
