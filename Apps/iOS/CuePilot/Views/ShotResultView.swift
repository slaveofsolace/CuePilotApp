import SwiftUI

struct ShotResultView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CuePilotState.self) private var state

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Label(state.alignment.rawValue, systemImage: "scope")
                        .font(.system(size: 35, weight: .bold))
                        .foregroundStyle(alignmentColor)
                    Text(
                        verbatim: abs(state.angularCorrection).formatted(
                            .number.precision(.fractionLength(1))
                        )
                        + "° "
                        + (state.angularCorrection >= 0 ? "RIGHT" : "LEFT")
                    )
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .foregroundStyle(alignmentColor)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)

                TableDiagramView(
                    balls: state.balls,
                    recommendation: state.recommendation
                )

                VStack(spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(
                            "POWER "
                            + state.recommendedPower.lowerBound.formatted(
                                .percent.precision(.fractionLength(0))
                            )
                            + "–"
                            + state.recommendedPower.upperBound.formatted(
                                .percent.precision(.fractionLength(0))
                            )
                        )
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(state.currentPower, format: .percent.precision(.fractionLength(0)))
                            .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    }

                    ProgressView(value: state.currentPower)
                        .tint(powerColor)
                        .accessibilityLabel("Current visible power")
                        .accessibilityValue(
                            Text(
                                state.currentPower,
                                format: .percent.precision(.fractionLength(0))
                            )
                        )

                    metricRow(
                        title: "Center ball",
                        value: "Default spin",
                        systemImage: "scope"
                    )
                    metricRow(
                        title: "Confidence",
                        value: state.shotConfidence.formatted(
                            .percent.precision(.fractionLength(0))
                        ),
                        systemImage: "shield"
                    )
                }

                Button {
                    // Candidate alternatives remain on the current analysis surface.
                } label: {
                    HStack {
                        Text("Alternative Shots")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 17, weight: .medium))
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(CuePilotTheme.teal)

                ActionRow(
                    title: "Match Session",
                    systemImage: "list.bullet.rectangle"
                ) {
                    router.open(.matchSession)
                }

                Button(role: .destructive) {
                    state.pictureInPicture.stop()
                    router.reset()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: CuePilotTheme.controlRadius))
            }
            .padding(.horizontal, CuePilotTheme.contentPadding)
            .padding(.bottom, 28)
        }
        .navigationTitle("Live Assist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alignmentColor: Color {
        switch state.alignment {
        case .aimLocked, .ready:
            CuePilotTheme.locked
        case .fineAlignment, .rotateLeft, .rotateRight,
             .morePower, .lessPower:
            CuePilotTheme.caution
        case .doNotShoot:
            CuePilotTheme.destructive
        default:
            .secondary
        }
    }

    private var powerColor: Color {
        state.recommendedPower.contains(state.currentPower)
            ? CuePilotTheme.locked
            : CuePilotTheme.caution
    }

    private func metricRow(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .frame(width: 28)
            Text(title)
                .font(.system(size: 17, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Divider().overlay(CuePilotTheme.separator)
        }
    }
}
