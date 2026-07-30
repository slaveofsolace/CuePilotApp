import PhotosUI
import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(CuePilotState.self) private var state
    @State private var selectedScreenshot: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    CuePilotMark()
                    Text("CuePilot")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.top, 18)
                .padding(.bottom, 16)

                ActionRow(
                    title: "Start Live Assist",
                    systemImage: "scope",
                    prominent: true
                ) {
                    router.open(.liveSetup)
                }

                ActionRow(
                    title: "Resume Match",
                    systemImage: "arrow.counterclockwise.circle"
                ) {
                    router.open(.matchSession)
                }

                Divider()
                    .overlay(CuePilotTheme.separator)
                    .padding(.vertical, 4)

                PhotosPicker(selection: $selectedScreenshot, matching: .images) {
                    homeRowLabel(
                        title: "Analyze Latest Screenshot",
                        systemImage: "photo.badge.magnifyingglass"
                    )
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $selectedScreenshot, matching: .images) {
                    homeRowLabel(
                        title: "Select Screenshot",
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.plain)

                Divider()
                    .overlay(CuePilotTheme.separator)
                    .padding(.vertical, 4)

                navigationRow(
                    title: "Calibration",
                    systemImage: "scope",
                    route: .calibration
                )
                navigationRow(
                    title: "Secondary Tools",
                    systemImage: "wrench.and.screwdriver",
                    route: .secondaryTools
                )
                navigationRow(
                    title: "Settings",
                    systemImage: "gearshape",
                    route: .settings
                )

                Label(
                    "On-device analysis. No recordings saved.",
                    systemImage: "lock"
                )
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.top, 14)
                .accessibilityLabel(
                    "Privacy: analysis stays on this device and no recording is saved."
                )
            }
            .padding(.horizontal, CuePilotTheme.contentPadding)
            .padding(.bottom, 28)
        }
        .navigationBarHidden(true)
        .task(id: selectedScreenshot) {
            guard let selectedScreenshot else { return }
            do {
                guard let data = try await selectedScreenshot
                    .loadTransferable(type: Data.self),
                    !Task.isCancelled else {
                    state.failScreenshotLoad()
                    return
                }
                state.loadScreenshot(data: data)
                router.open(.detectionReview)
            } catch is CancellationError {
                return
            } catch {
                state.failScreenshotLoad()
            }
        }
    }

    private func navigationRow(
        title: String,
        systemImage: String,
        route: AppRoute
    ) -> some View {
        Button {
            router.open(route)
        } label: {
            homeRowLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    nonisolated private func homeRowLabel(
        title: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(CuePilotTheme.teal)
                .frame(width: 30)
            Text(title)
                .font(.system(size: 18, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Divider().overlay(CuePilotTheme.separator)
        }
    }
}
