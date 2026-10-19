import Foundation

/// Local editing history (Cmd+Z).
///
/// This is *not* project memory. A decision recorded in the document survives
/// closing the app; an undone edit does not. `UndoHistory` therefore holds
/// document snapshots, and each entry carries a label for the menu.
public struct UndoHistory: Sendable {
    public struct Entry: Sendable {
        public var label: String
        public var documentBefore: KollioDocument
        public var documentAfter: KollioDocument
    }

    public private(set) var entries: [Entry] = []
    public private(set) var cursor: Int = 0
    public var limit: Int

    public init(limit: Int = 100) {
        self.limit = limit
    }

    public var canUndo: Bool { cursor > 0 }
    public var canRedo: Bool { cursor < entries.count }

    /// The entry a following `undo` would revert.
    ///
    /// Read *before* calling `undo`, because `undo` moves the cursor and does not
    /// report what it did. The audit ledger needs to say which action was taken
    /// back, and a reversal that cannot name its target is only half a record.
    public var nextUndoIndex: Int? { canUndo ? cursor - 1 : nil }

    public var undoLabel: String? { canUndo ? entries[cursor - 1].label : nil }
    public var redoLabel: String? { canRedo ? entries[cursor].label : nil }

    public mutating func record(label: String, before: KollioDocument, after: KollioDocument) {
        // A new action after an undo discards the redo tail.
        if cursor < entries.count {
            entries.removeSubrange(cursor..<entries.count)
        }
        guard before != after else { return }
        entries.append(Entry(label: label, documentBefore: before, documentAfter: after))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        cursor = entries.count
    }

    public mutating func undo(current: KollioDocument) -> KollioDocument? {
        guard canUndo else { return nil }
        cursor -= 1
        return entries[cursor].documentBefore
    }

    public mutating func redo(current: KollioDocument) -> KollioDocument? {
        guard canRedo else { return nil }
        let document = entries[cursor].documentAfter
        cursor += 1
        return document
    }

    public mutating func reset() {
        entries.removeAll()
        cursor = 0
    }
}

/// Applies commands, records undo entries, and keeps the document consistent.
///
/// This is the seam the app binds to. Views never mutate the document directly.
public struct KollioSession: Sendable {
    public private(set) var store: DocumentStore
    public private(set) var history: UndoHistory
    public private(set) var lastError: DocumentError?

    public init(document: KollioDocument = KollioDocument()) {
        self.store = DocumentStore(document: document)
        self.history = UndoHistory()
        self.journalBase = try? DocumentCodec.encode(document)
    }

    /// The document as it stood before the first action recorded in *this*
    /// session, encoded.
    ///
    /// A replay needs somewhere to start, and "an empty document" is the wrong
    /// answer for every document that was opened rather than built here: the
    /// journal records what happened *since*, so replaying from nothing rebuilds
    /// only the edits and loses the content they were applied to.
    ///
    /// It is deliberately *before the first action*, not the current document.
    /// Seeding it from the current state makes a preview of the first action
    /// replay every action on top of an already-finished document and show the
    /// present instead of the past, which is the one thing a preview must never
    /// do. It is session state rather than a fact about the document, which is
    /// why it is not in the document and not in its schema: a file written last
    /// week and reopened today replays from that file's own content.
    public private(set) var journalBase: Data?

    /// The document a journal replay starts from.
    public var journalBaseDocument: KollioDocument {
        guard let journalBase else { return KollioDocument() }
        return (try? DocumentCodec.decode(journalBase)) ?? KollioDocument()
    }

    public var document: KollioDocument { store.document }
    public var semanticRevision: Int { store.semanticRevision }

    /// Replaces the underlying document entirely. Used for history restore (DEC-06).
    public mutating func replaceDocument(with document: KollioDocument) {
        store.replace(with: document)
    }

    /// Records an entry against the document as it stands, without applying
    /// commands.
    ///
    /// For an action that is not a command batch — a restore, which replaces the
    /// document wholesale. It appends to the *current* document on purpose: an
    /// earlier version took the pre-action document as a parameter and wrote it
    /// back, which silently undid the very restore that had just been recorded.
    public mutating func recordHistoryEntry(_ entry: HistoryEntry) {
        var updated = store.document
        var ledger = updated.history
        ledger.append(entry)
        updated.history = ledger
        store.replace(with: updated)
    }

    /// The history ids of the applied actions, aligned with `history.entries`.
    ///
    /// Kept beside the undo stack rather than inside it because the two answer
    /// different questions: one is "what can I take back in this session", the
    /// other is "what happened to this document". They are trimmed together, and
    /// `recordReversal` indexes this with the stack's own cursor.
    private var appliedHistoryIDs: [HistoryEntryID] = []

    @discardableResult
    public mutating func apply(_ commands: [Command], label: String, at date: Date = Date()) -> Bool {
        let before = store.document
        // The state an action was applied to is the state a preview of it has to
        // start from, and it is captured before the action lands. The base moves
        // with the first action of the session so that it is always exactly the
        // state before the oldest entry this session can still preview.
        //
        // It deliberately moves on *every* first action, including after a
        // reload: a session that reopened a file has no memory of what came
        // before its first entry, and the honest base for that first entry is
        // the file as it was found — not the file as it was left, which would
        // replay the whole history onto itself.
        if appliedHistoryIDs.isEmpty {
            journalBase = try? DocumentCodec.encode(before)
        }
        var updated = before
        do {
            try store.apply(commands, at: date)
            updated = store.document
            // Only what actually changed is recorded, because the undo stack drops
            // a no-op too. A ledger counting an action nobody can take back would
            // be counting something that did not happen.
            if before != updated {
                let id = HistoryEntryID(UUID().uuidString)
                var ledger = updated.history
                ledger.append(HistoryEntry(
                    id: id,
                    kind: .applied,
                    at: date,
                    label: label,
                    commands: commands,
                    revisionBefore: before.revision,
                    revisionAfter: updated.revision,
                    semanticRevisionBefore: before.semanticRevision,
                    semanticRevisionAfter: updated.semanticRevision
                ))
                updated.history = ledger
                appliedHistoryIDs.append(id)
                if appliedHistoryIDs.count > history.limit {
                    appliedHistoryIDs.removeFirst(appliedHistoryIDs.count - history.limit)
                }
            }
            // Recorded *after* the ledger append, deliberately. The undo snapshot
            // has to be a document that contains the history, or undoing would
            // restore a state that has forgotten the action it is undoing, and the
            // ledger would lose its own entry every time a person pressed Cmd+Z.
            history.record(label: label, before: before, after: updated)
            store.replace(with: updated)
            lastError = nil
            return true
        } catch let error as DocumentError {
            lastError = error
            return false
        } catch {
            lastError = .forbiddenOperation(String(describing: error))
            return false
        }
    }

    @discardableResult
    public mutating func undo(at date: Date = Date()) -> Bool {
        let index = history.nextUndoIndex
        // The ledger is carried across the restore. The undo snapshot predates the
        // entry it is undoing, so restoring it wholesale would erase the record of
        // the action and leave the ledger claiming a reversal of something it has
        // never heard of. An action is not undone by forgetting it happened; it is
        // undone by being recorded as undone.
        let ledger = store.document.history
        guard var document = history.undo(current: store.document) else { return false }
        document.history = ledger
        store.replace(with: document)
        // A reversal is only recorded when the target is still addressable. When
        // the stack has been trimmed past the ledger, the reversal is not written
        // rather than written against the wrong entry, because a reversal pointing
        // at the wrong action is worse than a missing one.
        if let index, index < appliedHistoryIDs.count {
            recordReversal(of: appliedHistoryIDs[index], at: date)
        }
        return true
    }

    /// Records that an action was taken back.
    ///
    /// Appended, never substituted. "That was undone" and "that never happened"
    /// are different statements, and only the second one erases work somebody did.
    private mutating func recordReversal(of target: HistoryEntryID, at date: Date) {
        let before = store.document
        var ledger = before.history
        ledger.append(HistoryEntry(
            id: HistoryEntryID(UUID().uuidString),
            kind: .reversed(target: target),
            at: date,
            label: history.undoLabel ?? "undo",
            commands: [],
            revisionBefore: before.revision,
            revisionAfter: before.revision,
            semanticRevisionBefore: before.semanticRevision,
            semanticRevisionAfter: before.semanticRevision
        ))
        var updated = before
        updated.history = ledger
        store.replace(with: updated)
    }

    @discardableResult
    public mutating func redo() -> Bool {
        // Same reasoning as `undo`, and for the same reason: the snapshot's ledger
        // is older than the one this document has, so keeping the current one is
        // the only way the record stays append-only.
        let ledger = store.document.history
        guard var document = history.redo(current: store.document) else { return false }
        document.history = ledger
        store.replace(with: document)
        return true
    }
}
