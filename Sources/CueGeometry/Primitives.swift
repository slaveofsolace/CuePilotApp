import Foundation

public struct Size2D: Sendable, Hashable, Codable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct Rect2D: Sendable, Hashable, Codable {
    public var origin: Point2D
    public var size: Size2D

    public init(origin: Point2D, size: Size2D) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: Point2D(x: x, y: y),
            size: Size2D(width: width, height: height)
        )
    }

    public var minX: Double { min(origin.x, origin.x + size.width) }
    public var maxX: Double { max(origin.x, origin.x + size.width) }
    public var minY: Double { min(origin.y, origin.y + size.height) }
    public var maxY: Double { max(origin.y, origin.y + size.height) }
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var center: Point2D {
        Point2D(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
    }
    public var diagonal: Double {
        hypot(width, height)
    }

    public func contains(_ point: Point2D, inset: Double = 0) -> Bool {
        point.x >= minX + inset &&
            point.x <= maxX - inset &&
            point.y >= minY + inset &&
            point.y <= maxY - inset
    }

    public func clamped(_ point: Point2D, inset: Double = 0) -> Point2D {
        Point2D(
            x: min(max(point.x, minX + inset), maxX - inset),
            y: min(max(point.y, minY + inset), maxY - inset)
        )
    }
}

public struct Segment2D: Sendable, Hashable, Codable {
    public var start: Point2D
    public var end: Point2D

    public init(start: Point2D, end: Point2D) {
        self.start = start
        self.end = end
    }

    public var vector: Vector2D { end - start }
    public var lengthSquared: Double { vector.lengthSquared }
    public var length: Double { vector.length }
    public var midpoint: Point2D { (start + end) / 2 }
    public var unitDirection: Vector2D { vector.normalized() }

    public func point(at parameter: Double) -> Point2D {
        start + vector * parameter
    }

    public func closestParameter(to point: Point2D) -> Double {
        guard lengthSquared > GeometryTolerance.default else { return 0 }
        return min(1, max(0, (point - start).dot(vector) / lengthSquared))
    }

    public func closestPoint(to point: Point2D) -> Point2D {
        self.point(at: closestParameter(to: point))
    }

    public func distance(to point: Point2D) -> Double {
        closestPoint(to: point).distance(to: point)
    }

    public func contains(
        _ point: Point2D,
        tolerance: Double = GeometryTolerance.default
    ) -> Bool {
        distance(to: point) <= tolerance &&
            point.x >= min(start.x, end.x) - tolerance &&
            point.x <= max(start.x, end.x) + tolerance &&
            point.y >= min(start.y, end.y) - tolerance &&
            point.y <= max(start.y, end.y) + tolerance
    }

    /// Returns one intersection point. For overlapping collinear segments this
    /// is the first shared endpoint in receiver order.
    public func intersection(
        with other: Segment2D,
        tolerance: Double = GeometryTolerance.default
    ) -> Point2D? {
        let r = vector
        let s = other.vector
        let denominator = r.cross(s)
        let offset = other.start - start

        if abs(denominator) <= tolerance {
            guard abs(offset.cross(r)) <= tolerance else { return nil }
            let candidates = [start, end, other.start, other.end]
            return candidates.first {
                contains($0, tolerance: tolerance) &&
                    other.contains($0, tolerance: tolerance)
            }
        }

        let t = offset.cross(s) / denominator
        let u = offset.cross(r) / denominator
        guard t >= -tolerance, t <= 1 + tolerance,
              u >= -tolerance, u <= 1 + tolerance else {
            return nil
        }
        return point(at: min(1, max(0, t)))
    }

    public func intersects(
        _ other: Segment2D,
        tolerance: Double = GeometryTolerance.default
    ) -> Bool {
        intersection(with: other, tolerance: tolerance) != nil
    }
}

public struct Circle2D: Sendable, Hashable, Codable {
    public var center: Point2D
    public var radius: Double

    public init(center: Point2D, radius: Double) {
        self.center = center
        self.radius = max(0, radius)
    }

    public func contains(_ point: Point2D, tolerance: Double = 0) -> Bool {
        center.distanceSquared(to: point) <=
            (radius + tolerance) * (radius + tolerance)
    }

    public func intersects(
        _ segment: Segment2D,
        extraRadius: Double = 0,
        tolerance: Double = GeometryTolerance.default
    ) -> Bool {
        segment.distance(to: center) <= radius + extraRadius + tolerance
    }
}

public struct PathClearance: Sendable, Hashable, Codable {
    public var isClear: Bool
    public var minimumClearance: Double
    public var blockingBallID: Int?

    public init(isClear: Bool, minimumClearance: Double, blockingBallID: Int?) {
        self.isClear = isClear
        self.minimumClearance = minimumClearance
        self.blockingBallID = blockingBallID
    }

    /// Measures center-line clearance for a moving circular ball.
    public static func evaluate(
        path: Segment2D,
        movingRadius: Double,
        obstacles: [BallState],
        excluding excludedIDs: Set<Int> = [],
        margin: Double = 0
    ) -> PathClearance {
        var minimum = Double.infinity
        var blocker: Int?

        for obstacle in obstacles where
            !obstacle.isPocketed && !excludedIDs.contains(obstacle.id) {
            let clearance = path.distance(to: obstacle.center) -
                movingRadius - obstacle.radius - margin
            if clearance < minimum {
                minimum = clearance
            }
            if clearance < -GeometryTolerance.default, blocker == nil {
                blocker = obstacle.id
            }
        }

        return PathClearance(
            isClear: blocker == nil,
            minimumClearance: minimum,
            blockingBallID: blocker
        )
    }
}
