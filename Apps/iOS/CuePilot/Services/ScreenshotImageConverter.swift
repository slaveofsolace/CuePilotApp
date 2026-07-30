import CoreGraphics
import CueVision
import UIKit

enum ScreenshotImageConverter {
    @MainActor
    static func rgbaImage(
        from image: UIImage,
        maximumDimension: CGFloat = 1_280
    ) -> RGBAImage? {
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else {
            return nil
        }

        let scale = min(
            1,
            maximumDimension / max(originalSize.width, originalSize.height)
        )
        let size = CGSize(
            width: max(1, (originalSize.width * scale).rounded()),
            height: max(1, (originalSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }

        guard let cgImage = normalized.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        let rendered = bytes.withUnsafeMutableBytes { storage -> Bool in
            guard let address = storage.baseAddress,
                  let context = CGContext(
                      data: address,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: width * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo:
                          CGImageAlphaInfo.premultipliedLast.rawValue
                          | CGBitmapInfo.byteOrder32Big.rawValue
                  ) else {
                return false
            }
            context.draw(
                cgImage,
                in: CGRect(x: 0, y: 0, width: width, height: height)
            )
            return true
        }
        guard rendered else { return nil }
        return try? RGBAImage(width: width, height: height, bytes: bytes)
    }
}
