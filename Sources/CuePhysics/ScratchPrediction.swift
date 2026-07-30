import CueGeometry
import Foundation

public enum ScratchRiskLevel: String, Sendable, Hashable, Codable, CaseIterable {
    case low
    case moderate
    case high
}

public struct ScratchPrediction: Sendable, Hashable, Codable {
    public var level: ScratchRiskLevel
    public var probability: Double
    public var threatenedPocket: PocketID?
    public var predictedCuePath: Segment2D?

    public init(
        level: ScratchRiskLevel,
        probability: Double,
        threatenedPocket: PocketID? = nil,
        predictedCuePath: Segment2D? = nil
    ) {
        self.level = level
        self.probability = min(1, max(0, probability))
        self.threatenedPocket = threatenedPocket
        self.predictedCuePath = predictedCuePath
    }

    public static let low = ScratchPrediction(level: .low, probability: 0.02)
}

public enum ScratchAnalyzer {
    /// Predicts the first post-impact cue-ball leg for a center-ball hit.
    public static func predict(
        cue: BallState,
        target: BallState,
        ghostCenter: Point2D,
        incomingSpeed: Double,
        table: TableGeometry,
        obstacles: [BallState],
        parameters: PhysicsParameters = .default
    ) -> ScratchPrediction {
        let incomingDirection = (ghostCenter - cue.center).normalized()
        let collisionNormal = (target.center - ghostCenter).normalized()
        let collision = EqualMassCollision.resolve(
            firstVelocity: incomingDirection * max(0, incomingSpeed),
            normal: collisionNormal,
            restitution: parameters.ballRestitution
        )
        let postVelocity = collision.firstVelocity
        guard postVelocity.length > 0.035 else {
            return .low
        }

        let stoppingDistance = RollingMotion.stoppingDistance(
            initialSpeed: postVelocity.length,
            rollingFriction: parameters.rollingFriction
        )
        let maximumDistance = min(
            table.playableBounds.diagonal * 1.5,
            stoppingDistance
        )
        let impactCenter = ghostCenter
        let end = impactCenter + postVelocity.normalized() * maximumDistance
        let path = Segment2D(start: impactCenter, end: end)

        let obstacleHitParameter = obstacles
            .filter {
                !$0.isPocketed &&
                    $0.id != cue.id &&
                    $0.id != target.id
            }
            .compactMap {
                rayCircleEntryParameter(
                    segment: path,
                    circle: Circle2D(
                        center: $0.center,
                        radius: cue.radius + $0.radius
                    )
                )
            }
            .min() ?? .infinity

        var threatenedPocket: PocketID?
        var closestPocketParameter = Double.infinity
        var closestClearance = Double.infinity

        for pocket in table.pockets {
            let effectiveRadius = max(
                cue.radius * 0.85,
                pocket.captureRadius - cue.radius * 0.25
            )
            let circle = Circle2D(
                center: pocket.aimPoint,
                radius: effectiveRadius
            )
            guard let parameter = rayCircleEntryParameter(
                segment: path,
                circle: circle
            ), parameter < obstacleHitParameter else {
                continue
            }
            let clearance = path.distance(to: pocket.aimPoint)
            if parameter < closestPocketParameter {
                closestPocketParameter = parameter
                closestClearance = clearance
                threatenedPocket = pocket.id
            }
        }

        guard let threatenedPocket else {
            let nearPocket = table.pockets.map {
                path.distance(to: $0.aimPoint) - $0.captureRadius
            }.min() ?? .infinity
            if nearPocket < cue.radius * 1.5 {
                return ScratchPrediction(
                    level: .moderate,
                    probability: 0.24,
                    predictedCuePath: path
                )
            }
            return ScratchPrediction(
                level: .low,
                probability: 0.03,
                predictedCuePath: path
            )
        }

        let pocket = table.pocket(id: threatenedPocket)
        let capture = pocket?.captureRadius ?? cue.radius
        let normalizedClearance = closestClearance / max(
            capture,
            GeometryTolerance.default
        )
        let probability = min(0.97, max(0.55, 1.05 - normalizedClearance * 0.35))
        return ScratchPrediction(
            level: .high,
            probability: probability,
            threatenedPocket: threatenedPocket,
            predictedCuePath: path
        )
    }

    private static func rayCircleEntryParameter(
        segment: Segment2D,
        circle: Circle2D
    ) -> Double? {
        let direction = segment.vector
        let offset = segment.start - circle.center
        let a = direction.dot(direction)
        guard a > GeometryTolerance.default else { return nil }
        let b = 2 * offset.dot(direction)
        let c = offset.dot(offset) - circle.radius * circle.radius
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let root = discriminant.squareRoot()
        let candidates = [
            (-b - root) / (2 * a),
            (-b + root) / (2 * a),
        ].filter { $0 >= 0 && $0 <= 1 }
        return candidates.min()
    }
}
