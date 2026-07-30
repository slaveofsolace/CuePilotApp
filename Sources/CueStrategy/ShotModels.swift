import CueGeometry
import CuePhysics
import Foundation

public enum ShotKind: String, Sendable, Hashable, Codable, CaseIterable {
    case direct
    case combination
    case bank
    case safety
}

public enum CandidateRejection: String, Sendable, Hashable, Codable, CaseIterable {
    case illegalTarget
    case pathBlocked
    case targetPathBlocked
    case pocketRejected
    case jawCollision
    case ghostOverlapsBall
    case ghostOutsideTable
    case railCollision
    case excessiveCut
    case bankUnreachable
    case scratchRisk
    case lowDetectionConfidence
}

public struct PowerRange: Sendable, Hashable, Codable {
    public var minimum: Double
    public var maximum: Double

    public init(minimum: Double, maximum: Double) {
        let lower = min(minimum, maximum)
        let upper = max(minimum, maximum)
        self.minimum = min(1, max(0, lower))
        self.maximum = min(1, max(0, upper))
    }

    public var midpoint: Double {
        (minimum + maximum) / 2
    }

    public var width: Double {
        maximum - minimum
    }

    public func contains(_ power: Double) -> Bool {
        power >= minimum && power <= maximum
    }
}

public struct ShotCandidate: Sendable, Hashable, Codable, Identifiable {
    public var id: String
    public var kind: ShotKind
    public var targetBallID: Int
    public var secondaryBallID: Int?
    public var pocketID: PocketID
    public var bankRailID: RailID?
    public var aimPoint: Point2D
    public var ghostCenters: [Point2D]
    public var cuePath: Segment2D
    public var objectPaths: [Segment2D]
    public var requiredCueAngle: Double
    public var cutAngle: Double
    public var minimumClearance: Double
    public var scratch: ScratchPrediction
    public var powerRange: PowerRange
    public var estimatedSuccessProbability: Double
    public var score: Double
    public var isLegal: Bool
    public var rejections: [CandidateRejection]

    public init(
        id: String,
        kind: ShotKind,
        targetBallID: Int,
        secondaryBallID: Int? = nil,
        pocketID: PocketID,
        bankRailID: RailID? = nil,
        aimPoint: Point2D,
        ghostCenters: [Point2D],
        cuePath: Segment2D,
        objectPaths: [Segment2D],
        requiredCueAngle: Double,
        cutAngle: Double,
        minimumClearance: Double,
        scratch: ScratchPrediction,
        powerRange: PowerRange,
        estimatedSuccessProbability: Double,
        score: Double,
        isLegal: Bool,
        rejections: [CandidateRejection] = []
    ) {
        self.id = id
        self.kind = kind
        self.targetBallID = targetBallID
        self.secondaryBallID = secondaryBallID
        self.pocketID = pocketID
        self.bankRailID = bankRailID
        self.aimPoint = aimPoint
        self.ghostCenters = ghostCenters
        self.cuePath = cuePath
        self.objectPaths = objectPaths
        self.requiredCueAngle = requiredCueAngle
        self.cutAngle = cutAngle
        self.minimumClearance = minimumClearance
        self.scratch = scratch
        self.powerRange = powerRange
        self.estimatedSuccessProbability = min(
            1,
            max(0, estimatedSuccessProbability)
        )
        self.score = score
        self.isLegal = isLegal
        self.rejections = rejections
    }
}

public struct AlignmentCorridor: Sendable, Hashable, Codable {
    public var requiredAngle: Double
    /// Unwrapped around `requiredAngle`; it may cross the conventional ±π seam.
    public var minimumAngle: Double
    public var maximumAngle: Double
    public var physicalHalfWidth: Double
    public var estimatedSuccessProbability: Double
    public var confidence: Double
    public var sampleCount: Int

    public init(
        requiredAngle: Double,
        minimumAngle: Double,
        maximumAngle: Double,
        physicalHalfWidth: Double,
        estimatedSuccessProbability: Double,
        confidence: Double,
        sampleCount: Int
    ) {
        self.requiredAngle = requiredAngle
        self.minimumAngle = min(minimumAngle, maximumAngle)
        self.maximumAngle = max(minimumAngle, maximumAngle)
        self.physicalHalfWidth = max(0, physicalHalfWidth)
        self.estimatedSuccessProbability = min(
            1,
            max(0, estimatedSuccessProbability)
        )
        self.confidence = min(1, max(0, confidence))
        self.sampleCount = max(0, sampleCount)
    }

    public var width: Double {
        maximumAngle - minimumAngle
    }

    public func contains(_ angle: Double) -> Bool {
        let relative = AngleMath.signedDifference(
            from: requiredAngle,
            to: angle
        )
        let lower = minimumAngle - requiredAngle
        let upper = maximumAngle - requiredAngle
        return relative >= lower && relative <= upper
    }
}

public enum GuidanceState: String, Sendable, Hashable, Codable, CaseIterable {
    case searching
    case analyzing
    case rotateLeft
    case rotateRight
    case fineAlignment
    case aimLocked
    case morePower
    case lessPower
    case ready
    case doNotShoot
    case waitingForTurn
}

public struct AlignmentGuidance: Sendable, Hashable, Codable {
    public var state: GuidanceState
    public var signedCorrection: Double
    public var currentAngle: Double?
    public var requiredAngle: Double
    public var minimumValidAngle: Double
    public var maximumValidAngle: Double
    public var confidence: Double
    public var estimatedSuccessProbability: Double

    public init(
        state: GuidanceState,
        signedCorrection: Double,
        currentAngle: Double?,
        requiredAngle: Double,
        minimumValidAngle: Double,
        maximumValidAngle: Double,
        confidence: Double,
        estimatedSuccessProbability: Double
    ) {
        self.state = state
        self.signedCorrection = signedCorrection
        self.currentAngle = currentAngle
        self.requiredAngle = requiredAngle
        self.minimumValidAngle = minimumValidAngle
        self.maximumValidAngle = maximumValidAngle
        self.confidence = confidence
        self.estimatedSuccessProbability = estimatedSuccessProbability
    }
}

public struct ShotRecommendation: Sendable, Hashable, Codable {
    public var candidate: ShotCandidate
    public var corridor: AlignmentCorridor
    public var alternatives: [ShotCandidate]

    public init(
        candidate: ShotCandidate,
        corridor: AlignmentCorridor,
        alternatives: [ShotCandidate] = []
    ) {
        self.candidate = candidate
        self.corridor = corridor
        self.alternatives = alternatives
    }

    public func guidance(
        currentAngle: Double?,
        currentPower: Double?,
        isPlayersTurn: Bool = true,
        minimumLockConfidence: Double = 0.62,
        fineAlignmentThreshold: Double = AngleMath.radians(1.25)
    ) -> AlignmentGuidance {
        let correction = currentAngle.map {
            AngleMath.signedDifference(from: $0, to: corridor.requiredAngle)
        } ?? 0

        let state: GuidanceState
        if !isPlayersTurn {
            state = .waitingForTurn
        } else if !candidate.isLegal ||
                    !candidate.rejections.isEmpty ||
                    corridor.estimatedSuccessProbability < minimumLockConfidence ||
                    candidate.scratch.level == .high {
            state = .doNotShoot
        } else if currentAngle == nil {
            state = .searching
        } else if !corridor.contains(currentAngle!) {
            if abs(correction) <= fineAlignmentThreshold {
                state = .fineAlignment
            } else {
                state = correction > 0 ? .rotateLeft : .rotateRight
            }
        } else if corridor.confidence < minimumLockConfidence {
            state = .fineAlignment
        } else if let currentPower {
            if currentPower < candidate.powerRange.minimum {
                state = .morePower
            } else if currentPower > candidate.powerRange.maximum {
                state = .lessPower
            } else {
                state = .ready
            }
        } else {
            state = .aimLocked
        }

        return AlignmentGuidance(
            state: state,
            signedCorrection: correction,
            currentAngle: currentAngle,
            requiredAngle: corridor.requiredAngle,
            minimumValidAngle: corridor.minimumAngle,
            maximumValidAngle: corridor.maximumAngle,
            confidence: corridor.confidence,
            estimatedSuccessProbability: corridor.estimatedSuccessProbability
        )
    }
}
