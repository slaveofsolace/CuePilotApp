@preconcurrency import AVFoundation
@preconcurrency import AVKit
import CoreGraphics
import CoreMedia
import CoreVideo
import CuePresentation
import CueStrategy
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class PictureInPictureGuide: NSObject {
    let displayLayer = AVSampleBufferDisplayLayer()

    private(set) var controller: AVPictureInPictureController?
    private(set) var isActive = false
    private(set) var isPossible = false
    private(set) var hasLiveData = false

    var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    func prepare() {
        guard isSupported, controller == nil else { return }

        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        renderNeutral()

        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        self.controller = controller
        isPossible = controller.isPictureInPicturePossible

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            isPossible = false
        }
    }

    func start() {
        guard let controller else { return }
        isPossible = controller.isPictureInPicturePossible
        guard isPossible else { return }
        controller.startPictureInPicture()
    }

    func stop() {
        controller?.stopPictureInPicture()
    }

    func renderNeutral() {
        hasLiveData = false
        enqueueFrame(
            status: "SEARCHING",
            power: "NO LIVE DATA",
            confidence: "",
            showsLiveGeometry: false
        )
    }

    func clearLiveData() {
        displayLayer.sampleBufferRenderer.flush(
            removingDisplayedImage: true,
            completionHandler: nil
        )
        renderNeutral()
    }

    func render(liveState: CompactLiveState) {
        hasLiveData = true
        let status = label(for: liveState.alignment)
        let minimum = Int(
            (liveState.recommendedPowerMinimum * 100).rounded()
        )
        let maximum = Int(
            (liveState.recommendedPowerMaximum * 100).rounded()
        )
        let confidence = Int((liveState.confidence * 100).rounded())
        enqueueFrame(
            status: status,
            power: "POWER \(minimum)–\(maximum)%",
            confidence: "\(confidence)% confidence",
            showsLiveGeometry: true
        )
    }

    private func enqueueFrame(
        status: String,
        power: String,
        confidence: String,
        showsLiveGeometry: Bool
    ) {
        guard let pixelBuffer = makeGuidePixelBuffer(
            status: status,
            power: power,
            confidence: confidence,
            showsLiveGeometry: showsLiveGeometry
        ) else {
            return
        }

        var formatDescription: CMVideoFormatDescription?
        guard
            CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &formatDescription
            ) == noErr,
            let formatDescription
        else {
            return
        }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 15),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard
            CMSampleBufferCreateReadyWithImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescription: formatDescription,
                sampleTiming: &timing,
                sampleBufferOut: &sampleBuffer
            ) == noErr,
            let sampleBuffer
        else {
            return
        }

        CMSetAttachment(
            sampleBuffer,
            key: kCMSampleAttachmentKey_DisplayImmediately,
            value: kCFBooleanTrue,
            attachmentMode: kCMAttachmentMode_ShouldNotPropagate
        )
        let renderer = displayLayer.sampleBufferRenderer
        if renderer.status == .failed {
            renderer.flush()
        }
        renderer.enqueue(sampleBuffer)
    }

    private func makeGuidePixelBuffer(
        status: String,
        power: String,
        confidence: String,
        showsLiveGeometry: Bool
    ) -> CVPixelBuffer? {
        let width = 640
        let height = 360
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:],
        ]
        var pixelBuffer: CVPixelBuffer?
        guard
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &pixelBuffer
            ) == kCVReturnSuccess,
            let pixelBuffer
        else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            )
        else {
            return nil
        }

        context.setFillColor(
            UIColor(red: 13 / 255, green: 16 / 255, blue: 18 / 255, alpha: 1)
                .cgColor
        )
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let table = CGRect(x: 26, y: 38, width: 400, height: 284)
        context.setFillColor(
            UIColor(red: 13 / 255, green: 79 / 255, blue: 81 / 255, alpha: 1)
                .cgColor
        )
        context.fill(table)

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.28).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: table.midX - 30, y: table.midY))
        context.addLine(to: CGPoint(x: table.midX + 30, y: table.midY))
        context.move(to: CGPoint(x: table.midX, y: table.midY - 30))
        context.addLine(to: CGPoint(x: table.midX, y: table.midY + 30))
        context.strokePath()

        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (status as NSString).draw(
            in: CGRect(x: 438, y: 118, width: 188, height: 40),
            withAttributes: [
                .font: UIFont.systemFont(ofSize: 25, weight: .bold),
                .foregroundColor: showsLiveGeometry
                    ? UIColor(
                        red: 120 / 255,
                        green: 214 / 255,
                        blue: 91 / 255,
                        alpha: 1
                    )
                    : UIColor.lightGray,
                .paragraphStyle: paragraph,
            ]
        )
        (power as NSString).draw(
            in: CGRect(x: 438, y: 174, width: 188, height: 32),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(
                    ofSize: 18,
                    weight: .semibold
                ),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
        )
        (confidence as NSString).draw(
            in: CGRect(x: 438, y: 214, width: 188, height: 28),
            withAttributes: [
                .font: UIFont.monospacedDigitSystemFont(
                    ofSize: 14,
                    weight: .regular
                ),
                .foregroundColor: UIColor.lightGray,
                .paragraphStyle: paragraph,
            ]
        )
        return pixelBuffer
    }

    private func label(for state: GuidanceState) -> String {
        switch state {
        case .searching:
            "SEARCHING"
        case .analyzing:
            "ANALYZING"
        case .rotateLeft:
            "ROTATE LEFT"
        case .rotateRight:
            "ROTATE RIGHT"
        case .fineAlignment:
            "FINE ALIGNMENT"
        case .aimLocked:
            "AIM LOCKED"
        case .morePower:
            "MORE POWER"
        case .lessPower:
            "LESS POWER"
        case .ready:
            "READY"
        case .doNotShoot:
            "DO NOT SHOOT"
        case .waitingForTurn:
            "WAITING"
        }
    }
}

extension PictureInPictureGuide:
    @preconcurrency AVPictureInPictureControllerDelegate,
    @preconcurrency AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {}

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        isActive = true
        isPossible = true
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        isActive = false
        isPossible =
            pictureInPictureController.isPictureInPicturePossible
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isActive = false
        isPossible = false
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {}

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        false
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping @Sendable () -> Void
    ) {
        completionHandler()
    }
}

struct PictureInPicturePreview: UIViewRepresentable {
    let guide: PictureInPictureGuide

    func makeUIView(context: Context) -> LayerHostView {
        let view = LayerHostView()
        view.hostedLayer = guide.displayLayer
        return view
    }

    func updateUIView(_ uiView: LayerHostView, context: Context) {
        uiView.hostedLayer = guide.displayLayer
    }
}

final class LayerHostView: UIView {
    var hostedLayer: CALayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            if let hostedLayer {
                layer.addSublayer(hostedLayer)
                setNeedsLayout()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostedLayer?.frame = bounds
    }
}
