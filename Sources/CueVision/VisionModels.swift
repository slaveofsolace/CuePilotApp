import CueGeometry
import Foundation

public struct VisionUncertainty: Codable, Equatable, Sendable {
    /// One standard deviation in the coordinate system of the associated value.
    public var positionSigma: Double
    public var radiusSigma: Double
    public var angularSigmaDegrees: Double

    public init(
        positionSigma: Double,
        radiusSigma: Double = 0,
        angularSigmaDegrees: Double = 0
    ) {
        self.positionSigma = max(0, positionSigma)
        self.radiusSigma = max(0, radiusSigma)
        self.angularSigmaDegrees = max(0, angularSigmaDegrees)
    }
}

public struct DetectedTable: Codable, Equatable, Sendable {
    /// Clockwise pixel coordinates: top-left, top-right, bottom-right,
    /// bottom-left.
    public var corners: [Point2D]
    public var imageToCanonical: ProjectiveTransform2D
    public var geometry: TableGeometry
    public var confidence: Double
    public var uncertainty: VisionUncertainty

    public init(
        corners: [Point2D],
        imageToCanonical: ProjectiveTransform2D,
        geometry: TableGeometry,
        confidence: Double,
        uncertainty: VisionUncertainty
    ) {
        self.corners = corners
        self.imageToCanonical = imageToCanonical
        self.geometry = geometry
        self.confidence = confidence.clamped(to: 0 ... 1)
        self.uncertainty = uncertainty
    }
}

public struct DetectedPocket: Codable, Equatable, Sendable {
    public var geometry: PocketGeometry
    public var pixelCenter: Point2D
    public var confidence: Double
    public var uncertainty: VisionUncertainty

    public init(
        geometry: PocketGeometry,
        pixelCenter: Point2D,
        confidence: Double,
        uncertainty: VisionUncertainty
    ) {
        self.geometry = geometry
        self.pixelCenter = pixelCenter
        self.confidence = confidence.clamped(to: 0 ... 1)
        self.uncertainty = uncertainty
    }
}

public struct DetectedBall: Codable, Equatable, Sendable {
    public var ball: BallState
    public var pixelCenter: Point2D
    public var pixelRadius: Double
    public var classificationConfidence: Double
    public var uncertainty: VisionUncertainty
    public var isOccluded: Bool

    public init(
        ball: BallState,
        pixelCenter: Point2D,
        pixelRadius: Double,
        classificationConfidence: Double,
        uncertainty: VisionUncertainty,
        isOccluded: Bool = false
    ) {
        self.ball = ball
        self.pixelCenter = pixelCenter
        self.pixelRadius = max(0, pixelRadius)
        self.classificationConfidence = classificationConfidence.clamped(to: 0 ... 1)
        self.uncertainty = uncertainty
        self.isOccluded = isOccluded
    }
}

public struct CueLineEstimate: Codable, Equatable, Sendable {
    public var pixelLine: Segment2D
    public var canonicalLine: Segment2D?
    public var angleRadians: Double
    public var confidence: Double
    public var uncertainty: VisionUncertainty

    public init(
        pixelLine: Segment2D,
        canonicalLine: Segment2D?,
        angleRadians: Double,
        confidence: Double,
        uncertainty: VisionUncertainty
    ) {
        self.pixelLine = pixelLine
        self.canonicalLine = canonicalLine
        self.angleRadians = angleRadians
        self.confidence = confidence.clamped(to: 0 ... 1)
        self.uncertainty = uncertainty
    }
}

public struct PowerTrackEstimate: Codable, Equatable, Sendable {
    public var pixelTrack: Segment2D
    public var pixelHandle: Point2D
    public var normalizedPower: Double
    public var isChanging: Bool
    public var confidence: Double
    public var uncertainty: VisionUncertainty

    public init(
        pixelTrack: Segment2D,
        pixelHandle: Point2D,
        normalizedPower: Double,
        isChanging: Bool,
        confidence: Double,
        uncertainty: VisionUncertainty
    ) {
        self.pixelTrack = pixelTrack
        self.pixelHandle = pixelHandle
        self.normalizedPower = normalizedPower.clamped(to: 0 ... 1)
        self.isChanging = isChanging
        self.confidence = confidence.clamped(to: 0 ... 1)
        self.uncertainty = uncertainty
    }
}

public struct VisionAnalysis: Codable, Equatable, Sendable {
    public var sequence: UInt64
    public var timestampNanoseconds: UInt64
    public var frameFingerprint: UInt64
    public var sceneChanged: Bool
    public var table: DetectedTable?
    public var pockets: [DetectedPocket]
    public var balls: [DetectedBall]
    public var cueLine: CueLineEstimate?
    public var powerTrack: PowerTrackEstimate?
    public var overallConfidence: Double

    public init(
        sequence: UInt64,
        timestampNanoseconds: UInt64,
        frameFingerprint: UInt64,
        sceneChanged: Bool,
        table: DetectedTable?,
        pockets: [DetectedPocket],
        balls: [DetectedBall],
        cueLine: CueLineEstimate?,
        powerTrack: PowerTrackEstimate?,
        overallConfidence: Double
    ) {
        self.sequence = sequence
        self.timestampNanoseconds = timestampNanoseconds
        self.frameFingerprint = frameFingerprint
        self.sceneChanged = sceneChanged
        self.table = table
        self.pockets = pockets
        self.balls = balls
        self.cueLine = cueLine
        self.powerTrack = powerTrack
        self.overallConfidence = overallConfidence.clamped(to: 0 ... 1)
    }
}

public enum ManualCorrection: Codable, Equatable, Sendable {
    case setTableCorner(index: Int, pixelPoint: Point2D)
    case setPocket(PocketID, pixelPoint: Point2D)
    case upsertBall(DetectedBall)
    case removeBall(id: Int)
    case moveBall(id: Int, canonicalCenter: Point2D, pixelCenter: Point2D)
    case classifyBall(id: Int, kind: BallKind)
    case markPocketed(id: Int, Bool)
}

/// Immutable correction operations make review actions undoable and easy to
/// test. Invalid identifiers are no-ops instead of corrupting the snapshot.
public struct DetectionReview: Codable, Equatable, Sendable {
    public var analysis: VisionAnalysis
    public var appliedCorrections: [ManualCorrection]

    public init(analysis: VisionAnalysis, appliedCorrections: [ManualCorrection] = []) {
        self.analysis = analysis
        self.appliedCorrections = appliedCorrections
    }

    public func applying(_ correction: ManualCorrection) -> DetectionReview {
        var result = self
        switch correction {
        case let .setTableCorner(index, point):
            guard index >= 0, index < 4,
                  var table = result.analysis.table,
                  table.corners.count == 4 else { return self }
            table.corners[index] = point
            if let transform = try? ProjectiveTransform2D.mapping(
                source: table.corners,
                destination: [
                    Point2D(x: 0, y: 0),
                    Point2D(x: 2, y: 0),
                    Point2D(x: 2, y: 1),
                    Point2D(x: 0, y: 1),
                ]
            ) {
                table.imageToCanonical = transform
                table.confidence = min(table.confidence, 0.98)
                table.uncertainty.positionSigma = 0.5
                result.analysis.table = table
                for ballIndex in result.analysis.balls.indices {
                    if let canonical = transform.applying(
                        to: result.analysis.balls[ballIndex].pixelCenter
                    ) {
                        result.analysis.balls[ballIndex].ball.center = canonical
                    }
                }
                for pocketIndex in result.analysis.pockets.indices {
                    if let canonical = transform.applying(
                        to: result.analysis.pockets[pocketIndex].pixelCenter
                    ) {
                        result.analysis.pockets[pocketIndex].geometry.center = canonical
                        result.analysis.pockets[pocketIndex].geometry.aimPoint = canonical
                    }
                }
                result.synchronizePocketGeometry()
            } else {
                return self
            }
        case let .setPocket(id, point):
            guard let index = result.analysis.pockets.firstIndex(where: {
                $0.geometry.id == id
            }) else { return self }
            result.analysis.pockets[index].pixelCenter = point
            if let canonical = result.analysis.table?.imageToCanonical.applying(to: point) {
                result.analysis.pockets[index].geometry.center = canonical
                result.analysis.pockets[index].geometry.aimPoint = canonical
            }
            result.analysis.pockets[index].confidence = 1
            result.analysis.pockets[index].uncertainty.positionSigma = 0.5
            result.synchronizePocketGeometry()
        case let .upsertBall(ball):
            if let index = result.analysis.balls.firstIndex(where: {
                $0.ball.id == ball.ball.id
            }) {
                result.analysis.balls[index] = ball
            } else {
                result.analysis.balls.append(ball)
            }
        case let .removeBall(id):
            guard result.analysis.balls.contains(where: { $0.ball.id == id }) else {
                return self
            }
            result.analysis.balls.removeAll { $0.ball.id == id }
        case let .moveBall(id, canonicalCenter, pixelCenter):
            guard let index = result.analysis.balls.firstIndex(where: {
                $0.ball.id == id
            }) else { return self }
            result.analysis.balls[index].ball.center = canonicalCenter
            result.analysis.balls[index].pixelCenter = pixelCenter
            result.analysis.balls[index].ball.confidence = 1
            result.analysis.balls[index].uncertainty.positionSigma = 0.25
        case let .classifyBall(id, kind):
            guard let index = result.analysis.balls.firstIndex(where: {
                $0.ball.id == id
            }) else { return self }
            result.analysis.balls[index].ball.kind = kind
            result.analysis.balls[index].classificationConfidence = 1
        case let .markPocketed(id, isPocketed):
            guard let index = result.analysis.balls.firstIndex(where: {
                $0.ball.id == id
            }) else { return self }
            result.analysis.balls[index].ball.isPocketed = isPocketed
        }
        result.appliedCorrections.append(correction)
        return result
    }

    private mutating func synchronizePocketGeometry() {
        guard var table = analysis.table else { return }
        for detected in analysis.pockets {
            if let index = table.geometry.pockets.firstIndex(where: {
                $0.id == detected.geometry.id
            }) {
                table.geometry.pockets[index] = detected.geometry
            }
        }
        analysis.table = table
    }
}

public protocol CueLineEstimating: Sendable {
    func estimate(
        in image: RGBAImage,
        table: DetectedTable,
        balls: [DetectedBall]
    ) -> CueLineEstimate?
}

public protocol PowerTrackEstimating: Sendable {
    func estimate(
        in image: RGBAImage,
        previous: PowerTrackEstimate?
    ) -> PowerTrackEstimate?
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
