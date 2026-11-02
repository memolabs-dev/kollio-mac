import Foundation

/// A result recorded against an experiment (DEC-05).
///
/// The shape enforces the one separation the specification is about: what was
/// *observed* and what it *means* are different fields, and nothing in this
/// type derives one from the other. The observation is a sentence a person
/// wrote after running something. The outcome is a stance on the success
/// criterion. They are both required, they are not each other, and the type
/// has no field that would let a percentage pretend either of them is
/// arithmetic.
///
/// What is deliberately absent: any validity score. "Insufficient data yields
/// an accepted inconclusive result, never an invented validity percentage" is
/// a rule about what cannot even be written down, so there is no place to
/// write it. An inconclusive result carries its reason instead, which is the
/// visible missing data AC02 asks for.
///
/// Versions are append-only: recording is the act, rewriting is not offered.
/// The observation a person wrote stays exactly as they wrote it, which is
/// what makes "the AI does not rewrite a supplied result" true by
/// construction rather than by discipline.
public struct ExperimentResultVersion: Codable, Hashable, Sendable {
    /// What a distinct acceptance means, and why there are only two.
    ///
    /// `criterionMet` says the thing the criterion promised was observed.
    /// `criterionNotMet` says it was not. Neither is a truth claim about the
    /// world: a criterion can be met by coincidence, and only a further
    /// decision says what follows. There is no "partially met", because a
    /// partial answer to a yes/no criterion is not a stance, it is an
    /// inconclusive result waiting for its reason.
    public enum Outcome: Codable, Hashable, Sendable {
        case conclusive(Conclusive)
        /// Data insufficient, named. The reason is required: an inconclusive
        /// result that cannot say what is missing is not an honest answer,
        /// it is a shrug.
        case inconclusive(String)

        public enum Conclusive: String, Codable, Sendable {
            case criterionMet
            case criterionNotMet
        }

        public var isInconclusive: Bool {
            if case .inconclusive = self { return true }
            return false
        }
    }

    public var observation: String
    public var measurements: [ExperimentMeasurement]
    /// What the run could not do. The second half of AC02: missing data is
    /// visible whether or not the outcome says so.
    public var limits: String?
    /// Where the numbers came from, when they came from something the
    /// document holds. Optional, and validated to exist at command time.
    public var sourceObjectID: ObjectID?
    public var outcome: Outcome
    public var provenance: Provenance
    public var recordedAt: Date

    public init(
        observation: String,
        measurements: [ExperimentMeasurement] = [],
        limits: String? = nil,
        sourceObjectID: ObjectID? = nil,
        outcome: Outcome,
        provenance: Provenance,
        recordedAt: Date
    ) {
        self.observation = observation
        self.measurements = measurements
        self.limits = limits
        self.sourceObjectID = sourceObjectID
        self.outcome = outcome
        self.provenance = provenance
        self.recordedAt = recordedAt.kollioNormalized
    }

    public var conclusion: Outcome.Conclusive? {
        if case .conclusive(let c) = outcome { return c }
        return nil
    }
}

/// One number, and what it counts.
///
/// A measurement without a unit is not a measurement, it is a coincidence with
/// a decimal point, so the unit is required here and re-checked at the command
/// layer: the type can be built wrongly by code, and the command is the only
/// place a person's input crosses.
public struct ExperimentMeasurement: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}

/// A learning proposed from a result (DEC-05).
///
/// It is proposed, not accepted, when it is created. "A distinct decision must
/// be accepted" is enforced by construction: accepting a learning means
/// pointing at a real decision in the document — a `Decision` recorded by the
/// person, through DEC-01's own command. Nothing here manufactures one, and
/// nothing here applies one. The learning does not change the document; it
/// says what the result taught, and leaves the taking-a-decision to the act
/// that takes decisions.
public struct LearnedFinding: Codable, Hashable, Sendable, Identifiable {
    public enum Status: String, Codable, Sendable {
        /// Proposed, and the document is unchanged by it.
        case proposed
        /// A real decision exists, and this learning names it.
        case accepted
    }

    public var id: FindingID
    /// The learning in the person's words. Authored, never generated.
    public var statement: LocalizedText
    /// The result it learned from, and which version of it.
    public var experimentID: ExperimentID
    public var revisionIndex: Int
    /// Where the learning applies. Empty is refused at the command layer: a
    /// learning about nothing is not a learning.
    public var scopeObjectIDs: [ObjectID]
    public var status: Status
    public var acceptedByDecision: DecisionID?
    public var proposedAt: Date
    public var provenance: Provenance

    public init(
        id: FindingID,
        statement: LocalizedText,
        experimentID: ExperimentID,
        revisionIndex: Int,
        scopeObjectIDs: [ObjectID],
        status: Status = .proposed,
        acceptedByDecision: DecisionID? = nil,
        proposedAt: Date,
        provenance: Provenance
    ) {
        self.id = id
        self.statement = statement
        self.experimentID = experimentID
        self.revisionIndex = revisionIndex
        self.scopeObjectIDs = scopeObjectIDs
        self.status = status
        self.acceptedByDecision = acceptedByDecision
        self.proposedAt = proposedAt.kollioNormalized
        self.provenance = provenance
    }
}

public struct FindingID: Hashable, Sendable, Codable, CustomStringConvertible, RawRepresentable, ExpressibleByStringLiteral, KollioIdentifier {
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
