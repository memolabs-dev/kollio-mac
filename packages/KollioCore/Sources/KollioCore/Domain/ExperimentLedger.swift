import Foundation

/// A validation experiment, built before it runs (DEC-04).
///
/// The reason this is a ledger and not a text field on a hypothesis: an
/// experiment is project memory in exactly the sense a decision is. It has to
/// survive a quit, a reload and a share, and it has to stay readable *after* a
/// result exists — which is the whole of AC01, "criteria are kept before the
/// result". A person who wrote a success criterion on Monday and reads the
/// result on Friday must be able to see the criterion they committed to, not
/// the one they would have written after knowing the outcome.
///
/// The struct is therefore append-only in the one place it matters: the fields
/// the result will be judged against live in revisions, and no edit rewrites
/// them. Editing appends. What a revision is for is stated by AC03: editing
/// after a result creates a visible revision, and the visible part is done by
/// never hiding the old ones.
///
/// Note what the type refuses to know: whether the experiment has run, whether
/// it succeeded, whether its due date has passed. An overdue date is not a
/// failure, and an unrecorded conclusion stays unknown — those are DEC-05's
/// questions, and this type carries no answer to them, not even a default.
public struct Experiment: Codable, Hashable, Sendable, Identifiable {
    /// The reasoning this experiment validates: the object whose claim is at
    /// stake. Attached to the reasoning, never to a board.
    public var targetObjectID: ObjectID
    /// What is being asked. Required: an experiment with no question is a
    /// task, and this is not a task list.
    public var question: LocalizedText
    /// How it will be run. Optional: the honest state of a just-born
    /// experiment is often "question first, method next".
    public var method: LocalizedText?
    /// What would count as a success. Required, and never rewritten.
    public var successCriterion: LocalizedText
    /// Evidence objects the document already holds that this experiment should
    /// be judged against. Every id is validated against the document's content
    /// at command time, so a link here points at a thing that exists.
    public var expectedEvidence: [ObjectID]
    /// Who runs it, when it is due. Both optional, and neither is a status:
    /// the type has no vocabulary for "late", by design.
    public var owner: ActorID?
    public var dueDate: Date?
    /// A simulation is labelled as one. There is no default of `false`
    /// *claimed as truth*: `false` means "not a simulation", `true` means
    /// "this never touched the world", and both are authored.
    public var isSimulation: Bool
    /// The block's own past, oldest first. Revision 0 is the creation.
    public var revisions: [ExperimentRevision]
    /// The results recorded against the block, oldest first, append-only.
    ///
    /// A second result does not overwrite the first: two runs are two answers,
    /// and a ledger that kept only the newest would let a second run quietly
    /// retire a first without a word. Reading "the result" means reading the
    /// last one; nothing here hides the ones before it.
    public var results: [ExperimentResultVersion]
    /// The learnings proposed from those results.
    public var findings: [LearnedFinding]

    public var id: ExperimentID
    public var createdAt: Date
    public var provenance: Provenance

    public init(
        id: ExperimentID,
        targetObjectID: ObjectID,
        question: LocalizedText,
        method: LocalizedText? = nil,
        successCriterion: LocalizedText,
        expectedEvidence: [ObjectID] = [],
        owner: ActorID? = nil,
        dueDate: Date? = nil,
        isSimulation: Bool = false,
        revisions: [ExperimentRevision]? = nil,
        results: [ExperimentResultVersion] = [],
        findings: [LearnedFinding] = [],
        createdAt: Date,
        provenance: Provenance
    ) {
        self.id = id
        self.targetObjectID = targetObjectID
        self.question = question
        self.method = method
        self.successCriterion = successCriterion
        self.expectedEvidence = expectedEvidence
        self.owner = owner
        self.dueDate = dueDate
        self.isSimulation = isSimulation
        self.results = results
        self.findings = findings
        self.revisions = revisions ?? [
            ExperimentRevision(
                question: question,
                method: method,
                successCriterion: successCriterion,
                expectedEvidence: expectedEvidence,
                provenance: provenance,
                recordedAt: createdAt
            )
        ]
        self.createdAt = createdAt.kollioNormalized
        self.provenance = provenance
    }

    /// The fields a result will be judged against, as they stand now.
    public var currentRevision: ExperimentRevision {
        revisions.last ?? ExperimentRevision(
            question: question,
            method: method,
            successCriterion: successCriterion,
            expectedEvidence: expectedEvidence,
            provenance: provenance,
            recordedAt: createdAt
        )
    }

    /// The criterion as it stood when a given revision was current. The point
    /// of the revision list: the criterion a result was judged against is
    /// readable after the fact, not replaced by today's.
    public func revision(_ index: Int) -> ExperimentRevision? {
        revisions.indices.contains(index) ? revisions[index] : nil
    }
}

/// One committed version of an experiment's judged-against fields.
///
/// Deliberately shallow: no result, no outcome. What was committed, by whom and
/// when is enough for the question this answers, which is "what did the person
/// commit to before they knew?". The result belongs to DEC-05 and will name the
/// revision it was judged against; putting it here would let a criterion and a
/// verdict grow into one undecidable blob.
public struct ExperimentRevision: Codable, Hashable, Sendable {
    public var question: LocalizedText
    public var method: LocalizedText?
    public var successCriterion: LocalizedText
    public var expectedEvidence: [ObjectID]
    public var provenance: Provenance
    public var recordedAt: Date

    public init(
        question: LocalizedText,
        method: LocalizedText?,
        successCriterion: LocalizedText,
        expectedEvidence: [ObjectID],
        provenance: Provenance,
        recordedAt: Date
    ) {
        self.question = question
        self.method = method
        self.successCriterion = successCriterion
        self.expectedEvidence = expectedEvidence
        self.provenance = provenance
        self.recordedAt = recordedAt.kollioNormalized
    }
}

/// Every experiment in the document.
///
/// Part of the document rather than a side store, for the reason every ledger
/// here gives: an experiment and the reasoning it validates are one thing, and
/// they travel in one file.
public struct ExperimentLedger: Codable, Hashable, Sendable {
    public var experiments: [ExperimentID: Experiment]

    public init(experiments: [ExperimentID: Experiment] = [:]) {
        self.experiments = experiments
    }

    public func experiment(_ id: ExperimentID) -> Experiment? {
        experiments[id]
    }

    /// Every learning proposed anywhere in the document.
    public var findings: [LearnedFinding] {
        experiments.values.flatMap(\.findings)
    }

    /// Every learning proposed anywhere in the document.
    public func finding(_ id: FindingID) -> LearnedFinding? {
        findings.first { $0.id == id }
    }

    /// The experiments attached to one object's reasoning.
    public func experiments(targeting objectID: ObjectID) -> [Experiment] {
        experiments.values
            .filter { $0.targetObjectID == objectID }
            .sorted {
                // Oldest first, and the id breaks a tie on purpose: two
                // experiments created within the same normalised second have
                // equal dates, and a sort that leaves their order to chance
                // would make "the newest" mean "whatever the dictionary felt
                // like". The tiebreak is arbitrary and *stable*, which is what
                // a reader of a list is owed.
                ($0.createdAt, $0.id.rawValue) < ($1.createdAt, $1.id.rawValue)
            }
    }
}
