import Foundation
import Testing
@testable import KollioCore

@Suite("Document export")
struct DocumentExportTests {
    @Test("A scoped portable document has no dangling internal references")
    func portableScopeIsSelfContained() throws {
        let document = Fixture.sarah()
        let selected: Set<ObjectID> = [
            KollioID.object("sarah-csv"),
            KollioID.object("sarah-viable")
        ]
        let exported = DocumentExporter.portableDocument(from: document, scope: .objects(selected))
        let reopened = try DocumentCodec.decode(try DocumentCodec.encode(exported))

        #expect(Set(reopened.content.keys) == selected)
        #expect(reopened.relationships.values.allSatisfy {
            selected.contains($0.from) && selected.contains($0.to)
        })
        #expect(reopened.presentation.instances.allSatisfy { selected.contains($0.objectID) })
        #expect(reopened.decisions.values.allSatisfy { selected.contains($0.targetObjectID) })
        #expect(reopened.sources.citations.values.allSatisfy { selected.contains($0.claimID) })
        #expect(reopened.history.isEmpty)
    }

    @Test("The exported scope is frozen at preview time")
    func freezesChosenScope() {
        let document = Fixture.sarah()
        let first = KollioID.object("sarah-csv")
        let later = KollioID.object("sarah-crm")
        let snapshot = DocumentExporter.snapshot(of: document, scope: .objects([first]))
        let changedSelection: Set<ObjectID> = [later]
        let markdown = String(decoding: snapshot.markdown, as: UTF8.self)

        #expect(changedSelection != Set(snapshot.objectIDs))
        #expect(snapshot.objectIDs == [first])
        #expect(markdown.contains(document.content[first]!.text.text))
        #expect(markdown.contains(document.content[later]!.text.text) == false)
    }

    @Test("Private markdown contains work and source titles but no provenance or locator")
    func excludesOperationalSecrets() throws {
        var document = Fixture.sarah()
        let id = KollioID.object("sarah-csv")
        document.content[id]?.provenance = Provenance(
            actor: "actor:private",
            kind: .remoteModel,
            requestId: "request-secret-token",
            proposalId: "proposal-private"
        )
        let snapshot = DocumentExporter.snapshot(of: document, scope: .document)
        let markdown = String(decoding: snapshot.markdown, as: UTF8.self)

        #expect(markdown.contains(document.content[id]!.text.text))
        #expect(markdown.contains("request-secret-token") == false)
        #expect(markdown.contains("actor:private") == false)
        #expect(markdown.contains("proposal-private") == false)
    }

    @Test("PNG and Markdown are two renderings of one frozen scope")
    func pngAndMarkdownShareOneScope() {
        let document = Fixture.sarah()
        let selected: Set<ObjectID> = [KollioID.object("sarah-csv"), KollioID.object("sarah-crm")]
        let snapshot = DocumentExporter.snapshot(of: document, scope: .objects(selected))
        let markdownLines = String(decoding: snapshot.markdown, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        #expect(markdownLines == snapshot.blocks.map(\.markdownLine))
        // Everything a rasteriser could draw is already in the blocks, so a PNG
        // cannot show a decision the previewed Markdown did not contain.
        let rendered = snapshot.blocks
            .filter { $0.role != .spacer }
            .map(\.text)
        #expect(rendered.contains(document.content[KollioID.object("sarah-csv")]!.text.text))
        #expect(rendered.allSatisfy { $0.contains("request-secret") == false })
    }

    @Test("The asset plan holds the sources the exported scope actually cites")
    func assetPlanFollowsTheScope() throws {
        let document = Fixture.sarah()
        let claimed = KollioID.object("sarah-csv")
        let other = KollioID.object("sarah-crm")
        let locator = "/tmp/report.pdf"
        var withSource = document
        withSource.sources = SourceLedger(
            sources: [Self.report(id: "src:1", kind: .pdf, locator: locator),
                Self.report(id: "src:2", kind: .csv, locator: "/tmp/other.csv")],
            citations: [
                Citation(id: "cite:1", claimID: claimed, sourceID: "src:1", revisionID: "rev:1", locator: SourceLocator(), quote: "42"),
                Citation(id: "cite:2", claimID: other, sourceID: "src:2", revisionID: "rev:1", locator: SourceLocator(), quote: "7")
            ]
        )
        let plan = DocumentExporter.assetPlan(
            for: withSource,
            scope: .objects([claimed]),
            existingPaths: [locator, "/tmp/other.csv"]
        )

        // The scope is the filter: the second source is not archived with it.
        #expect(plan.count == 1)
        let entry = try #require(plan.first)
        #expect(entry.sourceID == "src:1")
        #expect(entry.outcome == .copyable)
    }

    @Test("A link has no bytes to copy and a moved file is a warning, not a failure")
    func assetPlanIsHonestAboutWhatIsMissing() throws {
        let claimed = KollioID.object("sarah-csv")
        var document = Fixture.sarah()
        document.sources = SourceLedger(
            sources: [Self.report(id: "src:1", kind: .link, locator: "https://example.invalid/report")],
            citations: [
                Citation(id: "cite:1", claimID: claimed, sourceID: "src:1", revisionID: "rev:1", locator: SourceLocator(), quote: "42")
            ]
        )
        let linkPlan = DocumentExporter.assetPlan(for: document, scope: .document, existingPaths: [])
        #expect(linkPlan.first?.outcome == .linkOnly)

        var moved = Fixture.sarah()
        moved.sources = SourceLedger(
            sources: [Self.report(id: "src:1", kind: .pdf, locator: "/gone/nowhere.pdf")],
            citations: [
                Citation(id: "cite:1", claimID: claimed, sourceID: "src:1", revisionID: "rev:1", locator: SourceLocator(), quote: "42")
            ]
        )
        let movedPlan = DocumentExporter.assetPlan(for: moved, scope: .document, existingPaths: [])
        #expect(movedPlan.first?.outcome == .missing)
    }

    @Test("A scope with no claims archives nothing")
    func emptyScopeArchivesNothing() {
        let document = Fixture.sarah()
        let plan = DocumentExporter.assetPlan(
            for: document,
            scope: .objects([KollioID.object("sarah-csv")]),
            existingPaths: ["/anything"]
        )
        #expect(plan.isEmpty)
    }

    static func report(id: SourceID, kind: SourceReference.Kind, locator: String) -> SourceReference {
        SourceReference(
            id: id,
            kind: kind,
            title: "Report",
            locator: locator,
            revisions: [
                SourceRevision(
                    id: "rev:1",
                    sequence: 1,
                    extraction: .ready(text: "42"),
                    digest: "d"
                )
            ]
        )
    }
}
