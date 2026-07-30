import CueDiagnostics
import CueGeometry
import Foundation

public struct TableDetector: Sendable {
    public init() {}

    public func detect(in image: RGBAImage) -> DetectedTable? {
        var minX = image.width
        var maxX = -1
        var minY = image.height
        var maxY = -1
        var count = 0
        var rowMinimum = Array(repeating: image.width, count: image.height)
        var rowMaximum = Array(repeating: -1, count: image.height)
        var rowCount = Array(repeating: 0, count: image.height)

        for y in 0..<image.height {
            for x in 0..<image.width {
                guard let pixel = image.pixel(x: x, y: y), Self.isFelt(pixel) else {
                    continue
                }
                minX = min(minX, x)
                maxX = max(maxX, x)
                minY = min(minY, y)
                maxY = max(maxY, y)
                rowMinimum[y] = min(rowMinimum[y], x)
                rowMaximum[y] = max(rowMaximum[y], x)
                rowCount[y] += 1
                count += 1
            }
        }

        guard count > image.width * image.height / 20, maxX > minX, maxY > minY else {
            return nil
        }

        let peakRowCount = rowCount.max() ?? 0
        let qualifyingRows = (minY...maxY).filter {
            rowCount[$0] >= max(8, peakRowCount / 3)
        }
        guard let topY = qualifyingRows.first, let bottomY = qualifyingRows.last else {
            return nil
        }

        let sampleRadius = max(1, (bottomY - topY) / 30)
        func edge(at y: Int, minimum: Bool) -> Double {
            let range = max(minY, y - sampleRadius)...min(maxY, y + sampleRadius)
            let values = range.compactMap { row -> Int? in
                guard rowCount[row] >= max(8, peakRowCount / 4) else { return nil }
                return minimum ? rowMinimum[row] : rowMaximum[row]
            }.sorted()
            return Double(values[values.count / 2])
        }

        let topLeft = Point2D(x: edge(at: topY, minimum: true), y: Double(topY))
        let topRight = Point2D(x: edge(at: topY, minimum: false), y: Double(topY))
        let bottomRight = Point2D(x: edge(at: bottomY, minimum: false), y: Double(bottomY))
        let bottomLeft = Point2D(x: edge(at: bottomY, minimum: true), y: Double(bottomY))
        let corners = [topLeft, topRight, bottomRight, bottomLeft]
        guard let transform = try? ProjectiveTransform2D.mapping(
            source: corners,
            destination: [
                Point2D(x: 0, y: 0),
                Point2D(x: 2, y: 0),
                Point2D(x: 2, y: 1),
                Point2D(x: 0, y: 1),
            ]
        ) else {
            return nil
        }

        let boundingArea = Double((maxX - minX + 1) * (maxY - minY + 1))
        let support = Double(count) / boundingArea
        let aspect = Double(maxX - minX) / Double(maxY - minY)
        let aspectScore = max(0, 1 - abs(aspect - 2) / 2)
        let confidence = (support * 0.72 + aspectScore * 0.28).clamped(to: 0 ... 1)
        let pixelWidth = (topRight.distance(to: topLeft) + bottomRight.distance(to: bottomLeft)) / 2
        let canonicalRadius = max(0.018, min(0.040, 6.1 / max(1, pixelWidth) * 2))

        return DetectedTable(
            corners: corners,
            imageToCanonical: transform,
            geometry: .standard(ballRadius: canonicalRadius),
            confidence: confidence,
            uncertainty: VisionUncertainty(positionSigma: 0.5 + (1 - confidence) * 4)
        )
    }

    static func isFelt(_ pixel: RGBAPixel) -> Bool {
        let green = Int(pixel.green)
        return green > 42 &&
            green > Int(pixel.red) * 6 / 5 &&
            green > Int(pixel.blue) * 6 / 5 &&
            Int(pixel.green) - Int(pixel.red) > 18
    }
}

public struct PocketDetector: Sendable {
    public init() {}

    public func detect(in image: RGBAImage, table: DetectedTable) -> [DetectedPocket] {
        guard table.corners.count == 4 else { return [] }
        let tl = table.corners[0]
        let tr = table.corners[1]
        let br = table.corners[2]
        let bl = table.corners[3]
        let expected: [(PocketID, Point2D)] = [
            (.topLeft, tl),
            (.topCenter, (tl + tr) / 2),
            (.topRight, tr),
            (.bottomLeft, bl),
            (.bottomCenter, (bl + br) / 2),
            (.bottomRight, br),
        ]
        let searchRadius = max(7, Int((tr.distance(to: tl) + br.distance(to: bl)) / 50))
        let canonical = TableGeometry.standard(
            ballRadius: table.geometry.defaultBallRadius
        )

        return expected.compactMap { id, expectedPoint in
            let centerX = Int(expectedPoint.x.rounded())
            let centerY = Int(expectedPoint.y.rounded())
            var totalWeight = 0.0
            var weightedX = 0.0
            var weightedY = 0.0
            var darkCount = 0
            var tested = 0

            for y in max(0, centerY - searchRadius)...min(image.height - 1, centerY + searchRadius) {
                for x in max(0, centerX - searchRadius)...min(image.width - 1, centerX + searchRadius) {
                    let dx = x - centerX
                    let dy = y - centerY
                    guard dx * dx + dy * dy <= searchRadius * searchRadius,
                          let pixel = image.pixel(x: x, y: y) else { continue }
                    tested += 1
                    let darkness = max(0, 72 - pixel.luminance) / 72
                    guard darkness > 0 else { continue }
                    totalWeight += darkness
                    weightedX += Double(x) * darkness
                    weightedY += Double(y) * darkness
                    darkCount += 1
                }
            }

            guard totalWeight > 1, let geometry = canonical.pocket(id: id) else {
                return nil
            }
            let center = Point2D(
                x: weightedX / totalWeight,
                y: weightedY / totalWeight
            )
            let coverage = Double(darkCount) / Double(max(1, tested))
            let confidence = min(1, coverage * 5.5)
            return DetectedPocket(
                geometry: geometry,
                pixelCenter: center,
                confidence: confidence,
                uncertainty: VisionUncertainty(
                    positionSigma: max(0.5, (1 - confidence) * Double(searchRadius))
                )
            )
        }
    }
}

public struct BallDetector: Sendable {
    public init() {}

    public func detect(in image: RGBAImage, table: DetectedTable) -> [DetectedBall] {
        guard table.corners.count == 4 else { return [] }
        let minX = Int(table.corners.map(\.x).min()!.rounded(.up))
        let maxX = Int(table.corners.map(\.x).max()!.rounded(.down))
        let minY = Int(table.corners.map(\.y).min()!.rounded(.up))
        let maxY = Int(table.corners.map(\.y).max()!.rounded(.down))
        let tablePixelWidth = (
            table.corners[1].distance(to: table.corners[0]) +
            table.corners[2].distance(to: table.corners[3])
        ) / 2
        let radius = max(4, Int((tablePixelWidth / 45).rounded()))
        let inset = radius + 2
        guard maxX - minX > inset * 2, maxY - minY > inset * 2 else { return [] }
        let pocketCenters = [
            table.corners[0],
            (table.corners[0] + table.corners[1]) / 2,
            table.corners[1],
            table.corners[3],
            (table.corners[3] + table.corners[2]) / 2,
            table.corners[2],
        ]

        let offsets = Self.diskOffsets(radius: radius)
        let ringOffsets = Self.ringOffsets(radius: radius)
        var candidates: [(point: Point2D, score: Double, kind: BallKind, classConfidence: Double)] = []

        for y in stride(from: minY + inset, through: maxY - inset, by: 2) {
            for x in stride(from: minX + inset, through: maxX - inset, by: 2) {
                let point = Point2D(x: Double(x), y: Double(y))
                guard let canonicalPoint = table.imageToCanonical.applying(to: point),
                      table.geometry.playableBounds.contains(
                          canonicalPoint,
                          inset: table.geometry.defaultBallRadius * 0.70
                      ) else {
                    continue
                }
                guard pocketCenters.allSatisfy({
                    $0.distance(to: point) > Double(radius) * 2.65
                }) else {
                    continue
                }
                var foreground = 0
                var white = 0
                var dark = 0
                var chromatic = 0
                var total = 0

                for offset in offsets {
                    guard let pixel = image.pixel(x: x + offset.x, y: y + offset.y) else {
                        continue
                    }
                    total += 1
                    if Self.isBallForeground(pixel) {
                        foreground += 1
                    }
                    if pixel.luminance > 190, pixel.channelRange < 55 {
                        white += 1
                    }
                    if pixel.luminance < 52 {
                        dark += 1
                    }
                    if pixel.channelRange > 55, !TableDetector.isFelt(pixel) {
                        chromatic += 1
                    }
                }

                guard total > 0 else { continue }
                let foregroundRatio = Double(foreground) / Double(total)
                guard foregroundRatio > 0.58 else { continue }
                var feltRing = 0
                var ringTotal = 0
                for offset in ringOffsets {
                    guard let pixel = image.pixel(x: x + offset.x, y: y + offset.y) else {
                        continue
                    }
                    ringTotal += 1
                    if TableDetector.isFelt(pixel) { feltRing += 1 }
                }
                let ringRatio = Double(feltRing) / Double(max(1, ringTotal))
                let score = foregroundRatio * 0.75 + ringRatio * 0.25
                guard score > 0.58 else { continue }

                let whiteRatio = Double(white) / Double(total)
                let darkRatio = Double(dark) / Double(total)
                let chromaticRatio = Double(chromatic) / Double(total)
                let kind: BallKind
                let classConfidence: Double
                if whiteRatio > 0.66, chromaticRatio < 0.16 {
                    kind = .cue
                    classConfidence = min(1, whiteRatio)
                } else if darkRatio > 0.58 {
                    kind = .eight
                    classConfidence = min(1, darkRatio)
                } else if whiteRatio > 0.17, chromaticRatio > 0.10 {
                    kind = .stripe
                    classConfidence = min(1, whiteRatio + chromaticRatio)
                } else if chromaticRatio > 0.28 {
                    kind = .solid
                    classConfidence = min(1, chromaticRatio * 1.4)
                } else {
                    kind = .unknown
                    classConfidence = 0.35
                }
                candidates.append((
                    Point2D(x: Double(x), y: Double(y)),
                    score,
                    kind,
                    classConfidence
                ))
            }
        }

        let suppressionDistance = Double(radius) * 1.55
        var selected: [(point: Point2D, score: Double, kind: BallKind, classConfidence: Double)] = []
        for candidate in candidates.sorted(by: {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.point.y != $1.point.y { return $0.point.y < $1.point.y }
            return $0.point.x < $1.point.x
        }) {
            if selected.allSatisfy({
                $0.point.distance(to: candidate.point) >= suppressionDistance
            }) {
                selected.append(candidate)
            }
        }

        selected.sort {
            if $0.point.y != $1.point.y { return $0.point.y < $1.point.y }
            return $0.point.x < $1.point.x
        }
        var nextSolidID = 1
        var nextStripeID = 9
        var nextUnknownID = 100
        var usedCue = false
        var usedEight = false

        return selected.prefix(16).compactMap { candidate -> DetectedBall? in
            guard let canonical = table.imageToCanonical.applying(to: candidate.point) else {
                return nil
            }
            let identifier: Int
            switch candidate.kind {
            case .cue where !usedCue:
                identifier = 0
                usedCue = true
            case .eight where !usedEight:
                identifier = 8
                usedEight = true
            case .solid:
                identifier = nextSolidID
                nextSolidID += 1
            case .stripe:
                identifier = nextStripeID
                nextStripeID += 1
            default:
                identifier = nextUnknownID
                nextUnknownID += 1
            }
            let confidence = min(table.confidence, candidate.score)
            let ball = BallState(
                id: identifier,
                kind: candidate.kind,
                center: canonical,
                radius: table.geometry.defaultBallRadius,
                confidence: confidence
            )
            return DetectedBall(
                ball: ball,
                pixelCenter: candidate.point,
                pixelRadius: Double(radius),
                classificationConfidence: candidate.classConfidence,
                uncertainty: VisionUncertainty(
                    positionSigma: 0.35 + (1 - confidence) * Double(radius),
                    radiusSigma: 0.5 + (1 - confidence),
                    angularSigmaDegrees: 0
                ),
                isOccluded: candidate.score < 0.72
            )
        }
    }

    private static func isBallForeground(_ pixel: RGBAPixel) -> Bool {
        if TableDetector.isFelt(pixel) { return false }
        if pixel.luminance < 62 { return true }
        if pixel.luminance > 128, pixel.channelRange < 60 { return true }
        return pixel.channelRange > 42
    }

    private static func diskOffsets(radius: Int) -> [(x: Int, y: Int)] {
        let step = max(1, radius / 3)
        return stride(from: -radius, through: radius, by: step).flatMap { y in
            stride(from: -radius, through: radius, by: step).compactMap { x in
                x * x + y * y <= radius * radius ? (x, y) : nil
            }
        }
    }

    private static func ringOffsets(radius: Int) -> [(x: Int, y: Int)] {
        let outer = Double(radius) * 1.45
        return (0..<24).map { index in
            let angle = Double(index) * 2 * .pi / 24
            return (
                Int((cos(angle) * outer).rounded()),
                Int((sin(angle) * outer).rounded())
            )
        }
    }
}

public struct PixelCueLineEstimator: CueLineEstimating {
    public init() {}

    public func estimate(
        in image: RGBAImage,
        table: DetectedTable,
        balls: [DetectedBall]
    ) -> CueLineEstimate? {
        var points: [Point2D] = []
        for y in 0..<image.height {
            for x in 0..<image.width {
                guard let pixel = image.pixel(x: x, y: y),
                      pixel.red > 175,
                      pixel.green > 115,
                      pixel.blue < 175,
                      Int(pixel.red) - Int(pixel.blue) > 45,
                      Int(pixel.green) - Int(pixel.blue) > 25,
                      Int(pixel.green) - Int(pixel.blue) < 108,
                      table.imageToCanonical.applying(
                          to: Point2D(x: Double(x), y: Double(y))
                      ).map({
                          table.geometry.playableBounds.contains($0, inset: 0.015)
                      }) == true,
                      !balls.contains(where: {
                          $0.pixelCenter.distance(to: Point2D(x: Double(x), y: Double(y))) <
                              $0.pixelRadius * 1.15
                      }) else {
                    continue
                }
                points.append(Point2D(x: Double(x), y: Double(y)))
            }
        }
        guard points.count >= 12 else { return nil }

        let mean = points.reduce(.zero, +) / Double(points.count)
        var xx = 0.0
        var yy = 0.0
        var xy = 0.0
        for point in points {
            let delta = point - mean
            xx += delta.x * delta.x
            yy += delta.y * delta.y
            xy += delta.x * delta.y
        }
        let principalAngle = 0.5 * atan2(2 * xy, xx - yy)
        var axis = Vector2D(x: cos(principalAngle), y: sin(principalAngle))
        let projections = points.map { ($0 - mean).dot(axis) }
        guard let minimum = projections.min(), let maximum = projections.max(),
              maximum - minimum > 12 else { return nil }
        var start = mean + axis * minimum
        var end = mean + axis * maximum

        if let cueBall = balls.first(where: { $0.ball.kind == .cue }) {
            if cueBall.pixelCenter.distance(to: start) <
                cueBall.pixelCenter.distance(to: end) {
                swap(&start, &end)
                axis = -axis
            }
            axis = (cueBall.pixelCenter - mean).normalized(or: axis)
        }
        let forwardStart = balls.first(where: { $0.ball.kind == .cue })?.pixelCenter ?? end
        let forwardEnd = forwardStart + axis * max(25, maximum - minimum)
        let pixelLine = Segment2D(start: forwardStart, end: forwardEnd)
        let canonicalLine: Segment2D?
        if let canonicalStart = table.imageToCanonical.applying(to: pixelLine.start),
           let canonicalEnd = table.imageToCanonical.applying(to: pixelLine.end) {
            canonicalLine = Segment2D(start: canonicalStart, end: canonicalEnd)
        } else {
            canonicalLine = nil
        }
        let linearity = max(xx, yy) / max(1, min(xx, yy))
        let confidence = min(1, Double(points.count) / 80) *
            min(1, linearity / 18)
        return CueLineEstimate(
            pixelLine: pixelLine,
            canonicalLine: canonicalLine,
            angleRadians: axis.angle,
            confidence: confidence,
            uncertainty: VisionUncertainty(
                positionSigma: 1,
                angularSigmaDegrees: max(0.15, 2.5 * (1 - confidence))
            )
        )
    }
}

public struct PixelPowerTrackEstimator: PowerTrackEstimating {
    public init() {}

    public func estimate(
        in image: RGBAImage,
        previous: PowerTrackEstimate?
    ) -> PowerTrackEstimate? {
        var handlePoints: [Point2D] = []
        for y in 0..<image.height {
            for x in 0..<image.width {
                guard let pixel = image.pixel(x: x, y: y),
                      pixel.blue > 145,
                      pixel.green > 105,
                      pixel.red < 110,
                      Int(pixel.blue) - Int(pixel.red) > 70 else {
                    continue
                }
                handlePoints.append(Point2D(x: Double(x), y: Double(y)))
            }
        }
        guard handlePoints.count >= 6 else { return nil }
        let handle = handlePoints.reduce(.zero, +) / Double(handlePoints.count)
        let handleY = Int(handle.y.rounded())
        var trackX: [Int] = []
        for y in max(0, handleY - 4)...min(image.height - 1, handleY + 4) {
            for x in 0..<image.width {
                guard let pixel = image.pixel(x: x, y: y),
                      pixel.luminance >= 80,
                      pixel.luminance <= 205,
                      pixel.channelRange < 38 else { continue }
                trackX.append(x)
            }
        }
        guard let minimum = trackX.min(), let maximum = trackX.max(),
              maximum - minimum >= image.width / 8 else {
            return nil
        }
        let track = Segment2D(
            start: Point2D(x: Double(minimum), y: handle.y),
            end: Point2D(x: Double(maximum), y: handle.y)
        )
        let normalized = ((handle.x - track.start.x) / track.length).clamped(to: 0 ... 1)
        let changed: Bool
        if let previous {
            changed = abs(previous.normalizedPower - normalized) > 0.008
        } else {
            changed = false
        }
        let confidence = min(1, Double(trackX.count) / Double(max(1, maximum - minimum)))
        return PowerTrackEstimate(
            pixelTrack: track,
            pixelHandle: handle,
            normalizedPower: normalized,
            isChanging: changed,
            confidence: confidence,
            uncertainty: VisionUncertainty(positionSigma: max(0.5, 1.5 * (1 - confidence)))
        )
    }
}

public actor VisionAnalyzer {
    private let tableDetector: TableDetector
    private let pocketDetector: PocketDetector
    private let ballDetector: BallDetector
    private let cueLineEstimator: any CueLineEstimating
    private let powerTrackEstimator: any PowerTrackEstimating
    private let diagnostics: PrivacySafeDiagnostics?
    private var sequence: UInt64 = 0
    private var previousFingerprint: UInt64?
    private var previousAnalysis: VisionAnalysis?
    private var previousPower: PowerTrackEstimate?

    public init(
        tableDetector: TableDetector = TableDetector(),
        pocketDetector: PocketDetector = PocketDetector(),
        ballDetector: BallDetector = BallDetector(),
        cueLineEstimator: any CueLineEstimating = PixelCueLineEstimator(),
        powerTrackEstimator: any PowerTrackEstimating = PixelPowerTrackEstimator(),
        diagnostics: PrivacySafeDiagnostics? = nil
    ) {
        self.tableDetector = tableDetector
        self.pocketDetector = pocketDetector
        self.ballDetector = ballDetector
        self.cueLineEstimator = cueLineEstimator
        self.powerTrackEstimator = powerTrackEstimator
        self.diagnostics = diagnostics
    }

    /// The input image is consumed for this call only. The actor retains the
    /// compact analytical result and fingerprint, never pixel bytes.
    public func analyze(
        _ image: RGBAImage,
        timestampNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) async -> VisionAnalysis {
        sequence &+= 1
        let fingerprint = image.sceneFingerprint()
        let sceneChanged = previousFingerprint != fingerprint
        if !sceneChanged, var cached = previousAnalysis {
            let cueStarted = DispatchTime.now().uptimeNanoseconds
            cached.sequence = sequence
            cached.timestampNanoseconds = timestampNanoseconds
            cached.sceneChanged = false
            if let table = cached.table {
                cached.cueLine = cueLineEstimator.estimate(
                    in: image,
                    table: table,
                    balls: cached.balls
                )
            }
            let cueElapsed = milliseconds(since: cueStarted)
            let powerStarted = DispatchTime.now().uptimeNanoseconds
            cached.powerTrack = powerTrackEstimator.estimate(
                in: image,
                previous: previousPower
            )
            let powerElapsed = milliseconds(since: powerStarted)
            previousPower = cached.powerTrack
            previousAnalysis = cached
            await diagnostics?.increment(.skippedDuplicateFrames)
            await diagnostics?.record(.cueTracking, milliseconds: cueElapsed)
            await diagnostics?.record(.powerTracking, milliseconds: powerElapsed)
            return cached
        }

        let started = DispatchTime.now().uptimeNanoseconds
        let tableStarted = DispatchTime.now().uptimeNanoseconds
        let table = tableDetector.detect(in: image)
        let pockets = table.map { pocketDetector.detect(in: image, table: $0) } ?? []
        let tableElapsed = milliseconds(since: tableStarted)
        let ballStarted = DispatchTime.now().uptimeNanoseconds
        let balls = table.map { ballDetector.detect(in: image, table: $0) } ?? []
        let ballElapsed = milliseconds(since: ballStarted)
        let cueStarted = DispatchTime.now().uptimeNanoseconds
        let cue = table.flatMap {
            cueLineEstimator.estimate(in: image, table: $0, balls: balls)
        }
        let cueElapsed = milliseconds(since: cueStarted)
        let powerStarted = DispatchTime.now().uptimeNanoseconds
        let power = powerTrackEstimator.estimate(in: image, previous: previousPower)
        let powerElapsed = milliseconds(since: powerStarted)
        let components = [
            table?.confidence,
            balls.isEmpty ? nil : balls.map(\.ball.confidence).reduce(0, +) / Double(balls.count),
            cue?.confidence,
            power?.confidence,
        ].compactMap { $0 }
        let confidence = components.isEmpty ? 0 :
            components.reduce(0, +) / Double(components.count)
        let analysis = VisionAnalysis(
            sequence: sequence,
            timestampNanoseconds: timestampNanoseconds,
            frameFingerprint: fingerprint,
            sceneChanged: true,
            table: table,
            pockets: pockets,
            balls: balls,
            cueLine: cue,
            powerTrack: power,
            overallConfidence: confidence
        )
        previousFingerprint = fingerprint
        previousAnalysis = analysis
        previousPower = power
        await diagnostics?.increment(.analyzedFrames)
        if confidence < 0.55 {
            await diagnostics?.increment(.uncertainDetections)
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000
        await diagnostics?.record(.framePreprocessing, milliseconds: elapsed)
        await diagnostics?.record(.tableDetection, milliseconds: tableElapsed)
        await diagnostics?.record(.ballDetection, milliseconds: ballElapsed)
        await diagnostics?.record(.cueTracking, milliseconds: cueElapsed)
        await diagnostics?.record(.powerTracking, milliseconds: powerElapsed)
        return analysis
    }

    public func reset() {
        previousFingerprint = nil
        previousAnalysis = nil
        previousPower = nil
    }

    private func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
