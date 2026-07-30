import CueGeometry
import Foundation

public struct BankShotSolution: Sendable, Hashable, Codable {
    public var railID: RailID
    public var contactPoint: Point2D
    public var inboundPath: Segment2D
    public var outboundPath: Segment2D
    public var reflectedDirection: Vector2D
    public var angularError: Double
    public var incidenceAngle: Double

    public init(
        railID: RailID,
        contactPoint: Point2D,
        inboundPath: Segment2D,
        outboundPath: Segment2D,
        reflectedDirection: Vector2D,
        angularError: Double,
        incidenceAngle: Double
    ) {
        self.railID = railID
        self.contactPoint = contactPoint
        self.inboundPath = inboundPath
        self.outboundPath = outboundPath
        self.reflectedDirection = reflectedDirection
        self.angularError = angularError
        self.incidenceAngle = incidenceAngle
    }
}

public enum BankShotGeometry {
    public static func mirrored(
        _ point: Point2D,
        across line: Segment2D
    ) -> Point2D? {
        let direction = line.unitDirection
        guard direction.length > GeometryTolerance.default else { return nil }
        let projection = line.start + (point - line.start).projected(onto: direction)
        return projection * 2 - point
    }

    /// Finds a one-rail contact point. The search evaluates the actual
    /// restitution reflection instead of assuming a perfectly elastic rail.
    public static func solve(
        objectBall: BallState,
        pocket: PocketGeometry,
        cushion: CushionSegment,
        tableCenter: Point2D,
        restitution: Double = PhysicsParameters.default.cushionRestitution
    ) throws -> BankShotSolution {
        let rail = cushion.segment
        let tangent = rail.unitDirection
        guard tangent.length > GeometryTolerance.default else {
            throw ShotGeometryError.unreachableBank
        }

        var inwardNormal = tangent.perpendicularLeft
        if (tableCenter - rail.midpoint).dot(inwardNormal) < 0 {
            inwardNormal = -inwardNormal
        }
        let centerRail = Segment2D(
            start: rail.start + inwardNormal * objectBall.radius,
            end: rail.end + inwardNormal * objectBall.radius
        )

        let endpointInset = min(
            0.45,
            max(
                0.01,
                (objectBall.radius + pocket.jawRadius) /
                    max(centerRail.length, GeometryTolerance.default)
            )
        )
        guard endpointInset < 0.5 else {
            throw ShotGeometryError.unreachableBank
        }

        func error(at parameter: Double) -> (
            error: Double,
            point: Point2D,
            reflected: Vector2D
        ) {
            let contact = centerRail.point(at: parameter)
            let incident = (contact - objectBall.center).normalized()
            let reflected = CushionCollision.reflectedVelocity(
                incidentVelocity: incident,
                railDirection: tangent,
                restitution: restitution
            ).normalized()
            let desired = (pocket.aimPoint - contact).normalized()
            return (
                abs(
                    AngleMath.signedDifference(
                        from: reflected.angle,
                        to: desired.angle
                    )
                ),
                contact,
                reflected
            )
        }

        var bestParameter = endpointInset
        var best = error(at: bestParameter)
        let sampleCount = 96
        for index in 1...sampleCount {
            let fraction = Double(index) / Double(sampleCount)
            let parameter = endpointInset +
                (1 - 2 * endpointInset) * fraction
            let candidate = error(at: parameter)
            if candidate.error < best.error {
                bestParameter = parameter
                best = candidate
            }
        }

        var lower = max(endpointInset, bestParameter - 1 / Double(sampleCount))
        var upper = min(1 - endpointInset, bestParameter + 1 / Double(sampleCount))
        for _ in 0..<28 {
            let oneThird = lower + (upper - lower) / 3
            let twoThird = upper - (upper - lower) / 3
            if error(at: oneThird).error < error(at: twoThird).error {
                upper = twoThird
            } else {
                lower = oneThird
            }
        }
        bestParameter = (lower + upper) / 2
        best = error(at: bestParameter)

        let inbound = Segment2D(start: objectBall.center, end: best.point)
        let outbound = Segment2D(start: best.point, end: pocket.aimPoint)
        guard inbound.length > objectBall.radius,
              outbound.length > objectBall.radius else {
            throw ShotGeometryError.unreachableBank
        }

        let normal = tangent.perpendicularLeft
        let incidence = asin(
            min(1, abs(inbound.unitDirection.dot(normal)))
        )

        return BankShotSolution(
            railID: cushion.id,
            contactPoint: best.point,
            inboundPath: inbound,
            outboundPath: outbound,
            reflectedDirection: best.reflected,
            angularError: best.error,
            incidenceAngle: incidence
        )
    }
}
