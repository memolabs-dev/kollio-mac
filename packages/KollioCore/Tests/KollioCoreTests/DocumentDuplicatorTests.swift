import Foundation
import Testing
@testable import KollioCore

@Suite("Document duplication")
struct DocumentDuplicatorTests {
    @Test("A duplicate is independently identifiable and internally coherent")
    func remapsInternalIdentity() throws {
        let original = Fixture.sarah()
        let copy = try DocumentDuplicator.duplicate(
            original,
            documentID: "document:copy",
            title: "Sarah copy"
        )

        #expect(copy.documentId == "document:copy")
        #expect(copy.documentId != original.documentId)
        #expect(copy.title == "Sarah copy")
        #expect(Set(copy.content.keys).isDisjoint(with: original.content.keys))
        #expect(Set(copy.relationships.keys).isDisjoint(with: original.relationships.keys))
        #expect(Set(copy.decisions.keys).isDisjoint(with: original.decisions.keys))
        #expect(Set(copy.presentation.instances.map(\.id)).isDisjoint(with: original.presentation.instances.map(\.id)))

        for relationship in copy.relationships.values {
            #expect(copy.content[relationship.from] != nil)
            #expect(copy.content[relationship.to] != nil)
        }
        for instance in copy.presentation.instances {
            #expect(copy.content[instance.objectID] != nil)
        }
    }

    @Test("Duplication preserves authored words, source locations and provenance")
    func preservesExternalAndAuthoredValues() throws {
        var original = Fixture.sarah()
        let objectID = try #require(original.content.keys.sorted(by: { $0.rawValue < $1.rawValue }).first)
        original.content[objectID]?.text = LocalizedText(objectID.rawValue)
        original.content[objectID]?.provenance = Provenance(
            actor: "actor:owner",
            kind: .human,
            requestId: "request:kept",
            proposalId: "proposal:kept"
        )

        let copy = try DocumentDuplicator.duplicate(original)
        let copiedObject = try #require(copy.content.values.first(where: { $0.text.text == objectID.rawValue }))

        #expect(copiedObject.id != objectID)
        #expect(copiedObject.text.text == objectID.rawValue)
        #expect(copiedObject.provenance.actor == "actor:owner")
        #expect(copiedObject.provenance.requestId == "request:kept")
        #expect(copiedObject.provenance.proposalId == "proposal:kept")
    }
}
