@preconcurrency import AppKit
@preconcurrency import CoreImage
@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import CueVision
import Foundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class WindowCaptureService {
    var onFrame: ((CapturedFrame) -> Void)?
    var onFailure: ((String) -> Void)?
    var onRegistrationChange: ((FrameRegistration) -> Void)?

    private(set) var windows: [CaptureWindowOption] = []
    private(set) var selectedWindowID: CGWindowID?

    private var sourceWindows: [CGWindowID: SCWindow] = [:]
    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    private var alignmentTask: Task<Void, Never>?

    func discoverWindows() async throws -> [CaptureWindowOption] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let candidates = content.windows.compactMap { window -> (SCWindow, CaptureWindowOption)? in
            guard window.owningApplication?.processID != ownPID,
                  window.frame.width >= 180,
                  window.frame.height >= 240,
                  window.isOnScreen else {
                return nil
            }

            let applicationName = window.owningApplication?.applicationName ?? "Application"
            let title = window.title ?? ""
            let searchable = "\(applicationName) \(title)"
            let likelyMirroring =
                searchable.localizedCaseInsensitiveContains("iPhone Mirroring") ||
                (
                    searchable.localizedCaseInsensitiveContains("iPhone") &&
                    searchable.localizedCaseInsensitiveContains("Mirror")
                )
            return (
                window,
                CaptureWindowOption(
                    id: window.windowID,
                    applicationName: applicationName,
                    title: title,
                    frame: window.frame,
                    isLikelyIPhoneMirroring: likelyMirroring
                )
            )
        }
        .filter { $0.1.isLikelyIPhoneMirroring }
        .sorted {
            if $0.1.isLikelyIPhoneMirroring != $1.1.isLikelyIPhoneMirroring {
                return $0.1.isLikelyIPhoneMirroring
            }
            if $0.1.applicationName != $1.1.applicationName {
                return $0.1.applicationName.localizedStandardCompare(
                    $1.1.applicationName
                ) == .orderedAscending
            }
            return $0.1.title.localizedStandardCompare($1.1.title) == .orderedAscending
        }

        sourceWindows = Dictionary(uniqueKeysWithValues: candidates.map { ($0.0.windowID, $0.0) })
        windows = candidates.map(\.1)
        return windows
    }

    func startCapture(
        windowID: CGWindowID,
        analysisEnabled: Bool
    ) async throws {
        guard let sourceWindow = sourceWindows[windowID] else {
            throw CaptureServiceError.windowUnavailable
        }

        await stopCapture()

        let filter = SCContentFilter(desktopIndependentWindow: sourceWindow)
        let configuration = SCStreamConfiguration()
        let scale = backingScale(for: sourceWindow.frame)
        configuration.width = max(2, Int((sourceWindow.frame.width * scale).rounded()))
        configuration.height = max(2, Int((sourceWindow.frame.height * scale).rounded()))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.ignoreShadowsSingleWindow = true

        let output = CaptureStreamOutput(
            analysisEnabled: analysisEnabled,
            frameHandler: { [weak self] frame in
                Task { @MainActor in
                    self?.onFrame?(frame)
                }
            },
            failureHandler: { [weak self] message in
                Task { @MainActor in
                    self?.onFailure?(message)
                }
            }
        )
        let captureStream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: output
        )
        try captureStream.addStreamOutput(
            output,
            type: .screen,
            sampleHandlerQueue: output.sampleQueue
        )

        streamOutput = output
        stream = captureStream
        selectedWindowID = windowID
        try await captureStream.startCapture()
        startAlignmentTracking(windowID: windowID)
    }

    func setAnalysisEnabled(_ enabled: Bool) {
        streamOutput?.setAnalysisEnabled(enabled)
    }

    func stopCapture() async {
        alignmentTask?.cancel()
        alignmentTask = nil
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        streamOutput = nil
        selectedWindowID = nil
    }

    private func backingScale(for quartzFrame: CGRect) -> Double {
        let appKitFrame = WindowGeometryResolver.appKitRect(fromQuartz: quartzFrame)
        return Double(
            NSScreen.screens.first(where: { $0.frame.intersects(appKitFrame) })?
                .backingScaleFactor ?? 2
        )
    }

    private func startAlignmentTracking(windowID: CGWindowID) {
        alignmentTask?.cancel()
        alignmentTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let registration = WindowGeometryResolver.registration(
                    for: windowID
                )
                self.onRegistrationChange?(registration)
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }
}

enum CaptureServiceError: LocalizedError {
    case windowUnavailable

    var errorDescription: String? {
        switch self {
        case .windowUnavailable:
            "The selected window is no longer available."
        }
    }
}

final class CaptureStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let sampleQueue = DispatchQueue(
        label: "com.slaveofsolace.cuepilot.capture",
        qos: .userInteractive
    )

    private let frameHandler: @Sendable (CapturedFrame) -> Void
    private let failureHandler: @Sendable (String) -> Void
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let stateLock = NSLock()
    private var analysisEnabled: Bool
    private var lastAnalysisTime: UInt64 = 0

    init(
        analysisEnabled: Bool,
        frameHandler: @escaping @Sendable (CapturedFrame) -> Void,
        failureHandler: @escaping @Sendable (String) -> Void
    ) {
        self.analysisEnabled = analysisEnabled
        self.frameHandler = frameHandler
        self.failureHandler = failureHandler
        super.init()
    }

    func setAnalysisEnabled(_ enabled: Bool) {
        stateLock.withLock {
            analysisEnabled = enabled
            if !enabled {
                lastAnalysisTime = 0
            }
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else {
            return
        }

        let attachments = frameAttachments(sampleBuffer)
        let status = frameStatus(from: attachments)
        let isComplete = status == .complete || status == .started
        guard isComplete else {
            return
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard frameHasVisibleSignal(pixelBuffer) else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        let analysisClockNanoseconds = DispatchTime.now().uptimeNanoseconds
        let shouldAnalyze = stateLock.withLock { () -> Bool in
            guard analysisEnabled else { return false }
            let minimumInterval: UInt64 = 83_000_000
            guard lastAnalysisTime == 0 ||
                    analysisClockNanoseconds - lastAnalysisTime >= minimumInterval else {
                return false
            }
            lastAnalysisTime = analysisClockNanoseconds
            return true
        }
        let analysisImage = shouldAnalyze
            ? makeDownsampledRGBA(from: pixelBuffer, maximumDimension: 720)
            : nil

        frameHandler(
            CapturedFrame(
                image: cgImage,
                analysisImage: analysisImage,
                registration: frameRegistration(
                    attachments: attachments,
                    fallbackPixelSize: CGSize(
                        width: CVPixelBufferGetWidth(pixelBuffer),
                        height: CVPixelBufferGetHeight(pixelBuffer)
                    )
                ),
                latencyMilliseconds: frameLatency(
                    attachments: attachments,
                    nowAbsoluteTicks: mach_absolute_time()
                ),
                receivedAt: ContinuousClock().now,
                isComplete: true
            )
        )
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        failureHandler(error.localizedDescription)
    }

    private func frameAttachments(
        _ sampleBuffer: CMSampleBuffer
    ) -> [SCStreamFrameInfo: Any] {
        guard let array = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]] else {
            return [:]
        }
        return array.first ?? [:]
    }

    private func frameStatus(
        from attachments: [SCStreamFrameInfo: Any]
    ) -> SCFrameStatus {
        let rawValue: Int
        if let number = attachments[.status] as? NSNumber {
            rawValue = number.intValue
        } else if let value = attachments[.status] as? Int {
            rawValue = value
        } else {
            return .complete
        }
        return SCFrameStatus(rawValue: rawValue) ?? .complete
    }

    private func frameRegistration(
        attachments: [SCStreamFrameInfo: Any],
        fallbackPixelSize: CGSize
    ) -> FrameRegistration {
        let screenRect = rectValue(attachments[.screenRect]) ?? .zero
        let rawScaleFactor = numberValue(attachments[.scaleFactor]) ?? 1
        let rawContentScale = numberValue(attachments[.contentScale]) ?? 1
        let scaleFactor = rawScaleFactor.isFinite && rawScaleFactor > 0
            ? rawScaleFactor
            : 1
        let contentScale = rawContentScale.isFinite && rawContentScale > 0
            ? rawContentScale
            : 1
        let fallbackSurfaceSize = CGSize(
            width: fallbackPixelSize.width / CGFloat(scaleFactor),
            height: fallbackPixelSize.height / CGFloat(scaleFactor)
        )
        let contentRect = rectValue(attachments[.contentRect]) ??
            CGRect(origin: .zero, size: fallbackSurfaceSize)
        return FrameRegistration(
            screenRect: screenRect,
            contentRect: contentRect,
            scaleFactor: scaleFactor,
            contentScale: contentScale,
            isOnScreen: !screenRect.isEmpty
        )
    }

    private func frameLatency(
        attachments: [SCStreamFrameInfo: Any],
        nowAbsoluteTicks: UInt64
    ) -> Double {
        guard let displayTime = uint64Value(attachments[.displayTime]),
              nowAbsoluteTicks >= displayTime else {
            return 0
        }
        let nanoseconds = MachTime.nanoseconds(
            fromAbsoluteTicks: nowAbsoluteTicks - displayTime
        )
        let milliseconds = Double(nanoseconds) / 1_000_000
        return milliseconds.isFinite && milliseconds < 10_000 ? milliseconds : 0
    }

    private func makeDownsampledRGBA(
        from pixelBuffer: CVPixelBuffer,
        maximumDimension: Int
    ) -> RGBAImage? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourceRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let largest = max(sourceWidth, sourceHeight)
        let ratio = min(1, Double(maximumDimension) / Double(max(1, largest)))
        let width = max(1, Int((Double(sourceWidth) * ratio).rounded()))
        let height = max(1, Int((Double(sourceHeight) * ratio).rounded()))
        let source = baseAddress.assumingMemoryBound(to: UInt8.self)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let sourceY = min(sourceHeight - 1, y * sourceHeight / height)
            for x in 0..<width {
                let sourceX = min(sourceWidth - 1, x * sourceWidth / width)
                let sourceOffset = sourceY * sourceRowBytes + sourceX * 4
                let destinationOffset = (y * width + x) * 4
                bytes[destinationOffset] = source[sourceOffset + 2]
                bytes[destinationOffset + 1] = source[sourceOffset + 1]
                bytes[destinationOffset + 2] = source[sourceOffset]
                bytes[destinationOffset + 3] = source[sourceOffset + 3]
            }
        }
        return try? RGBAImage(width: width, height: height, bytes: bytes)
    }

    private func frameHasVisibleSignal(_ pixelBuffer: CVPixelBuffer) -> Bool {
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return false
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let source = baseAddress.assumingMemoryBound(to: UInt8.self)
        var minimumLuminance = UInt8.max
        var maximumLuminance = UInt8.min

        for sampleY in 0..<12 {
            let y = min(height - 1, sampleY * height / 12)
            for sampleX in 0..<12 {
                let x = min(width - 1, sampleX * width / 12)
                let offset = y * rowBytes + x * 4
                let blue = UInt16(source[offset])
                let green = UInt16(source[offset + 1])
                let red = UInt16(source[offset + 2])
                let luminance = UInt8(
                    min(255, (red * 54 + green * 183 + blue * 19) >> 8)
                )
                minimumLuminance = min(minimumLuminance, luminance)
                maximumLuminance = max(maximumLuminance, luminance)
            }
        }
        return maximumLuminance > 8 &&
            Int(maximumLuminance) - Int(minimumLuminance) > 4
    }

    private func rectValue(_ value: Any?) -> CGRect? {
        if let rect = value as? CGRect {
            return rect
        }
        if let value = value as? NSValue {
            return value.rectValue
        }
        return nil
    }

    private func numberValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        return value as? Double
    }

    private func uint64Value(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber {
            return number.uint64Value
        }
        return value as? UInt64
    }
}

enum WindowGeometryResolver {
    static func registration(for windowID: CGWindowID) -> FrameRegistration {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow],
            windowID
        ) as? [[CFString: Any]],
        let info = windowInfo.first,
        let boundsValue = info[kCGWindowBounds] else {
            return .unavailable
        }

        // CoreGraphics documents kCGWindowBounds as a CFDictionary.
        // swiftlint:disable:next force_cast
        let boundsDictionary = boundsValue as! CFDictionary
        var quartzRect = CGRect.zero
        guard CGRectMakeWithDictionaryRepresentation(
            boundsDictionary,
            &quartzRect
        ) else {
            return .unavailable
        }
        let isOnScreen = (info[kCGWindowIsOnscreen] as? NSNumber)?.boolValue ?? false
        let alpha = (info[kCGWindowAlpha] as? NSNumber)?.doubleValue ?? 1
        return FrameRegistration(
            screenRect: quartzRect,
            contentRect: CGRect(origin: .zero, size: quartzRect.size),
            scaleFactor: backingScale(forQuartz: quartzRect),
            contentScale: 1,
            isOnScreen: isOnScreen && alpha > 0.01 && !quartzRect.isEmpty
        )
    }

    static func appKitRect(fromQuartz rect: CGRect) -> CGRect {
        let primaryScreen = NSScreen.screens.first(where: {
            abs($0.frame.origin.x) < 0.5 && abs($0.frame.origin.y) < 0.5
        }) ?? NSScreen.screens.first
        guard let primaryScreen else { return rect }
        return CGRect(
            x: rect.minX,
            y: primaryScreen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    private static func backingScale(forQuartz rect: CGRect) -> Double {
        let appKitRect = appKitRect(fromQuartz: rect)
        return Double(
            NSScreen.screens.first(where: { $0.frame.intersects(appKitRect) })?
                .backingScaleFactor ?? 1
        )
    }
}

private enum MachTime {
    static let timebase: mach_timebase_info_data_t = {
        var result = mach_timebase_info_data_t()
        mach_timebase_info(&result)
        return result
    }()

    static func nanoseconds(fromAbsoluteTicks ticks: UInt64) -> UInt64 {
        let numerator = UInt64(timebase.numer)
        let denominator = UInt64(max(1, timebase.denom))
        if ticks > UInt64.max / max(1, numerator) {
            return UInt64(Double(ticks) * Double(numerator) / Double(denominator))
        }
        return ticks * numerator / denominator
    }
}
