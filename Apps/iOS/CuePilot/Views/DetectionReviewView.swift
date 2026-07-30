import CueGeometry
import SwiftUI

struct DetectionReviewView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CuePilotState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(spacing: 18) {
                EditableTableView(
                    balls: $state.balls,
                    selectedBallID: $state.selectedBallID,
                    tableCorners: $state.tableCornerMarkers,
                    pockets: $state.pocketMarkers,
                    reviewMode: state.reviewMode,
                    moveTableCorner: state.moveTableCorner,
                    movePocket: state.movePocket,
                    moveBall: state.moveBall
                )

                if state.screenshotAnalysisInProgress {
                    ProgressView("Analyzing screenshot on device")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    state.reviewMode = 0
                } label: {
                    Label("Adjust Corners", systemImage: "viewfinder")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(CuePilotTheme.teal)

                Picker("Review mode", selection: $state.reviewMode) {
                    Text("Table").tag(0)
                    Text("Balls").tag(1)
                    Text("Pockets").tag(2)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(state.detectionStatus)
                        .font(.system(size: 17, weight: .medium))
                    Spacer()
                    Text(state.detectionConfidence, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        .foregroundStyle(CuePilotTheme.teal)
                }

                if let selectedBall = state.selectedBall {
                    Picker(
                        "Selected ball",
                        selection: Binding(
                            get: {
                                state.selectedBall?.appearance
                                    ?? selectedBall.appearance
                            },
                            set: {
                                state.classifyBall(
                                    id: selectedBall.id,
                                    as: $0
                                )
                            }
                        )
                    ) {
                        ForEach(BallAppearance.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityHint(
                        "Corrects the selected ball classification used by the rules engine."
                    )
                }

                Button {
                    state.addBall()
                } label: {
                    Label("Add Ball", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .font(.system(size: 17, weight: .medium))
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: CuePilotTheme.controlRadius))

                Button(role: .destructive) {
                    state.removeSelectedBall()
                } label: {
                    Label("Remove Selected", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .font(.system(size: 17, weight: .medium))
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: CuePilotTheme.controlRadius))
                .disabled(state.selectedBallID == nil)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Shot rules")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Picker("Your group", selection: $state.group) {
                        ForEach(PlayerGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Your turn", isOn: $state.isUsersTurn)

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
                            state.requiresEightBallPocket
                                ? "Required before solving an 8-ball shot."
                                : "Used when your group has been cleared."
                        )
                    }
                }
                .padding(.vertical, 4)

                if state.needsManualGeometryConfirmation {
                    Button("Confirm Manual Geometry") {
                        state.confirmManualGeometry()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .buttonStyle(.borderedProminent)
                    .tint(CuePilotTheme.caution)
                }

                if let validationMessage =
                    state.detectionValidationMessage {
                    Label(
                        validationMessage,
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CuePilotTheme.caution)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Continue") {
                    if state.finishDetectionReview() {
                        router.open(.shotResult)
                    }
                }
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    state.canFinishDetectionReview
                        ? CuePilotTheme.teal
                        : CuePilotTheme.elevated
                )
                .foregroundStyle(
                    state.canFinishDetectionReview
                        ? .white
                        : .secondary
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CuePilotTheme.controlRadius,
                        style: .continuous
                    )
                )
                .disabled(!state.canFinishDetectionReview)
            }
            .padding(.horizontal, CuePilotTheme.contentPadding)
            .padding(.bottom, 28)
        }
        .navigationTitle("Detection Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
