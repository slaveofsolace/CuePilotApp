import CueGeometry
import CuePhysics
import Foundation

public enum PowerEstimator {
    /// Produces a deliberately broad normalized range. Calibration can remap
    /// this range to a particular game's visible slider.
    public static func estimate(
        cueDistance: Double,
        objectDistance: Double,
        cutAngle: Double,
        collisionCount: Int,
        railCount: Int,
        desiredCueTravel: Double = 0.15,
        table: TableGeometry,
        parameters: PhysicsParameters = .default
    ) -> PowerRange {
        let diagonal = max(
            table.playableBounds.diagonal,
            GeometryTolerance.default
        )
        let normalizedTravel = min(
            1.5,
            max(0, cueDistance + objectDistance) / diagonal
        )
        let cutPenalty = min(1, abs(cutAngle) / (.pi / 2))
        let frictionPenalty = min(0.15, parameters.rollingFriction * 0.22)
        let center = 0.20 +
            normalizedTravel * 0.32 +
            cutPenalty * 0.14 +
            Double(max(0, collisionCount - 1)) * 0.07 +
            Double(max(0, railCount)) * 0.10 +
            min(0.10, max(0, desiredCueTravel) / diagonal * 0.12) +
            frictionPenalty
        let halfWidth = max(
            0.045,
            0.075 - cutPenalty * 0.018 - Double(railCount) * 0.008
        )
        return PowerRange(
            minimum: center - halfWidth,
            maximum: center + halfWidth
        )
    }
}
