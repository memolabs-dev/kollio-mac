import Foundation

/// What a person did to the document, in order, and never edited afterwards.
///
/// ## What this is, and what it is not
///
/// It answers one question that the document cannot: **what happened to this?**
/// The document holds state plus decisions, and a decision preserves a *judgement*
/// somebody made. It does not record that a line was retyped, that a relationship
/// was removed, or that a whole branch was created and then abandoned. So the
/// history of an object is not recoverable from the object.
///
/// It is **not** an event log in the event-sourcing sense, and it is **not** a
/// source of truth:
///
/// - **It is not authoritative.** `KollioDocument` holds the truth. This ledger is
///   derived from the commands a session applied, and a file can arrive without
///   one. Restoring a document from this ledger is not implemented, and no claim
///   is made that it would work.
/// - **It is append-only.** A reversal is recorded as a reversal, never as the
///   removal of what came before. "That was taken back" and "that never happened"
///   are different statements about a person's work, and only the second one
///   erases it.
///
/// Calling it an event log would be the attractive mistake here. The difference is
/// not academic: an event log you can replay is a design commitment, and this one
/// cannot be replayed yet. It is an audit trail with a stated end.
public struct HistoryLedger: Codable, Hashable, Sendable {
    public private(set) var entries: [HistoryEntry]

    public init(entries: [HistoryEntry] = []) {
        self.entries = entries
    }

    public var isEmpty: Bool { entries.isEmpty }
    public var count: Int { entries.count }

    public mutating func append(_ entry: HistoryEntry) {
        entries.append(entry)
    }

    public mutating func removeAll(where predicate: (HistoryEntry) -> Bool) {
        entries.removeAll(where: predicate)
    }

    public func entry(_ id: HistoryEntryID) -> HistoryEntry? {
        entries.first { $0.id == id }
    }

    /// The entries that touched an object, in order.
    ///
    /// This is the question the document cannot answer, and the reason the ledger
    /// exists. A reversal is included when it touched the object, because
    /// "this was undone" is exactly what somebody reading the history of an object
    /// needs to know.
    public func entries(touching object: ObjectID, in document: KollioDocument) -> [HistoryEntry] {
        entries.filter { $0.touchedObjectIDs(in: document).contains(object) }
    }

    /// The entries a person could reasonably be shown for an object, newest last.
    ///
    /// Reversals are folded into the entry they cancel rather than listed beside
    /// them: a list that showed "added a branch" and "undid it" as two separate
    /// rows would make a person do the arithmetic themselves.
    public func narrative(for object: ObjectID, in document: KollioDocument) -> [HistoryNarrativeItem] {
        var cancelled = Set<HistoryEntryID>()
        for entry in entries {
            if case .reversed(let target) = entry.kind { cancelled.insert(target) }
        }
        return entries
            .filter { $0.touchedObjectIDs(in: document).contains(object) }
            .compactMap { entry in
                if cancelled.contains(entry.id) { return nil }
                let wasReverted = entries.contains { other in
                    if case .reversed(let target) = other.kind { return target == entry.id }
                    return false
                }
                return HistoryNarrativeItem(
                    at: entry.at,
                    label: entry.label,
                    movedMeaning: entry.movedMeaning,
                    wasLaterReverted: wasReverted,
                    entryID: entry.id
                )
            }
    }
}

/// One recorded action.
public struct HistoryEntry: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: Codable, Hashable, Sendable {
        /// A batch of commands that was accepted.
        case applied
        /// A batch of commands that a person took back. The payload is kept, so the
        /// history says what was undone and not merely that something was.
        case reversed(target: HistoryEntryID)
    }

    public var id: HistoryEntryID
    public var kind: Kind
    public var at: Date
    /// The menu label the person acted under, which is the only description of
    /// *why* that exists. A history that recorded commands without intent would
    /// answer "what" and never "what for".
    public var label: String
    public var commands: [Command]
    public var revisionBefore: Int
    public var revisionAfter: Int
    public var semanticRevisionBefore: Int
    public var semanticRevisionAfter: Int

    public init(
        id: HistoryEntryID,
        kind: Kind,
        at: Date,
        label: String,
        commands: [Command],
        revisionBefore: Int,
        revisionAfter: Int,
        semanticRevisionBefore: Int,
        semanticRevisionAfter: Int
    ) {
        self.id = id
        self.kind = kind
        self.at = at
        self.label = label
        self.commands = commands
        self.revisionBefore = revisionBefore
        self.revisionAfter = revisionAfter
        self.semanticRevisionBefore = semanticRevisionBefore
        self.semanticRevisionAfter = semanticRevisionAfter
    }

    /// True when this changed what the document means, as opposed to where
    /// something is drawn.
    public var movedMeaning: Bool { semanticRevisionBefore != semanticRevisionAfter }

    /// The objects this entry touched, for the question the document cannot answer.
    ///
    /// Resolved against the document the commands were applied to. An entry whose
    /// relationship has since been removed resolves to the ends that were current
    /// when it happened, which is the only reading that makes sense of it.
    public func touchedObjectIDs(in document: KollioDocument) -> Set<ObjectID> {
        Set(commands.flatMap { $0.touchedObjectIDs(in: document) })
    }
}

/// One row of a person's history of a thing, with a reversal already folded in.
public struct HistoryNarrativeItem: Hashable, Sendable, Identifiable {
    public var at: Date
    public var label: String
    public var movedMeaning: Bool
    public var wasLaterReverted: Bool
    /// The ledger entry this row came from, so preview and restore can find it.
    public var entryID: HistoryEntryID

    public init(at: Date, label: String, movedMeaning: Bool, wasLaterReverted: Bool, entryID: HistoryEntryID) {
        self.at = at
        self.label = label
        self.movedMeaning = movedMeaning
        self.wasLaterReverted = wasLaterReverted
        self.entryID = entryID
    }

    public var id: String { "\(at.timeIntervalSince1970)-\(label)" }
}

public struct HistoryEntryID: Hashable, Sendable, Codable, CustomStringConvertible {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ seed: String) { self.rawValue = "history_\(seed)" }
    public var idString: String { rawValue }
    public var description: String { rawValue }
}
