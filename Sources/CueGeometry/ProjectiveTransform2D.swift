import Foundation

public enum ProjectiveTransformError: Error, Sendable, Equatable {
    case wrongPointCount
    case singularConfiguration
}

/// A 3×3 homography for mapping a detected table quadrilateral into canonical
/// table coordinates.
public struct ProjectiveTransform2D: Sendable, Hashable, Codable {
    /// Row-major matrix values. Exactly nine elements are always stored.
    public let values: [Double]

    public init(values: [Double]) throws {
        guard values.count == 9 else {
            throw ProjectiveTransformError.wrongPointCount
        }
        self.values = values
    }

    private init(uncheckedValues values: [Double]) {
        self.values = values
    }

    public static let identity = ProjectiveTransform2D(
        uncheckedValues: [1, 0, 0, 0, 1, 0, 0, 0, 1]
    )

    public func applying(to point: Point2D) -> Point2D? {
        let denominator = values[6] * point.x + values[7] * point.y + values[8]
        guard abs(denominator) > GeometryTolerance.default else {
            return nil
        }
        return Point2D(
            x: (values[0] * point.x + values[1] * point.y + values[2]) / denominator,
            y: (values[3] * point.x + values[4] * point.y + values[5]) / denominator
        )
    }

    /// Solves the eight independent homography coefficients from four
    /// point-pairs. Point order must describe corresponding corners.
    public static func mapping(
        source: [Point2D],
        destination: [Point2D]
    ) throws -> ProjectiveTransform2D {
        guard source.count == 4, destination.count == 4 else {
            throw ProjectiveTransformError.wrongPointCount
        }

        var augmented = Array(
            repeating: Array(repeating: 0.0, count: 9),
            count: 8
        )

        for index in 0..<4 {
            let x = source[index].x
            let y = source[index].y
            let u = destination[index].x
            let v = destination[index].y
            let row = index * 2

            augmented[row] = [
                x, y, 1, 0, 0, 0, -u * x, -u * y, u,
            ]
            augmented[row + 1] = [
                0, 0, 0, x, y, 1, -v * x, -v * y, v,
            ]
        }

        for column in 0..<8 {
            var pivot = column
            for row in (column + 1)..<8 where
                abs(augmented[row][column]) > abs(augmented[pivot][column]) {
                pivot = row
            }

            guard abs(augmented[pivot][column]) > GeometryTolerance.default else {
                throw ProjectiveTransformError.singularConfiguration
            }

            if pivot != column {
                augmented.swapAt(pivot, column)
            }

            let scale = augmented[column][column]
            for entry in column..<9 {
                augmented[column][entry] /= scale
            }

            for row in 0..<8 where row != column {
                let factor = augmented[row][column]
                guard abs(factor) > GeometryTolerance.default else { continue }
                for entry in column..<9 {
                    augmented[row][entry] -= factor * augmented[column][entry]
                }
            }
        }

        let coefficients = (0..<8).map { augmented[$0][8] }
        return try ProjectiveTransform2D(values: coefficients + [1])
    }
}
