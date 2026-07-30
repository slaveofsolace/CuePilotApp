import SwiftUI

struct LiveAssistSetupView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CuePilotState.self) private var state

    var body: some View {
        @Bindable var state = state

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                setupStep(number: 1, title: "Start Broadcast") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Approve the system screen broadcast, then return here.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)

                        BroadcastPickerButton()
                        .frame(height: 64)
                        .background(CuePilotTheme.teal)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: CuePilotTheme.controlRadius,
                                style: .continuous
                            )
                        )

                        connectionStatus(
                            active: state.broadcastActive,
                            activeText: "Live frames received",
                            pendingText: "Waiting for broadcast frames"
                        )
                    }
                }

                setupStep(number: 2, title: "Start Picture in Picture") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start the live visual guide from this screen.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)

                        Button {
                            state.pictureInPicture.prepare()
                            state.pictureInPicture.start()
                        } label: {
                            Label("Start PiP", systemImage: "pip.enter")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 64)
                                .foregroundStyle(.white)
                                .background(CuePilotTheme.teal)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: CuePilotTheme.controlRadius,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!state.pictureInPicture.isSupported)

                        PictureInPicturePreview(
                            guide: state.pictureInPicture
                        )
                        .frame(height: 104)
                        .background(.black)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                        )
                        .accessibilityLabel(
                            "Picture in Picture guidance preview"
                        )

                        connectionStatus(
                            active: state.pictureInPictureActive,
                            activeText: "PiP active",
                            pendingText:
                                pictureInPicturePendingText
                        )
                    }
                }

                setupStep(number: 3, title: "Return to your game") {
                    Text(
                        "Keep the system broadcast and PiP guide visible. "
                        + "You remain in control of every aim and shot."
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    privacyRow(
                        title: "Frames stay on this device",
                        detail: "No frame is sent to a server.",
                        image: "lock"
                    )
                    privacyRow(
                        title: "No recording is retained",
                        detail: "Frame buffers are discarded after analysis.",
                        image: "shield"
                    )
                }
                .padding(.top, 8)

                Button("Done") {
                    router.open(.shotResult)
                }
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(
                    state.broadcastActive && state.pictureInPictureActive
                        ? CuePilotTheme.teal
                        : CuePilotTheme.elevated
                )
                .foregroundStyle(
                    state.broadcastActive && state.pictureInPictureActive
                        ? .white
                        : .secondary
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: CuePilotTheme.controlRadius,
                        style: .continuous
                    )
                )
                .disabled(!(state.broadcastActive && state.pictureInPictureActive))
                .padding(.top, 28)
            }
            .padding(.horizontal, CuePilotTheme.contentPadding)
            .padding(.bottom, 28)
        }
        .navigationTitle("Live Assist Setup")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            state.pictureInPicture.prepare()
            state.pictureInPicture.renderNeutral()
        }
    }

    private func setupStep<Content: View>(
        number: Int,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CuePilotTheme.teal)
                .frame(width: 38, height: 38)
                .overlay {
                    Circle().stroke(CuePilotTheme.teal, lineWidth: 2)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 16) {
                Text("\(number). \(title)")
                    .font(.system(size: 23, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                content()
            }
        }
        .padding(.vertical, 24)
        .overlay(alignment: .bottom) {
            Divider().overlay(CuePilotTheme.separator)
        }
    }

    private func connectionStatus(
        active: Bool,
        activeText: String,
        pendingText: String
    ) -> some View {
        Label(active ? activeText : pendingText, systemImage: "circle.fill")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(active ? CuePilotTheme.locked : CuePilotTheme.caution)
            .symbolRenderingMode(.monochrome)
            .accessibilityLabel(active ? activeText : pendingText)
    }

    private func privacyRow(
        title: String,
        detail: String,
        image: String
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: image)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(CuePilotTheme.teal)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 15)
        .overlay(alignment: .bottom) {
            Divider().overlay(CuePilotTheme.separator)
        }
    }

    private var pictureInPicturePendingText: String {
        guard state.pictureInPicture.isSupported else {
            return "Unavailable"
        }
        return state.pictureInPictureReady
            ? "Ready — not active"
            : "Preparing"
    }
}
