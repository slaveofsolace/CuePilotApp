import CueGeometry
import Foundation

public enum ShotGeometryError: Error, Sendable, Equatable {
    case coincidentObjectAndPocket
    case coincidentCueAndGhost
    case unreachableBank
}

public struct DirectShotSolution: Sendable, Hashable, Codable {
    public var ghostCenter: Point2D
    public var objectDirection: Vector2D
    public var cuePath: Segment2D
    public var objectPath: Segment2D
    public var requiredCueAngle: Double
    public var cutAngle: Double

    public init(
        ghostCenter: Point2D,
        objectDirection: Vector2D,
        cuePath: Segment2D,
        objectPath: Segment2D,
        requiredCueAngle: Double,
        cutAngle: Double
    ) {
        self.ghostCenter = ghostCenter
        self.objectDirection = objectDirection
        self.cuePath = cuePath
        self.objectPath = objectPath
        self.requiredCueAngle = requiredCueAngle
        self.cutAngle = cutAngle
    }
}

public enum DirectShotGeometry {
    /// Calculates `G = T - (cueRadius + targetRadius) × normalize(P - T)`.
    public static func ghostCenter(
        target: BallState,
        cueRadius: Double,
        pocketAimPoint: Point2D
    ) throws -> Point2D {
        let delta = pocketAimPoint - target.center
        guard delta.length > GeometryTolerance.default else {
            throw ShotGeometryError.coincidentObjectAndPocket
        }
        return target.center -
            delta.normalized() * (cueRadius + target.radius)
    }

    public static func solve(
        cue: BallState,
        target: BallState,
        pocketAimPoint: Point2D
    ) throws -> DirectShotSolution {
        let objectDirection = (pocketAimPoint - target.center).normalized()
        guard objectDirection.length > GeometryTolerance.default else {
            throw ShotGeometryError.coincidentObjectAndPocket
        }

        let ghost = target.center -
            objectDirection * (cue.radius + target.radius)
        let cueDirection = ghost - cue.center
        guard cueDirection.length > GeometryTolerance.default else {
            throw ShotGeometryError.coincidentCueAndGhost
        }

        let incoming = cueDirection.normalized()
        let cutAngle = abs(
            AngleMath.signedDifference(
                from: incoming.angle,
                to: objectDirection.angle
            )
        )

        return DirectShotSolution(
            ghostCenter: ghost,
            objectDirection: objectDirection,
            cuePath: Segment2D(start: cue.center, end: ghost),
            objectPath: Segment2D(start: target.center, end: pocketAimPoint),
            requiredCueAngle: incoming.angle,
            cutAngle: cutAngle
        )
    }
}

public struct CombinationShotSolution: Sendable, Hashable, Codable {
    public var firstObjectGhostCenter: Point2D
    public var secondObjectGhostCenter: Point2D
    public var cuePath: Segment2D
    public var firstObjectPath: Segment2D
    public var secondObjectPath: Segment2D
    public var requiredCueAngle: Double
    public var firstCutAngle: Double
    public var secondCutAngle: Double

    public init(
        firstObjectGhostCenter: Point2D,
        secondObjectGhostCenter: Point2D,
        cuePath: Segment2D,
        firstObjectPath: Segment2D,
        secondObjectPath: Segment2D,
        requiredCueAngle: Double,
        firstCutAngle: Double,
        secondCutAngle: Double
    ) {
        self.firstObjectGhostCenter = firstObjectGhostCenter
        self.secondObjectGhostCenter = secondObjectGhostCenter
        self.cuePath = cuePath
        self.firstObjectPath = firstObjectPath
        self.secondObjectPath = secondObjectPath
        self.requiredCueAngle = requiredCueAngle
        self.firstCutAngle = firstCutAngle
        self.secondCutAngle = secondCutAngle
    }
}

public enum CombinationShotGeometry {
    /// Works backward from the pocket for a cue → first object → second object
    /// combination. Each returned ghost center is a center-at-impact position.
    public static func solve(
        cue: BallState,
        firstObject: BallState,
        secondObject: BallState,
        pocketAimPoint: Point2D
    ) throws -> CombinationShotSolution {
        let secondDirection = (pocketAimPoint - secondObject.center).normalized()
        guard secondDirection.length > GeometryTolerance.default else {
            throw ShotGeometryError.coincidentObjectAndPocket
        }

        let firstAtSecondImpact = secondObject.center -
            secondDirection * (firstObject.radius + secondObject.radius)
        let firstTravel = firstAtSecondImpact - firstObject.center
        guard firstTravel.length > GeometryTolerance.default else {
            throw ShotGeometryError.coincidentCueAndGhost
        }

        let firstDirection = firstTravel.normalized()
        let cueAtFirstImpact = firstObject.center -
            firstDirection * (cue.radius + firstObject.radius)
        let cueTravel = cueAtFirstImpact - cue.center
        guard cueTravel.length > GeometryTolerance.default else {
            throw ShotGeometryError.coincidentCueAndGhost
        }

        let cueDirection = cueTravel.normalized()
        return CombinationShotSolution(
            firstObjectGhostCenter: cueAtFirstImpact,
            secondObjectGhostCenter: firstAtSecondImpact,
            cuePath: Segment2D(start: cue.center, end: cueAtFirstImpact),
            firstObjectPath: Segment2D(
                start: firstObject.center,
                end: firstAtSecondImpact
            ),
            secondObjectPath: Segment2D(
                start: secondObject.center,
                end: pocketAimPoint
            ),
            requiredCueAngle: cueDirection.angle,
            firstCutAngle: abs(
                AngleMath.signedDifference(
                    from: cueDirection.angle,
                    to: firstDirection.angle
                )
            ),
            secondCutAngle: abs(
                AngleMath.signedDifference(
                    from: firstDirection.angle,
                    to: secondDirection.angle
                )
            )
        )
    }
}
