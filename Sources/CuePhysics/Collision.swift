import CueGeometry
import Foundation

public struct PhysicsParameters: Sendable, Hashable, Codable {
    public var ballRestitution: Double
    public var cushionRestitution: Double
    /// Speed lost per normalized table-distance.
    public var rollingFriction: Double

    public init(
        ballRestitution: Double = 0.94,
        cushionRestitution: Double = 0.72,
        rollingFriction: Double = 0.18
    ) {
        self.ballRestitution = min(1, max(0, ballRestitution))
        self.cushionRestitution = min(1, max(0, cushionRestitution))
        self.rollingFriction = max(0, rollingFriction)
    }

    public static let `default` = PhysicsParameters()
}

public struct BallCollisionResult: Sendable, Hashable, Codable {
    public var firstVelocity: Vector2D
    public var secondVelocity: Vector2D

    public init(firstVelocity: Vector2D, secondVelocity: Vector2D) {
        self.firstVelocity = firstVelocity
        self.secondVelocity = secondVelocity
    }
}

public enum EqualMassCollision {
    /// Resolves a frictionless instantaneous collision between equal masses.
    /// `normal` points from the first ball's center to the second ball's center.
    public static func resolve(
        firstVelocity: Vector2D,
        secondVelocity: Vector2D = .zero,
        normal: Vector2D,
        restitution: Double = PhysicsParameters.default.ballRestitution
    ) -> BallCollisionResult {
        let unitNormal = normal.normalized()
        guard unitNormal.length > GeometryTolerance.default else {
            return BallCollisionResult(
                firstVelocity: firstVelocity,
                secondVelocity: secondVelocity
            )
        }

        let closingSpeed = (firstVelocity - secondVelocity).dot(unitNormal)
        guard closingSpeed > 0 else {
            return BallCollisionResult(
                firstVelocity: firstVelocity,
                secondVelocity: secondVelocity
            )
        }

        let impulsePerMass = (1 + min(1, max(0, restitution))) *
            closingSpeed / 2
        return BallCollisionResult(
            firstVelocity: firstVelocity - unitNormal * impulsePerMass,
            secondVelocity: secondVelocity + unitNormal * impulsePerMass
        )
    }
}

public enum CushionCollision {
    /// Reflects the normal component with restitution while preserving the
    /// tangential component.
    public static func reflectedVelocity(
        incidentVelocity: Vector2D,
        railDirection: Vector2D,
        restitution: Double = PhysicsParameters.default.cushionRestitution
    ) -> Vector2D {
        let tangent = railDirection.normalized()
        guard tangent.length > GeometryTolerance.default else {
            return incidentVelocity
        }
        let normal = tangent.perpendicularLeft
        let tangentialVelocity = tangent * incidentVelocity.dot(tangent)
        let normalVelocity = normal * incidentVelocity.dot(normal)
        return tangentialVelocity - normalVelocity * min(1, max(0, restitution))
    }
}

public enum RollingMotion {
    public static func remainingSpeed(
        initialSpeed: Double,
        afterDistance distance: Double,
        rollingFriction: Double
    ) -> Double {
        max(0, initialSpeed - max(0, distance) * max(0, rollingFriction))
    }

    public static func stoppingDistance(
        initialSpeed: Double,
        rollingFriction: Double
    ) -> Double {
        guard rollingFriction > GeometryTolerance.default else {
            return .infinity
        }
        return max(0, initialSpeed) / rollingFriction
    }
}
