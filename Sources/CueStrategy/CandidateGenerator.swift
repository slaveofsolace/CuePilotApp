import CueGeometry
import CuePhysics
import Foundation

public struct StrategyConfiguration: Sendable, Hashable, Codable {
    public var pathMargin: Double
    public var maximumDirectCutAngle: Double
    public var maximumCombinationCutAngle: Double
    public var maximumBankAngularError: Double
    public var minimumDetectionConfidence: Double
    public var maximumScratchProbability: Double
    public var includeCombinations: Bool
    public var includeBanks: Bool
    public var maximumMonteCarloCandidates: Int
    public var maximumAlternatives: Int
    public var minimumRecommendationProbability: Double
    public var physics: PhysicsParameters
    public var monteCarlo: MonteCarloConfiguration

    public init(
        pathMargin: Double = 0.002,
        maximumDirectCutAngle: Double = AngleMath.radians(78),
        maximumCombinationCutAngle: Double = AngleMath.radians(68),
        maximumBankAngularError: Double = AngleMath.radians(4),
        minimumDetectionConfidence: Double = 0.48,
        maximumScratchProbability: Double = 0.72,
        includeCombinations: Bool = true,
        includeBanks: Bool = true,
        maximumMonteCarloCandidates: Int = 6,
        maximumAlternatives: Int = 4,
        minimumRecommendationProbability: Double = 0.30,
        physics: PhysicsParameters = .default,
        monteCarlo: MonteCarloConfiguration = .default
    ) {
        self.pathMargin = max(0, pathMargin)
        self.maximumDirectCutAngle = max(0, maximumDirectCutAngle)
        self.maximumCombinationCutAngle = max(0, maximumCombinationCutAngle)
        self.maximumBankAngularError = max(0, maximumBankAngularError)
        self.minimumDetectionConfidence = min(
            1,
            max(0, minimumDetectionConfidence)
        )
        self.maximumScratchProbability = min(
            1,
            max(0, maximumScratchProbability)
        )
        self.includeCombinations = includeCombinations
        self.includeBanks = includeBanks
        self.maximumMonteCarloCandidates = max(1, maximumMonteCarloCandidates)
        self.maximumAlternatives = max(0, maximumAlternatives)
        self.minimumRecommendationProbability = min(
            1,
            max(0, minimumRecommendationProbability)
        )
        self.physics = physics
        self.monteCarlo = monteCarlo
    }

    public static let `default` = StrategyConfiguration()
}

public enum CandidateGenerator {
    /// Generates validated candidates in deterministic ID order. Rejected
    /// candidates are retained for diagnostics and marked `isLegal == false`.
    public static func generate(
        in state: EightBallGameState,
        configuration: StrategyConfiguration = .default
    ) -> [ShotCandidate] {
        guard state.outcome == .inProgress,
              state.turn == .player,
              let cue = state.cueBall else {
            return []
        }

        let legalTargets = EightBallRules.legalTargets(in: state)
            .sorted { $0.id < $1.id }
        var candidates: [ShotCandidate] = []
        for target in legalTargets {
            for pocket in pockets(for: target, state: state) {
                candidates.append(
                    directCandidate(
                        cue: cue,
                        target: target,
                        pocket: pocket,
                        state: state,
                        configuration: configuration
                    )
                )
            }
        }

        if configuration.includeCombinations {
            candidates.append(
                contentsOf: combinationCandidates(
                    cue: cue,
                    legalTargets: legalTargets,
                    state: state,
                    configuration: configuration
                )
            )
        }

        if configuration.includeBanks {
            candidates.append(
                contentsOf: bankCandidates(
                    cue: cue,
                    legalTargets: legalTargets,
                    state: state,
                    configuration: configuration
                )
            )
        }

        return candidates.sorted { $0.id < $1.id }
    }

    private static func pockets(
        for target: BallState,
        state: EightBallGameState
    ) -> [PocketGeometry] {
        if target.kind == .eight {
            guard let required = state.requiredEightBallPocket,
                  let pocket = state.table.pocket(id: required) else {
                return []
            }
            return [pocket]
        }
        return state.table.pockets.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private static func directCandidate(
        cue: BallState,
        target: BallState,
        pocket: PocketGeometry,
        state: EightBallGameState,
        configuration: StrategyConfiguration
    ) -> ShotCandidate {
        let id = "direct:t\(target.id):p\(pocket.id.rawValue)"
        do {
            let solution = try DirectShotGeometry.solve(
                cue: cue,
                target: target,
                pocketAimPoint: pocket.aimPoint
            )
            var rejections: [CandidateRejection] = []

            if !EightBallRules.isLegalFirstContact(
                ballID: target.id,
                in: state
            ) {
                rejections.append(.illegalTarget)
            }
            if !state.table.containsBall(
                center: solution.ghostCenter,
                radius: cue.radius
            ) {
                rejections.append(.ghostOutsideTable)
            }
            if overlapsObstacle(
                center: solution.ghostCenter,
                radius: cue.radius,
                balls: state.balls,
                excluding: [cue.id, target.id],
                margin: configuration.pathMargin
            ) {
                rejections.append(.ghostOverlapsBall)
            }

            let cueClearance = PathClearance.evaluate(
                path: solution.cuePath,
                movingRadius: cue.radius,
                obstacles: state.balls,
                excluding: [cue.id, target.id],
                margin: configuration.pathMargin
            )
            if !cueClearance.isClear {
                rejections.append(.pathBlocked)
            }

            let targetClearance = PathClearance.evaluate(
                path: solution.objectPath,
                movingRadius: target.radius,
                obstacles: state.balls,
                excluding: [cue.id, target.id],
                margin: configuration.pathMargin
            )
            if !targetClearance.isClear {
                rejections.append(.targetPathBlocked)
            }
            if !pocket.accepts(
                centerPath: solution.objectPath,
                ballRadius: target.radius,
                margin: configuration.pathMargin
            ) {
                rejections.append(.pocketRejected)
            }
            if pocket.jawClearance(
                for: solution.objectPath,
                ballRadius: target.radius
            ) < configuration.pathMargin {
                rejections.append(.jawCollision)
            }
            if state.table.intersectsCushion(solution.cuePath) != nil ||
                state.table.intersectsCushion(solution.objectPath) != nil {
                rejections.append(.railCollision)
            }
            if solution.cutAngle > configuration.maximumDirectCutAngle {
                rejections.append(.excessiveCut)
            }
            let minimumConfidence = min(cue.confidence, target.confidence)
            if minimumConfidence < configuration.minimumDetectionConfidence {
                rejections.append(.lowDetectionConfidence)
            }

            let power = PowerEstimator.estimate(
                cueDistance: solution.cuePath.length,
                objectDistance: solution.objectPath.length,
                cutAngle: solution.cutAngle,
                collisionCount: 1,
                railCount: 0,
                table: state.table,
                parameters: configuration.physics
            )
            let scratch = ScratchAnalyzer.predict(
                cue: cue,
                target: target,
                ghostCenter: solution.ghostCenter,
                incomingSpeed: 0.20 + 1.40 * power.midpoint,
                table: state.table,
                obstacles: state.balls,
                parameters: configuration.physics
            )
            if scratch.probability > configuration.maximumScratchProbability {
                rejections.append(.scratchRisk)
            }

            let clearance = finiteClearance(
                min(
                    cueClearance.minimumClearance,
                    targetClearance.minimumClearance,
                    pocket.jawClearance(
                        for: solution.objectPath,
                        ballRadius: target.radius
                    )
                ),
                table: state.table
            )
            let probability = baseProbability(
                kind: .direct,
                cutAngle: solution.cutAngle,
                totalDistance: solution.cuePath.length +
                    solution.objectPath.length,
                clearance: clearance,
                radius: target.radius,
                pocket: pocket,
                confidence: minimumConfidence,
                scratch: scratch,
                table: state.table
            )
            let score = score(
                kind: .direct,
                probability: probability,
                clearance: clearance,
                radius: target.radius,
                scratch: scratch
            )
            return ShotCandidate(
                id: id,
                kind: .direct,
                targetBallID: target.id,
                pocketID: pocket.id,
                aimPoint: solution.ghostCenter,
                ghostCenters: [solution.ghostCenter],
                cuePath: solution.cuePath,
                objectPaths: [solution.objectPath],
                requiredCueAngle: solution.requiredCueAngle,
                cutAngle: solution.cutAngle,
                minimumClearance: clearance,
                scratch: scratch,
                powerRange: power,
                estimatedSuccessProbability: probability,
                score: score,
                isLegal: rejections.isEmpty,
                rejections: unique(rejections)
            )
        } catch {
            return rejectedPlaceholder(
                id: id,
                kind: .direct,
                cue: cue,
                target: target,
                pocket: pocket,
                rejection: .pocketRejected
            )
        }
    }

    private static func combinationCandidates(
        cue: BallState,
        legalTargets: [BallState],
        state: EightBallGameState,
        configuration: StrategyConfiguration
    ) -> [ShotCandidate] {
        var result: [ShotCandidate] = []
        for first in legalTargets {
            for second in legalTargets where second.id != first.id {
                for pocket in pockets(for: second, state: state) {
                    let id = "combo:t\(first.id):s\(second.id):p\(pocket.id.rawValue)"
                    do {
                        let solution = try CombinationShotGeometry.solve(
                            cue: cue,
                            firstObject: first,
                            secondObject: second,
                            pocketAimPoint: pocket.aimPoint
                        )
                        var rejections: [CandidateRejection] = []
                        if !EightBallRules.isLegalFirstContact(
                            ballID: first.id,
                            in: state
                        ) {
                            rejections.append(.illegalTarget)
                        }
                        if !state.table.containsBall(
                            center: solution.firstObjectGhostCenter,
                            radius: cue.radius
                        ) || !state.table.containsBall(
                            center: solution.secondObjectGhostCenter,
                            radius: first.radius
                        ) {
                            rejections.append(.ghostOutsideTable)
                        }
                        if overlapsObstacle(
                            center: solution.firstObjectGhostCenter,
                            radius: cue.radius,
                            balls: state.balls,
                            excluding: [cue.id, first.id],
                            margin: configuration.pathMargin
                        ) || overlapsObstacle(
                            center: solution.secondObjectGhostCenter,
                            radius: first.radius,
                            balls: state.balls,
                            excluding: [first.id, second.id],
                            margin: configuration.pathMargin
                        ) {
                            rejections.append(.ghostOverlapsBall)
                        }

                        let cueClearance = PathClearance.evaluate(
                            path: solution.cuePath,
                            movingRadius: cue.radius,
                            obstacles: state.balls,
                            excluding: [cue.id, first.id],
                            margin: configuration.pathMargin
                        )
                        let firstClearance = PathClearance.evaluate(
                            path: solution.firstObjectPath,
                            movingRadius: first.radius,
                            obstacles: state.balls,
                            excluding: [cue.id, first.id, second.id],
                            margin: configuration.pathMargin
                        )
                        let secondClearance = PathClearance.evaluate(
                            path: solution.secondObjectPath,
                            movingRadius: second.radius,
                            obstacles: state.balls,
                            excluding: [cue.id, first.id, second.id],
                            margin: configuration.pathMargin
                        )
                        if !cueClearance.isClear {
                            rejections.append(.pathBlocked)
                        }
                        if !firstClearance.isClear || !secondClearance.isClear {
                            rejections.append(.targetPathBlocked)
                        }
                        if !pocket.accepts(
                            centerPath: solution.secondObjectPath,
                            ballRadius: second.radius,
                            margin: configuration.pathMargin
                        ) {
                            rejections.append(.pocketRejected)
                        }
                        if pocket.jawClearance(
                            for: solution.secondObjectPath,
                            ballRadius: second.radius
                        ) < configuration.pathMargin {
                            rejections.append(.jawCollision)
                        }
                        if solution.firstCutAngle >
                            configuration.maximumCombinationCutAngle ||
                            solution.secondCutAngle >
                            configuration.maximumCombinationCutAngle {
                            rejections.append(.excessiveCut)
                        }
                        if state.table.intersectsCushion(solution.cuePath) != nil ||
                            state.table.intersectsCushion(solution.firstObjectPath) != nil ||
                            state.table.intersectsCushion(solution.secondObjectPath) != nil {
                            rejections.append(.railCollision)
                        }

                        let minimumConfidence = min(
                            cue.confidence,
                            first.confidence,
                            second.confidence
                        )
                        if minimumConfidence <
                            configuration.minimumDetectionConfidence {
                            rejections.append(.lowDetectionConfidence)
                        }
                        let power = PowerEstimator.estimate(
                            cueDistance: solution.cuePath.length,
                            objectDistance: solution.firstObjectPath.length +
                                solution.secondObjectPath.length,
                            cutAngle: max(
                                solution.firstCutAngle,
                                solution.secondCutAngle
                            ),
                            collisionCount: 2,
                            railCount: 0,
                            table: state.table,
                            parameters: configuration.physics
                        )
                        let scratch = ScratchAnalyzer.predict(
                            cue: cue,
                            target: first,
                            ghostCenter: solution.firstObjectGhostCenter,
                            incomingSpeed: 0.20 + 1.40 * power.midpoint,
                            table: state.table,
                            obstacles: state.balls,
                            parameters: configuration.physics
                        )
                        if scratch.probability >
                            configuration.maximumScratchProbability {
                            rejections.append(.scratchRisk)
                        }
                        let clearance = finiteClearance(
                            min(
                                cueClearance.minimumClearance,
                                firstClearance.minimumClearance,
                                secondClearance.minimumClearance,
                                pocket.jawClearance(
                                    for: solution.secondObjectPath,
                                    ballRadius: second.radius
                                )
                            ),
                            table: state.table
                        )
                        let probability = baseProbability(
                            kind: .combination,
                            cutAngle: max(
                                solution.firstCutAngle,
                                solution.secondCutAngle
                            ),
                            totalDistance: solution.cuePath.length +
                                solution.firstObjectPath.length +
                                solution.secondObjectPath.length,
                            clearance: clearance,
                            radius: second.radius,
                            pocket: pocket,
                            confidence: minimumConfidence,
                            scratch: scratch,
                            table: state.table
                        )
                        result.append(
                            ShotCandidate(
                                id: id,
                                kind: .combination,
                                targetBallID: first.id,
                                secondaryBallID: second.id,
                                pocketID: pocket.id,
                                aimPoint: solution.firstObjectGhostCenter,
                                ghostCenters: [
                                    solution.firstObjectGhostCenter,
                                    solution.secondObjectGhostCenter,
                                ],
                                cuePath: solution.cuePath,
                                objectPaths: [
                                    solution.firstObjectPath,
                                    solution.secondObjectPath,
                                ],
                                requiredCueAngle: solution.requiredCueAngle,
                                cutAngle: max(
                                    solution.firstCutAngle,
                                    solution.secondCutAngle
                                ),
                                minimumClearance: clearance,
                                scratch: scratch,
                                powerRange: power,
                                estimatedSuccessProbability: probability,
                                score: score(
                                    kind: .combination,
                                    probability: probability,
                                    clearance: clearance,
                                    radius: second.radius,
                                    scratch: scratch
                                ),
                                isLegal: rejections.isEmpty,
                                rejections: unique(rejections)
                            )
                        )
                    } catch {
                        result.append(
                            rejectedPlaceholder(
                                id: id,
                                kind: .combination,
                                cue: cue,
                                target: first,
                                secondaryBallID: second.id,
                                pocket: pocket,
                                rejection: .pocketRejected
                            )
                        )
                    }
                }
            }
        }
        return result
    }

    private static func bankCandidates(
        cue: BallState,
        legalTargets: [BallState],
        state: EightBallGameState,
        configuration: StrategyConfiguration
    ) -> [ShotCandidate] {
        var result: [ShotCandidate] = []
        let cushions = state.table.cushions.sorted {
            $0.id.rawValue < $1.id.rawValue
        }
        for target in legalTargets {
            for pocket in pockets(for: target, state: state) {
                for cushion in cushions {
                    let id = "bank:t\(target.id):p\(pocket.id.rawValue):r\(cushion.id.rawValue)"
                    do {
                        let bank = try BankShotGeometry.solve(
                            objectBall: target,
                            pocket: pocket,
                            cushion: cushion,
                            tableCenter: state.table.playableBounds.center,
                            restitution: configuration.physics.cushionRestitution
                        )
                        let inboundDirection = bank.inboundPath.unitDirection
                        let ghost = target.center -
                            inboundDirection * (cue.radius + target.radius)
                        let cuePath = Segment2D(start: cue.center, end: ghost)
                        let cut = abs(
                            AngleMath.signedDifference(
                                from: cuePath.unitDirection.angle,
                                to: inboundDirection.angle
                            )
                        )
                        var rejections: [CandidateRejection] = []
                        if !state.table.containsBall(
                            center: ghost,
                            radius: cue.radius
                        ) {
                            rejections.append(.ghostOutsideTable)
                        }
                        if overlapsObstacle(
                            center: ghost,
                            radius: cue.radius,
                            balls: state.balls,
                            excluding: [cue.id, target.id],
                            margin: configuration.pathMargin
                        ) {
                            rejections.append(.ghostOverlapsBall)
                        }
                        let cueClearance = PathClearance.evaluate(
                            path: cuePath,
                            movingRadius: cue.radius,
                            obstacles: state.balls,
                            excluding: [cue.id, target.id],
                            margin: configuration.pathMargin
                        )
                        let inboundClearance = PathClearance.evaluate(
                            path: bank.inboundPath,
                            movingRadius: target.radius,
                            obstacles: state.balls,
                            excluding: [cue.id, target.id],
                            margin: configuration.pathMargin
                        )
                        let outboundClearance = PathClearance.evaluate(
                            path: bank.outboundPath,
                            movingRadius: target.radius,
                            obstacles: state.balls,
                            excluding: [cue.id, target.id],
                            margin: configuration.pathMargin
                        )
                        if !cueClearance.isClear {
                            rejections.append(.pathBlocked)
                        }
                        if !inboundClearance.isClear ||
                            !outboundClearance.isClear {
                            rejections.append(.targetPathBlocked)
                        }
                        if !pocket.accepts(
                            centerPath: bank.outboundPath,
                            ballRadius: target.radius,
                            margin: configuration.pathMargin
                        ) {
                            rejections.append(.pocketRejected)
                        }
                        if bank.angularError >
                            configuration.maximumBankAngularError {
                            rejections.append(.bankUnreachable)
                        }
                        if cut > configuration.maximumDirectCutAngle {
                            rejections.append(.excessiveCut)
                        }
                        if state.table.cushions.contains(where: {
                            $0.id != cushion.id &&
                                ($0.segment.intersects(bank.inboundPath) ||
                                    $0.segment.intersects(bank.outboundPath))
                        }) {
                            rejections.append(.railCollision)
                        }

                        let minimumConfidence = min(
                            cue.confidence,
                            target.confidence
                        )
                        if minimumConfidence <
                            configuration.minimumDetectionConfidence {
                            rejections.append(.lowDetectionConfidence)
                        }
                        let power = PowerEstimator.estimate(
                            cueDistance: cuePath.length,
                            objectDistance: bank.inboundPath.length +
                                bank.outboundPath.length,
                            cutAngle: cut,
                            collisionCount: 1,
                            railCount: 1,
                            table: state.table,
                            parameters: configuration.physics
                        )
                        let scratch = ScratchAnalyzer.predict(
                            cue: cue,
                            target: target,
                            ghostCenter: ghost,
                            incomingSpeed: 0.20 + 1.40 * power.midpoint,
                            table: state.table,
                            obstacles: state.balls,
                            parameters: configuration.physics
                        )
                        if scratch.probability >
                            configuration.maximumScratchProbability {
                            rejections.append(.scratchRisk)
                        }
                        let clearance = finiteClearance(
                            min(
                                cueClearance.minimumClearance,
                                inboundClearance.minimumClearance,
                                outboundClearance.minimumClearance,
                                pocket.jawClearance(
                                    for: bank.outboundPath,
                                    ballRadius: target.radius
                                )
                            ),
                            table: state.table
                        )
                        let probability = baseProbability(
                            kind: .bank,
                            cutAngle: cut + bank.angularError,
                            totalDistance: cuePath.length +
                                bank.inboundPath.length +
                                bank.outboundPath.length,
                            clearance: clearance,
                            radius: target.radius,
                            pocket: pocket,
                            confidence: minimumConfidence,
                            scratch: scratch,
                            table: state.table
                        )
                        result.append(
                            ShotCandidate(
                                id: id,
                                kind: .bank,
                                targetBallID: target.id,
                                pocketID: pocket.id,
                                bankRailID: cushion.id,
                                aimPoint: ghost,
                                ghostCenters: [ghost],
                                cuePath: cuePath,
                                objectPaths: [
                                    bank.inboundPath,
                                    bank.outboundPath,
                                ],
                                requiredCueAngle: cuePath.unitDirection.angle,
                                cutAngle: cut,
                                minimumClearance: clearance,
                                scratch: scratch,
                                powerRange: power,
                                estimatedSuccessProbability: probability,
                                score: score(
                                    kind: .bank,
                                    probability: probability,
                                    clearance: clearance,
                                    radius: target.radius,
                                    scratch: scratch
                                ),
                                isLegal: rejections.isEmpty,
                                rejections: unique(rejections)
                            )
                        )
                    } catch {
                        result.append(
                            rejectedPlaceholder(
                                id: id,
                                kind: .bank,
                                cue: cue,
                                target: target,
                                pocket: pocket,
                                rejection: .bankUnreachable,
                                bankRailID: cushion.id
                            )
                        )
                    }
                }
            }
        }
        return result
    }

    private static func overlapsObstacle(
        center: Point2D,
        radius: Double,
        balls: [BallState],
        excluding: Set<Int>,
        margin: Double
    ) -> Bool {
        balls.contains {
            !$0.isPocketed &&
                !excluding.contains($0.id) &&
                center.distance(to: $0.center) <
                    radius + $0.radius + margin - GeometryTolerance.default
        }
    }

    private static func baseProbability(
        kind: ShotKind,
        cutAngle: Double,
        totalDistance: Double,
        clearance: Double,
        radius: Double,
        pocket: PocketGeometry,
        confidence: Double,
        scratch: ScratchPrediction,
        table: TableGeometry
    ) -> Double {
        let cutFactor = pow(max(0.08, cos(min(.pi / 2, cutAngle))), 1.35)
        let distanceFactor = exp(
            -0.32 * totalDistance /
                max(table.playableBounds.diagonal, GeometryTolerance.default)
        )
        let clearanceFactor = min(
            1,
            max(0.35, (clearance + radius * 2) / max(radius * 4, 0.001))
        )
        let openingRatio = pocket.effectiveOpeningWidth(ballRadius: radius) /
            max(pocket.mouth.length, GeometryTolerance.default)
        let pocketFactor = 0.72 + min(0.28, max(0, openingRatio) * 0.35)
        let kindFactor: Double
        switch kind {
        case .direct: kindFactor = 1
        case .combination: kindFactor = 0.72
        case .bank: kindFactor = 0.62
        case .safety: kindFactor = 0.70
        }
        return min(
            0.99,
            max(
                0,
                cutFactor * distanceFactor * clearanceFactor *
                    pocketFactor * confidence * kindFactor *
                    (1 - scratch.probability * 0.45)
            )
        )
    }

    private static func score(
        kind: ShotKind,
        probability: Double,
        clearance: Double,
        radius: Double,
        scratch: ScratchPrediction
    ) -> Double {
        let priority: Double
        switch kind {
        case .direct: priority = 15
        case .combination: priority = 5
        case .safety: priority = 0
        case .bank: priority = -5
        }
        let clearanceBonus = min(
            8,
            max(-8, clearance / max(radius, 0.001) * 2)
        )
        return probability * 100 +
            priority +
            clearanceBonus -
            scratch.probability * 30
    }

    private static func finiteClearance(
        _ clearance: Double,
        table: TableGeometry
    ) -> Double {
        clearance.isFinite ? clearance : table.playableBounds.diagonal
    }

    private static func unique(
        _ values: [CandidateRejection]
    ) -> [CandidateRejection] {
        var seen: Set<CandidateRejection> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func rejectedPlaceholder(
        id: String,
        kind: ShotKind,
        cue: BallState,
        target: BallState,
        secondaryBallID: Int? = nil,
        pocket: PocketGeometry,
        rejection: CandidateRejection,
        bankRailID: RailID? = nil
    ) -> ShotCandidate {
        let path = Segment2D(start: cue.center, end: target.center)
        return ShotCandidate(
            id: id,
            kind: kind,
            targetBallID: target.id,
            secondaryBallID: secondaryBallID,
            pocketID: pocket.id,
            bankRailID: bankRailID,
            aimPoint: target.center,
            ghostCenters: [],
            cuePath: path,
            objectPaths: [
                Segment2D(start: target.center, end: pocket.aimPoint),
            ],
            requiredCueAngle: path.unitDirection.angle,
            cutAngle: .pi,
            minimumClearance: -Double.greatestFiniteMagnitude,
            scratch: .low,
            powerRange: PowerRange(minimum: 0, maximum: 0),
            estimatedSuccessProbability: 0,
            score: -Double.greatestFiniteMagnitude,
            isLegal: false,
            rejections: [rejection]
        )
    }
}
