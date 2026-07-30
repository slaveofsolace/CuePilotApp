import CueGeometry
import CuePhysics
import Foundation

public struct MonteCarloConfiguration: Sendable, Hashable, Codable {
    public var simulationsPerAngle: Int
    public var angleStepCount: Int
    public var successThreshold: Double
    public var centerStandardDeviation: Double
    public var radiusStandardDeviation: Double
    public var cueAngleStandardDeviation: Double
    public var powerStandardDeviation: Double
    public var frictionStandardDeviation: Double
    public var restitutionStandardDeviation: Double
    public var pocketToleranceStandardDeviation: Double
    public var maximumPhysicalHalfWidth: Double

    public init(
        simulationsPerAngle: Int = 72,
        angleStepCount: Int = 25,
        successThreshold: Double = 0.58,
        centerStandardDeviation: Double = 0.0018,
        radiusStandardDeviation: Double = 0.00055,
        cueAngleStandardDeviation: Double = AngleMath.radians(0.22),
        powerStandardDeviation: Double = 0.018,
        frictionStandardDeviation: Double = 0.012,
        restitutionStandardDeviation: Double = 0.018,
        pocketToleranceStandardDeviation: Double = 0.0015,
        maximumPhysicalHalfWidth: Double = AngleMath.radians(6)
    ) {
        self.simulationsPerAngle = max(1, simulationsPerAngle)
        let steps = max(3, angleStepCount)
        self.angleStepCount = steps.isMultiple(of: 2) ? steps + 1 : steps
        self.successThreshold = min(1, max(0, successThreshold))
        self.centerStandardDeviation = max(0, centerStandardDeviation)
        self.radiusStandardDeviation = max(0, radiusStandardDeviation)
        self.cueAngleStandardDeviation = max(
            0,
            cueAngleStandardDeviation
        )
        self.powerStandardDeviation = max(0, powerStandardDeviation)
        self.frictionStandardDeviation = max(
            0,
            frictionStandardDeviation
        )
        self.restitutionStandardDeviation = max(
            0,
            restitutionStandardDeviation
        )
        self.pocketToleranceStandardDeviation = max(
            0,
            pocketToleranceStandardDeviation
        )
        self.maximumPhysicalHalfWidth = min(
            .pi / 2,
            max(0, maximumPhysicalHalfWidth)
        )
    }

    public static let `default` = MonteCarloConfiguration()

    /// Scales every measurement/model uncertainty while preserving the sample
    /// budget and physical table limits.
    public func scalingUncertainty(by scale: Double) -> MonteCarloConfiguration {
        MonteCarloConfiguration(
            simulationsPerAngle: simulationsPerAngle,
            angleStepCount: angleStepCount,
            successThreshold: successThreshold,
            centerStandardDeviation: centerStandardDeviation * max(0, scale),
            radiusStandardDeviation: radiusStandardDeviation * max(0, scale),
            cueAngleStandardDeviation: cueAngleStandardDeviation * max(0, scale),
            powerStandardDeviation: powerStandardDeviation * max(0, scale),
            frictionStandardDeviation: frictionStandardDeviation * max(0, scale),
            restitutionStandardDeviation: restitutionStandardDeviation * max(0, scale),
            pocketToleranceStandardDeviation:
                pocketToleranceStandardDeviation * max(0, scale),
            maximumPhysicalHalfWidth: maximumPhysicalHalfWidth
        )
    }
}

public enum AlignmentAnalyzer {
    /// Samples a physically bounded angle interval with deterministic,
    /// seeded perturbations. The returned interval can only narrow the
    /// analytical pocket/contact bound.
    public static func corridor(
        for candidate: ShotCandidate,
        in state: EightBallGameState,
        configuration: MonteCarloConfiguration = .default,
        physics: PhysicsParameters = .default,
        seed: UInt64 = 0
    ) -> AlignmentCorridor {
        guard let cue = state.cueBall,
              let target = state.ball(id: candidate.targetBallID),
              let pocket = state.table.pocket(id: candidate.pocketID) else {
            return AlignmentCorridor(
                requiredAngle: candidate.requiredCueAngle,
                minimumAngle: candidate.requiredCueAngle,
                maximumAngle: candidate.requiredCueAngle,
                physicalHalfWidth: 0,
                estimatedSuccessProbability: 0,
                confidence: 0,
                sampleCount: 0
            )
        }

        let pocketedBall = candidate.secondaryBallID
            .flatMap { state.ball(id: $0) } ?? target
        let lastPath = candidate.objectPaths.last
        let finalDistance = max(
            lastPath?.length ?? pocketedBall.center.distance(to: pocket.aimPoint),
            pocketedBall.radius
        )
        let effectiveHalfOpening = pocket.effectiveOpeningWidth(
            ballRadius: pocketedBall.radius
        ) / 2
        let pocketHalfAngle = atan2(effectiveHalfOpening, finalDistance)
        let contactHalfAngle = asin(
            min(
                1,
                (cue.radius + target.radius) /
                    max(candidate.cuePath.length, cue.radius + target.radius)
            )
        )
        let cutTransfer = max(0.14, cos(min(.pi / 2, candidate.cutAngle)))
        let physicalHalfWidth = min(
            configuration.maximumPhysicalHalfWidth,
            contactHalfAngle * 0.80,
            pocketHalfAngle * cutTransfer * 0.82
        )

        guard physicalHalfWidth > GeometryTolerance.default else {
            return AlignmentCorridor(
                requiredAngle: candidate.requiredCueAngle,
                minimumAngle: candidate.requiredCueAngle,
                maximumAngle: candidate.requiredCueAngle,
                physicalHalfWidth: 0,
                estimatedSuccessProbability: 0,
                confidence: 0,
                sampleCount: configuration.simulationsPerAngle
            )
        }

        let stepCount = configuration.angleStepCount
        let angleStep = 2 * physicalHalfWidth / Double(stepCount - 1)
        let offsets = (0..<stepCount).map {
            -physicalHalfWidth + Double($0) * angleStep
        }
        let baseSeed = stableSeed(seed: seed, identifier: candidate.id)
        var probabilities: [Double] = []
        probabilities.reserveCapacity(stepCount)

        for (angleIndex, offset) in offsets.enumerated() {
            var successes = 0
            for simulationIndex in 0..<configuration.simulationsPerAngle {
                var random = SplitMix64(
                    seed: baseSeed &+
                        UInt64(angleIndex) &* 0x9E3779B97F4A7C15 &+
                        UInt64(simulationIndex) &* 0xBF58476D1CE4E5B9
                )
                let success: Bool
                if candidate.kind == .direct {
                    success = simulateDirect(
                        candidate: candidate,
                        cue: cue,
                        target: target,
                        pocket: pocket,
                        state: state,
                        angleOffset: offset,
                        configuration: configuration,
                        physics: physics,
                        random: &random
                    )
                } else {
                    success = simulateCompound(
                        candidate: candidate,
                        cue: cue,
                        target: target,
                        physicalHalfWidth: physicalHalfWidth,
                        angleOffset: offset,
                        configuration: configuration,
                        physics: physics,
                        random: &random
                    )
                }
                if success {
                    successes += 1
                }
            }
            probabilities.append(
                Double(successes) / Double(configuration.simulationsPerAngle)
            )
        }

        let qualifying = probabilities.indices.filter {
            probabilities[$0] >= configuration.successThreshold
        }
        let selectedRange = bestContiguousRange(
            qualifyingIndices: qualifying,
            probabilities: probabilities,
            centerIndex: stepCount / 2
        )

        let requiredOffset: Double
        let minimumOffset: Double
        let maximumOffset: Double
        let successProbability: Double
        if let selectedRange {
            let lower = max(
                -physicalHalfWidth,
                offsets[selectedRange.lowerBound] - angleStep / 2
            )
            let upper = min(
                physicalHalfWidth,
                offsets[selectedRange.upperBound] + angleStep / 2
            )
            minimumOffset = lower
            maximumOffset = upper
            requiredOffset = (lower + upper) / 2
            let values = probabilities[selectedRange]
            successProbability = values.reduce(0, +) / Double(values.count)
        } else {
            let bestIndex = probabilities.indices.max {
                if probabilities[$0] == probabilities[$1] {
                    return abs(offsets[$0]) > abs(offsets[$1])
                }
                return probabilities[$0] < probabilities[$1]
            } ?? stepCount / 2
            requiredOffset = offsets[bestIndex]
            minimumOffset = requiredOffset
            maximumOffset = requiredOffset
            successProbability = probabilities[bestIndex]
        }

        let uncertainty = uncertaintyIndex(
            configuration: configuration,
            cue: cue,
            target: target,
            candidate: candidate,
            physicalHalfWidth: physicalHalfWidth,
            physics: physics
        )
        let detectionConfidence = min(cue.confidence, target.confidence)
        let confidence = detectionConfidence *
            exp(-uncertainty) *
            (0.65 + 0.35 * candidate.estimatedSuccessProbability)
        let required = candidate.requiredCueAngle + requiredOffset

        return AlignmentCorridor(
            requiredAngle: required,
            minimumAngle: candidate.requiredCueAngle + minimumOffset,
            maximumAngle: candidate.requiredCueAngle + maximumOffset,
            physicalHalfWidth: physicalHalfWidth,
            estimatedSuccessProbability: successProbability,
            confidence: confidence,
            sampleCount: stepCount * configuration.simulationsPerAngle
        )
    }

    private static func simulateDirect(
        candidate: ShotCandidate,
        cue: BallState,
        target: BallState,
        pocket: PocketGeometry,
        state: EightBallGameState,
        angleOffset: Double,
        configuration: MonteCarloConfiguration,
        physics: PhysicsParameters,
        random: inout SplitMix64
    ) -> Bool {
        let cueCenter = cue.center + Vector2D(
            x: random.normal() * configuration.centerStandardDeviation,
            y: random.normal() * configuration.centerStandardDeviation
        )
        let targetCenter = target.center + Vector2D(
            x: random.normal() * configuration.centerStandardDeviation,
            y: random.normal() * configuration.centerStandardDeviation
        )
        let cueRadius = max(
            cue.radius * 0.75,
            cue.radius + random.normal() *
                configuration.radiusStandardDeviation
        )
        let targetRadius = max(
            target.radius * 0.75,
            target.radius + random.normal() *
                configuration.radiusStandardDeviation
        )
        let angle = candidate.requiredCueAngle +
            angleOffset +
            random.normal() * configuration.cueAngleStandardDeviation
        let direction = Vector2D(x: cos(angle), y: sin(angle))
        let targetOffset = targetCenter - cueCenter
        let projection = targetOffset.dot(direction)
        let collisionRadius = cueRadius + targetRadius
        let perpendicularSquared = max(
            0,
            targetOffset.lengthSquared - projection * projection
        )
        guard projection > 0,
              perpendicularSquared <= collisionRadius * collisionRadius else {
            return false
        }

        let entry = projection -
            max(0, collisionRadius * collisionRadius - perpendicularSquared)
                .squareRoot()
        guard entry >= 0 else { return false }
        let cueImpactCenter = cueCenter + direction * entry
        let collisionNormal = (targetCenter - cueImpactCenter).normalized()
        guard collisionNormal.length > GeometryTolerance.default else {
            return false
        }

        let power = min(
            1,
            max(
                0,
                candidate.powerRange.midpoint +
                    random.normal() * configuration.powerStandardDeviation
            )
        )
        let rollingFriction = max(
            0.001,
            physics.rollingFriction +
                random.normal() * configuration.frictionStandardDeviation
        )
        let restitution = min(
            1,
            max(
                0,
                physics.ballRestitution +
                    random.normal() * configuration.restitutionStandardDeviation
            )
        )
        let initialSpeed = 0.20 + 1.40 * power
        let impactSpeed = RollingMotion.remainingSpeed(
            initialSpeed: initialSpeed,
            afterDistance: entry,
            rollingFriction: rollingFriction
        )
        guard impactSpeed > 0.03 else { return false }
        let collision = EqualMassCollision.resolve(
            firstVelocity: direction * impactSpeed,
            normal: collisionNormal,
            restitution: restitution
        )
        let objectVelocity = collision.secondVelocity
        guard objectVelocity.length > 0.03 else { return false }

        let pocketShift = Vector2D(
            x: random.normal() * configuration.centerStandardDeviation * 0.35,
            y: random.normal() * configuration.centerStandardDeviation * 0.35
        )
        let shiftedPocket = PocketGeometry(
            id: pocket.id,
            center: pocket.center + pocketShift,
            aimPoint: pocket.aimPoint + pocketShift,
            mouth: Segment2D(
                start: pocket.mouth.start + pocketShift,
                end: pocket.mouth.end + pocketShift
            ),
            captureRadius: pocket.captureRadius,
            jawRadius: pocket.jawRadius
        )
        let pocketTolerance = random.normal() *
            configuration.pocketToleranceStandardDeviation
        let effectiveTargetRadius = max(
            targetRadius * 0.65,
            targetRadius - pocketTolerance
        )
        let travelDirection = objectVelocity.normalized()
        let requiredDistance = targetCenter.distance(to: shiftedPocket.aimPoint)
        let objectPath = Segment2D(
            start: targetCenter,
            end: targetCenter + travelDirection *
                (requiredDistance + state.table.playableBounds.diagonal * 0.15)
        )
        guard shiftedPocket.accepts(
            centerPath: objectPath,
            ballRadius: effectiveTargetRadius
        ) else {
            return false
        }

        let remainingObjectSpeed = RollingMotion.remainingSpeed(
            initialSpeed: objectVelocity.length,
            afterDistance: requiredDistance,
            rollingFriction: rollingFriction
        )
        guard remainingObjectSpeed > 0.02 else { return false }

        let cuePath = Segment2D(start: cueCenter, end: cueImpactCenter)
        let cueClearance = uncertainClearance(
            path: cuePath,
            movingRadius: cueRadius,
            balls: state.balls,
            excluding: [cue.id, target.id],
            centerNoise: configuration.centerStandardDeviation,
            radiusNoise: configuration.radiusStandardDeviation,
            random: &random
        )
        guard cueClearance else { return false }
        let objectClearance = uncertainClearance(
            path: objectPath,
            movingRadius: targetRadius,
            balls: state.balls,
            excluding: [cue.id, target.id],
            centerNoise: configuration.centerStandardDeviation,
            radiusNoise: configuration.radiusStandardDeviation,
            random: &random
        )
        guard objectClearance else { return false }

        return random.nextUnit() >= candidate.scratch.probability
    }

    private static func simulateCompound(
        candidate: ShotCandidate,
        cue: BallState,
        target: BallState,
        physicalHalfWidth: Double,
        angleOffset: Double,
        configuration: MonteCarloConfiguration,
        physics: PhysicsParameters,
        random: inout SplitMix64
    ) -> Bool {
        let centerAngleNoise = random.normal() *
            configuration.centerStandardDeviation /
            max(candidate.cuePath.length, cue.radius + target.radius)
        let angularError = abs(
            angleOffset +
                centerAngleNoise +
                random.normal() * configuration.cueAngleStandardDeviation
        )
        guard angularError <= physicalHalfWidth else { return false }

        let power = candidate.powerRange.midpoint +
            random.normal() * configuration.powerStandardDeviation
        guard power >= candidate.powerRange.minimum * 0.88,
              power <= min(1, candidate.powerRange.maximum * 1.12) else {
            return false
        }
        let frictionPenalty = abs(
            random.normal() * configuration.frictionStandardDeviation
        ) / max(physics.rollingFriction, 0.01)
        let restitutionPenalty = abs(
            random.normal() * configuration.restitutionStandardDeviation
        )
        let kindFactor: Double
        switch candidate.kind {
        case .combination: kindFactor = 0.88
        case .bank: kindFactor = 0.80
        case .safety: kindFactor = 0.82
        case .direct: kindFactor = 1
        }
        let centerSuccess = min(
            0.96,
            candidate.estimatedSuccessProbability * 1.35 * kindFactor
        )
        let edgeFactor = max(
            0,
            1 - pow(angularError / physicalHalfWidth, 2) * 0.45
        )
        let probability = centerSuccess * edgeFactor *
            max(0.4, 1 - frictionPenalty * 0.25 - restitutionPenalty)
            * (1 - candidate.scratch.probability)
        return random.nextUnit() < probability
    }

    private static func uncertainClearance(
        path: Segment2D,
        movingRadius: Double,
        balls: [BallState],
        excluding: Set<Int>,
        centerNoise: Double,
        radiusNoise: Double,
        random: inout SplitMix64
    ) -> Bool {
        for ball in balls where
            !ball.isPocketed && !excluding.contains(ball.id) {
            let center = ball.center + Vector2D(
                x: random.normal() * centerNoise,
                y: random.normal() * centerNoise
            )
            let radius = max(
                0,
                ball.radius + random.normal() * radiusNoise
            )
            if path.distance(to: center) <
                movingRadius + radius - GeometryTolerance.default {
                return false
            }
        }
        return true
    }

    private static func uncertaintyIndex(
        configuration: MonteCarloConfiguration,
        cue: BallState,
        target: BallState,
        candidate: ShotCandidate,
        physicalHalfWidth: Double,
        physics: PhysicsParameters
    ) -> Double {
        let radius = max(
            (cue.radius + target.radius) / 2,
            GeometryTolerance.default
        )
        let corridor = max(physicalHalfWidth, AngleMath.radians(0.05))
        let powerWidth = max(candidate.powerRange.width, 0.025)
        return configuration.centerStandardDeviation / radius * 0.50 +
            configuration.radiusStandardDeviation / radius * 0.35 +
            configuration.cueAngleStandardDeviation / corridor * 0.55 +
            configuration.powerStandardDeviation / powerWidth * 0.25 +
            configuration.frictionStandardDeviation /
                max(physics.rollingFriction, 0.02) * 0.18 +
            configuration.restitutionStandardDeviation * 0.20 +
            configuration.pocketToleranceStandardDeviation / radius * 0.30
    }

    private static func bestContiguousRange(
        qualifyingIndices: [Int],
        probabilities: [Double],
        centerIndex: Int
    ) -> ClosedRange<Int>? {
        guard let first = qualifyingIndices.first else { return nil }
        var ranges: [ClosedRange<Int>] = []
        var start = first
        var previous = first
        for index in qualifyingIndices.dropFirst() {
            if index != previous + 1 {
                ranges.append(start...previous)
                start = index
            }
            previous = index
        }
        ranges.append(start...previous)

        if let centered = ranges.first(where: { $0.contains(centerIndex) }) {
            return centered
        }
        return ranges.max {
            let lhsPeak = probabilities[$0].max() ?? 0
            let rhsPeak = probabilities[$1].max() ?? 0
            if lhsPeak == rhsPeak {
                return $0.count < $1.count
            }
            return lhsPeak < rhsPeak
        }
    }

    private static func stableSeed(seed: UInt64, identifier: String) -> UInt64 {
        var hash = UInt64(0xcbf29ce484222325) ^ seed
        for byte in identifier.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func normal() -> Double {
        let first = max(nextUnit(), Double.leastNonzeroMagnitude)
        let second = nextUnit()
        return sqrt(-2 * log(first)) * cos(2 * .pi * second)
    }
}
