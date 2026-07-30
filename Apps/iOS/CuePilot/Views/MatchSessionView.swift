import CueGeometry
import SwiftUI

struct MatchSessionView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CuePilotState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Label(
                        state.isUsersTurn ? "YOUR TURN" : "WAITING FOR TURN",
                        systemImage: "scope"
                    )
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        state.isUsersTurn
                            ? CuePilotTheme.teal
                            : .secondary
                    )

                    Label(state.group.rawValue, systemImage: "circle.grid.3x3")
                        .font(.system(size: 20, weight: .medium))

                    Picker("Your group", selection: $state.group) {
                        ForEach(PlayerGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Your turn", isOn: $state.isUsersTurn)
                        .toggleStyle(.switch)
                        .accessibilityHint(
                            "Updates legal-target guidance for the live broadcast."
                        )

                    if state.group != .open {
                        Picker(
                            "Called 8-ball pocket",
                            selection: $state.requiredEightBallPocket
                        ) {
                            Text("Not selected")
                                .tag(nil as PocketID?)
                            ForEach(PocketID.allCases, id: \.self) {
                                Text($0.displayName)
                                    .tag(Optional($0))
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityHint(
                            "Limits legal 8-ball guidance to the called pocket."
                        )
                    }

                    remainingBalls

                    Label(
                        state.isCalibrated ? "Calibrated" : "Calibration needed",
                        systemImage: state.isCalibrated
                            ? "checkmark.circle"
                            : "exclamationmark.triangle"
                    )
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(
                        state.isCalibrated
                            ? CuePilotTheme.locked
                            : CuePilotTheme.caution
                    )
                }
                .padding(.top, 8)

                TableDiagramView(balls: state.balls)
                    .frame(maxHeight: 300)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Prior Shots")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 8)

                    if state.history.isEmpty {
                        Text("No shots recorded in this match.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(.vertical, 14)
                    }

                    ForEach(state.history) { shot in
                        HStack(spacing: 14) {
                            Image(
                                systemName: shot.successful
                                    ? "checkmark.circle"
                                    : "xmark.circle"
                            )
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(
                                shot.successful
                                    ? CuePilotTheme.locked
                                    : CuePilotTheme.caution
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shot.title)
                                    .font(.system(size: 17, weight: .medium))
                                Text(shot.detail)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(shot.result)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(
                                    shot.successful
                                        ? CuePilotTheme.locked
                                        : CuePilotTheme.caution
                                )
                        }
                        .padding(.vertical, 14)
                        .overlay(alignment: .bottom) {
                            Divider().overlay(CuePilotTheme.separator)
                        }
                    }
                }

                ActionRow(
                    title: "Return to Live Assist",
                    systemImage: "scope",
                    prominent: true
                ) {
                    router.open(.shotResult)
                }

                Button(role: .destructive) {
                    state.isUsersTurn = false
                    state.pictureInPicture.stop()
                    router.reset()
                } label: {
                    Label("End Match", systemImage: "stop")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: CuePilotTheme.controlRadius))
            }
            .padding(.horizontal, CuePilotTheme.contentPadding)
            .padding(.bottom, 28)
        }
        .navigationTitle("Match Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var remainingBalls: some View {
        VStack(spacing: 8) {
            Text("Remaining \(state.group.rawValue)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 10) {
                ForEach(remainingNumbers, id: \.self) { number in
                    ZStack {
                        Circle()
                            .fill(ballColor(number))
                        Circle()
                            .fill(.white)
                            .frame(width: 17, height: 17)
                        Text("\(number)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black)
                    }
                    .frame(width: 34, height: 34)
                    .accessibilityLabel("Ball \(number)")
                }
            }
        }
    }

    private var remainingNumbers: [Int] {
        switch state.group {
        case .open, .solids:
            Array(1 ... 7)
        case .stripes:
            Array(9 ... 15)
        }
    }

    private func ballColor(_ number: Int) -> Color {
        let colors: [Color] = [
            .yellow, .blue, .red, .purple, .orange, .green, .brown,
        ]
        return colors[(number - 1) % colors.count]
    }
}
