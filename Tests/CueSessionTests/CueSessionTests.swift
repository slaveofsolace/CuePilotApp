import CueCalibration
import CueDiagnostics
import CueGeometry
import CuePresentation
import CueSession
import CueStrategy
import Foundation
import XCTest

final class CueSessionTests: XCTestCase {
    func testSuccessfulOpenTableShotAssignsGroupAndKeepsTurn() {
        let state = makeGame()
        let session = MatchSession(game: state)
        let updated = session.recordingPlayerShot(
            ShotObservation(
                firstContactBallID: 1,
                pocketedBallIDs: [1]
            ),
            calibrationOutcome: .pocketedSuccessfully
        )

        XCTAssertEqual(updated.game.groupAssignment, .solids)
        XCTAssertEqual(updated.game.turn, .player)
        XCTAssertEqual(updated.game.phase, .groupPlay)
        XCTAssertEqual(updated.shots.count, 1)
        XCTAssertTrue(updated.shots[0].legality.isLegal)
        XCTAssertEqual(updated.shots[0].calibrationOutcome, .pocketedSuccessfully)
    }

    func testScratchChangesTurnAndGrantsBallInHand() {
        var game = makeGame()
        game.groupAssignment = .solids
        game.phase = .groupPlay
        let updated = MatchSession(game: game).recordingPlayerShot(
            ShotObservation(
                firstContactBallID: 1,
                cueBallPocketed: true
            ),
            calibrationOutcome: .scratched
        )
        XCTAssertEqual(updated.game.turn, .opponent)
        XCTAssertTrue(updated.game.ballInHand)
        XCTAssertFalse(updated.shots[0].legality.isLegal)
        XCTAssertTrue(updated.shots[0].legality.violations.contains(.cueBallScratch))
    }

    func testEarlyEightBallIsARecordedLoss() {
        let game = makeGame()
        let updated = MatchSession(game: game).recordingPlayerShot(
            ShotObservation(
                firstContactBallID: 8,
                pocketedBallIDs: [8],
                calledPocket: .topLeft
            )
        )
        XCTAssertEqual(updated.game.outcome, .lost)
        XCTAssertEqual(updated.game.phase, .finished)
        XCTAssertTrue(updated.shots[0].legality.violations.contains(.earlyEightBall))
    }

    func testLegalFinalEightBallWinsOnlyInRequiredPocket() {
        var game = makeGame()
        game.groupAssignment = .solids
        game.phase = .eightBall
        game.requiredEightBallPocket = .bottomRight
        for index in game.balls.indices where game.balls[index].kind == .solid {
            game.balls[index].isPocketed = true
        }
        let updated = MatchSession(game: game).recordingPlayerShot(
            ShotObservation(
                firstContactBallID: 8,
                pocketedBallIDs: [8],
                calledPocket: .bottomRight
            )
        )
        XCTAssertEqual(updated.game.outcome, .won)
        XCTAssertTrue(updated.shots[0].legality.isLegal)
    }

    func testOpponentEightBallRequiresExplicitLegalityBeforeReconciliation() {
        var game = makeGame()
        game.turn = .opponent
        let session = MatchSession(game: game)
        let unresolved = session.recordingOpponentShot(
            pocketedBallIDs: [8],
            cueBallPocketed: false,
            nextTurn: .player
        )
        XCTAssertEqual(unresolved, session)
        XCTAssertFalse(unresolved.game.ball(id: 8)!.isPocketed)
        XCTAssertEqual(unresolved.game.outcome, .inProgress)

        let resolved = session.recordingOpponentShot(
            pocketedBallIDs: [8],
            cueBallPocketed: false,
            nextTurn: .player,
            opponentEightBallWasLegal: true
        )
        XCTAssertTrue(resolved.game.ball(id: 8)!.isPocketed)
        XCTAssertEqual(resolved.game.outcome, .lost)
        XCTAssertEqual(resolved.game.phase, .finished)
    }

    func testCalibrationOutcomesMoveOnlyDefensibleParameters() {
        let base = CalibrationProfile()
        let left = base.applying(CalibrationObservation(
            outcome: .missedLeft,
            commandedAngleDegrees: 12,
            commandedPower: 0.5
        ))
        let right = base.applying(CalibrationObservation(
            outcome: .missedRight,
            commandedAngleDegrees: 12,
            commandedPower: 0.5
        ))
        let weak = base.applying(CalibrationObservation(
            outcome: .tooWeak,
            commandedPower: 0.5
        ))
        let hard = base.applying(CalibrationObservation(
            outcome: .tooHard,
            commandedPower: 0.5
        ))

        XCTAssertGreaterThan(left.aimBiasDegrees, base.aimBiasDegrees)
        XCTAssertLessThan(right.aimBiasDegrees, base.aimBiasDegrees)
        XCTAssertGreaterThan(weak.powerOffset, base.powerOffset)
        XCTAssertLessThan(hard.powerOffset, base.powerOffset)
        XCTAssertEqual(left.sampleCount, 1)
        XCTAssertGreaterThan(left.confidence, 0)
    }

    func testManualSessionCorrectionsAreValueSemantic() {
        let session = MatchSession(game: makeGame())
        let corrected = session
            .applyingManualCorrection(.assignGroup(.stripes))
            .applyingManualCorrection(.setTurn(.opponent))
            .applyingManualCorrection(.setBallInHand(true))
            .applyingManualCorrection(.requireEightBallPocket(.topCenter))
            .applyingManualCorrection(.markBallPocketed(id: 9, true))

        XCTAssertEqual(session.game.groupAssignment, .open)
        XCTAssertEqual(corrected.game.groupAssignment, .stripes)
        XCTAssertEqual(corrected.game.turn, .opponent)
        XCTAssertTrue(corrected.game.ballInHand)
        XCTAssertEqual(corrected.game.requiredEightBallPocket, .topCenter)
        XCTAssertTrue(corrected.game.ball(id: 9)!.isPocketed)
    }

    func testCalibrationCoversEveryDeclaredOutcomeWithBoundedValues() {
        var profile = CalibrationProfile()
        for outcome in ShotOutcome.allCases {
            profile = profile.applying(CalibrationObservation(
                outcome: outcome,
                commandedAngleDegrees: 18,
                commandedPower: 0.72,
                measuredTravelRatio: 1.05,
                confidence: 0.8
            ))
        }
        XCTAssertEqual(profile.sampleCount, ShotOutcome.allCases.count)
        XCTAssertTrue((-4 ... 4).contains(profile.aimBiasDegrees))
        XCTAssertTrue((0.70 ... 1.30).contains(profile.powerScale))
        XCTAssertTrue((-0.20 ... 0.20).contains(profile.powerOffset))
        XCTAssertTrue((0 ... 1).contains(profile.confidence))
    }

    func testSessionAndCalibrationJSONStoresRoundTrip() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CuePilotTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sessionStore = SessionStore(fileURL: directory.appendingPathComponent("sessions.json"))
        let calibrationStore = CalibrationStore(
            fileURL: directory.appendingPathComponent("calibration.json")
        )
        let session = MatchSession(game: makeGame())
        let profile = CalibrationProfile(name: "Test")

        try await sessionStore.create(session)
        try await calibrationStore.create(profile)
        let storedSession = try await sessionStore.session(id: session.id)
        let storedProfiles = try await calibrationStore.profiles()
        XCTAssertEqual(storedSession, session)
        XCTAssertEqual(storedProfiles, [profile])

        let updated = session.settingTurn(.opponent)
        try await sessionStore.upsert(updated)
        let reloaded = try await sessionStore.session(id: session.id)
        XCTAssertEqual(reloaded.game.turn, MatchTurn.opponent)
    }

    func testLiveStateWireRoundTripAndChecksumRejection() throws {
        let original = makeLiveState(sequence: 41, shotID: 901)
        let encoded = LiveStateWireFormat.encode(original)
        XCTAssertEqual(encoded.count, LiveStateWireFormat.byteCount)
        XCTAssertEqual(try LiveStateWireFormat.decode(encoded), original)

        var corrupted = encoded
        corrupted[52] ^= 0x80
        XCTAssertThrowsError(try LiveStateWireFormat.decode(corrupted)) {
            XCTAssertEqual($0 as? LiveStateWireError, .checksumMismatch)
        }
    }

    func testLiveStateTransportFallsBackFromCorruptNewestSlot() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("guidance.bin")
        let transport = LiveStateFileTransport(fileURL: fileURL)
        try await transport.write(makeLiveState(sequence: 7, shotID: 70))
        try await transport.write(makeLiveState(sequence: 8, shotID: 80))

        let handle = try FileHandle(forUpdating: fileURL)
        try handle.seek(toOffset: 0)
        try handle.write(contentsOf: Data([0]))
        try handle.close()

        let recovered = try await transport.readLatest()
        XCTAssertEqual(recovered.sequence, 7)
        XCTAssertEqual(recovered.recommendedShotID, 70)
    }

    func testLiveStateTransportKeepsSequenceMonotonicAcrossWriterRestart() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("guidance.bin")
        let firstWriter = LiveStateFileTransport(fileURL: fileURL)
        try await firstWriter.write(makeLiveState(sequence: 100, shotID: 100))

        let restartedWriter = LiveStateFileTransport(fileURL: fileURL)
        try await restartedWriter.write(makeLiveState(sequence: 1, shotID: 200))
        let latest = try await restartedWriter.readLatest()

        XCTAssertEqual(latest.sequence, 101)
        XCTAssertEqual(latest.recommendedShotID, 200)
    }

    func testGuidanceRequiresStableAimAndPowerBeforeReady() async throws {
        let recommendation = try XCTUnwrap(makeRecommendation())
        let stabilizer = GuidanceStabilizer(
            minimumStableFrames: 3,
            minimumStableDurationMilliseconds: 220,
            minimumConfidence: 0
        )
        let angle = recommendation.corridor.requiredAngle
        let power = recommendation.candidate.powerRange.midpoint

        let weak = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: angle,
            currentPower: 0,
            isPlayersTurn: true,
            detectionConfidence: 1,
            timestampNanoseconds: 0
        )
        XCTAssertEqual(weak.guidance.state, .morePower)
        XCTAssertEqual(weak.stableFrameCount, 0)

        let first = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: angle,
            currentPower: power,
            isPlayersTurn: true,
            detectionConfidence: 1,
            timestampNanoseconds: 500_000_000
        )
        let second = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: angle,
            currentPower: power,
            isPlayersTurn: true,
            detectionConfidence: 1,
            timestampNanoseconds: 600_000_000
        )
        let ready = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: angle,
            currentPower: power,
            isPlayersTurn: true,
            detectionConfidence: 1,
            timestampNanoseconds: 740_000_000
        )
        XCTAssertEqual(first.guidance.state, .fineAlignment)
        XCTAssertEqual(second.guidance.state, .fineAlignment)
        XCTAssertEqual(ready.guidance.state, .ready)
        XCTAssertEqual(ready.stableFrameCount, 3)
        XCTAssertEqual(ready.stableDurationMilliseconds, 240, accuracy: 0.001)

        let blocked = await stabilizer.update(
            recommendation: recommendation,
            currentAngle: angle,
            currentPower: power,
            isPlayersTurn: true,
            detectionConfidence: 1,
            warnings: [.scratchRisk],
            timestampNanoseconds: 800_000_000
        )
        XCTAssertEqual(blocked.guidance.state, .doNotShoot)
        XCTAssertEqual(blocked.stableFrameCount, 0)
    }

    func testDiagnosticsRemainBoundedAndExportAggregateDataOnly() async throws {
        let diagnostics = PrivacySafeDiagnostics(
            appVersion: "1.2/<build>",
            platform: "iOS\n18",
            maximumSamplesPerOperation: 8
        )
        await diagnostics.increment(.analyzedFrames, by: 3)
        await diagnostics.increment(.analyzedFrames, by: -1)
        for value in 0..<10 {
            await diagnostics.record(
                .tableDetection,
                milliseconds: Double(value)
            )
        }
        await diagnostics.record(.ballDetection, milliseconds: .infinity)

        let snapshot = await diagnostics.snapshot(
            at: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(snapshot.appVersion, "1.2build")
        XCTAssertEqual(snapshot.platform, "iOS18")
        XCTAssertEqual(snapshot.counters["analyzedFrames"], 3)
        let latency = try XCTUnwrap(snapshot.latencies["tableDetection"])
        XCTAssertEqual(latency.sampleCount, 8)
        XCTAssertEqual(latency.minimumMilliseconds, 2)
        XCTAssertEqual(latency.medianMilliseconds, 5.5, accuracy: 0.001)
        XCTAssertEqual(latency.maximumMilliseconds, 9)
        XCTAssertNil(snapshot.latencies["ballDetection"])

        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("diagnostics.json")
        try await diagnostics.export(
            to: destination,
            at: Date(timeIntervalSince1970: 0)
        )
        let exported = try Data(contentsOf: destination)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(
            try decoder.decode(DiagnosticsExport.self, from: exported),
            snapshot
        )
        let attributes = try FileManager.default.attributesOfItem(
            atPath: destination.path
        )
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        XCTAssertEqual(permissions.map { $0 & 0o777 }, 0o600)

        await diagnostics.reset()
        let reset = await diagnostics.snapshot()
        XCTAssertTrue(reset.counters.isEmpty)
        XCTAssertTrue(reset.latencies.isEmpty)
    }

    private func makeGame() -> EightBallGameState {
        EightBallGameState(
            table: .standard(),
            balls: [
                BallState(
                    id: 0,
                    kind: .cue,
                    center: Point2D(x: 0.4, y: 0.5),
                    radius: 0.028
                ),
                BallState(
                    id: 1,
                    kind: .solid,
                    center: Point2D(x: 0.9, y: 0.3),
                    radius: 0.028
                ),
                BallState(
                    id: 2,
                    kind: .solid,
                    center: Point2D(x: 1.1, y: 0.5),
                    radius: 0.028
                ),
                BallState(
                    id: 8,
                    kind: .eight,
                    center: Point2D(x: 1.3, y: 0.5),
                    radius: 0.028
                ),
                BallState(
                    id: 9,
                    kind: .stripe,
                    center: Point2D(x: 1.5, y: 0.7),
                    radius: 0.028
                ),
            ]
        )
    }

    private func makeRecommendation() -> ShotRecommendation? {
        let configuration = StrategyConfiguration(
            includeCombinations: false,
            includeBanks: false,
            maximumMonteCarloCandidates: 3,
            monteCarlo: MonteCarloConfiguration(
                simulationsPerAngle: 20,
                angleStepCount: 11,
                successThreshold: 0.45
            )
        )
        return StrategyEngine(configuration: configuration).recommendShot(
            in: makeGame(),
            seed: 7
        )
    }

    private func makeLiveState(
        sequence: UInt64,
        shotID: UInt32
    ) -> CompactLiveState {
        CompactLiveState(
            sequence: sequence,
            timestampNanoseconds: sequence * 1_000,
            orientation: .landscapeRight,
            tableConfidence: 0.91,
            turn: .player,
            group: .solids,
            recommendedShotID: shotID,
            currentCueAngle: 0.18,
            requiredCueAngle: 0.20,
            signedAngularError: 0.02,
            validMinimumAngle: 0.17,
            validMaximumAngle: 0.23,
            recommendedPowerMinimum: 0.50,
            recommendedPowerMaximum: 0.62,
            currentVisiblePower: 0.56,
            alignment: .ready,
            confidence: 0.88,
            estimatedSuccessProbability: 0.76,
            warningFlags: [.lowConfidence],
            targetBallID: 1,
            targetPocket: .topLeft
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "CuePilotTests-\(UUID().uuidString)",
            isDirectory: true
        )
    }
}
