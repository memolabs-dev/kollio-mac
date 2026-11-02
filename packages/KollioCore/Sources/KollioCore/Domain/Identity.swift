import Foundation

/// Stable identity of a semantic object. Never regenerated, never reused.
/// Anything that can key a document map by its string form.
public protocol KollioIdentifier: Hashable {
    init(_ string: String)
    var idString: String { get }
}

public struct ObjectID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
    public init(stringLiteral value: String) { self.rawValue = value }
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var idString: String { rawValue }

    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct RelationshipID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
    public init(stringLiteral value: String) { self.rawValue = value }
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var idString: String { rawValue }
    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct InstanceID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
    public init(stringLiteral value: String) { self.rawValue = value }
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var idString: String { rawValue }
    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ExperimentID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
    public init(stringLiteral value: String) { self.rawValue = value }
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var idString: String { rawValue }
    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct DecisionID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
    public init(stringLiteral value: String) { self.rawValue = value }
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var idString: String { rawValue }
    public var description: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Kind of identity source. Kept so provenance can distinguish a human author
/// from a local deterministic engine or a remote model.
public struct ActorID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
    public init(stringLiteral value: String) { self.rawValue = value }
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var idString: String { rawValue }
    public var description: String { rawValue }
}

/// Source of a semantic change, durable in the document.
public struct Provenance: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case human
        case localEngine
        case remoteModel
    }

    public var actor: ActorID
    public var kind: Kind
    public var requestId: String?
    public var proposalId: String?

    public init(actor: ActorID, kind: Kind, requestId: String? = nil, proposalId: String? = nil) {
        self.actor = actor
        self.kind = kind
        self.requestId = requestId
        self.proposalId = proposalId
    }

    public static func human(_ id: ActorID) -> Provenance {
        Provenance(actor: id, kind: .human)
    }
}

/// A reusable contribution: a method, a technical block, an asset that can take
/// part in more than one product. Visual duplication of an object never creates
/// a new contribution (see `NodeInstance`).
public struct ContributionRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: ActorID
    public var name: String
    public var kind: ContentObject.Kind
    public var owner: ActorID
    public var reusable: Bool

    public init(id: ActorID, name: String, kind: ContentObject.Kind, owner: ActorID, reusable: Bool = true) {
        self.id = id
        self.name = name
        self.kind = kind
        self.owner = owner
        self.reusable = reusable
    }
}
