import CueGeometry
import CueStrategy
import SwiftUI

struct TableDiagramView: View {
    let balls: [DisplayBall]
    var showGuidance = true
    var showDetection = false
    var selectedBallID: DisplayBall.ID?
    var recommendation: ShotRecommendation?

    var body: some View {
        Canvas { context, size in
            let outer = CGRect(origin: .zero, size: size)
            let railWidth = max(12, min(size.width, size.height) * 0.055)
            let playing = outer.insetBy(dx: railWidth, dy: railWidth)

            context.fill(
                Path(roundedRect: outer, cornerRadius: railWidth * 1.2),
                with: .color(Color(red: 28 / 255, green: 31 / 255, blue: 31 / 255))
            )
            context.fill(
                Path(roundedRect: playing, cornerRadius: railWidth * 0.55),
                with: .color(CuePilotTheme.table)
            )

            drawPockets(context: &context, playing: playing, radius: railWidth * 0.72)

            if showGuidance, let recommendation {
                drawGuidance(
                    recommendation,
                    context: &context,
                    playing: playing
                )
            }

            for ball in balls {
                drawBall(context: &context, ball: ball, playing: playing, size: size)
            }

            if showDetection {
                context.stroke(
                    Path(roundedRect: playing, cornerRadius: railWidth * 0.55),
                    with: .color(CuePilotTheme.teal),
                    style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                )
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let ballText = balls
            .map {
                switch $0.appearance {
                case .cue:
                    "cue ball"
                case .unknown:
                    "unclassified ball"
                default:
                    "ball \($0.number)"
                }
            }
            .joined(separator: ", ")
        if showGuidance, let recommendation {
            return "Billiards table with \(ballText). Recommended path targets the "
                + "\(recommendation.candidate.pocketID.displayName.lowercased()) pocket."
        }
        return "Detected billiards table with \(ballText)."
    }

    private func drawPockets(
        context: inout GraphicsContext,
        playing: CGRect,
        radius: CGFloat
    ) {
        let points = [
            CGPoint(x: playing.minX, y: playing.minY),
            CGPoint(x: playing.midX, y: playing.minY),
            CGPoint(x: playing.maxX, y: playing.minY),
            CGPoint(x: playing.minX, y: playing.maxY),
            CGPoint(x: playing.midX, y: playing.maxY),
            CGPoint(x: playing.maxX, y: playing.maxY),
        ]
        for point in points {
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(.black))
        }
    }

    private func drawGuidance(
        _ recommendation: ShotRecommendation,
        context: inout GraphicsContext,
        playing: CGRect
    ) {
        let cue = canonicalPoint(
            recommendation.candidate.cuePath.start,
            in: playing
        )
        let target = canonicalPoint(
            recommendation.candidate.cuePath.end,
            in: playing
        )
        var cueLine = Path()
        cueLine.move(to: cue)
        cueLine.addLine(to: target)
        context.stroke(
            cueLine,
            with: .color(.white),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )

        for segment in recommendation.candidate.objectPaths {
            var objectLine = Path()
            objectLine.move(
                to: canonicalPoint(segment.start, in: playing)
            )
            objectLine.addLine(
                to: canonicalPoint(segment.end, in: playing)
            )
            context.stroke(
                objectLine,
                with: .color(CuePilotTheme.locked),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    dash: [7, 5]
                )
            )
        }
        let ghostRadius = min(playing.width, playing.height) * 0.045
        for ghost in recommendation.candidate.ghostCenters {
            let ghostCenter = canonicalPoint(ghost, in: playing)
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: ghostCenter.x - ghostRadius,
                        y: ghostCenter.y - ghostRadius,
                        width: ghostRadius * 2,
                        height: ghostRadius * 2
                    )
                ),
                with: .color(.white.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
        }
    }

    private func drawBall(
        context: inout GraphicsContext,
        ball: DisplayBall,
        playing: CGRect,
        size: CGSize
    ) {
        let center = point(x: ball.x, y: ball.y, in: playing)
        let radius = min(size.width, size.height) * 0.028
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let color: Color = switch ball.appearance {
        case .cue: .white
        case .eight: .black
        case .solid: ballColor(number: ball.number)
        case .stripe: ballColor(number: ball.number).opacity(0.9)
        case .unknown: .gray
        }
        context.fill(Path(ellipseIn: rect), with: .color(color))

        if ball.appearance == .stripe {
            let stripe = CGRect(
                x: rect.minX,
                y: rect.midY - radius * 0.33,
                width: rect.width,
                height: radius * 0.66
            )
            context.fill(Path(roundedRect: stripe, cornerRadius: radius * 0.2), with: .color(.white))
        }

        if ball.appearance != .cue {
            let labelRect = rect.insetBy(dx: radius * 0.45, dy: radius * 0.45)
            context.fill(Path(ellipseIn: labelRect), with: .color(.white))
            context.draw(
                Text(ball.appearance == .unknown ? "?" : "\(ball.number)")
                    .font(.system(size: max(8, radius * 0.62), weight: .bold))
                    .foregroundStyle(.black),
                at: center
            )
        }

        let outline = ball.id == selectedBallID ? Color.white : CuePilotTheme.teal
        context.stroke(
            Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)),
            with: .color(outline.opacity(showDetection ? 1 : 0.5)),
            lineWidth: ball.id == selectedBallID ? 3 : 1.5
        )
    }

    private func point(x: Double, y: Double, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + CGFloat(x) * rect.width,
            y: rect.minY + CGFloat(y) * rect.height
        )
    }

    private func canonicalPoint(
        _ point: CueGeometry.Point2D,
        in rect: CGRect
    ) -> CGPoint {
        self.point(x: point.x / 2, y: point.y, in: rect)
    }

    private func ballColor(number: Int) -> Color {
        let colors: [Color] = [
            .yellow, .blue, .red, .purple, .orange, .green, .brown,
        ]
        return colors[max(number - 1, 0) % colors.count]
    }
}
