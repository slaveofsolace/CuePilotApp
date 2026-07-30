import AppKit
import CueGeometry
import CueStrategy
import CueVision
import SwiftUI

struct CuePilotRootView: View {
    @ObservedObject var model: CuePilotMacModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 176, ideal: 205, max: 245)
        } detail: {
            detail
                .frame(minWidth: 620, minHeight: 540)
        }
        .navigationTitle(model.destination.title)
        .toolbar {
            CuePilotToolbar(model: model)
        }
        .inspector(isPresented: $model.isInspectorPresented) {
            CaptureInspectorView(model: model)
                .inspectorColumnWidth(min: 255, ideal: 280, max: 330)
        }
        .onDisappear {
            model.stopAnalysis()
        }
    }

    private var sidebar: some View {
        List(selection: $model.destination) {
            Section("Capture") {
                NavigationLink(value: SidebarDestination.capture) {
                    Label("Capture", systemImage: SidebarDestination.capture.systemImage)
                }
            }
            Section("Setup") {
                NavigationLink(value: SidebarDestination.calibration) {
                    Label(
                        "Calibration",
                        systemImage: SidebarDestination.calibration.systemImage
                    )
                }
            }
            Section("CuePilot") {
                NavigationLink(value: SidebarDestination.settings) {
                    Label("Settings", systemImage: SidebarDestination.settings.systemImage)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: model.isAligned ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(model.isAligned ? .green : .secondary)
                Text(model.isAligned ? "Overlay aligned" : model.lifecycle.title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.destination {
        case .capture:
            CaptureWorkspaceView(model: model)
        case .calibration:
            CalibrationView(model: model)
        case .settings:
            CuePilotSettingsView(model: model, embedded: true)
        }
    }
}

private struct CuePilotToolbar: ToolbarContent {
    @ObservedObject var model: CuePilotMacModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Menu {
                if model.availableWindows.isEmpty {
                    Text("No iPhone Mirroring windows")
                } else {
                    ForEach(model.availableWindows) { window in
                        Button {
                            model.selectWindow(window.id)
                        } label: {
                            if model.selectedWindowID == window.id {
                                Label(window.displayName, systemImage: "checkmark")
                            } else if window.isLikelyIPhoneMirroring {
                                Label(window.displayName, systemImage: "iphone")
                            } else {
                                Text(window.displayName)
                            }
                        }
                    }
                }
                Divider()
                Button {
                    Task {
                        await model.refreshWindows()
                    }
                } label: {
                    Label("Refresh Windows", systemImage: "arrow.clockwise")
                }
                Button {
                    model.openIPhoneMirroring()
                } label: {
                    Label("Open iPhone Mirroring", systemImage: "iphone")
                }
            } label: {
                Label(
                    model.selectedWindow?.displayName ?? "Select Mirroring Window",
                    systemImage: "iphone.gen3"
                )
                .lineLimit(1)
            }
            .help("Select the iPhone Mirroring window to capture")
        }

        ToolbarItem(placement: .principal) {
            Button {
                model.toggleAnalysis()
            } label: {
                Label(
                    model.analysisEnabled ? "Stop Analysis" : "Start Analysis",
                    systemImage: model.analysisEnabled ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(model.analysisEnabled ? .red : .accentColor)
            .help(
                model.analysisEnabled
                    ? "Stop analysis and hide the overlay"
                    : "Analyze live frames and show the aligned overlay"
            )
        }

        ToolbarItem(placement: .status) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(nsColor: model.captureStatusColor))
                Text(model.lifecycle.title)
                    .lineLimit(1)
            }
            .font(.callout)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Capture status: \(model.lifecycle.title)")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                model.isInspectorPresented.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.trailing")
            }
            .help("Show or hide the capture inspector")
        }
    }
}

private struct CaptureWorkspaceView: View {
    @ObservedObject var model: CuePilotMacModel

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                captureCanvas(size: proxy.size)
                    .padding(20)
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: model.isAligned ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(model.isAligned ? .green : .secondary)
                Text(captureFooterText)
                Spacer()
                if model.hasCapturedFrame {
                    Text(
                        "\(model.framesPerSecond.formatted(.number.precision(.fractionLength(0)))) FPS"
                    )
                    Text("·")
                    Text(
                        "\(model.frameLatencyMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms"
                    )
                }
            }
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .frame(height: 48)
        }
    }

    @ViewBuilder
    private func captureCanvas(size: CGSize) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.black.opacity(0.28))

            if let frame = model.latestFrameImage {
                LiveFrameView(
                    frame: frame,
                    framePixelSize: model.latestFramePixelSize,
                    analysis: model.latestAnalysis,
                    displayScale: model.calibrationDisplayScale,
                    debugMode: model.debugMode
                )
                .padding(8)
                .transition(.opacity)
            } else {
                CapturePlaceholder(
                    status: model.lifecycle,
                    openMirroring: model.openIPhoneMirroring,
                    refresh: {
                        Task {
                            await model.refreshWindows()
                        }
                    },
                    openPermission: model.revealScreenRecordingSettings
                )
                .padding(24)
                .transition(.opacity)
            }

            if model.analysisEnabled, model.hasCapturedFrame {
                VStack {
                    Spacer()
                    GuidanceBadge(
                        title: model.guidanceTitle,
                        power: model.powerRecommendation,
                        state: model.guidanceState
                    )
                    .padding(.bottom, 22)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(.separator.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            model.hasCapturedFrame
                ? "Live iPhone Mirroring capture"
                : "Waiting for iPhone Mirroring capture"
        )
    }

    private var captureFooterText: String {
        if model.isAligned {
            return "Capture aligned"
        }
        if model.hasCapturedFrame {
            return "Frame received · waiting for window registration"
        }
        return model.lifecycle.title
    }
}

private struct LiveFrameView: View {
    let frame: NSImage
    let framePixelSize: CGSize
    let analysis: AnalysisPacket?
    let displayScale: Double
    let debugMode: Bool

    var body: some View {
        GeometryReader { proxy in
            let fitted = AspectFit.frame(
                contentSize: framePixelSize,
                in: proxy.size
            )
            ZStack {
                Image(nsImage: frame)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fitted.width, height: fitted.height)

                GuidanceDrawingView(
                    state: OverlayRenderState(
                        analysis: analysis?.analysis,
                        recommendation: analysis?.recommendation,
                        guidanceState: analysis?.guidance?.guidance.state,
                        analysisImageSize: analysis?.imageSize ?? .zero,
                        capturedFramePixelSize: framePixelSize,
                        registration: .unavailable,
                        usesScreenRegistration: false,
                        calibrationDisplayScale: displayScale,
                        debugMode: debugMode,
                        statusText: "",
                        powerText: nil
                    ),
                    canvasSize: fitted.size
                )
                .frame(width: fitted.width, height: fitted.height)
            }
            .position(x: fitted.midX, y: fitted.midY)
        }
    }
}

private struct GuidanceBadge: View {
    let title: String
    let power: String?
    let state: GuidanceState?

    var body: some View {
        VStack(spacing: 3) {
            Label(title, systemImage: state?.symbol ?? "viewfinder")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            if let power {
                Text(power)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.72), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch state {
        case .aimLocked, .ready:
            .green
        case .doNotShoot:
            .red
        case .morePower, .lessPower:
            .yellow
        default:
            .cyan
        }
    }
}

private struct CapturePlaceholder: View {
    let status: CaptureLifecycle
    let openMirroring: () -> Void
    let refresh: () -> Void
    let openPermission: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.16),
                            Color.mint.opacity(0.08),
                            Color.black.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 2)
                }
                .aspectRatio(1.6, contentMode: .fit)
                .padding(42)
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Image(systemName: status.symbol)
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text(status.title)
                    .font(.title2.weight(.semibold))
                Text(instruction)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 430)
                HStack {
                    if status == .permissionRequired {
                        Button("Open Screen Recording Settings", action: openPermission)
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Open iPhone Mirroring", action: openMirroring)
                            .buttonStyle(.borderedProminent)
                        Button("Refresh", action: refresh)
                    }
                }
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var instruction: String {
        switch status {
        case .permissionRequired:
            "Allow CuePilot to record the selected window, then return and refresh. Frames remain on this Mac."
        case .failed:
            "The selected window could not be captured. Reopen iPhone Mirroring and choose it again."
        default:
            "Open iPhone Mirroring, show the 8-ball game, select its window, then choose Start Analysis."
        }
    }
}

struct CaptureInspectorView: View {
    @ObservedObject var model: CuePilotMacModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                inspectorSection("Capture Status") {
                    LabeledContent("State") {
                        Label(model.lifecycle.title, systemImage: model.lifecycle.symbol)
                    }
                    LabeledContent("Source") {
                        Text(model.selectedWindow?.displayName ?? "None")
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Frame rate") {
                        Text(
                            "\(model.framesPerSecond.formatted(.number.precision(.fractionLength(0)))) FPS"
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("Frame latency") {
                        Text(
                            "\(model.frameLatencyMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms"
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("Analysis") {
                        Text(
                            "\(model.analysisLatencyMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms"
                        )
                        .monospacedDigit()
                    }
                }

                Divider()

                inspectorSection("Match State") {
                    Picker("My group", selection: $model.groupAssignment) {
                        ForEach(GroupAssignment.allCases, id: \.self) { group in
                            Text(group.displayTitle).tag(group)
                        }
                    }
                    Picker("Turn", selection: $model.matchTurn) {
                        ForEach(MatchTurn.allCases, id: \.self) { turn in
                            Text(turn.displayTitle).tag(turn)
                        }
                    }
                    Picker(
                        "Called 8-ball pocket",
                        selection: $model.requiredEightBallPocket
                    ) {
                        Text("Not selected").tag(nil as PocketID?)
                        ForEach(PocketID.allCases, id: \.self) { pocket in
                            Text(pocket.displayTitle).tag(Optional(pocket))
                        }
                    }
                    Text(
                        "Group, turn, and called pocket are applied to every live recommendation."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                inspectorSection("Alignment") {
                    LabeledContent("Registration") {
                        Label(
                            model.isAligned ? "Aligned" : "Waiting",
                            systemImage: model.isAligned
                                ? "checkmark.circle.fill"
                                : "circle.dashed"
                        )
                        .foregroundStyle(model.isAligned ? .green : .secondary)
                    }
                    LabeledContent("Scale") {
                        Text(
                            model.registration.scaleFactor.formatted(
                                .number.precision(.fractionLength(2))
                            ) + "×"
                        )
                        .monospacedDigit()
                    }
                    LabeledContent("Confidence") {
                        Text(model.analysisConfidenceText)
                            .monospacedDigit()
                    }
                    Button("Recalibrate") {
                        model.showCalibration()
                    }
                }

                Divider()

                inspectorSection("Overlay") {
                    HStack {
                        Image(systemName: "sun.min")
                        Slider(value: $model.overlayOpacity, in: 0.2 ... 1)
                        Text(
                            model.overlayOpacity.formatted(
                                .percent.precision(.fractionLength(0))
                            )
                        )
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                    }
                    Toggle("Debug Mode", isOn: $model.debugMode)
                    Picker("Hotkey", selection: $model.hotKeyChoice) {
                        ForEach(HotKeyChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                }

                if model.permissionHelpVisible {
                    Divider()
                    Button("Open Screen Recording Settings") {
                        model.revealScreenRecordingSettings()
                    }
                }
            }
            .padding(18)
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }
}

struct CalibrationView: View {
    @ObservedObject var model: CuePilotMacModel

    var body: some View {
        Form {
            Section {
                Text(
                    "Use a stable mirrored game frame before changing calibration. " +
                        "These values adjust guidance display only; they never control the game."
                )
                .foregroundStyle(.secondary)
            } header: {
                Label("Overlay Calibration", systemImage: "scope")
            }

            Section("Alignment") {
                LabeledContent("Window registration") {
                    Label(
                        model.isAligned ? "Aligned" : "No live registration",
                        systemImage: model.isAligned
                            ? "checkmark.circle.fill"
                            : "exclamationmark.circle"
                    )
                    .foregroundStyle(model.isAligned ? .green : .secondary)
                }
                HStack {
                    Text("Aim bias")
                    Slider(
                        value: $model.calibrationAimBias,
                        in: -4 ... 4,
                        step: 0.1
                    )
                    Text(
                        model.calibrationAimBias.formatted(
                            .number.precision(.fractionLength(1))
                        ) + "°"
                    )
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
                }
                HStack {
                    Text("Display scale")
                    Slider(
                        value: $model.calibrationDisplayScale,
                        in: 0.9 ... 1.1,
                        step: 0.005
                    )
                    Text(
                        model.calibrationDisplayScale.formatted(
                            .percent.precision(.fractionLength(1))
                        )
                    )
                    .monospacedDigit()
                    .frame(width: 58, alignment: .trailing)
                }
            }

            Section {
                Button("Reset Calibration") {
                    model.calibrationAimBias = 0
                    model.calibrationDisplayScale = 1
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct CuePilotSettingsView: View {
    @ObservedObject var model: CuePilotMacModel
    var embedded = false

    var body: some View {
        Form {
            Section("Capture") {
                LabeledContent("Preferred source") {
                    Text("iPhone Mirroring")
                }
                Text(
                    "Capture begins only after you choose Start Analysis and ends when you stop. CuePilot captures only the selected window; it does not record audio, click, or automate iPhone Mirroring."
                )
                .foregroundStyle(.secondary)
            }

            Section("Overlay") {
                HStack {
                    Text("Opacity")
                    Slider(value: $model.overlayOpacity, in: 0.2 ... 1)
                    Text(
                        model.overlayOpacity.formatted(
                            .percent.precision(.fractionLength(0))
                        )
                    )
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                }
                Toggle("Show diagnostics on overlay", isOn: $model.debugMode)
                Picker("Analysis hotkey", selection: $model.hotKeyChoice) {
                    ForEach(HotKeyChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
            }

            Section("Privacy") {
                Label("Frame analysis stays on this Mac", systemImage: "lock.shield")
                Label("Captured frames are not saved", systemImage: "externaldrive.badge.xmark")
            }

            if embedded {
                Section {
                    SettingsLink {
                        Label("Open Settings Window", systemImage: "gearshape")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: embedded ? 0 : 520, minHeight: embedded ? 0 : 420)
    }
}

private enum AspectFit {
    static func frame(contentSize: CGSize, in container: CGSize) -> CGRect {
        guard contentSize.width > 0,
              contentSize.height > 0,
              container.width > 0,
              container.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let scale = min(
            container.width / contentSize.width,
            container.height / contentSize.height
        )
        let size = CGSize(
            width: contentSize.width * scale,
            height: contentSize.height * scale
        )
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}
