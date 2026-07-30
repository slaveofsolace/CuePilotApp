import CueGeometry
import Foundation

public enum GroupAssignment: String, Sendable, Hashable, Codable, CaseIterable {
    case open
    case solids
    case stripes
}

public enum MatchTurn: String, Sendable, Hashable, Codable, CaseIterable {
    case player
    case opponent
    case unknown
}

public enum MatchPhase: String, Sendable, Hashable, Codable, CaseIterable {
    case openingBreak
    case openTable
    case groupPlay
    case eightBall
    case finished
}

public enum MatchOutcome: String, Sendable, Hashable, Codable, CaseIterable {
    case inProgress
    case won
    case lost
}

public struct EightBallGameState: Sendable, Hashable, Codable {
    public var table: TableGeometry
    public var balls: [BallState]
    public var groupAssignment: GroupAssignment
    public var turn: MatchTurn
    public var phase: MatchPhase
    public var ballInHand: Bool
    public var requiredEightBallPocket: PocketID?
    public var outcome: MatchOutcome

    public init(
        table: TableGeometry,
        balls: [BallState],
        groupAssignment: GroupAssignment = .open,
        turn: MatchTurn = .player,
        phase: MatchPhase = .openTable,
        ballInHand: Bool = false,
        requiredEightBallPocket: PocketID? = nil,
        outcome: MatchOutcome = .inProgress
    ) {
        self.table = table
        self.balls = balls
        self.groupAssignment = groupAssignment
        self.turn = turn
        self.phase = phase
        self.ballInHand = ballInHand
        self.requiredEightBallPocket = requiredEightBallPocket
        self.outcome = outcome
    }

    public var cueBall: BallState? {
        balls.first { $0.kind == .cue && !$0.isPocketed }
    }

    public func ball(id: Int) -> BallState? {
        balls.first { $0.id == id }
    }

    public var activeObjectBalls: [BallState] {
        balls.filter { !$0.isPocketed && $0.isObjectBall }
    }
}

public enum RulesViolation: String, Sendable, Hashable, Codable, CaseIterable {
    case notPlayersTurn
    case noFirstContact
    case illegalFirstContact
    case earlyEightBall
    case requiredEightBallPocketMissing
    case wrongEightBallPocket
    case cueBallScratch
}

public struct ShotObservation: Sendable, Hashable, Codable {
    public var firstContactBallID: Int?
    public var pocketedBallIDs: Set<Int>
    public var cueBallPocketed: Bool
    public var calledPocket: PocketID?

    public init(
        firstContactBallID: Int?,
        pocketedBallIDs: Set<Int> = [],
        cueBallPocketed: Bool = false,
        calledPocket: PocketID? = nil
    ) {
        self.firstContactBallID = firstContactBallID
        self.pocketedBallIDs = pocketedBallIDs
        self.cueBallPocketed = cueBallPocketed
        self.calledPocket = calledPocket
    }
}

public struct ShotLegality: Sendable, Hashable, Codable {
    public var isLegal: Bool
    public var violations: [RulesViolation]

    public init(isLegal: Bool, violations: [RulesViolation]) {
        self.isLegal = isLegal
        self.violations = violations
    }
}

public struct RulesResolution: Sendable, Hashable, Codable {
    public var state: EightBallGameState
    public var legality: ShotLegality
    public var keepsTurn: Bool

    public init(
        state: EightBallGameState,
        legality: ShotLegality,
        keepsTurn: Bool
    ) {
        self.state = state
        self.legality = legality
        self.keepsTurn = keepsTurn
    }
}

public enum EightBallRules {
    /// Returns legal first-contact balls. The 8-ball appears only after every
    /// assigned group ball has been pocketed.
    public static func legalTargets(in state: EightBallGameState) -> [BallState] {
        guard state.outcome == .inProgress else { return [] }
        let active = state.activeObjectBalls
        switch state.groupAssignment {
        case .open:
            return active.filter { $0.kind == .solid || $0.kind == .stripe }
        case .solids:
            let solids = active.filter { $0.kind == .solid }
            return solids.isEmpty ? active.filter { $0.kind == .eight } : solids
        case .stripes:
            let stripes = active.filter { $0.kind == .stripe }
            return stripes.isEmpty ? active.filter { $0.kind == .eight } : stripes
        }
    }

    public static func isLegalFirstContact(
        ballID: Int,
        in state: EightBallGameState
    ) -> Bool {
        legalTargets(in: state).contains { $0.id == ballID }
    }

    public static func canShootEightBall(in state: EightBallGameState) -> Bool {
        guard state.groupAssignment != .open else { return false }
        return legalTargets(in: state).contains { $0.kind == .eight }
    }

    /// Applies a player shot to the local match state. This intentionally
    /// models the core legal 8-ball contract and leaves league-specific break
    /// variations to the session layer.
    public static func resolve(
        _ observation: ShotObservation,
        in state: EightBallGameState
    ) -> RulesResolution {
        var updated = state
        var violations: [RulesViolation] = []
        let legalTargetIDs = Set(legalTargets(in: state).map(\.id))

        if state.turn != .player {
            violations.append(.notPlayersTurn)
        }

        if let firstContact = observation.firstContactBallID {
            if !legalTargetIDs.contains(firstContact) {
                if state.ball(id: firstContact)?.kind == .eight &&
                    !canShootEightBall(in: state) {
                    violations.append(.earlyEightBall)
                } else {
                    violations.append(.illegalFirstContact)
                }
            }
        } else {
            violations.append(.noFirstContact)
        }

        if observation.cueBallPocketed {
            violations.append(.cueBallScratch)
        }

        let eightBall = state.balls.first { $0.kind == .eight }
        let eightPocketed = eightBall.map {
            observation.pocketedBallIDs.contains($0.id)
        } ?? false
        if eightPocketed {
            if !canShootEightBall(in: state) {
                if !violations.contains(.earlyEightBall) {
                    violations.append(.earlyEightBall)
                }
            } else if state.requiredEightBallPocket == nil {
                violations.append(.requiredEightBallPocketMissing)
            } else if observation.calledPocket != state.requiredEightBallPocket {
                violations.append(.wrongEightBallPocket)
            }
        }

        for index in updated.balls.indices where
            observation.pocketedBallIDs.contains(updated.balls[index].id) {
            updated.balls[index].isPocketed = true
        }
        if observation.cueBallPocketed,
           let cueIndex = updated.balls.firstIndex(where: { $0.kind == .cue }) {
            updated.balls[cueIndex].isPocketed = true
        }

        let legality = ShotLegality(
            isLegal: violations.isEmpty,
            violations: violations
        )

        if eightPocketed {
            updated.outcome = violations.isEmpty ? .won : .lost
            updated.phase = .finished
            updated.turn = .unknown
            updated.ballInHand = false
            return RulesResolution(
                state: updated,
                legality: legality,
                keepsTurn: false
            )
        }

        if violations.isEmpty, state.groupAssignment == .open {
            let newlyPocketed = state.balls
                .filter {
                    observation.pocketedBallIDs.contains($0.id) &&
                        ($0.kind == .solid || $0.kind == .stripe)
                }
                .sorted { $0.id < $1.id }
            if let assignmentBall = newlyPocketed.first {
                updated.groupAssignment =
                    assignmentBall.kind == .solid ? .solids : .stripes
                updated.phase = .groupPlay
            }
        }

        let ownPocketed = state.balls.contains {
            observation.pocketedBallIDs.contains($0.id) &&
                legalTargetIDs.contains($0.id)
        }
        let keepsTurn = violations.isEmpty && ownPocketed
        updated.turn = keepsTurn ? .player : .opponent
        updated.ballInHand = !violations.isEmpty

        if updated.groupAssignment != .open,
           legalTargets(in: updated).contains(where: { $0.kind == .eight }) {
            updated.phase = .eightBall
        }

        return RulesResolution(
            state: updated,
            legality: legality,
            keepsTurn: keepsTurn
        )
    }
}
