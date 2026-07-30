import Foundation

public enum SessionStoreError: Error, Equatable, Sendable {
    case duplicateIdentifier
    case sessionNotFound
}

public actor SessionStore {
    private struct Envelope: Codable, Sendable {
        var schemaVersion: Int
        var sessions: [MatchSession]
    }

    private let fileURL: URL
    private var cache: [MatchSession]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func sessions() throws -> [MatchSession] {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cache = []
            return []
        }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(Envelope.self, from: data)
        cache = envelope.sessions
        return envelope.sessions
    }

    public func session(id: UUID) throws -> MatchSession {
        guard let result = try sessions().first(where: { $0.id == id }) else {
            throw SessionStoreError.sessionNotFound
        }
        return result
    }

    public func create(_ session: MatchSession) throws {
        var current = try sessions()
        guard !current.contains(where: { $0.id == session.id }) else {
            throw SessionStoreError.duplicateIdentifier
        }
        current.append(session)
        try save(current)
    }

    public func upsert(_ session: MatchSession) throws {
        var current = try sessions()
        if let index = current.firstIndex(where: { $0.id == session.id }) {
            guard session.revision >= current[index].revision else { return }
            current[index] = session
        } else {
            current.append(session)
        }
        try save(current)
    }

    public func remove(id: UUID) throws {
        var current = try sessions()
        guard current.contains(where: { $0.id == id }) else {
            throw SessionStoreError.sessionNotFound
        }
        current.removeAll { $0.id == id }
        try save(current)
    }

    public func removeFinished() throws {
        var current = try sessions()
        current.removeAll(where: \.isFinished)
        try save(current)
    }

    private func save(_ sessions: [MatchSession]) throws {
        let sorted = sessions.sorted { $0.updatedAt > $1.updatedAt }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(
            schemaVersion: MatchSession.schemaVersion,
            sessions: sorted
        ))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        cache = sorted
    }
}
