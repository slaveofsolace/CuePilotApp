import SwiftUI

struct EditableTableView: View {
    @Binding var balls: [DisplayBall]
    @Binding var selectedBallID: DisplayBall.ID?
    @Binding var tableCorners: [ReviewMarker]
    @Binding var pockets: [ReviewMarker]
    let reviewMode: Int
    let moveTableCorner: (Int, Double, Double) -> Void
    let movePocket: (Int, Double, Double) -> Void
    let moveBall: (DisplayBall.ID, Double, Double) -> Void

    @State private var selectedMarkerID: Int?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TableDiagramView(
                    balls: balls,
                    showGuidance: false,
                    showDetection: true,
                    selectedBallID: selectedBallID
                )
                if reviewMode == 0 {
                    markerOverlay(
                        markers: tableCorners,
                        label: "Corner",
                        color: CuePilotTheme.caution,
                        size: proxy.size
                    )
                } else if reviewMode == 2 {
                    markerOverlay(
                        markers: pockets,
                        label: "Pocket",
                        color: CuePilotTheme.teal,
                        size: proxy.size
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(reviewGesture(size: proxy.size))
        }
        .aspectRatio(0.62, contentMode: .fit)
        .accessibilityHint(accessibilityHint)
        .onChange(of: reviewMode) {
            selectedMarkerID = nil
            selectedBallID = nil
        }
    }

    private func reviewGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let normalized = normalizedPoint(
                    value.location,
                    size: size
                )
                switch reviewMode {
                case 0:
                    move(
                        markerIn: tableCorners,
                        to: normalized,
                        using: moveTableCorner
                    )
                case 2:
                    move(
                        markerIn: pockets,
                        to: normalized,
                        using: movePocket
                    )
                default:
                    moveBall(to: normalized)
                }
            }
            .onEnded { _ in
                selectedMarkerID = nil
            }
    }

    private func moveBall(to normalized: (x: Double, y: Double)) {
        if selectedBallID == nil {
            selectedBallID = nearestBall(to: normalized)?.id
        }
        guard let selectedBallID else { return }
        moveBall(selectedBallID, normalized.x, normalized.y)
    }

    private func move(
        markerIn markers: [ReviewMarker],
        to normalized: (x: Double, y: Double),
        using update: (Int, Double, Double) -> Void
    ) {
        if selectedMarkerID == nil {
            selectedMarkerID = nearestMarker(
                in: markers,
                to: normalized
            )?.id
        }
        guard let selectedMarkerID else { return }
        update(selectedMarkerID, normalized.x, normalized.y)
    }

    private func markerOverlay(
        markers: [ReviewMarker],
        label: String,
        color: Color,
        size: CGSize
    ) -> some View {
        ForEach(markers) { marker in
            let location = viewPoint(
                x: marker.x,
                y: marker.y,
                size: size
            )
            ZStack {
                Circle()
                    .fill(.black.opacity(0.72))
                Circle()
                    .stroke(color, lineWidth: 3)
                Text("\(marker.id + 1)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .position(location)
            .accessibilityLabel("\(label) \(marker.id + 1)")
        }
    }

    private func normalizedPoint(
        _ point: CGPoint,
        size: CGSize
    ) -> (x: Double, y: Double) {
        let inset = min(size.width, size.height) * 0.055
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)
        return (
            x: min(max(Double((point.x - inset) / width), 0), 1),
            y: min(max(Double((point.y - inset) / height), 0), 1)
        )
    }

    private func viewPoint(
        x: Double,
        y: Double,
        size: CGSize
    ) -> CGPoint {
        let inset = min(size.width, size.height) * 0.055
        return CGPoint(
            x: inset + CGFloat(x) * max(size.width - inset * 2, 1),
            y: inset + CGFloat(y) * max(size.height - inset * 2, 1)
        )
    }

    private func nearestBall(
        to point: (x: Double, y: Double)
    ) -> DisplayBall? {
        balls.min {
            distanceSquared($0, point) < distanceSquared($1, point)
        }
    }

    private func nearestMarker(
        in markers: [ReviewMarker],
        to point: (x: Double, y: Double)
    ) -> ReviewMarker? {
        markers.min {
            markerDistanceSquared($0, point)
                < markerDistanceSquared($1, point)
        }
    }

    private func distanceSquared(
        _ ball: DisplayBall,
        _ point: (x: Double, y: Double)
    ) -> Double {
        let dx = ball.x - point.x
        let dy = ball.y - point.y
        return dx * dx + dy * dy
    }

    private func markerDistanceSquared(
        _ marker: ReviewMarker,
        _ point: (x: Double, y: Double)
    ) -> Double {
        let dx = marker.x - point.x
        let dy = marker.y - point.y
        return dx * dx + dy * dy
    }

    private var accessibilityHint: String {
        switch reviewMode {
        case 0:
            "Drag a numbered corner handle to correct the table boundary."
        case 2:
            "Drag a numbered pocket handle to correct its center."
        default:
            "Drag a selected ball to correct its center."
        }
    }
}
