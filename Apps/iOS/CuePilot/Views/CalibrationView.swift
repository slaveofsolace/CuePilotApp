import SwiftUI

struct CalibrationView: View {
    @Environment(CuePilotState.self) private var state
    @State private var selectedOutcome = "Pocketed successfully"

    private let outcomes = [
        "Pocketed successfully",
        "Missed left",
        "Missed right",
        "Hit the left jaw",
        "Hit the right jaw",
        "Hit the cushion before the pocket",
        "Too weak",
        "Too hard",
        "Scratched",
        "Cue ball stopped early",
        "Cue ball traveled too far",
        "Unexpected collision",
    ]

    var body: some View {
        Form {
            Section {
                LabeledContent("Profile", value: "This iPhone")
                LabeledContent(
                    "Status",
                    value: state.isCalibrated ? "Calibrated" : "Needs samples"
                )
            } header: {
                Text("Local profile")
            } footer: {
                Text("Calibration remains on this device.")
            }

            Section("Record the last shot") {
                Picker("Outcome", selection: $selectedOutcome) {
                    ForEach(outcomes, id: \.self) { outcome in
                        Text(outcome).tag(outcome)
                    }
                }
                Button("Apply Outcome") {
                    state.isCalibrated = true
                    if selectedOutcome == "Missed left" {
                        state.angularCorrection += 0.1
                    } else if selectedOutcome == "Missed right" {
                        state.angularCorrection -= 0.1
                    }
                }
            }

            Section {
                Button("Reset Calibration", role: .destructive) {
                    state.resetCalibration()
                }
            }
        }
        .navigationTitle("Calibration")
        .navigationBarTitleDisplayMode(.inline)
    }
}
