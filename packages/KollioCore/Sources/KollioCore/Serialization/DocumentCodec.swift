import Foundation

/// Reads and writes the portable `.kollio` document.
///
/// The file is versioned JSON, human-inspectable, and completely independent of
/// SwiftUI, AppKit and the renderer.
public enum DocumentCodec {
    public enum CodecError: Error, CustomStringConvertible {
        case unsupportedSchemaVersion(found: Int, supported: Int)
        case malformed(String)

        public var description: String {
            switch self {
            case .unsupportedSchemaVersion(let found, let supported):
                return "Unsupported .kollio schema version \(found), this build reads up to \(supported)"
            case .malformed(let detail):
                return "Malformed .kollio file: \(detail)"
            }
        }
    }

    public static let fileExtension = "kollio"

    /// ISO 8601 with fractional seconds: readable in the file, and lossless
    /// enough that a save / reopen cycle is a true round-trip.
    static func timestamp() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DocumentCodec.timestamp().string(from: date))
        }
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = DocumentCodec.timestamp().date(from: raw) else {
                throw CodecError.malformed("invalid date \(raw)")
            }
            return date
        }
        return decoder
    }

    public static func encode(_ document: KollioDocument) throws -> Data {
        try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> KollioDocument {
        let document: KollioDocument
        do {
            document = try decoder.decode(KollioDocument.self, from: data)
        } catch {
            throw CodecError.malformed(String(describing: error))
        }
        guard document.schemaVersion <= KollioDocument.currentSchemaVersion else {
            throw CodecError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: KollioDocument.currentSchemaVersion
            )
        }
        return document
    }

    public static func write(_ document: KollioDocument, to url: URL) throws {
        try encode(document).write(to: url, options: .atomic)
    }

    public static func read(from url: URL) throws -> KollioDocument {
        try decode(Data(contentsOf: url))
    }
}

/// Stable id minting. Ids are never regenerated, so this only needs to be
/// collision free within a document.
public enum KollioID {
    public static func object(_ seed: String) -> ObjectID { ObjectID("object:\(seed)") }
    public static func relationship(_ seed: String) -> RelationshipID { RelationshipID("relationship:\(seed)") }
    public static func decision(_ seed: String) -> DecisionID { DecisionID("decision:\(seed)") }
    public static func experiment(_ seed: String) -> ExperimentID { ExperimentID("experiment:\(seed)") }
    public static func instance(_ seed: String) -> InstanceID { InstanceID("instance:\(seed)") }
    public static func contribution(_ seed: String) -> ActorID { ActorID("contribution:\(seed)") }
}
