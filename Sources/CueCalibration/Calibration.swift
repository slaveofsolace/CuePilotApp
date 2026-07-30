import Foundation

public enum ShotOutcome: String, Codable, CaseIterable, Sendable {
    case pocketedSuccessfully
    case missedLeft
    case missedRight
    case hitLeftJaw
    case hitRightJaw
    case hitCushionBeforePocket
    case tooWeak
    case tooHard
    case scratched
    case cueBallStoppedEarly
    case cueBallTraveledTooFar
    case unexpectedCollision
}

public struct CalibrationObservation: Codable, Equatable, Sendable {
    public var outcome: ShotOutcome
    public var commandedAngleDegrees: Double
    public var commandedPower: Double
    public var measuredTravelRatio: Double?
    public var confidence: Double
    public var timestamp: Date

    public init(
        outcome: ShotOutcome,
        commandedAngleDegrees: Double = 0,
        commandedPower: Double,
        measuredTravelRatio: Double? = nil,
        confidence: Double = 1,
        timestamp: Date = Date()
    ) {
        self.outcome = outcome
        self.commandedAngleDegrees = commandedAngleDegrees
        self.commandedPower = commandedPower.clamped(to: 0 ... 1)
        self.measuredTravelRatio = measuredTravelRatio
        self.confidence = confidence.clamped(to: 0 ... 1)
        self.timestamp = timestamp
    }
}

public struct CalibrationProfile: Codable, Identifiable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var deviceClass: String
    public var visualGameVersion: String
    public var aimBiasDegrees: Double
    public var powerScale: Double
    public var powerOffset: Double
    public var rollingResistance: Double
    public var cushionRestitution: Double
    public var ballRestitution: Double
    public var pocketTolerance: Double
    public var touchDragScale: Double
    public var displayScale: Double
    public var confidence: Double
    public var sampleCount: Int
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Default",
        deviceClass: String = "unspecified",
        visualGameVersion: String = "generic",
        aimBiasDegrees: Double = 0,
        powerScale: Double = 1,
        powerOffset: Double = 0,
        rollingResistance: Double = 0.18,
        cushionRestitution: Double = 0.78,
        ballRestitution: Double = 0.94,
        pocketTolerance: Double = 1,
        touchDragScale: Double = 1,
        displayScale: Double = 1,
        confidence: Double = 0,
        sampleCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = Self.schemaVersion
        self.id = id
        self.name = name
        self.deviceClass = deviceClass
        self.visualGameVersion = visualGameVersion
        self.aimBiasDegrees = aimBiasDegrees
        self.powerScale = powerScale
        self.powerOffset = powerOffset
        self.rollingResistance = rollingResistance
        self.cushionRestitution = cushionRestitution
        self.ballRestitution = ballRestitution
        self.pocketTolerance = pocketTolerance
        self.touchDragScale = touchDragScale
        self.displayScale = displayScale
        self.confidence = confidence.clamped(to: 0 ... 1)
        self.sampleCount = max(0, sampleCount)
        self.updatedAt = updatedAt
    }

    /// Applies a conservative exponentially weighted update. Individual shot
    /// outcomes move only the parameters they can reasonably inform.
    public func applying(_ observation: CalibrationObservation) -> CalibrationProfile {
        var result = self
        let evidence = observation.confidence
        guard evidence > 0 else { return result }
        let learningRate = min(0.08, 1 / Double(max(8, sampleCount + 1))) * evidence
        let angularStep = max(0.02, min(0.25, abs(observation.commandedAngleDegrees) * 0.015 + 0.04))
        let powerStep = 0.035

        switch observation.outcome {
        case .pocketedSuccessfully:
            result.aimBiasDegrees *= (1 - learningRate * 0.25)
            result.powerOffset *= (1 - learningRate * 0.25)
            result.pocketTolerance += learningRate * (1 - result.pocketTolerance)
        case .missedLeft, .hitLeftJaw:
            result.aimBiasDegrees += angularStep * evidence
            result.pocketTolerance -= learningRate * 0.20
        case .missedRight, .hitRightJaw:
            result.aimBiasDegrees -= angularStep * evidence
            result.pocketTolerance -= learningRate * 0.20
        case .hitCushionBeforePocket:
            result.aimBiasDegrees *= (1 - learningRate)
            result.cushionRestitution -= learningRate * 0.08
        case .tooWeak:
            result.powerOffset += powerStep * evidence
            result.powerScale += learningRate * 0.10
        case .tooHard:
            result.powerOffset -= powerStep * evidence
            result.powerScale -= learningRate * 0.10
        case .scratched:
            result.powerScale -= learningRate * 0.06
            result.pocketTolerance -= learningRate * 0.10
        case .cueBallStoppedEarly:
            result.rollingResistance += learningRate * 0.08
            result.powerOffset += powerStep * 0.5 * evidence
        case .cueBallTraveledTooFar:
            result.rollingResistance -= learningRate * 0.08
            result.powerOffset -= powerStep * 0.5 * evidence
        case .unexpectedCollision:
            result.ballRestitution -= learningRate * 0.04
            result.pocketTolerance -= learningRate * 0.05
        }

        if let travelRatio = observation.measuredTravelRatio,
           travelRatio.isFinite,
           travelRatio > 0 {
            let boundedRatio = travelRatio.clamped(to: 0.5 ... 1.5)
            result.powerScale += (1 / boundedRatio - result.powerScale) * learningRate
        }

        result.aimBiasDegrees = result.aimBiasDegrees.clamped(to: -4 ... 4)
        result.powerScale = result.powerScale.clamped(to: 0.70 ... 1.30)
        result.powerOffset = result.powerOffset.clamped(to: -0.20 ... 0.20)
        result.rollingResistance = result.rollingResistance.clamped(to: 0.05 ... 0.40)
        result.cushionRestitution = result.cushionRestitution.clamped(to: 0.50 ... 0.98)
        result.ballRestitution = result.ballRestitution.clamped(to: 0.70 ... 0.99)
        result.pocketTolerance = result.pocketTolerance.clamped(to: 0.70 ... 1.20)
        result.sampleCount += 1
        result.confidence = (1 - exp(-Double(result.sampleCount) / 18)) * evidence
        result.updatedAt = observation.timestamp
        return result
    }

    public func decayingConfidence(by fraction: Double, at date: Date = Date()) -> CalibrationProfile {
        var result = self
        result.confidence *= (1 - fraction.clamped(to: 0 ... 1))
        result.updatedAt = date
        return result
    }

    public func normalizedPower(for requestedPower: Double) -> Double {
        ((requestedPower * powerScale) + powerOffset).clamped(to: 0 ... 1)
    }
}

public enum CalibrationStoreError: Error, Equatable {
    case duplicateIdentifier
    case profileNotFound
}

/// Local JSON persistence with atomic file replacement. No networking API is
/// present in this module.
public actor CalibrationStore {
    private struct Envelope: Codable, Sendable {
        var schemaVersion: Int
        var profiles: [CalibrationProfile]
    }

    private let fileURL: URL
    private var cachedProfiles: [CalibrationProfile]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func profiles() throws -> [CalibrationProfile] {
        if let cachedProfiles { return cachedProfiles }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedProfiles = []
            return []
        }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(Envelope.self, from: data)
        cachedProfiles = envelope.profiles
        return envelope.profiles
    }

    public func bestProfile(
        deviceClass: String,
        visualGameVersion: String
    ) throws -> CalibrationProfile? {
        try profiles()
            .filter {
                $0.deviceClass == deviceClass &&
                    $0.visualGameVersion == visualGameVersion
            }
            .max {
                if $0.confidence != $1.confidence {
                    return $0.confidence < $1.confidence
                }
                return $0.updatedAt < $1.updatedAt
            }
    }

    @discardableResult
    public func create(_ profile: CalibrationProfile) throws -> CalibrationProfile {
        var current = try profiles()
        guard !current.contains(where: { $0.id == profile.id }) else {
            throw CalibrationStoreError.duplicateIdentifier
        }
        current.append(profile)
        try save(current)
        return profile
    }

    @discardableResult
    public func update(_ profile: CalibrationProfile) throws -> CalibrationProfile {
        var current = try profiles()
        guard let index = current.firstIndex(where: { $0.id == profile.id }) else {
            throw CalibrationStoreError.profileNotFound
        }
        current[index] = profile
        try save(current)
        return profile
    }

    public func upsert(_ profile: CalibrationProfile) throws {
        var current = try profiles()
        if let index = current.firstIndex(where: { $0.id == profile.id }) {
            current[index] = profile
        } else {
            current.append(profile)
        }
        try save(current)
    }

    @discardableResult
    public func record(
        _ observation: CalibrationObservation,
        profileID: UUID
    ) throws -> CalibrationProfile {
        var current = try profiles()
        guard let index = current.firstIndex(where: { $0.id == profileID }) else {
            throw CalibrationStoreError.profileNotFound
        }
        let updated = current[index].applying(observation)
        current[index] = updated
        try save(current)
        return updated
    }

    public func remove(id: UUID) throws {
        var current = try profiles()
        guard current.contains(where: { $0.id == id }) else {
            throw CalibrationStoreError.profileNotFound
        }
        current.removeAll { $0.id == id }
        try save(current)
    }

    public func reset() throws {
        try save([])
    }

    private func save(_ profiles: [CalibrationProfile]) throws {
        let envelope = Envelope(
            schemaVersion: CalibrationProfile.schemaVersion,
            profiles: profiles.sorted { $0.updatedAt > $1.updatedAt }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        cachedProfiles = envelope.profiles
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
