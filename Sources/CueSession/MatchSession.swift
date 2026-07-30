import CueCalibration
import CueGeometry
import CueStrategy
import Foundation

public enum SessionCorrection: Codable, Equatable, Sendable {
    case assignGroup(GroupAssignment)
    case requireEightBallPocket(PocketID?)
    case markBallPocketed(id: Int, Bool)
    case setTurn(MatchTurn)
    case setBallInHand(Bool)
    case replaceBall(BallState)
    case setOutcome(MatchOutcome)
}

public struct RecordedShot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sequence: Int
    public var recordedAt: Date
    public var observation: ShotObservation
    public var legality: ShotLegality
    public var groupBefore: GroupAssignment
    public var groupAfter: GroupAssignment
    public var turnAfter: MatchTurn
    public var calibrationOutcome: ShotOutcome?

    public init(
        id: UUID = UUID(),
        sequence: Int,
        recordedAt: Date = Date(),
        observation: ShotObservation,
        legality: ShotLegality,
        groupBefore: GroupAssignment,
        groupAfter: GroupAssignment,
        turnAfter: MatchTurn,
        calibrationOutcome: ShotOutcome?
    ) {
        self.id = id
        self.sequence = sequence
        self.recordedAt = recordedAt
        self.observation = observation
        self.legality = legality
        self.groupBefore = groupBefore
        self.groupAfter = groupAfter
        self.turnAfter = turnAfter
        self.calibrationOutcome = calibrationOutcome
    }
}

public struct MatchSession: Codable, Equatable, Identifiable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var revision: UInt64
    public var game: EightBallGameState
    public var shots: [RecordedShot]
    public var calibrationProfileID: UUID?

    public init(
        id: UUID = UUID(),
        title: String = "Match",
        createdAt: Date = Date(),
        game: EightBallGameState,
        shots: [RecordedShot] = [],
        calibrationProfileID: UUID? = nil
    ) {
        self.schemaVersion = Self.schemaVersion
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.revision = 0
        self.game = game
        self.shots = shots
        self.calibrationProfileID = calibrationProfileID
    }

    public var isFinished: Bool {
        game.outcome != .inProgress
    }

    public var remainingPlayerBalls: [BallState] {
        switch game.groupAssignment {
        case .open:
            return game.activeObjectBalls.filter {
                $0.kind == .solid || $0.kind == .stripe
            }
        case .solids:
            return game.activeObjectBalls.filter { $0.kind == .solid }
        case .stripes:
            return game.activeObjectBalls.filter { $0.kind == .stripe }
        }
    }

    public func settingTurn(
        _ turn: MatchTurn,
        ballInHand: Bool? = nil,
        at date: Date = Date()
    ) -> MatchSession {
        guard !isFinished else { return self }
        var result = self
        result.game.turn = turn
        if let ballInHand {
            result.game.ballInHand = ballInHand
        }
        result.touch(at: date)
        return result
    }

    public func assigning(
        group: GroupAssignment,
        at date: Date = Date()
    ) -> MatchSession {
        guard !isFinished else { return self }
        var result = self
        result.game.groupAssignment = group
        result.game.phase = group == .open ? .openTable : .groupPlay
        if group != .open,
           EightBallRules.canShootEightBall(in: result.game) {
            result.game.phase = .eightBall
        }
        result.touch(at: date)
        return result
    }

    public func requiringEightBallPocket(
        _ pocket: PocketID?,
        at date: Date = Date()
    ) -> MatchSession {
        guard !isFinished else { return self }
        var result = self
        result.game.requiredEightBallPocket = pocket
        result.touch(at: date)
        return result
    }

    public func reconcilingBoard(
        _ balls: [BallState],
        at date: Date = Date()
    ) -> MatchSession {
        guard !isFinished else { return self }
        var result = self
        result.game.balls = balls
        if result.game.groupAssignment != .open,
           EightBallRules.canShootEightBall(in: result.game) {
            result.game.phase = .eightBall
        }
        result.touch(at: date)
        return result
    }

    public func recordingPlayerShot(
        _ observation: ShotObservation,
        calibrationOutcome: ShotOutcome? = nil,
        at date: Date = Date()
    ) -> MatchSession {
        guard game.outcome == .inProgress else { return self }
        let groupBefore = game.groupAssignment
        let resolution = EightBallRules.resolve(observation, in: game)
        var result = self
        result.game = resolution.state
        result.shots.append(RecordedShot(
            sequence: shots.count + 1,
            recordedAt: date,
            observation: observation,
            legality: resolution.legality,
            groupBefore: groupBefore,
            groupAfter: resolution.state.groupAssignment,
            turnAfter: resolution.state.turn,
            calibrationOutcome: calibrationOutcome
        ))
        result.touch(at: date)
        return result
    }

    /// Manual match corrections use the same value-semantic approach as
    /// detection review: the original snapshot is untouched and unknown ball
    /// identifiers are no-ops.
    public func applyingManualCorrection(
        _ correction: SessionCorrection,
        at date: Date = Date()
    ) -> MatchSession {
        guard !isFinished else { return self }
        var result = self
        switch correction {
        case let .assignGroup(group):
            result.game.groupAssignment = group
            result.game.phase = group == .open ? .openTable : .groupPlay
        case let .requireEightBallPocket(pocket):
            result.game.requiredEightBallPocket = pocket
        case let .markBallPocketed(id, isPocketed):
            guard let index = result.game.balls.firstIndex(where: { $0.id == id }) else {
                return self
            }
            result.game.balls[index].isPocketed = isPocketed
        case let .setTurn(turn):
            result.game.turn = turn
        case let .setBallInHand(ballInHand):
            result.game.ballInHand = ballInHand
        case let .replaceBall(ball):
            if let index = result.game.balls.firstIndex(where: { $0.id == ball.id }) {
                result.game.balls[index] = ball
            } else {
                result.game.balls.append(ball)
            }
        case let .setOutcome(outcome):
            result.game.outcome = outcome
            if outcome != .inProgress {
                result.game.phase = .finished
                result.game.turn = .unknown
                result.game.ballInHand = false
            }
        }
        if result.game.groupAssignment != .open,
           EightBallRules.canShootEightBall(in: result.game) {
            result.game.phase = .eightBall
        }
        result.touch(at: date)
        return result
    }

    /// Opponent observations are reconciled without applying the player's
    /// legal-target rules. The next-turn decision remains explicit.
    public func recordingOpponentShot(
        pocketedBallIDs: Set<Int>,
        cueBallPocketed: Bool,
        nextTurn: MatchTurn,
        opponentEightBallWasLegal: Bool? = nil,
        at date: Date = Date()
    ) -> MatchSession {
        guard !isFinished, game.turn == .opponent else { return self }
        let pocketedEightBall = game.balls.contains {
            $0.kind == .eight && pocketedBallIDs.contains($0.id)
        }
        guard !pocketedEightBall || opponentEightBallWasLegal != nil else {
            return self
        }
        var result = self
        for index in result.game.balls.indices where
            pocketedBallIDs.contains(result.game.balls[index].id) {
            result.game.balls[index].isPocketed = true
        }
        result.game.turn = nextTurn
        result.game.ballInHand = cueBallPocketed && nextTurn == .player
        if let eightBall = result.game.balls.first(where: { $0.kind == .eight }),
           pocketedBallIDs.contains(eightBall.id),
           let opponentEightBallWasLegal {
            result.game.outcome = opponentEightBallWasLegal ? .lost : .won
            result.game.phase = .finished
            result.game.turn = .unknown
            result.game.ballInHand = false
        }
        if result.game.groupAssignment != .open,
           EightBallRules.canShootEightBall(in: result.game) {
            result.game.phase = .eightBall
        }
        result.touch(at: date)
        return result
    }

    private mutating func touch(at date: Date) {
        revision &+= 1
        updatedAt = date
    }
}

public actor MatchSessionController {
    private var session: MatchSession

    public init(session: MatchSession) {
        self.session = session
    }

    public func snapshot() -> MatchSession {
        session
    }

    @discardableResult
    public func setTurn(
        _ turn: MatchTurn,
        ballInHand: Bool? = nil,
        at date: Date = Date()
    ) -> MatchSession {
        session = session.settingTurn(turn, ballInHand: ballInHand, at: date)
        return session
    }

    @discardableResult
    public func applyPlayerShot(
        _ observation: ShotObservation,
        calibrationOutcome: ShotOutcome? = nil,
        at date: Date = Date()
    ) -> MatchSession {
        session = session.recordingPlayerShot(
            observation,
            calibrationOutcome: calibrationOutcome,
            at: date
        )
        return session
    }

    @discardableResult
    public func reconcile(
        balls: [BallState],
        at date: Date = Date()
    ) -> MatchSession {
        session = session.reconcilingBoard(balls, at: date)
        return session
    }
}
