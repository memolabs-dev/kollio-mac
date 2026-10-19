import Testing
@testable import KollioCore

@Suite("Document search")
struct DocumentSearchTests {
    @Test("CAN-09 AC01: a rejection reason stays findable after reopening")
    func rejectionReasonIsFindable() throws {
        let target = KollioID.object("sarah-csv")
        var store = DocumentStore(document: Fixture.sarah())
        try store.apply([.recordDecision(.init(
            id: "decision:search-aside",
            kind: .setAside,
            targetObjectID: target,
            rationale: LocalizedText("Aucun budget pour cette piste"),
            provenance: .human("tester")
        ))])

        let active = DocumentSearch().search("budget", in: store.document)
        let activeResult = try #require(active.results.first)
        #expect(activeResult.objectID == target)
        #expect(activeResult.field == .reason)
        #expect(activeResult.state == .setAside)

        try store.apply([.recordDecision(.init(
            id: "decision:search-reopen",
            kind: .reopened,
            targetObjectID: target,
            provenance: .human("tester")
        ))])

        let historical = DocumentSearch().search("budget", in: store.document)
        #expect(historical.results.first?.state == .archived)
        #expect(historical.results.first?.decisionID == DecisionID("decision:search-aside"))
    }

    @Test("CAN-09 AC03: an object outside the permitted scope is not searched")
    func privateResultIsAbsentFromSharedSearch() {
        let privateObject = KollioID.object("sarah-csv")
        let document = Fixture.sarah()
        let privateText = document.object(privateObject)?.text.text ?? ""
        let permitted = Set(document.objects.map(\.id).filter { $0 != privateObject })

        let outcome = DocumentSearch().search(privateText, in: document, permitted: permitted)

        #expect(outcome.results.contains { $0.objectID == privateObject } == false)
        #expect(outcome.notSearched.contains(.outsideScope(privateObject)))
    }
}
