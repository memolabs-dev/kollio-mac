import Foundation

/// What changed between the document as it was and the document as it is.
///
/// DEC-06 asks a preview to come "with differences". A preview that shows the
/// whole past document answers a question nobody asked — *what did the document
/// look like then* — while the question on the timeline is *what has happened
/// since*. This type is that second question, and nothing else.
///
/// Three properties keep it honest:
///
/// - **It is about one object.** The timeline is per object, so a diff of the
///   whole document would bury the one line the person is reading in everything
///   else that moved.
/// - **It compares the two states, it does not derive one from a journal.** The
///   states are rebuilt and read; nothing here reconstructs what an entry "meant".
/// - **A removal is a difference.** An object that is gone now, or a relation
///   that no longer exists, is a thing that happened, not a thing to hide.
public struct HistoryDifference: Hashable, Sendable {
    /// The object's own text, past against present.
    public enum Text: Hashable, Sendable {
        /// It reads the same in both states.
        case unchanged
        /// It reads differently. Both texts, because saying "changed" without
        /// saying to what is the same as saying nothing.
        case changed(from: String, to: String)
        /// It is not in the past state.
        case added(String)
        /// It is not in the present state.
        case removed(String)
    }

    /// One end of a relation, past against present.
    public enum Connection: Hashable, Sendable {
        case unchanged
        case added(kind: Relationship.Kind)
        case removed(kind: Relationship.Kind)
        case changed(from: Relationship.Kind, to: Relationship.Kind)
    }

    public var objectID: ObjectID
    public var text: Text
    /// Relations touching the object, keyed by the other end, so a pair of
    /// relations to the same object reads as one line rather than two.
    public var connections: [ObjectID: Connection]

    public init(objectID: ObjectID, text: Text, connections: [ObjectID: Connection] = [:]) {
        self.objectID = objectID
        self.text = text
        self.connections = connections
    }

    /// Whether anything at all moved. A preview with nothing to report is a
    /// preview that should say so rather than render an empty list.
    public var isEmpty: Bool {
        if case .unchanged = text { } else { return false }
        return connections.values.allSatisfy { if case .unchanged = $0 { return true } else { return false } }
    }
}

extension HistoryDifference {
    /// Compares the two states for one object.
    ///
    /// `past` is the rebuilt document and `present` the live one. The language
    /// is the interface's, because this is read, not authored: the texts
    /// compared are the person's own words in one variant, never a translation
    /// of one language into another.
    public static func between(
        objectID: ObjectID,
        past: KollioDocument,
        present: KollioDocument,
        languageCode: String
    ) -> HistoryDifference {
        let pastText = past.object(objectID)?.text.resolve(languageCode: languageCode)
        let presentText = present.object(objectID)?.text.resolve(languageCode: languageCode)

        let text: HistoryDifference.Text
        switch (pastText, presentText) {
        case (nil, nil):
            text = .unchanged
        case (nil, let now?):
            text = .added(now)
        case (let then?, nil):
            text = .removed(then)
        case (let then?, let now?):
            text = then == now ? .unchanged : .changed(from: then, to: now)
        }

        let pastConnections = connectionsOf(objectID, in: past)
        let presentConnections = connectionsOf(objectID, in: present)
        var connections: [ObjectID: Connection] = [:]
        for (other, kind) in pastConnections {
            guard let presentKind = presentConnections[other] else {
                connections[other] = .removed(kind: kind)
                continue
            }
            connections[other] = presentKind == kind
                ? .unchanged
                : .changed(from: kind, to: presentKind)
        }
        for (other, kind) in presentConnections where pastConnections[other] == nil {
            connections[other] = .added(kind: kind)
        }

        return HistoryDifference(objectID: objectID, text: text, connections: connections)
    }

    /// The other ends of every relation touching `objectID`, with the kind. Both
    /// directions count: a relation is between two objects whichever end the
    /// timeline happens to be open on.
    private static func connectionsOf(
        _ objectID: ObjectID,
        in document: KollioDocument
    ) -> [ObjectID: Relationship.Kind] {
        var found: [ObjectID: Relationship.Kind] = [:]
        for relationship in document.relationships.values {
            if relationship.from == objectID {
                found[relationship.to] = relationship.kind
            } else if relationship.to == objectID {
                found[relationship.from] = relationship.kind
            }
        }
        return found
    }
}
