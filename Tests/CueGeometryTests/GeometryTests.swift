import CueGeometry
import CuePhysics
import XCTest

final class GeometryTests: XCTestCase {
    func testVectorNormalizationAndRotation() {
        let vector = Vector2D(x: 3, y: 4)
        let unit = vector.normalized()
        XCTAssertEqual(unit.length, 1, accuracy: 1e-12)
        XCTAssertEqual(unit.x, 0.6, accuracy: 1e-12)
        XCTAssertEqual(unit.y, 0.8, accuracy: 1e-12)

        let rotated = Vector2D.unitX.rotated(by: .pi / 2)
        XCTAssertEqual(rotated.x, 0, accuracy: 1e-12)
        XCTAssertEqual(rotated.y, 1, accuracy: 1e-12)
        XCTAssertEqual(
            Vector2D.zero.normalized(or: .unitY),
            .unitY
        )
    }

    func testSegmentIntersectionHandlesCrossingParallelAndCollinearCases() throws {
        let horizontal = Segment2D(
            start: Point2D(x: 0, y: 1),
            end: Point2D(x: 2, y: 1)
        )
        let vertical = Segment2D(
            start: Point2D(x: 1, y: 0),
            end: Point2D(x: 1, y: 2)
        )
        let crossing = try XCTUnwrap(horizontal.intersection(with: vertical))
        XCTAssertEqual(crossing.x, 1, accuracy: 1e-12)
        XCTAssertEqual(crossing.y, 1, accuracy: 1e-12)

        let parallel = Segment2D(
            start: Point2D(x: 0, y: 2),
            end: Point2D(x: 2, y: 2)
        )
        XCTAssertFalse(horizontal.intersects(parallel))

        let overlap = Segment2D(
            start: Point2D(x: 1.5, y: 1),
            end: Point2D(x: 3, y: 1)
        )
        XCTAssertTrue(horizontal.intersects(overlap))
    }

    func testLineCircleClearanceFindsBlockerAndClearPath() {
        let path = Segment2D(
            start: Point2D(x: 0, y: 0),
            end: Point2D(x: 1, y: 0)
        )
        let blocker = BallState(
            id: 3,
            kind: .solid,
            center: Point2D(x: 0.5, y: 0.03),
            radius: 0.025
        )
        let blocked = PathClearance.evaluate(
            path: path,
            movingRadius: 0.025,
            obstacles: [blocker]
        )
        XCTAssertFalse(blocked.isClear)
        XCTAssertEqual(blocked.blockingBallID, 3)

        let clearBall = BallState(
            id: 4,
            kind: .solid,
            center: Point2D(x: 0.5, y: 0.2),
            radius: 0.025
        )
        let clear = PathClearance.evaluate(
            path: path,
            movingRadius: 0.025,
            obstacles: [clearBall]
        )
        XCTAssertTrue(clear.isClear)
        XCTAssertGreaterThan(clear.minimumClearance, 0)
    }

    func testGhostBallUsesSumOfBallRadii() throws {
        let cue = BallState(
            id: 0,
            kind: .cue,
            center: Point2D(x: 0, y: 0),
            radius: 0.03
        )
        let target = BallState(
            id: 1,
            kind: .solid,
            center: Point2D(x: 1, y: 0),
            radius: 0.025
        )
        let solution = try DirectShotGeometry.solve(
            cue: cue,
            target: target,
            pocketAimPoint: Point2D(x: 2, y: 0)
        )
        XCTAssertEqual(solution.ghostCenter.x, 0.945, accuracy: 1e-12)
        XCTAssertEqual(solution.ghostCenter.y, 0, accuracy: 1e-12)
        XCTAssertEqual(solution.cutAngle, 0, accuracy: 1e-12)
    }

    func testPocketMouthAcceptsCenterAndRejectsJawContact() {
        let pocket = PocketGeometry(
            id: .topCenter,
            center: Point2D(x: 1, y: -0.08),
            mouth: Segment2D(
                start: Point2D(x: 0.90, y: 0),
                end: Point2D(x: 1.10, y: 0)
            ),
            captureRadius: 0.06,
            jawRadius: 0.005
        )
        let centered = Segment2D(
            start: Point2D(x: 1, y: 0.4),
            end: pocket.aimPoint
        )
        XCTAssertTrue(pocket.accepts(centerPath: centered, ballRadius: 0.025))
        XCTAssertGreaterThan(
            pocket.jawClearance(for: centered, ballRadius: 0.025),
            0
        )

        let jawHit = Segment2D(
            start: Point2D(x: 0.9, y: 0.4),
            end: Point2D(x: 0.9, y: -0.08)
        )
        XCTAssertFalse(pocket.accepts(centerPath: jawHit, ballRadius: 0.025))
    }

    func testProjectiveTransformMapsDetectedQuadToCanonicalTable() throws {
        let source = [
            Point2D(x: 100, y: 80),
            Point2D(x: 500, y: 110),
            Point2D(x: 540, y: 310),
            Point2D(x: 70, y: 290),
        ]
        let destination = [
            Point2D(x: 0, y: 0),
            Point2D(x: 2, y: 0),
            Point2D(x: 2, y: 1),
            Point2D(x: 0, y: 1),
        ]
        let transform = try ProjectiveTransform2D.mapping(
            source: source,
            destination: destination
        )
        for index in source.indices {
            let mapped = try XCTUnwrap(transform.applying(to: source[index]))
            XCTAssertEqual(mapped.x, destination[index].x, accuracy: 1e-9)
            XCTAssertEqual(mapped.y, destination[index].y, accuracy: 1e-9)
        }
    }
}
