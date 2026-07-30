import Foundation

/// A finite two-dimensional vector used for both normalized table coordinates
/// and physical distances. CuePilot keeps geometry independent of CoreGraphics
/// so the solver is deterministic and usable from app extensions.
public struct Vector2D: Sendable, Hashable, Codable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2D(x: 0, y: 0)
    public static let unitX = Vector2D(x: 1, y: 0)
    public static let unitY = Vector2D(x: 0, y: 1)

    public var lengthSquared: Double {
        x * x + y * y
    }

    public var length: Double {
        lengthSquared.squareRoot()
    }

    public var angle: Double {
        atan2(y, x)
    }

    public var perpendicularLeft: Vector2D {
        Vector2D(x: -y, y: x)
    }

    public var perpendicularRight: Vector2D {
        Vector2D(x: y, y: -x)
    }

    /// Returns a unit vector, or `fallback` when the receiver has no stable
    /// direction.
    public func normalized(
        or fallback: Vector2D = .zero,
        tolerance: Double = GeometryTolerance.default
    ) -> Vector2D {
        let magnitude = length
        guard magnitude.isFinite, magnitude > tolerance else {
            return fallback
        }
        return self / magnitude
    }

    public func dot(_ other: Vector2D) -> Double {
        x * other.x + y * other.y
    }

    public func cross(_ other: Vector2D) -> Double {
        x * other.y - y * other.x
    }

    public func distanceSquared(to other: Vector2D) -> Double {
        (self - other).lengthSquared
    }

    public func distance(to other: Vector2D) -> Double {
        distanceSquared(to: other).squareRoot()
    }

    public func rotated(by radians: Double) -> Vector2D {
        let cosine = cos(radians)
        let sine = sin(radians)
        return Vector2D(
            x: x * cosine - y * sine,
            y: x * sine + y * cosine
        )
    }

    public func projected(onto axis: Vector2D) -> Vector2D {
        let unit = axis.normalized()
        return unit * dot(unit)
    }

    public func isApproximatelyEqual(
        to other: Vector2D,
        tolerance: Double = GeometryTolerance.default
    ) -> Bool {
        distanceSquared(to: other) <= tolerance * tolerance
    }

    public static prefix func - (value: Vector2D) -> Vector2D {
        Vector2D(x: -value.x, y: -value.y)
    }

    public static func + (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Vector2D, rhs: Vector2D) -> Vector2D {
        Vector2D(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static func * (lhs: Vector2D, rhs: Double) -> Vector2D {
        Vector2D(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    public static func * (lhs: Double, rhs: Vector2D) -> Vector2D {
        rhs * lhs
    }

    public static func / (lhs: Vector2D, rhs: Double) -> Vector2D {
        Vector2D(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

/// Points and vectors intentionally share storage and arithmetic. This keeps
/// the shot engine compact while preserving a semantic point name at API sites.
public typealias Point2D = Vector2D

public enum GeometryTolerance {
    public static let `default` = 1e-9
}

public enum AngleMath {
    /// Normalizes an angle into the half-open interval `[-π, π)`.
    public static func normalized(_ radians: Double) -> Double {
        guard radians.isFinite else { return radians }
        var value = radians.truncatingRemainder(dividingBy: 2 * .pi)
        if value >= .pi {
            value -= 2 * .pi
        } else if value < -.pi {
            value += 2 * .pi
        }
        return value
    }

    /// The shortest signed rotation from `current` to `target`.
    public static func signedDifference(from current: Double, to target: Double) -> Double {
        normalized(target - current)
    }

    public static func degrees(_ radians: Double) -> Double {
        radians * 180 / .pi
    }

    public static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }
}
