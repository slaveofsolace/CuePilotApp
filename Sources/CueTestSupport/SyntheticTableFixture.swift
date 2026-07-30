import CueGeometry
import CueVision
import Foundation

public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    public mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }
}

public struct SyntheticBall: Codable, Equatable, Sendable {
    public var id: Int
    public var kind: BallKind
    /// Canonical table coordinates, where the table is 2 by 1.
    public var center: Point2D

    public init(id: Int, kind: BallKind, center: Point2D) {
        self.id = id
        self.kind = kind
        self.center = center
    }
}

public struct SyntheticFixtureOptions: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int
    public var brightness: Double
    public var perspective: Double
    public var shadowStrength: Double
    public var compressionLevels: Int
    public var includeCue: Bool
    public var cueAngleRadians: Double
    public var includePowerTrack: Bool
    public var normalizedPower: Double
    public var highlightPocket: PocketID?
    public var partialObstruction: Bool

    public init(
        width: Int = 384,
        height: Int = 240,
        brightness: Double = 1,
        perspective: Double = 0.04,
        shadowStrength: Double = 0.20,
        compressionLevels: Int = 256,
        includeCue: Bool = true,
        cueAngleRadians: Double = 0,
        includePowerTrack: Bool = true,
        normalizedPower: Double = 0.62,
        highlightPocket: PocketID? = nil,
        partialObstruction: Bool = false
    ) {
        self.width = width
        self.height = height
        self.brightness = brightness
        self.perspective = perspective
        self.shadowStrength = shadowStrength
        self.compressionLevels = compressionLevels
        self.includeCue = includeCue
        self.cueAngleRadians = cueAngleRadians
        self.includePowerTrack = includePowerTrack
        self.normalizedPower = normalizedPower
        self.highlightPocket = highlightPocket
        self.partialObstruction = partialObstruction
    }
}

public struct SyntheticFixtureTruth: Codable, Equatable, Sendable {
    public var tableCorners: [Point2D]
    public var pockets: [PocketID: Point2D]
    public var balls: [SyntheticBall]
    public var pixelBallCenters: [Int: Point2D]
    public var pixelBallRadius: Double
    public var cueAngleRadians: Double?
    public var normalizedPower: Double?

    public init(
        tableCorners: [Point2D],
        pockets: [PocketID: Point2D],
        balls: [SyntheticBall],
        pixelBallCenters: [Int: Point2D],
        pixelBallRadius: Double,
        cueAngleRadians: Double?,
        normalizedPower: Double?
    ) {
        self.tableCorners = tableCorners
        self.pockets = pockets
        self.balls = balls
        self.pixelBallCenters = pixelBallCenters
        self.pixelBallRadius = pixelBallRadius
        self.cueAngleRadians = cueAngleRadians
        self.normalizedPower = normalizedPower
    }
}

public struct RenderedSyntheticFixture: Sendable {
    public var image: RGBAImage
    public var truth: SyntheticFixtureTruth

    public init(image: RGBAImage, truth: SyntheticFixtureTruth) {
        self.image = image
        self.truth = truth
    }
}

/// Renders an original, generic billiards table. Its flat colors and geometry
/// are intentionally independent of any third-party game artwork.
public struct SyntheticTableFixtureRenderer: Sendable {
    public init() {}

    public func render(
        balls: [SyntheticBall] = Self.standardBalls,
        options: SyntheticFixtureOptions = SyntheticFixtureOptions(),
        seed: UInt64 = 1
    ) throws -> RenderedSyntheticFixture {
        var generator = SeededGenerator(seed: seed)
        var canvas = try RGBAImage(
            width: options.width,
            height: options.height,
            fill: RGBAPixel(red: 21, green: 24, blue: 29)
        )
        let marginX = Double(options.width) * 0.095
        let top = Double(options.height) * 0.12
        let bottom = Double(options.height) * (options.includePowerTrack ? 0.78 : 0.87)
        let skew = Double(options.width) * options.perspective
        let railCorners = [
            Point2D(x: marginX + skew, y: top),
            Point2D(x: Double(options.width) - marginX - skew * 0.35, y: top + skew * 0.12),
            Point2D(x: Double(options.width) - marginX + skew * 0.45, y: bottom),
            Point2D(x: marginX - skew * 0.30, y: bottom - skew * 0.10),
        ]
        fillPolygon(
            railCorners,
            color: RGBAPixel(red: 94, green: 55, blue: 35),
            in: &canvas
        )
        let center = railCorners.reduce(.zero, +) / 4
        let railInset = max(7, Double(options.width) * 0.025)
        let feltCorners = railCorners.map { corner in
            let direction = (center - corner).normalized()
            return corner + direction * railInset
        }
        let feltBase = adjusted(
            RGBAPixel(red: 30, green: 126, blue: 82),
            brightness: options.brightness
        )
        fillPolygon(feltCorners, color: feltBase, in: &canvas)

        if options.shadowStrength > 0 {
            let shadowTop = interpolate(feltCorners[0], feltCorners[3], t: 0.45)
            let shadowBottom = interpolate(feltCorners[1], feltCorners[2], t: 0.65)
            drawLine(
                from: shadowTop,
                to: shadowBottom,
                thickness: max(8, Int(Double(options.height) * 0.06)),
                color: adjusted(
                    feltBase,
                    brightness: 1 - options.shadowStrength * 0.35
                ),
                in: &canvas
            )
        }

        let pocketLocations: [(PocketID, Point2D)] = [
            (.topLeft, feltCorners[0]),
            (.topCenter, (feltCorners[0] + feltCorners[1]) / 2),
            (.topRight, feltCorners[1]),
            (.bottomLeft, feltCorners[3]),
            (.bottomCenter, (feltCorners[3] + feltCorners[2]) / 2),
            (.bottomRight, feltCorners[2]),
        ]
        let tableWidth = (
            feltCorners[0].distance(to: feltCorners[1]) +
            feltCorners[3].distance(to: feltCorners[2])
        ) / 2
        let ballRadius = max(4.5, tableWidth / 45)
        let pocketRadius = ballRadius * 1.55
        for (id, point) in pocketLocations {
            if id == options.highlightPocket {
                drawCircle(
                    center: point,
                    radius: pocketRadius + 3,
                    color: RGBAPixel(red: 236, green: 184, blue: 65),
                    in: &canvas
                )
            }
            drawCircle(
                center: point,
                radius: pocketRadius,
                color: RGBAPixel(red: 11, green: 12, blue: 14),
                in: &canvas
            )
        }

        var pixelCenters: [Int: Point2D] = [:]
        for ball in balls {
            let pixelCenter = mapCanonical(ball.center, into: feltCorners)
            pixelCenters[ball.id] = pixelCenter
            if options.shadowStrength > 0 {
                drawCircle(
                    center: pixelCenter + Point2D(x: 2.2, y: 2.7),
                    radius: ballRadius * 1.08,
                    color: adjusted(feltBase, brightness: 0.50),
                    in: &canvas
                )
            }
            renderBall(
                ball,
                center: pixelCenter,
                radius: ballRadius,
                rotation: generator.value(in: -1 ... 1),
                in: &canvas
            )
        }

        if options.includeCue,
           let cue = balls.first(where: { $0.kind == .cue }),
           let cueCenter = pixelCenters[cue.id] {
            let direction = Vector2D(
                x: cos(options.cueAngleRadians),
                y: sin(options.cueAngleRadians)
            )
            let near = cueCenter - direction * (ballRadius * 1.35)
            let far = near - direction * (tableWidth * 0.27)
            drawLine(
                from: far,
                to: near,
                thickness: max(2, Int(ballRadius * 0.55)),
                color: RGBAPixel(red: 225, green: 172, blue: 95),
                in: &canvas
            )
            drawCircle(
                center: far,
                radius: ballRadius * 0.42,
                color: RGBAPixel(red: 93, green: 56, blue: 35),
                in: &canvas
            )
        }

        if options.partialObstruction,
           let ball = balls.last,
           let obstructedCenter = pixelCenters[ball.id] {
            let obstruction = [
                Point2D(x: obstructedCenter.x, y: obstructedCenter.y - ballRadius),
                Point2D(x: obstructedCenter.x + ballRadius * 1.5, y: obstructedCenter.y - ballRadius),
                Point2D(x: obstructedCenter.x + ballRadius * 1.5, y: obstructedCenter.y + ballRadius),
                Point2D(x: obstructedCenter.x, y: obstructedCenter.y + ballRadius),
            ]
            fillPolygon(
                obstruction,
                color: RGBAPixel(red: 74, green: 78, blue: 84),
                in: &canvas
            )
        }

        if options.includePowerTrack {
            let trackY = Double(options.height) * 0.91
            let trackStart = Point2D(x: Double(options.width) * 0.25, y: trackY)
            let trackEnd = Point2D(x: Double(options.width) * 0.82, y: trackY)
            drawLine(
                from: trackStart,
                to: trackEnd,
                thickness: 4,
                color: RGBAPixel(red: 132, green: 137, blue: 144),
                in: &canvas
            )
            let handle = interpolate(
                trackStart,
                trackEnd,
                t: options.normalizedPower.clamped(to: 0 ... 1)
            )
            drawCircle(
                center: handle,
                radius: 6,
                color: RGBAPixel(red: 40, green: 156, blue: 221),
                in: &canvas
            )
        }

        if options.compressionLevels < 256 {
            quantize(&canvas, levels: max(2, options.compressionLevels))
        }

        return RenderedSyntheticFixture(
            image: canvas,
            truth: SyntheticFixtureTruth(
                tableCorners: feltCorners,
                pockets: Dictionary(uniqueKeysWithValues: pocketLocations),
                balls: balls,
                pixelBallCenters: pixelCenters,
                pixelBallRadius: ballRadius,
                cueAngleRadians: options.includeCue ? options.cueAngleRadians : nil,
                normalizedPower: options.includePowerTrack ?
                    options.normalizedPower.clamped(to: 0 ... 1) : nil
            )
        )
    }

    public func randomizedFixture(
        seed: UInt64,
        ballCount: Int = 9,
        options: SyntheticFixtureOptions = SyntheticFixtureOptions()
    ) throws -> RenderedSyntheticFixture {
        var generator = SeededGenerator(seed: seed)
        var balls = [
            SyntheticBall(id: 0, kind: .cue, center: Point2D(x: 0.42, y: 0.5)),
            SyntheticBall(id: 8, kind: .eight, center: Point2D(x: 1.15, y: 0.5)),
        ]
        let desired = max(2, min(16, ballCount))
        var identifier = 1
        while balls.count < desired {
            if identifier == 8 { identifier += 1 }
            let candidate = Point2D(
                x: generator.value(in: 0.18 ... 1.82),
                y: generator.value(in: 0.12 ... 0.88)
            )
            guard balls.allSatisfy({ $0.center.distance(to: candidate) > 0.10 }) else {
                continue
            }
            balls.append(SyntheticBall(
                id: identifier,
                kind: identifier < 8 ? .solid : .stripe,
                center: candidate
            ))
            identifier += 1
        }
        return try render(balls: balls, options: options, seed: seed)
    }

    public static let standardBalls: [SyntheticBall] = [
        SyntheticBall(id: 0, kind: .cue, center: Point2D(x: 0.43, y: 0.57)),
        SyntheticBall(id: 1, kind: .solid, center: Point2D(x: 0.91, y: 0.29)),
        SyntheticBall(id: 4, kind: .solid, center: Point2D(x: 1.23, y: 0.71)),
        SyntheticBall(id: 8, kind: .eight, center: Point2D(x: 1.36, y: 0.43)),
        SyntheticBall(id: 10, kind: .stripe, center: Point2D(x: 1.61, y: 0.73)),
        SyntheticBall(id: 13, kind: .stripe, center: Point2D(x: 1.71, y: 0.27)),
    ]

    private func renderBall(
        _ ball: SyntheticBall,
        center: Point2D,
        radius: Double,
        rotation: Double,
        in image: inout RGBAImage
    ) {
        let color: RGBAPixel
        switch ball.kind {
        case .cue:
            color = RGBAPixel(red: 244, green: 243, blue: 231)
        case .eight:
            color = RGBAPixel(red: 23, green: 25, blue: 28)
        case .solid:
            color = solidColor(for: ball.id)
        case .stripe:
            color = stripeColor(for: ball.id)
        case .unknown:
            color = RGBAPixel(red: 151, green: 83, blue: 176)
        }

        if ball.kind == .stripe {
            drawCircle(
                center: center,
                radius: radius,
                color: RGBAPixel(red: 239, green: 238, blue: 226),
                in: &image
            )
            let bandHalfHeight = radius * (0.33 + abs(rotation) * 0.05)
            let xRange = Int((center.x - radius).rounded(.down))
                ... Int((center.x + radius).rounded(.up))
            let yRange = Int((center.y - bandHalfHeight).rounded(.down))
                ... Int((center.y + bandHalfHeight).rounded(.up))
            for y in yRange {
                for x in xRange {
                    let point = Point2D(x: Double(x), y: Double(y))
                    if point.distance(to: center) <= radius {
                        image.setPixel(color, x: x, y: y)
                    }
                }
            }
        } else {
            drawCircle(center: center, radius: radius, color: color, in: &image)
        }

        drawCircle(
            center: center + Point2D(x: -radius * 0.30, y: -radius * 0.30),
            radius: max(1, radius * 0.16),
            color: RGBAPixel(red: 255, green: 255, blue: 249),
            in: &image
        )
    }

    private func solidColor(for id: Int) -> RGBAPixel {
        let colors = [
            RGBAPixel(red: 226, green: 176, blue: 42),
            RGBAPixel(red: 47, green: 103, blue: 193),
            RGBAPixel(red: 187, green: 51, blue: 46),
            RGBAPixel(red: 113, green: 67, blue: 156),
            RGBAPixel(red: 220, green: 105, blue: 32),
            RGBAPixel(red: 41, green: 139, blue: 74),
            RGBAPixel(red: 133, green: 47, blue: 42),
        ]
        return colors[max(0, id - 1) % colors.count]
    }

    private func stripeColor(for id: Int) -> RGBAPixel {
        solidColor(for: max(1, id - 8))
    }

    private func mapCanonical(_ point: Point2D, into corners: [Point2D]) -> Point2D {
        let horizontal = (point.x / 2).clamped(to: 0 ... 1)
        let vertical = point.y.clamped(to: 0 ... 1)
        let top = interpolate(corners[0], corners[1], t: horizontal)
        let bottom = interpolate(corners[3], corners[2], t: horizontal)
        return interpolate(top, bottom, t: vertical)
    }

    private func interpolate(_ lhs: Point2D, _ rhs: Point2D, t: Double) -> Point2D {
        lhs + (rhs - lhs) * t
    }

    private func fillPolygon(
        _ points: [Point2D],
        color: RGBAPixel,
        in image: inout RGBAImage
    ) {
        guard points.count >= 3 else { return }
        let minX = max(0, Int(points.map(\.x).min()!.rounded(.down)))
        let maxX = min(image.width - 1, Int(points.map(\.x).max()!.rounded(.up)))
        let minY = max(0, Int(points.map(\.y).min()!.rounded(.down)))
        let maxY = min(image.height - 1, Int(points.map(\.y).max()!.rounded(.up)))
        for y in minY...maxY {
            for x in minX...maxX where pointInPolygon(
                Point2D(x: Double(x) + 0.5, y: Double(y) + 0.5),
                polygon: points
            ) {
                image.setPixel(color, x: x, y: y)
            }
        }
    }

    private func pointInPolygon(_ point: Point2D, polygon: [Point2D]) -> Bool {
        var inside = false
        var previous = polygon.count - 1
        for current in polygon.indices {
            let a = polygon[current]
            let b = polygon[previous]
            if (a.y > point.y) != (b.y > point.y) {
                let crossingX = (b.x - a.x) * (point.y - a.y) /
                    (b.y - a.y) + a.x
                if point.x < crossingX { inside.toggle() }
            }
            previous = current
        }
        return inside
    }

    private func drawCircle(
        center: Point2D,
        radius: Double,
        color: RGBAPixel,
        in image: inout RGBAImage
    ) {
        let minX = max(0, Int((center.x - radius).rounded(.down)))
        let maxX = min(image.width - 1, Int((center.x + radius).rounded(.up)))
        let minY = max(0, Int((center.y - radius).rounded(.down)))
        let maxY = min(image.height - 1, Int((center.y + radius).rounded(.up)))
        let radiusSquared = radius * radius
        for y in minY...maxY {
            for x in minX...maxX {
                let dx = Double(x) - center.x
                let dy = Double(y) - center.y
                if dx * dx + dy * dy <= radiusSquared {
                    image.setPixel(color, x: x, y: y)
                }
            }
        }
    }

    private func drawLine(
        from start: Point2D,
        to end: Point2D,
        thickness: Int,
        color: RGBAPixel,
        in image: inout RGBAImage
    ) {
        let segment = Segment2D(start: start, end: end)
        let minX = max(0, Int((min(start.x, end.x) - Double(thickness)).rounded(.down)))
        let maxX = min(
            image.width - 1,
            Int((max(start.x, end.x) + Double(thickness)).rounded(.up))
        )
        let minY = max(0, Int((min(start.y, end.y) - Double(thickness)).rounded(.down)))
        let maxY = min(
            image.height - 1,
            Int((max(start.y, end.y) + Double(thickness)).rounded(.up))
        )
        let radius = Double(thickness) / 2
        for y in minY...maxY {
            for x in minX...maxX where
                segment.distance(to: Point2D(x: Double(x), y: Double(y))) <= radius {
                image.setPixel(color, x: x, y: y)
            }
        }
    }

    private func adjusted(_ pixel: RGBAPixel, brightness: Double) -> RGBAPixel {
        func channel(_ value: UInt8) -> UInt8 {
            UInt8(max(0, min(255, Int((Double(value) * brightness).rounded()))))
        }
        return RGBAPixel(
            red: channel(pixel.red),
            green: channel(pixel.green),
            blue: channel(pixel.blue),
            alpha: pixel.alpha
        )
    }

    private func quantize(_ image: inout RGBAImage, levels: Int) {
        let step = max(1, 256 / levels)
        for y in 0..<image.height {
            for x in 0..<image.width {
                guard let pixel = image.pixel(x: x, y: y) else { continue }
                func channel(_ value: UInt8) -> UInt8 {
                    UInt8(min(255, (Int(value) / step) * step))
                }
                image.setPixel(
                    RGBAPixel(
                        red: channel(pixel.red),
                        green: channel(pixel.green),
                        blue: channel(pixel.blue),
                        alpha: pixel.alpha
                    ),
                    x: x,
                    y: y
                )
            }
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
