import AppKit
import CueGeometry
import CueStrategy
import CueVision
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let panel: PassThroughPanel
    private let host: NSHostingView<WindowOverlayView>
    private var sourceWindowID: CGWindowID?
    private var shouldBeVisible = false

    init() {
        let rootView = WindowOverlayView(state: .empty)
        host = NSHostingView(rootView: rootView)
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor

        panel = PassThroughPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .normal
        panel.collectionBehavior = [
            .ignoresCycle,
            .fullScreenAuxiliary,
            .transient,
        ]
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
    }

    func update(
        state: OverlayRenderState,
        opacity: Double
    ) {
        host.rootView = WindowOverlayView(state: state)
        panel.alphaValue = max(0.15, min(1, opacity))
    }

    func register(
        to sourceWindowID: CGWindowID,
        registration: FrameRegistration
    ) {
        self.sourceWindowID = sourceWindowID
        guard registration.isOnScreen, !registration.screenRect.isEmpty else {
            panel.orderOut(nil)
            return
        }

        let targetFrame = WindowGeometryResolver.appKitRect(
            fromQuartz: registration.screenRect
        )
        guard targetFrame.width > 0, targetFrame.height > 0 else {
            panel.orderOut(nil)
            return
        }
        if !panel.frame.equalTo(targetFrame) {
            panel.setFrame(targetFrame, display: true, animate: false)
        }
        if shouldBeVisible {
            panel.order(.above, relativeTo: Int(sourceWindowID))
        }
    }

    func setVisible(_ visible: Bool) {
        shouldBeVisible = visible
        guard visible, let sourceWindowID else {
            panel.orderOut(nil)
            return
        }
        panel.order(.above, relativeTo: Int(sourceWindowID))
    }

    func hide() {
        shouldBeVisible = false
        panel.orderOut(nil)
    }
}

private final class PassThroughPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct WindowOverlayView: View {
    let state: OverlayRenderState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GuidanceDrawingView(
                    state: state,
                    canvasSize: proxy.size
                )

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        if state.debugMode {
                            debugStatus
                        }
                        Spacer()
                        guidanceStatus
                    }
                    .padding(max(12, min(proxy.size.width, proxy.size.height) * 0.025))
                }
            }
        }
        .background(Color.clear)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var guidanceStatus: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Label(
                state.statusText,
                systemImage: state.guidanceState?.symbol ?? "viewfinder"
            )
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            if let powerText = state.powerText {
                Text(powerText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(statusColor.opacity(0.8), lineWidth: 1)
        }
    }

    private var debugStatus: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("FRAME REGISTRATION")
            Text(
                "\(Int(state.analysisImageSize.width)) × " +
                    "\(Int(state.analysisImageSize.height)) analysis"
            )
            if let analysis = state.analysis {
                Text(
                    "\(analysis.balls.count) balls · " +
                        "\(Int(analysis.overallConfidence * 100))% confidence"
                )
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
    }

    private var statusColor: Color {
        switch state.guidanceState {
        case .aimLocked, .ready:
            .green
        case .doNotShoot:
            .red
        case .morePower, .lessPower:
            .yellow
        default:
            .cyan
        }
    }
}

struct GuidanceDrawingView: View {
    let state: OverlayRenderState
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard let analysis = state.analysis,
                  state.analysisImageSize.width > 0,
                  state.analysisImageSize.height > 0 else {
                return
            }
            let projection = DrawingProjection(
                imageSize: state.analysisImageSize,
                capturedFramePixelSize: state.capturedFramePixelSize,
                canvasSize: size,
                registration: state.registration,
                usesScreenRegistration: state.usesScreenRegistration,
                calibrationDisplayScale: state.calibrationDisplayScale
            )

            if let table = analysis.table {
                drawTable(table, in: &context, projection: projection)
            }
            drawDetectedBalls(
                analysis.balls,
                targetID: state.recommendation?.candidate.targetBallID,
                in: &context,
                projection: projection
            )
            if let cueLine = analysis.cueLine {
                draw(
                    cueLine.pixelLine,
                    color: .white.opacity(0.8),
                    width: 1.5,
                    dash: [5, 4],
                    in: &context,
                    projection: projection
                )
            }
            if let table = analysis.table,
               let recommendation = state.recommendation,
               let canonicalToPixel = canonicalToPixelTransform(table: table) {
                drawRecommendation(
                    recommendation,
                    transform: canonicalToPixel,
                    in: &context,
                    projection: projection
                )
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func drawTable(
        _ table: DetectedTable,
        in context: inout GraphicsContext,
        projection: DrawingProjection
    ) {
        guard table.corners.count == 4 else { return }
        var path = Path()
        path.move(to: projection.point(table.corners[0]))
        for corner in table.corners.dropFirst() {
            path.addLine(to: projection.point(corner))
        }
        path.closeSubpath()
        context.stroke(
            path,
            with: .color(state.debugMode ? .cyan.opacity(0.8) : .cyan.opacity(0.28)),
            style: StrokeStyle(lineWidth: state.debugMode ? 1.5 : 0.8, dash: [6, 4])
        )
    }

    private func drawDetectedBalls(
        _ balls: [DetectedBall],
        targetID: Int?,
        in context: inout GraphicsContext,
        projection: DrawingProjection
    ) {
        for detected in balls {
            let center = projection.point(detected.pixelCenter)
            let radius = max(3, detected.pixelRadius * projection.averageScale)
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let color: Color
            if detected.ball.id == targetID {
                color = .yellow
            } else if detected.ball.kind == .cue {
                color = .cyan
            } else {
                color = .white.opacity(state.debugMode ? 0.8 : 0.38)
            }
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(color),
                lineWidth: detected.ball.id == targetID ? 2.3 : 1.2
            )
        }
    }

    private func drawRecommendation(
        _ recommendation: ShotRecommendation,
        transform: ProjectiveTransform2D,
        in context: inout GraphicsContext,
        projection: DrawingProjection
    ) {
        drawCanonical(
            recommendation.candidate.cuePath,
            transform: transform,
            color: .cyan,
            width: 2.4,
            dash: [],
            in: &context,
            projection: projection
        )
        for objectPath in recommendation.candidate.objectPaths {
            drawCanonical(
                objectPath,
                transform: transform,
                color: .cyan.opacity(0.9),
                width: 1.8,
                dash: [7, 4],
                in: &context,
                projection: projection
            )
        }
        for ghostCenter in recommendation.candidate.ghostCenters {
            guard let pixel = transform.applying(to: ghostCenter) else { continue }
            let center = projection.point(pixel)
            let radius = max(
                5,
                recommendation.candidate.cuePath.length * 0.018 *
                    projection.averageScale *
                    state.analysisImageSize.width / 2
            )
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.7, dash: [5, 3])
            )
        }
        if let scratchPath = recommendation.candidate.scratch.predictedCuePath {
            drawCanonical(
                scratchPath,
                transform: transform,
                color: recommendation.candidate.scratch.level == .high
                    ? .red
                    : .yellow.opacity(0.7),
                width: 1.3,
                dash: [4, 4],
                in: &context,
                projection: projection
            )
        }
        drawCorridor(
            recommendation,
            transform: transform,
            in: &context,
            projection: projection
        )
    }

    private func drawCorridor(
        _ recommendation: ShotRecommendation,
        transform: ProjectiveTransform2D,
        in context: inout GraphicsContext,
        projection: DrawingProjection
    ) {
        let cue = recommendation.candidate.cuePath.start
        let length = min(1.25, max(0.35, recommendation.candidate.cuePath.length))
        let lower = cue + Vector2D(
            x: cos(recommendation.corridor.minimumAngle),
            y: sin(recommendation.corridor.minimumAngle)
        ) * length
        let upper = cue + Vector2D(
            x: cos(recommendation.corridor.maximumAngle),
            y: sin(recommendation.corridor.maximumAngle)
        ) * length
        guard let cuePixel = transform.applying(to: cue),
              let lowerPixel = transform.applying(to: lower),
              let upperPixel = transform.applying(to: upper) else {
            return
        }

        var corridor = Path()
        corridor.move(to: projection.point(cuePixel))
        corridor.addLine(to: projection.point(lowerPixel))
        corridor.addLine(to: projection.point(upperPixel))
        corridor.closeSubpath()
        context.fill(corridor, with: .color(.cyan.opacity(0.10)))
        context.stroke(
            corridor,
            with: .color(.cyan.opacity(0.75)),
            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
        )
    }

    private func drawCanonical(
        _ segment: Segment2D,
        transform: ProjectiveTransform2D,
        color: Color,
        width: CGFloat,
        dash: [CGFloat],
        in context: inout GraphicsContext,
        projection: DrawingProjection
    ) {
        guard let start = transform.applying(to: segment.start),
              let end = transform.applying(to: segment.end) else {
            return
        }
        draw(
            Segment2D(start: start, end: end),
            color: color,
            width: width,
            dash: dash,
            in: &context,
            projection: projection
        )
    }

    private func draw(
        _ segment: Segment2D,
        color: Color,
        width: CGFloat,
        dash: [CGFloat],
        in context: inout GraphicsContext,
        projection: DrawingProjection
    ) {
        var path = Path()
        path.move(to: projection.point(segment.start))
        path.addLine(to: projection.point(segment.end))
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash)
        )
    }

    private func canonicalToPixelTransform(
        table: DetectedTable
    ) -> ProjectiveTransform2D? {
        try? ProjectiveTransform2D.mapping(
            source: [
                Point2D(x: 0, y: 0),
                Point2D(x: 2, y: 0),
                Point2D(x: 2, y: 1),
                Point2D(x: 0, y: 1),
            ],
            destination: table.corners
        )
    }
}

private struct DrawingProjection {
    let imageSize: CGSize
    let capturedFramePixelSize: CGSize
    let canvasSize: CGSize
    let registration: FrameRegistration
    let usesScreenRegistration: Bool
    let calibrationDisplayScale: Double

    var scaleX: CGFloat {
        if hasRegisteredSurface {
            return capturedFramePixelSize.width / max(1, imageSize.width) /
                CGFloat(registration.scaleFactor) /
                CGFloat(registration.contentScale) *
                canvasSize.width / max(1, registration.screenRect.width) *
                calibrationScale
        }
        return canvasSize.width / max(1, imageSize.width) * calibrationScale
    }

    var scaleY: CGFloat {
        if hasRegisteredSurface {
            return capturedFramePixelSize.height / max(1, imageSize.height) /
                CGFloat(registration.scaleFactor) /
                CGFloat(registration.contentScale) *
                canvasSize.height / max(1, registration.screenRect.height) *
                calibrationScale
        }
        return canvasSize.height / max(1, imageSize.height) * calibrationScale
    }

    var averageScale: CGFloat {
        (scaleX + scaleY) / 2
    }

    func point(_ point: Point2D) -> CGPoint {
        let mapped: CGPoint
        if hasRegisteredSurface {
            let outputPixelX =
                CGFloat(point.x) *
                capturedFramePixelSize.width / max(1, imageSize.width)
            let outputPixelY =
                CGFloat(point.y) *
                capturedFramePixelSize.height / max(1, imageSize.height)
            let surfacePointX =
                outputPixelX / CGFloat(registration.scaleFactor)
            let surfacePointY =
                outputPixelY / CGFloat(registration.scaleFactor)
            let sourcePointX =
                (surfacePointX - registration.contentRect.minX) /
                CGFloat(registration.contentScale)
            let sourcePointY =
                (surfacePointY - registration.contentRect.minY) /
                CGFloat(registration.contentScale)
            mapped = CGPoint(
                x: sourcePointX *
                    canvasSize.width / max(1, registration.screenRect.width),
                y: sourcePointY *
                    canvasSize.height / max(1, registration.screenRect.height)
            )
        } else {
            mapped = CGPoint(
                x: CGFloat(point.x) *
                    canvasSize.width / max(1, imageSize.width),
                y: CGFloat(point.y) *
                    canvasSize.height / max(1, imageSize.height)
            )
        }

        let center = CGPoint(
            x: canvasSize.width / 2,
            y: canvasSize.height / 2
        )
        return CGPoint(
            x: center.x + (mapped.x - center.x) * calibrationScale,
            y: center.y + (mapped.y - center.y) * calibrationScale
        )
    }

    private var hasRegisteredSurface: Bool {
        usesScreenRegistration &&
            registration.isOnScreen &&
            registration.hasSurfaceMetadata &&
            registration.screenRect.width > 0 &&
            registration.screenRect.height > 0 &&
            capturedFramePixelSize.width > 0 &&
            capturedFramePixelSize.height > 0
    }

    private var calibrationScale: CGFloat {
        CGFloat(min(1.1, max(0.9, calibrationDisplayScale)))
    }
}
