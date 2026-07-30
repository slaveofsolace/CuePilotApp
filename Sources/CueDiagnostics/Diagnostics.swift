import Foundation

/// A deliberately small vocabulary for runtime measurements. Diagnostic events
/// never accept arbitrary labels, file names, image data, or captured text.
public enum DiagnosticOperation: String, Codable, CaseIterable, Sendable {
    case framePreprocessing
    case tableDetection
    case ballDetection
    case cueTracking
    case powerTracking
    case strategySolve
    case stateTransport
}

public enum DiagnosticCounter: String, Codable, CaseIterable, Sendable {
    case analyzedFrames
    case skippedDuplicateFrames
    case uncertainDetections
    case manualCorrections
    case transportReadFailures
    case transportWriteFailures
    case sessionTransitions
}

public struct LatencySummary: Codable, Equatable, Sendable {
    public var sampleCount: Int
    public var minimumMilliseconds: Double
    public var medianMilliseconds: Double
    public var percentile95Milliseconds: Double
    public var maximumMilliseconds: Double

    public init(
        sampleCount: Int,
        minimumMilliseconds: Double,
        medianMilliseconds: Double,
        percentile95Milliseconds: Double,
        maximumMilliseconds: Double
    ) {
        self.sampleCount = sampleCount
        self.minimumMilliseconds = minimumMilliseconds
        self.medianMilliseconds = medianMilliseconds
        self.percentile95Milliseconds = percentile95Milliseconds
        self.maximumMilliseconds = maximumMilliseconds
    }
}

public struct DiagnosticsExport: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var appVersion: String
    public var platform: String
    public var counters: [String: Int]
    public var latencies: [String: LatencySummary]

    public init(
        generatedAt: Date,
        appVersion: String,
        platform: String,
        counters: [String: Int],
        latencies: [String: LatencySummary]
    ) {
        self.schemaVersion = Self.schemaVersion
        self.generatedAt = generatedAt
        self.appVersion = appVersion
        self.platform = platform
        self.counters = counters
        self.latencies = latencies
    }
}

/// Stores only bounded numeric telemetry in memory. It has no API that accepts
/// pixels, screenshots, OCR text, paths, bundle identifiers, or user content.
public actor PrivacySafeDiagnostics {
    private let appVersion: String
    private let platform: String
    private let maximumSamplesPerOperation: Int
    private var counters: [DiagnosticCounter: Int]
    private var latencySamples: [DiagnosticOperation: [Double]]

    public init(
        appVersion: String,
        platform: String,
        maximumSamplesPerOperation: Int = 512
    ) {
        self.appVersion = Self.sanitizedMetadata(appVersion)
        self.platform = Self.sanitizedMetadata(platform)
        self.maximumSamplesPerOperation = max(8, maximumSamplesPerOperation)
        self.counters = [:]
        self.latencySamples = [:]
    }

    public func increment(_ counter: DiagnosticCounter, by amount: Int = 1) {
        guard amount > 0 else { return }
        counters[counter, default: 0] += amount
    }

    public func record(_ operation: DiagnosticOperation, milliseconds: Double) {
        guard milliseconds.isFinite, milliseconds >= 0 else { return }
        var samples = latencySamples[operation, default: []]
        if samples.count == maximumSamplesPerOperation {
            samples.removeFirst()
        }
        samples.append(milliseconds)
        latencySamples[operation] = samples
    }

    public func snapshot(at date: Date = Date()) -> DiagnosticsExport {
        let exportedCounters = Dictionary(
            uniqueKeysWithValues: counters.map { ($0.key.rawValue, $0.value) }
        )
        let exportedLatencies: [String: LatencySummary] = Dictionary(
            uniqueKeysWithValues: latencySamples.compactMap { operation, values in
                guard let summary = Self.summarize(values) else {
                    return nil as (String, LatencySummary)?
                }
                return (operation.rawValue, summary)
            }
        )
        return DiagnosticsExport(
            generatedAt: date,
            appVersion: appVersion,
            platform: platform,
            counters: exportedCounters,
            latencies: exportedLatencies
        )
    }

    /// Export is always an explicit call with an explicit destination. The
    /// resulting JSON contains aggregate numbers only.
    @discardableResult
    public func export(to destination: URL, at date: Date = Date()) throws -> URL {
        let report = snapshot(at: date)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
        return destination
    }

    public func reset() {
        counters.removeAll(keepingCapacity: true)
        latencySamples.removeAll(keepingCapacity: true)
    }

    private static func summarize(_ samples: [Double]) -> LatencySummary? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        return LatencySummary(
            sampleCount: sorted.count,
            minimumMilliseconds: sorted[0],
            medianMilliseconds: percentile(0.50, in: sorted),
            percentile95Milliseconds: percentile(0.95, in: sorted),
            maximumMilliseconds: sorted[sorted.count - 1]
        )
    }

    private static func percentile(_ percentile: Double, in sorted: [Double]) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let position = percentile * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }

    private static func sanitizedMetadata(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: " ._-")
        )
        let scalars = value.unicodeScalars
            .filter { allowed.contains($0) }
            .prefix(64)
        let result = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "unspecified" : result
    }
}
