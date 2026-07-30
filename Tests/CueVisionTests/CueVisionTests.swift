import CueGeometry
import CueTestSupport
import CueVision
import Foundation
import XCTest

final class CueVisionTests: XCTestCase {
    func testRGBAImageValidatesStorageAndRoundTripsPixels() throws {
        XCTAssertThrowsError(
            try RGBAImage(width: 2, height: 2, bytes: [0, 1, 2])
        )
        var image = try RGBAImage(
            width: 3,
            height: 2,
            fill: RGBAPixel(red: 2, green: 3, blue: 4)
        )
        let marker = RGBAPixel(red: 90, green: 80, blue: 70, alpha: 60)
        image.setPixel(marker, x: 1, y: 1)
        XCTAssertEqual(image.pixel(x: 1, y: 1), marker)
        XCTAssertNil(image.pixel(x: 3, y: 1))
        XCTAssertEqual(image.bytes.count, image.width * image.height * 4)
    }

    func testCleanSyntheticFixtureDetectsTablePocketsAndBallKinds() throws {
        let fixture = try SyntheticTableFixtureRenderer().render()
        let table = try XCTUnwrap(TableDetector().detect(in: fixture.image))
        XCTAssertGreaterThan(table.confidence, 0.55)
        XCTAssertEqual(table.corners.count, 4)

        let pockets = PocketDetector().detect(in: fixture.image, table: table)
        XCTAssertEqual(Set(pockets.map(\.geometry.id)), Set(PocketID.allCases))
        XCTAssertTrue(pockets.allSatisfy { $0.confidence > 0.30 })

        let balls = BallDetector().detect(in: fixture.image, table: table)
        assertContainsDetectedKinds(
            [.cue, .eight, .solid, .stripe],
            in: balls
        )
        XCTAssertGreaterThanOrEqual(balls.count, fixture.truth.balls.count)

        for truth in fixture.truth.balls {
            let pixelCenter = try XCTUnwrap(fixture.truth.pixelBallCenters[truth.id])
            let nearest = try XCTUnwrap(balls.min {
                $0.pixelCenter.distance(to: pixelCenter) <
                    $1.pixelCenter.distance(to: pixelCenter)
            })
            XCTAssertLessThan(
                nearest.pixelCenter.distance(to: pixelCenter),
                fixture.truth.pixelBallRadius * 0.75
            )
            XCTAssertEqual(nearest.ball.kind, truth.kind)
        }
    }

    func testPerspectiveDarkAndCompressedFixtureRemainsDetectable() throws {
        let fixture = try SyntheticTableFixtureRenderer().render(
            options: SyntheticFixtureOptions(
                brightness: 0.70,
                perspective: 0.09,
                shadowStrength: 0.35,
                compressionLevels: 24,
                includeCue: true,
                cueAngleRadians: -0.34,
                includePowerTrack: true,
                normalizedPower: 0.58,
                highlightPocket: .bottomRight,
                partialObstruction: true
            ),
            seed: 77
        )
        let table = try XCTUnwrap(TableDetector().detect(in: fixture.image))
        let balls = BallDetector().detect(in: fixture.image, table: table)
        XCTAssertGreaterThanOrEqual(balls.count, fixture.truth.balls.count - 1)
        XCTAssertTrue(balls.contains { $0.ball.kind == .cue })
        XCTAssertTrue(balls.contains { $0.ball.kind == .eight })

        let cue = try XCTUnwrap(
            PixelCueLineEstimator().estimate(
                in: fixture.image,
                table: table,
                balls: balls
            )
        )
        XCTAssertLessThan(
            abs(AngleMath.signedDifference(
                from: cue.angleRadians,
                to: fixture.truth.cueAngleRadians!
            )),
            0.16
        )

        let power = try XCTUnwrap(
            PixelPowerTrackEstimator().estimate(in: fixture.image, previous: nil)
        )
        XCTAssertEqual(power.normalizedPower, 0.58, accuracy: 0.045)
    }

    func testCueAndPowerHooksReturnNilWhenControlsAreAbsent() throws {
        let fixture = try SyntheticTableFixtureRenderer().render(
            options: SyntheticFixtureOptions(
                includeCue: false,
                includePowerTrack: false
            )
        )
        let table = try XCTUnwrap(TableDetector().detect(in: fixture.image))
        let balls = BallDetector().detect(in: fixture.image, table: table)
        XCTAssertNil(
            PixelCueLineEstimator().estimate(
                in: fixture.image,
                table: table,
                balls: balls
            )
        )
        XCTAssertNil(
            PixelPowerTrackEstimator().estimate(
                in: fixture.image,
                previous: nil
            )
        )
    }

    func testTouchingBallsNearRailAndDifferentDisplayScale() throws {
        let balls = [
            SyntheticBall(id: 0, kind: .cue, center: Point2D(x: 0.18, y: 0.16)),
            SyntheticBall(id: 1, kind: .solid, center: Point2D(x: 0.95, y: 0.50)),
            SyntheticBall(id: 9, kind: .stripe, center: Point2D(x: 1.04, y: 0.50)),
            SyntheticBall(id: 8, kind: .eight, center: Point2D(x: 1.55, y: 0.80)),
        ]
        for size in [(320, 200), (640, 400)] {
            let fixture = try SyntheticTableFixtureRenderer().render(
                balls: balls,
                options: SyntheticFixtureOptions(
                    width: size.0,
                    height: size.1,
                    brightness: 1.12,
                    perspective: 0.06,
                    includeCue: false,
                    includePowerTrack: false
                )
            )
            let table = try XCTUnwrap(TableDetector().detect(in: fixture.image))
            let detected = BallDetector().detect(in: fixture.image, table: table)
            XCTAssertGreaterThanOrEqual(detected.count, 3)
            XCTAssertTrue(detected.contains { $0.ball.kind == .cue })
            XCTAssertTrue(detected.contains { $0.ball.kind == .eight })
        }
    }

    func testManualCorrectionsAreValueSemantic() throws {
        let fixture = try SyntheticTableFixtureRenderer().render()
        let table = try XCTUnwrap(TableDetector().detect(in: fixture.image))
        let balls = BallDetector().detect(in: fixture.image, table: table)
        let original = VisionAnalysis(
            sequence: 1,
            timestampNanoseconds: 1,
            frameFingerprint: 1,
            sceneChanged: true,
            table: table,
            pockets: PocketDetector().detect(in: fixture.image, table: table),
            balls: balls,
            cueLine: nil,
            powerTrack: nil,
            overallConfidence: 0.8
        )
        let id = try XCTUnwrap(
            balls.first(where: { $0.ball.kind == .solid })?.ball.id
        )
        let review = DetectionReview(analysis: original)
            .applying(.classifyBall(id: id, kind: .stripe))
            .applying(.moveBall(
                id: id,
                canonicalCenter: Point2D(x: 0.4, y: 0.5),
                pixelCenter: Point2D(x: 80, y: 90)
            ))
            .applying(.markPocketed(id: id, true))
            .applying(.setPocket(
                .topLeft,
                pixelPoint: Point2D(x: 72, y: 38)
            ))

        XCTAssertNotEqual(
            original.balls.first(where: { $0.ball.id == id })?.ball.kind,
            review.analysis.balls.first(where: { $0.ball.id == id })?.ball.kind
        )
        let corrected = try XCTUnwrap(
            review.analysis.balls.first(where: { $0.ball.id == id })
        )
        XCTAssertEqual(corrected.ball.center, Point2D(x: 0.4, y: 0.5))
        XCTAssertTrue(corrected.ball.isPocketed)
        let correctedPocket = try XCTUnwrap(
            review.analysis.pockets.first { $0.geometry.id == .topLeft }
        )
        XCTAssertEqual(
            review.analysis.table?.geometry.pocket(id: .topLeft)?.center,
            correctedPocket.geometry.center
        )
        XCTAssertEqual(review.appliedCorrections.count, 4)
    }

    func testAnalyzerSkipsIdenticalFullSolveWithoutRetainingFrame() async throws {
        let fixture = try SyntheticTableFixtureRenderer().render()
        let analyzer = VisionAnalyzer()
        let first = await analyzer.analyze(fixture.image, timestampNanoseconds: 1)
        let second = await analyzer.analyze(fixture.image, timestampNanoseconds: 2)
        XCTAssertTrue(first.sceneChanged)
        XCTAssertFalse(second.sceneChanged)
        XCTAssertEqual(second.sequence, first.sequence + 1)
        XCTAssertEqual(second.frameFingerprint, first.frameFingerprint)
        XCTAssertEqual(second.balls, first.balls)
    }

    private func assertContainsDetectedKinds(
        _ expected: Set<BallKind>,
        in balls: [DetectedBall],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = Set(balls.map(\.ball.kind))
        XCTAssertTrue(
            expected.isSubset(of: actual),
            "Missing \(expected.subtracting(actual)) from \(actual)",
            file: file,
            line: line
        )
    }
}
