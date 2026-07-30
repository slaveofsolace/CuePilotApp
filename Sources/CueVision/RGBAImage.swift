import Foundation

public struct RGBAPixel: Codable, Equatable, Hashable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var luminance: Double {
        0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }

    public var channelRange: UInt8 {
        max(red, green, blue) - min(red, green, blue)
    }

    public static let clear = RGBAPixel(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = RGBAPixel(red: 0, green: 0, blue: 0)
    public static let white = RGBAPixel(red: 255, green: 255, blue: 255)
}

public enum RGBAImageError: Error, Equatable, Sendable {
    case invalidDimensions
    case invalidByteCount(expected: Int, actual: Int)
}

/// A platform-neutral, tightly packed RGBA8 image. It can be constructed from
/// a pixel buffer by the host, analyzed, and then released without retaining a
/// UIKit, AppKit, or Core Video object.
public struct RGBAImage: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var bytes: [UInt8]

    public init(width: Int, height: Int, bytes: [UInt8]) throws {
        guard width > 0, height > 0,
              width <= Int.max / height / 4 else {
            throw RGBAImageError.invalidDimensions
        }
        let expected = width * height * 4
        guard bytes.count == expected else {
            throw RGBAImageError.invalidByteCount(expected: expected, actual: bytes.count)
        }
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    public init(width: Int, height: Int, fill: RGBAPixel) throws {
        guard width > 0, height > 0,
              width <= Int.max / height / 4 else {
            throw RGBAImageError.invalidDimensions
        }
        self.width = width
        self.height = height
        self.bytes = Array(repeating: 0, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            bytes[index] = fill.red
            bytes[index + 1] = fill.green
            bytes[index + 2] = fill.blue
            bytes[index + 3] = fill.alpha
        }
    }

    public func pixel(x: Int, y: Int) -> RGBAPixel? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        let offset = (y * width + x) * 4
        return RGBAPixel(
            red: bytes[offset],
            green: bytes[offset + 1],
            blue: bytes[offset + 2],
            alpha: bytes[offset + 3]
        )
    }

    public mutating func setPixel(_ pixel: RGBAPixel, x: Int, y: Int) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let offset = (y * width + x) * 4
        bytes[offset] = pixel.red
        bytes[offset + 1] = pixel.green
        bytes[offset + 2] = pixel.blue
        bytes[offset + 3] = pixel.alpha
    }

    public func mappedPixel(x: Int, y: Int, fallback: RGBAPixel = .clear) -> RGBAPixel {
        pixel(x: x, y: y) ?? fallback
    }

    /// A low-cost, deterministic scene fingerprint sampled on a fixed grid.
    /// It is not a perceptual hash and contains no reconstructable frame data.
    public func sceneFingerprint(grid: Int = 16) -> UInt64 {
        let columns = max(1, min(grid, width))
        let rows = max(1, min(grid, height))
        var hash: UInt64 = 14_695_981_039_346_656_037
        for row in 0..<rows {
            let y = min(height - 1, row * height / rows)
            for column in 0..<columns {
                let x = min(width - 1, column * width / columns)
                let offset = (y * width + x) * 4
                for channel in 0..<3 {
                    hash ^= UInt64(bytes[offset + channel] >> 3)
                    hash &*= 1_099_511_628_211
                }
            }
        }
        return hash
    }

}
