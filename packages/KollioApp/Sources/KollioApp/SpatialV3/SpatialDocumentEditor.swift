import Foundation
import KollioCore

/// The only edit entry point for the V3 document window. Calls the existing
/// KollioModel command system; never owns or writes a separate spatial document.
/// Presentation-only fixtures do not instantiate this adapter.
@MainActor
struct SpatialDocumentEditor {
    let model: KollioModel

    func createIdea(_ text: String, near anchorID: String?) -> ObjectID? {
        let anchor = anchorID.map { ObjectID($0) }
        if let anchor, model.object(anchor) == nil { return nil }
        return model.createIdea(text, near: anchor)
    }

    func updateText(_ text: String, of id: String, expectedVersion: Int) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let objectID = ObjectID(id)
        guard !trimmed.isEmpty, let object = model.object(objectID),
              object.objectVersion == expectedVersion else { return false }
        var localized = object.text
        // Editing what the reader actually sees must preserve both the base
        // text and translations authored in other languages.
        if localized.variants[model.languageCode] != nil {
            localized.variants[model.languageCode] = trimmed
        } else {
            localized.text = trimmed
        }
        if localized == object.text { return true }
        return model.perform([
            .updateObjectText(UpdateObjectText(
                id: objectID, text: localized, detail: object.detail,
                provenance: .human("local-user"), expectedVersion: expectedVersion
            ))
        ], label: "undo.updateObjectText")
    }

    /// Moves exactly one authored NodeInstance. The existing model commits
    /// one validated command/undo record, never moving sibling occurrences.
    @discardableResult
    func moveOccurrence(_ id: String, by delta: Position) -> Bool {
        let instanceID = InstanceID(id)
        guard delta.x.isFinite, delta.y.isFinite,
              abs(delta.x) > 0.5 || abs(delta.y) > 0.5,
              let before = model.document.presentation.instance(id: instanceID)?.position
        else { return false }
        model.moveInstances([instanceID], by: delta)
        guard let after = model.document.presentation.instance(id: instanceID)?.position else {
            return false
        }
        return after != before
    }

    /// An explicit, human-authored association. No semantic direction is
    /// guessed from a line drawn with the mouse.
    func associate(_ firstID: String, with secondID: String) -> RelationshipID? {
        let from = ObjectID(firstID)
        let to = ObjectID(secondID)
        guard from != to,
              model.object(from) != nil, model.object(to) != nil,
              !model.document.relationships.values.contains(where: {
                  ($0.from == from && $0.to == to || $0.from == to && $0.to == from)
                    && $0.kind == .associatedWith
              }) else { return nil }

        let id = RelationshipID("relationship:" + UUID().uuidString)
        let command = Command.addRelationship(AddRelationship(
            id: id,
            from: from,
            to: to,
            kind: .associatedWith,
            provenance: .human("local-user")
        ))
        guard model.perform([command], label: "undo.addRelationship") else { return nil }
        return id
    }

    @discardableResult
    func save() -> Bool {
        guard !model.hasUnreadableDocument else { return false }
        return model.save()
    }

    func undo() { model.undo() }
    func redo() { model.redo() }
}
