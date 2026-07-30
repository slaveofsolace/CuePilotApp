import Foundation

public enum BallKind: String, Sendable, Hashable, Codable, CaseIterable {
    case cue
    case eight
    case solid
    case stripe
    case unknown
}

/// A normalized board ball. Standard numbered-ball IDs are recommended:
/// cue `0`, solids `1...7`, eight `8`, and stripes `9...15`.
public struct BallState: Sendable, Hashable, Codable, Identifiable {
    public var id: Int
    public var kind: BallKind
    public var center: Point2D
    public var radius: Double
    public var confidence: Double
    public var isPocketed: Bool

    public init(
        id: Int,
        kind: BallKind,
        center: Point2D,
        radius: Double,
        confidence: Double = 1,
        isPocketed: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.center = center
        self.radius = max(0, radius)
        self.confidence = min(1, max(0, confidence))
        self.isPocketed = isPocketed
    }

    public var isObjectBall: Bool {
        kind != .cue && kind != .unknown
    }
}

public enum PocketID: String, Sendable, Hashable, Codable, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case bottomLeft
    case bottomCenter
    case bottomRight
}

public struct PocketGeometry: Sendable, Hashable, Codable, Identifiable {
    public var id: PocketID
    public var center: Point2D
    public var aimPoint: Point2D
    public var mouth: Segment2D
    public var captureRadius: Double
    public var jawRadius: Double

    public init(
        id: PocketID,
        center: Point2D,
        aimPoint: Point2D? = nil,
        mouth: Segment2D,
        captureRadius: Double,
        jawRadius: Double
    ) {
        self.id = id
        self.center = center
        self.aimPoint = aimPoint ?? center
        self.mouth = mouth
        self.captureRadius = max(0, captureRadius)
        self.jawRadius = max(0, jawRadius)
    }

    public var jaws: [Circle2D] {
        [
            Circle2D(center: mouth.start, radius: jawRadius),
            Circle2D(center: mouth.end, radius: jawRadius),
        ]
    }

    /// Width available to the center of a ball after accounting for both jaws.
    public func effectiveOpeningWidth(ballRadius: Double, margin: Double = 0) -> Double {
        max(0, mouth.length - 2 * (ballRadius + jawRadius + margin))
    }

    /// Checks that the center path crosses the pocket mouth between its jaws
    /// and continues toward the capture region.
    public func accepts(
        centerPath: Segment2D,
        ballRadius: Double,
        margin: Double = 0
    ) -> Bool {
        guard centerPath.vector.dot(aimPoint - centerPath.start) > 0,
              let crossing = centerPath.intersection(with: mouth),
              mouth.length > GeometryTolerance.default else {
            return false
        }

        let requiredJawDistance = ballRadius + jawRadius + margin
        guard crossing.distance(to: mouth.start) + GeometryTolerance.default >= requiredJawDistance,
              crossing.distance(to: mouth.end) + GeometryTolerance.default >= requiredJawDistance else {
            return false
        }

        let captureDistance = centerPath.distance(to: aimPoint)
        return captureDistance <= max(captureRadius, ballRadius) + margin ||
            centerPath.end.distance(to: aimPoint) <= max(captureRadius, ballRadius) + margin
    }

    public func jawClearance(
        for centerPath: Segment2D,
        ballRadius: Double
    ) -> Double {
        jaws.map {
            centerPath.distance(to: $0.center) - ballRadius - $0.radius
        }.min() ?? .infinity
    }
}

public enum RailID: String, Sendable, Hashable, Codable, CaseIterable {
    case topLeft
    case topRight
    case right
    case bottomRight
    case bottomLeft
    case left
}

public struct CushionSegment: Sendable, Hashable, Codable, Identifiable {
    public var id: RailID
    public var segment: Segment2D

    public init(id: RailID, segment: Segment2D) {
        self.id = id
        self.segment = segment
    }
}

public struct TableGeometry: Sendable, Hashable, Codable {
    public var playableBounds: Rect2D
    public var cushions: [CushionSegment]
    public var pockets: [PocketGeometry]
    public var defaultBallRadius: Double

    public init(
        playableBounds: Rect2D,
        cushions: [CushionSegment],
        pockets: [PocketGeometry],
        defaultBallRadius: Double
    ) {
        self.playableBounds = playableBounds
        self.cushions = cushions
        self.pockets = pockets
        self.defaultBallRadius = max(0, defaultBallRadius)
    }

    public func pocket(id: PocketID) -> PocketGeometry? {
        pockets.first { $0.id == id }
    }

    public func cushion(id: RailID) -> CushionSegment? {
        cushions.first { $0.id == id }
    }

    public func containsBall(center: Point2D, radius: Double) -> Bool {
        playableBounds.contains(center, inset: radius)
    }

    public func intersectsCushion(_ path: Segment2D) -> CushionSegment? {
        cushions.first { $0.segment.intersects(path) }
    }

    /// A canonical 2:1 pool table in normalized coordinates.
    public static func standard(
        width: Double = 2,
        height: Double = 1,
        ballRadius: Double = 0.028,
        cornerMouthWidth: Double = 0.13,
        sideMouthWidth: Double = 0.14
    ) -> TableGeometry {
        let bounds = Rect2D(x: 0, y: 0, width: width, height: height)
        let cornerGap = cornerMouthWidth / sqrt(2)
        let sideHalf = sideMouthWidth / 2
        let middleX = width / 2
        let centerOffset = ballRadius * 1.5
        let jawRadius = ballRadius * 0.20
        let captureRadius = ballRadius * 1.65

        let pockets = [
            PocketGeometry(
                id: .topLeft,
                center: Point2D(x: -centerOffset, y: -centerOffset),
                mouth: Segment2D(
                    start: Point2D(x: cornerGap, y: 0),
                    end: Point2D(x: 0, y: cornerGap)
                ),
                captureRadius: captureRadius,
                jawRadius: jawRadius
            ),
            PocketGeometry(
                id: .topCenter,
                center: Point2D(x: middleX, y: -centerOffset),
                mouth: Segment2D(
                    start: Point2D(x: middleX - sideHalf, y: 0),
                    end: Point2D(x: middleX + sideHalf, y: 0)
                ),
                captureRadius: captureRadius,
                jawRadius: jawRadius
            ),
            PocketGeometry(
                id: .topRight,
                center: Point2D(x: width + centerOffset, y: -centerOffset),
                mouth: Segment2D(
                    start: Point2D(x: width, y: cornerGap),
                    end: Point2D(x: width - cornerGap, y: 0)
                ),
                captureRadius: captureRadius,
                jawRadius: jawRadius
            ),
            PocketGeometry(
                id: .bottomLeft,
                center: Point2D(x: -centerOffset, y: height + centerOffset),
                mouth: Segment2D(
                    start: Point2D(x: 0, y: height - cornerGap),
                    end: Point2D(x: cornerGap, y: height)
                ),
                captureRadius: captureRadius,
                jawRadius: jawRadius
            ),
            PocketGeometry(
                id: .bottomCenter,
                center: Point2D(x: middleX, y: height + centerOffset),
                mouth: Segment2D(
                    start: Point2D(x: middleX + sideHalf, y: height),
                    end: Point2D(x: middleX - sideHalf, y: height)
                ),
                captureRadius: captureRadius,
                jawRadius: jawRadius
            ),
            PocketGeometry(
                id: .bottomRight,
                center: Point2D(x: width + centerOffset, y: height + centerOffset),
                mouth: Segment2D(
                    start: Point2D(x: width - cornerGap, y: height),
                    end: Point2D(x: width, y: height - cornerGap)
                ),
                captureRadius: captureRadius,
                jawRadius: jawRadius
            ),
        ]

        let cushions = [
            CushionSegment(
                id: .topLeft,
                segment: Segment2D(
                    start: Point2D(x: cornerGap, y: 0),
                    end: Point2D(x: middleX - sideHalf, y: 0)
                )
            ),
            CushionSegment(
                id: .topRight,
                segment: Segment2D(
                    start: Point2D(x: middleX + sideHalf, y: 0),
                    end: Point2D(x: width - cornerGap, y: 0)
                )
            ),
            CushionSegment(
                id: .right,
                segment: Segment2D(
                    start: Point2D(x: width, y: cornerGap),
                    end: Point2D(x: width, y: height - cornerGap)
                )
            ),
            CushionSegment(
                id: .bottomRight,
                segment: Segment2D(
                    start: Point2D(x: width - cornerGap, y: height),
                    end: Point2D(x: middleX + sideHalf, y: height)
                )
            ),
            CushionSegment(
                id: .bottomLeft,
                segment: Segment2D(
                    start: Point2D(x: middleX - sideHalf, y: height),
                    end: Point2D(x: cornerGap, y: height)
                )
            ),
            CushionSegment(
                id: .left,
                segment: Segment2D(
                    start: Point2D(x: 0, y: height - cornerGap),
                    end: Point2D(x: 0, y: cornerGap)
                )
            ),
        ]

        return TableGeometry(
            playableBounds: bounds,
            cushions: cushions,
            pockets: pockets,
            defaultBallRadius: ballRadius
        )
    }
}
