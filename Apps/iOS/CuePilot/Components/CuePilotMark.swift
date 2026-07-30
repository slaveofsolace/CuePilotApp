import SwiftUI

struct CuePilotMark: View {
    var size: CGFloat = 108

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) * 0.28
            let circle = Path(
                ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
            context.stroke(circle, with: .color(.white), lineWidth: 4)

            var cue = Path()
            cue.move(to: CGPoint(x: canvasSize.width * 0.18, y: canvasSize.height * 0.82))
            cue.addLine(to: CGPoint(x: canvasSize.width * 0.82, y: canvasSize.height * 0.18))
            context.stroke(
                cue,
                with: .color(.white),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )

            let contact = CGRect(
                x: canvasSize.width * 0.69,
                y: canvasSize.height * 0.27,
                width: 10,
                height: 10
            )
            context.fill(Path(ellipseIn: contact), with: .color(CuePilotTheme.teal))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
