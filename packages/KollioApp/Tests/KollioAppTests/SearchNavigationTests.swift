import Foundation
import Testing
import KollioCore
@testable import KollioApp

@Suite("Search navigation")
@MainActor
struct SearchNavigationTests {
    @Test("CAN-09 AC02: visiting a set-aside result changes only the temporary view")
    func returningChangesNoStatus() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-search-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let model = KollioModel(
            document: SarahFixture.document(),
            service: CapturingSuggestionService(),
            fileStore: DocumentFileStore(directory: directory)
        )
        let root = KollioID.object("sarah-csv")
        let child = KollioID.object("sarah-viable")
        model.setAside(root, reason: "Pas maintenant")
        #expect(model.visibleInstances.contains { $0.objectID == child } == false)

        let documentBefore = model.document
        let cameraBefore = model.camera
        model.openSearch()
        model.updateSearch(model.text(of: child))
        let result = try #require(model.search?.results.first { $0.objectID == child })

        #expect(model.revealSearchResult(result))
        #expect(model.visibleInstances.contains { $0.objectID == child })
        #expect(model.selection == [child])
        #expect(model.camera != cameraBefore)
        #expect(model.document == documentBefore)
        #expect(model.document.object(root)?.isSetAside == true)

        model.clearSearch()
        #expect(model.visibleInstances.contains { $0.objectID == child } == false)
        #expect(model.document == documentBefore)
    }
}
