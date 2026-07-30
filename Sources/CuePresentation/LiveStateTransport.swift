import CueGeometry
import CueStrategy
import Darwin
import Foundation

public enum LiveOrientation: UInt8, Codable, CaseIterable, Sendable {
    case unknown = 0
    case portrait = 1
    case portraitUpsideDown = 2
    case landscapeLeft = 3
    case landscapeRight = 4
}

public struct CompactLiveState: Equatable, Sendable {
    public static let currentVersion: UInt16 = 1

    public var sequence: UInt64
    public var timestampNanoseconds: UInt64
    public var orientation: LiveOrientation
    public var tableConfidence: Float
    public var turn: MatchTurn
    public var group: GroupAssignment
    public var recommendedShotID: UInt32
    public var currentCueAngle: Float?
    public var requiredCueAngle: Float
    public var signedAngularError: Float
    public var validMinimumAngle: Float
    public var validMaximumAngle: Float
    public var recommendedPowerMinimum: Float
    public var recommendedPowerMaximum: Float
    public var currentVisiblePower: Float?
    public var alignment: GuidanceState
    public var confidence: Float
    public var estimatedSuccessProbability: Float
    public var warningFlags: GuidanceWarning
    public var targetBallID: Int16?
    public var targetPocket: PocketID?

    public init(
        sequence: UInt64,
        timestampNanoseconds: UInt64,
        orientation: LiveOrientation = .unknown,
        tableConfidence: Float,
        turn: MatchTurn,
        group: GroupAssignment,
        recommendedShotID: UInt32,
        currentCueAngle: Float?,
        requiredCueAngle: Float,
        signedAngularError: Float,
        validMinimumAngle: Float,
        validMaximumAngle: Float,
        recommendedPowerMinimum: Float,
        recommendedPowerMaximum: Float,
        currentVisiblePower: Float?,
        alignment: GuidanceState,
        confidence: Float,
        estimatedSuccessProbability: Float,
        warningFlags: GuidanceWarning = [],
        targetBallID: Int16?,
        targetPocket: PocketID?
    ) {
        self.sequence = sequence
        self.timestampNanoseconds = timestampNanoseconds
        self.orientation = orientation
        self.tableConfidence = tableConfidence.unitClamped
        self.turn = turn
        self.group = group
        self.recommendedShotID = recommendedShotID
        self.currentCueAngle = currentCueAngle
        self.requiredCueAngle = requiredCueAngle
        self.signedAngularError = signedAngularError
        self.validMinimumAngle = validMinimumAngle
        self.validMaximumAngle = validMaximumAngle
        self.recommendedPowerMinimum = recommendedPowerMinimum.unitClamped
        self.recommendedPowerMaximum = recommendedPowerMaximum.unitClamped
        self.currentVisiblePower = currentVisiblePower?.unitClamped
        self.alignment = alignment
        self.confidence = confidence.unitClamped
        self.estimatedSuccessProbability = estimatedSuccessProbability.unitClamped
        self.warningFlags = warningFlags
        self.targetBallID = targetBallID
        self.targetPocket = targetPocket
    }

    public static func shotIdentifier(_ identifier: String) -> UInt32 {
        identifier.utf8.reduce(UInt32(2_166_136_261)) { hash, byte in
            (hash ^ UInt32(byte)) &* 16_777_619
        }
    }

    public static func make(
        sequence: UInt64,
        timestampNanoseconds: UInt64,
        orientation: LiveOrientation = .unknown,
        tableConfidence: Double,
        turn: MatchTurn,
        group: GroupAssignment,
        recommendation: ShotRecommendation?,
        stabilizedGuidance: StabilizedGuidance,
        currentCueAngle: Double?,
        currentVisiblePower: Double?
    ) -> CompactLiveState {
        let candidate = recommendation?.candidate
        let corridor = recommendation?.corridor
        let targetID = candidate.flatMap { Int16(exactly: $0.targetBallID) }
        return CompactLiveState(
            sequence: sequence,
            timestampNanoseconds: timestampNanoseconds,
            orientation: orientation,
            tableConfidence: Float(tableConfidence),
            turn: turn,
            group: group,
            recommendedShotID: candidate.map { shotIdentifier($0.id) } ?? 0,
            currentCueAngle: currentCueAngle.map(Float.init),
            requiredCueAngle: Float(corridor?.requiredAngle ?? 0),
            signedAngularError: Float(stabilizedGuidance.guidance.signedCorrection),
            validMinimumAngle: Float(corridor?.minimumAngle ?? 0),
            validMaximumAngle: Float(corridor?.maximumAngle ?? 0),
            recommendedPowerMinimum: Float(candidate?.powerRange.minimum ?? 0),
            recommendedPowerMaximum: Float(candidate?.powerRange.maximum ?? 0),
            currentVisiblePower: currentVisiblePower.map(Float.init),
            alignment: stabilizedGuidance.guidance.state,
            confidence: Float(stabilizedGuidance.guidance.confidence),
            estimatedSuccessProbability: Float(
                stabilizedGuidance.guidance.estimatedSuccessProbability
            ),
            warningFlags: stabilizedGuidance.warnings,
            targetBallID: targetID,
            targetPocket: candidate?.pocketID
        )
    }
}

public enum LiveStateWireError: Error, Equatable, Sendable {
    case wrongSize
    case invalidMagic
    case unsupportedVersion(UInt16)
    case checksumMismatch
    case invalidEnumValue
    case noValidSlot
}

/// A stable 128-byte representation. Numeric fields are little-endian and
/// enum values are explicitly mapped, so declaration-order changes cannot
/// silently break communication between an extension and its host.
public enum LiveStateWireFormat {
    public static let byteCount = 128
    private static let magic: UInt32 = 0x534C_5043 // "CPLS"

    public static func encode(_ state: CompactLiveState) -> Data {
        var bytes = Array(repeating: UInt8(0), count: byteCount)
        write(magic, to: &bytes, at: 0)
        write(CompactLiveState.currentVersion, to: &bytes, at: 4)
        write(UInt16(byteCount), to: &bytes, at: 6)
        write(state.sequence, to: &bytes, at: 8)
        write(state.timestampNanoseconds, to: &bytes, at: 16)
        bytes[24] = state.orientation.rawValue
        bytes[25] = code(state.turn)
        bytes[26] = code(state.group)
        bytes[27] = code(state.alignment)
        write(state.warningFlags.rawValue, to: &bytes, at: 28)
        write(state.recommendedShotID, to: &bytes, at: 32)
        write(
            UInt16(bitPattern: state.targetBallID ?? Int16.min),
            to: &bytes,
            at: 36
        )
        bytes[38] = code(state.targetPocket)
        write(state.tableConfidence.bitPattern, to: &bytes, at: 40)
        write(optionalBits(state.currentCueAngle), to: &bytes, at: 44)
        write(state.requiredCueAngle.bitPattern, to: &bytes, at: 48)
        write(state.signedAngularError.bitPattern, to: &bytes, at: 52)
        write(state.validMinimumAngle.bitPattern, to: &bytes, at: 56)
        write(state.validMaximumAngle.bitPattern, to: &bytes, at: 60)
        write(state.recommendedPowerMinimum.bitPattern, to: &bytes, at: 64)
        write(state.recommendedPowerMaximum.bitPattern, to: &bytes, at: 68)
        write(optionalBits(state.currentVisiblePower), to: &bytes, at: 72)
        write(state.confidence.bitPattern, to: &bytes, at: 76)
        write(state.estimatedSuccessProbability.bitPattern, to: &bytes, at: 80)
        let checksum = CRC32.checksum(bytes[0..<124])
        write(checksum, to: &bytes, at: 124)
        return Data(bytes)
    }

    public static func decode(_ data: Data) throws -> CompactLiveState {
        guard data.count == byteCount else { throw LiveStateWireError.wrongSize }
        let bytes = [UInt8](data)
        guard readUInt32(bytes, at: 0) == magic else {
            throw LiveStateWireError.invalidMagic
        }
        let version = readUInt16(bytes, at: 4)
        guard version == CompactLiveState.currentVersion else {
            throw LiveStateWireError.unsupportedVersion(version)
        }
        guard readUInt16(bytes, at: 6) == UInt16(byteCount),
              readUInt32(bytes, at: 124) == CRC32.checksum(bytes[0..<124]) else {
            throw LiveStateWireError.checksumMismatch
        }
        guard let orientation = LiveOrientation(rawValue: bytes[24]),
              let turn = turn(bytes[25]),
              let group = group(bytes[26]),
              let alignment = alignment(bytes[27]),
              bytes[38] == 255 || bytes[38] <= 5 else {
            throw LiveStateWireError.invalidEnumValue
        }
        let requiredCueAngle = Float(bitPattern: readUInt32(bytes, at: 48))
        let signedAngularError = Float(bitPattern: readUInt32(bytes, at: 52))
        let validMinimumAngle = Float(bitPattern: readUInt32(bytes, at: 56))
        let validMaximumAngle = Float(bitPattern: readUInt32(bytes, at: 60))
        guard requiredCueAngle.isFinite,
              signedAngularError.isFinite,
              validMinimumAngle.isFinite,
              validMaximumAngle.isFinite else {
            throw LiveStateWireError.invalidEnumValue
        }
        let targetBits = readUInt16(bytes, at: 36)
        let target = Int16(bitPattern: targetBits)
        return CompactLiveState(
            sequence: readUInt64(bytes, at: 8),
            timestampNanoseconds: readUInt64(bytes, at: 16),
            orientation: orientation,
            tableConfidence: Float(bitPattern: readUInt32(bytes, at: 40)),
            turn: turn,
            group: group,
            recommendedShotID: readUInt32(bytes, at: 32),
            currentCueAngle: optionalFloat(readUInt32(bytes, at: 44)),
            requiredCueAngle: requiredCueAngle,
            signedAngularError: signedAngularError,
            validMinimumAngle: validMinimumAngle,
            validMaximumAngle: validMaximumAngle,
            recommendedPowerMinimum: Float(bitPattern: readUInt32(bytes, at: 64)),
            recommendedPowerMaximum: Float(bitPattern: readUInt32(bytes, at: 68)),
            currentVisiblePower: optionalFloat(readUInt32(bytes, at: 72)),
            alignment: alignment,
            confidence: Float(bitPattern: readUInt32(bytes, at: 76)),
            estimatedSuccessProbability: Float(bitPattern: readUInt32(bytes, at: 80)),
            warningFlags: GuidanceWarning(rawValue: readUInt32(bytes, at: 28)),
            targetBallID: target == Int16.min ? nil : target,
            targetPocket: pocket(bytes[38])
        )
    }

    private static func optionalBits(_ value: Float?) -> UInt32 {
        value?.bitPattern ?? Float.nan.bitPattern
    }

    private static func optionalFloat(_ bits: UInt32) -> Float? {
        let value = Float(bitPattern: bits)
        return value.isFinite ? value : nil
    }

    private static func code(_ turn: MatchTurn) -> UInt8 {
        switch turn {
        case .unknown: 0
        case .player: 1
        case .opponent: 2
        }
    }

    private static func turn(_ code: UInt8) -> MatchTurn? {
        switch code {
        case 0: .unknown
        case 1: .player
        case 2: .opponent
        default: nil
        }
    }

    private static func code(_ group: GroupAssignment) -> UInt8 {
        switch group {
        case .open: 0
        case .solids: 1
        case .stripes: 2
        }
    }

    private static func group(_ code: UInt8) -> GroupAssignment? {
        switch code {
        case 0: .open
        case 1: .solids
        case 2: .stripes
        default: nil
        }
    }

    private static func code(_ alignment: GuidanceState) -> UInt8 {
        switch alignment {
        case .searching: 0
        case .analyzing: 1
        case .rotateLeft: 2
        case .rotateRight: 3
        case .fineAlignment: 4
        case .aimLocked: 5
        case .morePower: 6
        case .lessPower: 7
        case .ready: 8
        case .doNotShoot: 9
        case .waitingForTurn: 10
        }
    }

    private static func alignment(_ code: UInt8) -> GuidanceState? {
        switch code {
        case 0: .searching
        case 1: .analyzing
        case 2: .rotateLeft
        case 3: .rotateRight
        case 4: .fineAlignment
        case 5: .aimLocked
        case 6: .morePower
        case 7: .lessPower
        case 8: .ready
        case 9: .doNotShoot
        case 10: .waitingForTurn
        default: nil
        }
    }

    private static func code(_ pocket: PocketID?) -> UInt8 {
        switch pocket {
        case nil: 255
        case .topLeft: 0
        case .topCenter: 1
        case .topRight: 2
        case .bottomLeft: 3
        case .bottomCenter: 4
        case .bottomRight: 5
        }
    }

    private static func pocket(_ code: UInt8) -> PocketID? {
        switch code {
        case 0: .topLeft
        case 1: .topCenter
        case 2: .topRight
        case 3: .bottomLeft
        case 4: .bottomCenter
        case 5: .bottomRight
        default: nil
        }
    }

    private static func write<T: FixedWidthInteger>(
        _ value: T,
        to bytes: inout [UInt8],
        at offset: Int
    ) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { source in
            for index in source.indices {
                bytes[offset + index] = source[index]
            }
        }
    }

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            UInt32(bytes[offset + 1]) << 8 |
            UInt32(bytes[offset + 2]) << 16 |
            UInt32(bytes[offset + 3]) << 24
    }

    private static func readUInt64(_ bytes: [UInt8], at offset: Int) -> UInt64 {
        (0..<8).reduce(UInt64(0)) {
            $0 | UInt64(bytes[offset + $1]) << UInt64($1 * 8)
        }
    }
}

/// Double-slot file storage tolerates a reader observing one slot during a
/// write: it validates both checksums and selects the newest valid sequence.
public actor LiveStateFileTransport {
    public static let slotByteCount = 160
    public static let fileByteCount = slotByteCount * 2

    private static let slotMagic: UInt32 = 0x4453_5043 // "CPSD"
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func write(_ state: CompactLiveState) throws {
        try prepareFile()
        var committedState = state
        if let previousSequence = try? readLatest().sequence,
           committedState.sequence <= previousSequence {
            committedState.sequence = previousSequence &+ 1
        }
        let payload = LiveStateWireFormat.encode(committedState)
        var slot = Array(repeating: UInt8(0), count: Self.slotByteCount)
        writeInteger(Self.slotMagic, into: &slot, offset: 0)
        writeInteger(UInt16(1), into: &slot, offset: 4)
        writeInteger(UInt16(LiveStateWireFormat.byteCount), into: &slot, offset: 6)
        writeInteger(committedState.sequence, into: &slot, offset: 8)
        writeInteger(CRC32.checksum(payload), into: &slot, offset: 16)
        slot.replaceSubrange(24..<(24 + payload.count), with: payload)

        let handle = try FileHandle(forUpdating: fileURL)
        defer { try? handle.close() }
        flock(handle.fileDescriptor, LOCK_EX)
        defer { flock(handle.fileDescriptor, LOCK_UN) }
        let slotIndex = Int(committedState.sequence & 1)
        try handle.seek(toOffset: UInt64(slotIndex * Self.slotByteCount))
        try handle.write(contentsOf: Data(slot))
        try handle.synchronize()
    }

    public func readLatest() throws -> CompactLiveState {
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard data.count >= Self.fileByteCount else {
            throw LiveStateWireError.noValidSlot
        }
        let states = (0..<2).compactMap { index -> CompactLiveState? in
            let lower = index * Self.slotByteCount
            let slot = Data(data[lower..<(lower + Self.slotByteCount)])
            return try? decodeSlot(slot)
        }
        guard let latest = states.max(by: { $0.sequence < $1.sequence }) else {
            throw LiveStateWireError.noValidSlot
        }
        return latest
    }

    private func prepareFile() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            try Data(count: Self.fileByteCount).write(
                to: fileURL,
                options: [.atomic, .completeFileProtection]
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        } else {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
            if size < Self.fileByteCount {
                let handle = try FileHandle(forUpdating: fileURL)
                defer { try? handle.close() }
                try handle.truncate(atOffset: UInt64(Self.fileByteCount))
                try handle.synchronize()
            }
        }
    }

    private func decodeSlot(_ data: Data) throws -> CompactLiveState {
        let bytes = [UInt8](data)
        guard bytes.count == Self.slotByteCount,
              readUInt32(bytes, offset: 0) == Self.slotMagic,
              readUInt16(bytes, offset: 4) == 1,
              readUInt16(bytes, offset: 6) == UInt16(LiveStateWireFormat.byteCount) else {
            throw LiveStateWireError.invalidMagic
        }
        let payload = Data(bytes[24..<(24 + LiveStateWireFormat.byteCount)])
        guard readUInt32(bytes, offset: 16) == CRC32.checksum(payload) else {
            throw LiveStateWireError.checksumMismatch
        }
        let state = try LiveStateWireFormat.decode(payload)
        guard state.sequence == readUInt64(bytes, offset: 8) else {
            throw LiveStateWireError.checksumMismatch
        }
        return state
    }

    private func writeInteger<T: FixedWidthInteger>(
        _ value: T,
        into bytes: inout [UInt8],
        offset: Int
    ) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { source in
            for index in source.indices {
                bytes[offset + index] = source[index]
            }
        }
    }

    private func readUInt16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private func readUInt32(_ bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            UInt32(bytes[offset + 1]) << 8 |
            UInt32(bytes[offset + 2]) << 16 |
            UInt32(bytes[offset + 3]) << 24
    }

    private func readUInt64(_ bytes: [UInt8], offset: Int) -> UInt64 {
        (0..<8).reduce(UInt64(0)) {
            $0 | UInt64(bytes[offset + $1]) << UInt64($1 * 8)
        }
    }
}

enum CRC32 {
    static func checksum<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        var crc = UInt32.max
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xEDB8_8320 : 0)
            }
        }
        return ~crc
    }
}

private extension Float {
    var unitClamped: Float {
        guard isFinite else { return 0 }
        return min(1, max(0, self))
    }
}
