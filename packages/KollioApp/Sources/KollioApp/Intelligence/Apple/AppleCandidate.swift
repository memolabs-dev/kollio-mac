import Foundation
import KollioCore

#if canImport(FoundationModels)
import FoundationModels
#endif

/// What the on-device model is asked to produce.
///
/// This is deliberately small. A small local model should not be asked to
/// reconstruct a command enum, mint identifiers, or reason about the whole
/// document: it fills in meaning, and the trusted layer around it does the rest.
///
/// `@Generable` and `@Guide` live here, in the Apple adapter, and never on a
/// portable domain or command type. The `.kollio` document stays readable on a
/// Mac that has no Apple model at all.
///
/// The macro is gated on macOS 26, which is the framework's own floor, and the
/// app's deployment target stays where it is. This is a compile-time guard and
/// is not the same thing as the runtime availability check the adapter also
/// performs: compiling here does not mean the model is usable on this Mac.
@available(macOS 26.0, *)
@Generable
public struct AppleCandidate {
    /// `proposal`, `needsInput` or `noChange`. Nothing else is accepted, and
    /// `noChange` is a legitimate answer: the model is never pushed to invent a
    /// branch to fill the canvas.
    @Guide(description: "One of: proposal, needsInput, noChange")
    public var outcome: String

    /// One short sentence addressed to the user. Never a chain of thought.
    @Guide(description: "One short sentence addressed to the user, no reasoning")
    public var rationale: String

    /// At most a few directions. Bounded on purpose.
    @Guide(description: "At most 2 short proposed directions")
    public var ideas: [AppleCandidateIdea]

    public init(outcome: String, rationale: String, ideas: [AppleCandidateIdea]) {
        self.outcome = outcome
        self.rationale = rationale
        self.ideas = ideas
    }
}

@available(macOS 26.0, *)
@Generable
public struct AppleCandidateIdea {
    /// A short title, not a paragraph.
    @Guide(description: "A short title of at most 8 words")
    public var title: String

    /// One sentence on what this direction means.
    @Guide(description: "One sentence describing this direction")
    public var summary: String

    /// What kind of thing it is, from the small vocabulary the canvas renders.
    @Guide(description: "One of: hypothesis, constraint, question, method")
    public var kind: String

    public init(title: String, summary: String, kind: String) {
        self.title = title
        self.summary = summary
        self.kind = kind
    }
}

/// The trusted conversion from a model answer to real domain commands.
///
/// Identifiers are minted here, never taken from the model. Kinds outside the
/// rendered vocabulary are refused rather than invented. An outcome of
/// `proposal` with nothing usable in it is reported as `noChange` rather than as
/// an empty branch the user would have to dismiss.
public struct AppleCandidateConverter: Sendable {
    /// More than this is noise, not a branch.
    public static let maximumIdeas = 3

    public struct Converted: Sendable {
        /// A local result, expressed in the app's own vocabulary. The server
        /// package has its own equivalent, and the app must not depend on it.
        public enum Outcome: Sendable {
            case proposal(Proposal)
            case needsInput([String])
            case noChange
            case malformed(String)
        }
        public var result: Outcome
        public var droppedIdeas: Int
        public var droppedKinds: Int

        /// The same answer as a `ProposalResponse`, which is what the seam speaks.
        public var response: ProposalResponse {
            switch result {
            case .proposal(let proposal):
                return ProposalResponse(status: .proposed, proposal: proposal)
            case .needsInput(let questions):
                return .needsInput(questions.map { LocalizedText($0) })
            case .noChange:
                return .noChange()
            case .malformed:
                return .noChange()
            }
        }
    }

    public init() {}

    @available(macOS 26.0, *)
    public func convert(
        _ candidate: AppleCandidate,
        request: ProposalRequest,
        document: KollioDocument,
        contextScope: ProposalContextScope? = nil
    ) -> Converted {
        var droppedIdeas = 0
        var droppedKinds = 0

        // A short local answer earns a short branch. The scope is the client's,
        // and this can only narrow it.
        let budget = min(request.scope.maxOperations, Self.maximumIdeas)
        var operations: [Command] = []
        var created: [ObjectID] = []

        for (index, idea) in candidate.ideas.prefix(max(0, budget)).enumerated() {
            guard let kind = Self.kind(from: idea.kind) else {
                droppedKinds += 1
                continue
            }
            let title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                droppedIdeas += 1
                continue
            }
            let id = ObjectID("object:apple-\(Self.stem(request.requestId))-\(index)")
            guard document.object(id) == nil else { continue }
            operations.append(.createObject(CreateObject(
                id: id,
                kind: kind,
                text: LocalizedText(title),
                detail: idea.summary.isEmpty ? nil : LocalizedText(idea.summary),
                provenance: .init(
                    actor: ActorID("apple:on-device"),
                    kind: .localEngine,
                    requestId: request.requestId
                )
            )))
            created.append(id)
        }
        droppedIdeas += max(0, candidate.ideas.count - budget)

        // One relationship per idea, back to what the user asked about. The
        // anchor is the target of the request, which the server and the client
        // have both already checked exists.
        for (index, id) in created.enumerated() {
            guard let anchor = request.targetIds.first else { break }
            let relationshipID = RelationshipID("relationship:apple-\(Self.stem(request.requestId))-\(index)")
            guard document.relationship(relationshipID) == nil else { continue }
            operations.append(.addRelationship(AddRelationship(
                id: relationshipID,
                from: anchor,
                to: id,
                kind: .alternativeTo,
                provenance: .init(
                    actor: ActorID("apple:on-device"),
                    kind: .localEngine,
                    requestId: request.requestId
                )
            )))
        }

        let normalized = candidate.outcome.trimmingCharacters(in: .whitespaces).lowercased()
        switch normalized {
        case "nochange", "no change":
            return Converted(result: .noChange, droppedIdeas: droppedIdeas, droppedKinds: droppedKinds)
        case "needsinput", "needs input":
            return Converted(
                result: .needsInput([candidate.rationale.isEmpty ? "What should be explored first?" : candidate.rationale]),
                droppedIdeas: droppedIdeas,
                droppedKinds: droppedKinds
            )
        case "proposal":
            guard operations.isEmpty == false else {
                // Nothing usable came back. Said honestly, not shown as a branch.
                return Converted(result: .noChange, droppedIdeas: droppedIdeas, droppedKinds: droppedKinds)
            }
            let proposal = Proposal(
                proposalId: "proposal:\(request.requestId)",
                requestId: request.requestId,
                documentId: document.documentId,
                baseSemanticRevision: request.baseSemanticRevision,
                summary: LocalizedText(created.count == 1 ? "One direction" : "\(created.count) directions"),
                rationale: candidate.rationale.isEmpty ? nil : LocalizedText(candidate.rationale),
                operations: operations,
                placementHints: created.map { .init(objectID: $0) },
                generator: .init(name: "apple-on-device", deterministic: false),
                contextScope: contextScope
            )
            return Converted(result: .proposal(proposal), droppedIdeas: droppedIdeas, droppedKinds: droppedKinds)
        default:
            // An outcome this adapter does not understand is never guessed at.
            return Converted(result: .malformed("unrecognised outcome"), droppedIdeas: droppedIdeas, droppedKinds: droppedKinds)
        }
    }

    /// Only the kinds the canvas actually renders differently. Anything else is
    /// dropped rather than coerced.
    static func kind(from raw: String) -> ContentObject.Kind? {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "hypothesis": return .hypothesis
        case "constraint": return .constraint
        case "question": return .question
        case "method": return .method
        default: return nil
        }
    }

    /// A short, stable, collision-resistant stem for minted identifiers.
    static func stem(_ requestId: String) -> String {
        let allowed = requestId.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(allowed).prefix(8))
    }
}
