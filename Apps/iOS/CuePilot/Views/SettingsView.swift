import SwiftUI

struct SettingsView: View {
    @Environment(CuePilotState.self) private var state
    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Analysis") {
                Picker("Analysis Mode", selection: $state.analysisMode) {
                    Text("Speed").tag(0)
                    Text("Balanced").tag(1)
                    Text("Accuracy").tag(2)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Confidence Threshold")
                        Spacer()
                        Text(
                            state.confidenceThreshold,
                            format: .percent.precision(.fractionLength(0))
                        )
                        .monospacedDigit()
                    }
                    Slider(value: $state.confidenceThreshold, in: 0.5 ... 0.95, step: 0.05)
                }
            }

            Section("Guidance") {
                Toggle("Audio Guidance", isOn: $state.audioGuidance)
                NavigationLink {
                    OverlayAppearanceView()
                } label: {
                    Label("Overlay Appearance", systemImage: "eye")
                }
            }

            Section("Privacy") {
                LabeledContent("On-device only") {
                    Label("Confirmed", systemImage: "checkmark.circle")
                        .foregroundStyle(CuePilotTheme.locked)
                }
                NavigationLink {
                    PrivacyDetailsView()
                } label: {
                    Label("Privacy Details", systemImage: "shield")
                }
            }

            Section {
                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Label("Diagnostics", systemImage: "waveform.path.ecg")
                }

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset Calibration", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Maintenance")
            } footer: {
                Text("CuePilot 0.1.0")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Reset calibration?",
            isPresented: $showResetConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                state.resetCalibration()
            }
        } message: {
            Text("Aim and power adjustments learned on this device will be removed.")
        }
    }
}

private struct OverlayAppearanceView: View {
    @Environment(CuePilotState.self) private var state

    var body: some View {
        @Bindable var state = state

        Form {
            Section("Overlay") {
                LabeledContent(
                    "Opacity",
                    value: state.overlayOpacity,
                    format: .percent.precision(.fractionLength(0))
                )
                Slider(value: $state.overlayOpacity, in: 0.35 ... 1, step: 0.05)
            }

            Section {
                TableDiagramView(balls: state.balls)
                    .frame(maxHeight: 320)
                    .opacity(state.overlayOpacity)
            } header: {
                Text("Preview")
            }
        }
        .navigationTitle("Overlay Appearance")
    }
}

private struct PrivacyDetailsView: View {
    var body: some View {
        List {
            privacyItem(
                "On-device processing",
                "Screen frames are analyzed locally."
            )
            privacyItem(
                "No retained recording",
                "Screen frames are discarded after analysis."
            )
            privacyItem(
                "No analytics or ads",
                "The app contains no analytics or advertising SDK."
            )
            privacyItem(
                "Local diagnostics",
                "Performance summaries stay on this device."
            )
        }
        .navigationTitle("Privacy")
    }

    private func privacyItem(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
            Text(detail)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct DiagnosticsView: View {
    var body: some View {
        List {
            LabeledContent("App version", value: "0.1.0 (1)")
            LabeledContent("Frame upload", value: "Disabled")
            LabeledContent("Recording retention", value: "Disabled")
            LabeledContent("Calibration storage", value: "Local")
            Button("Export Anonymous Diagnostics") {
                // The diagnostics service supplies a user-initiated export document.
            }
        }
        .navigationTitle("Diagnostics")
    }
}
