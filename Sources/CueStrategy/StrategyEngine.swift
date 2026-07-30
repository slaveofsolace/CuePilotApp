import CueGeometry
import Foundation

public struct StrategyEngine: Sendable {
    public var configuration: StrategyConfiguration

    public init(configuration: StrategyConfiguration = .default) {
        self.configuration = configuration
    }

    /// Produces a complete legal recommendation with power and a robust,
    /// physically bounded alignment corridor.
    public func recommendShot(
        in state: EightBallGameState,
        seed: UInt64 = 0
    ) -> ShotRecommendation? {
        guard state.turn == .player, state.outcome == .inProgress else {
            return nil
        }
        let legalTargetIDs = Set(EightBallRules.legalTargets(in: state).map(\.id))
        let initial = CandidateGenerator.generate(
            in: state,
            configuration: configuration
        )
        .filter {
            $0.isLegal &&
                $0.rejections.isEmpty &&
                legalTargetIDs.contains($0.targetBallID)
        }
        .sorted(by: candidateOrder)

        guard !initial.isEmpty else { return nil }
        let evaluationCount = min(
            configuration.maximumMonteCarloCandidates,
            initial.count
        )
        var evaluated: [(candidate: ShotCandidate, corridor: AlignmentCorridor)] = []
        evaluated.reserveCapacity(evaluationCount)

        for index in 0..<evaluationCount {
            var candidate = initial[index]
            let corridor = AlignmentAnalyzer.corridor(
                for: candidate,
                in: state,
                configuration: configuration.monteCarlo,
                physics: configuration.physics,
                seed: seed
            )
            candidate.estimatedSuccessProbability =
                corridor.estimatedSuccessProbability
            let toleranceRatio = corridor.physicalHalfWidth >
                GeometryTolerance.default
                ? corridor.width / (2 * corridor.physicalHalfWidth)
                : 0
            candidate.score = candidate.score * 0.38 +
                corridor.estimatedSuccessProbability * 62 +
                toleranceRatio * 8
            evaluated.append((candidate, corridor))
        }

        evaluated.sort {
            if abs($0.candidate.score - $1.candidate.score) >
                GeometryTolerance.default {
                return $0.candidate.score > $1.candidate.score
            }
            return $0.candidate.id < $1.candidate.id
        }

        guard let selected = evaluated.first(where: {
            $0.corridor.estimatedSuccessProbability >=
                configuration.minimumRecommendationProbability
        }) else {
            return nil
        }

        let alternatives = evaluated
            .filter { $0.candidate.id != selected.candidate.id }
            .prefix(configuration.maximumAlternatives)
            .map(\.candidate)
        return ShotRecommendation(
            candidate: selected.candidate,
            corridor: selected.corridor,
            alternatives: Array(alternatives)
        )
    }

    /// Alias used by live/session clients that treat a recommendation as one
    /// full solve result.
    public func recommend(
        in state: EightBallGameState,
        seed: UInt64 = 0
    ) -> ShotRecommendation? {
        recommendShot(in: state, seed: seed)
    }

    private func candidateOrder(
        _ lhs: ShotCandidate,
        _ rhs: ShotCandidate
    ) -> Bool {
        if abs(lhs.score - rhs.score) > GeometryTolerance.default {
            return lhs.score > rhs.score
        }
        return lhs.id < rhs.id
    }
}
