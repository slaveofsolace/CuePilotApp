import CueGeometry
import CueStrategy
import Foundation

public struct GuidanceWarning: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let scratchRisk = GuidanceWarning(rawValue: 1 << 0)
    public static let foulRisk = GuidanceWarning(rawValue: 1 << 1)
    public static let pathBlocked = GuidanceWarning(rawValue: 1 << 2)
    public static let lowConfidence = GuidanceWarning(rawValue: 1 << 3)
    public static let staleState = GuidanceWarning(rawValue: 1 << 4)
    public static let recursiveCapture = GuidanceWarning(rawValue: 1 << 5)
}

public struct StabilizedGuidance: Codable, Equatable, Sendable {
    public var guidance: AlignmentGuidance
    public var warnings: GuidanceWarning
    public var stableFrameCount: Int
    public var stableDurationMilliseconds: Double

    public init(
        guidance: AlignmentGuidance,
        warnings: GuidanceWarning,
        stableFrameCount: Int,
        stableDurationMilliseconds: Double
    ) {
        self.guidance = guidance
        self.warnings = warnings
        self.stableFrameCount = stableFrameCount
        self.stableDurationMilliseconds = stableDurationMilliseconds
    }
}

/// Enforces temporal agreement before showing AIM LOCKED or READY.
public actor GuidanceStabilizer {
    private let minimumStableFrames: Int
    private let minimumStableNanoseconds: UInt64
    private let minimumConfidence: Double
    private var stableStart: UInt64?
    private var stableFrameCount = 0
    private var lastTimestamp: UInt64?

    public init(
        minimumStableFrames: Int = 3,
        minimumStableDurationMilliseconds: Double = 220,
        minimumConfidence: Double = 0.62
    ) {
        self.minimumStableFrames = max(2, minimumStableFrames)
        self.minimumStableNanoseconds = UInt64(
            max(0, minimumStableDurationMilliseconds) * 1_000_000
        )
        self.minimumConfidence = minimumConfidence.clamped(to: 0 ... 1)
    }

    public func update(
        recommendation: ShotRecommendation?,
        currentAngle: Double?,
        currentPower: Double?,
        isPlayersTurn: Bool,
        detectionConfidence: Double,
        warnings: GuidanceWarning = [],
        timestampNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> StabilizedGuidance {
        if let lastTimestamp, timestampNanoseconds < lastTimestamp {
            resetStability()
        }
        lastTimestamp = timestampNanoseconds

        guard let recommendation else {
            resetStability()
            return StabilizedGuidance(
                guidance: AlignmentGuidance(
                    state: isPlayersTurn ? .searching : .waitingForTurn,
                    signedCorrection: 0,
                    currentAngle: currentAngle,
                    requiredAngle: 0,
                    minimumValidAngle: 0,
                    maximumValidAngle: 0,
                    confidence: 0,
                    estimatedSuccessProbability: 0
                ),
                warnings: warnings.union(.lowConfidence),
                stableFrameCount: 0,
                stableDurationMilliseconds: 0
            )
        }

        var guidance = recommendation.guidance(
            currentAngle: currentAngle,
            currentPower: currentPower,
            isPlayersTurn: isPlayersTurn,
            minimumLockConfidence: minimumConfidence
        )
        var effectiveWarnings = warnings
        if detectionConfidence < minimumConfidence ||
            recommendation.corridor.confidence < minimumConfidence {
            effectiveWarnings.insert(.lowConfidence)
        }
        let powerIsReady = currentPower.map(
            recommendation.candidate.powerRange.contains
        ) ?? true
        let instantSafe = isPlayersTurn &&
            recommendation.candidate.isLegal &&
            recommendation.candidate.rejections.isEmpty &&
            recommendation.corridor.estimatedSuccessProbability >= minimumConfidence &&
            detectionConfidence >= minimumConfidence &&
            powerIsReady &&
            !effectiveWarnings.contains(.scratchRisk) &&
            !effectiveWarnings.contains(.foulRisk) &&
            !effectiveWarnings.contains(.pathBlocked) &&
            currentAngle.map(recommendation.corridor.contains) == true

        if instantSafe {
            if stableStart == nil {
                stableStart = timestampNanoseconds
                stableFrameCount = 1
            } else {
                stableFrameCount += 1
            }
        } else {
            resetStability()
        }

        let stableDuration = stableStart.map {
            timestampNanoseconds >= $0 ? timestampNanoseconds - $0 : 0
        } ?? 0
        let isStable = stableFrameCount >= minimumStableFrames &&
            stableDuration >= minimumStableNanoseconds

        if guidance.state == .ready || guidance.state == .aimLocked {
            if !isStable {
                guidance.state = .fineAlignment
            }
        }
        if !effectiveWarnings.isEmpty &&
            (effectiveWarnings.contains(.scratchRisk) ||
             effectiveWarnings.contains(.foulRisk) ||
             effectiveWarnings.contains(.pathBlocked)) {
            guidance.state = .doNotShoot
        }

        return StabilizedGuidance(
            guidance: guidance,
            warnings: effectiveWarnings,
            stableFrameCount: stableFrameCount,
            stableDurationMilliseconds: Double(stableDuration) / 1_000_000
        )
    }

    public func reset() {
        resetStability()
        lastTimestamp = nil
    }

    private func resetStability() {
        stableStart = nil
        stableFrameCount = 0
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
