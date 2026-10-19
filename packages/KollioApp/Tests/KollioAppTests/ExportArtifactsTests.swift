import AppKit
import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// The two exports that are not the document itself: the picture and the assets.
///
/// Both are checked against the same rule. The exported bytes must come from the
/// frozen scope and nothing else, and when an asset cannot travel, the archive
/// has to say so rather than pretend it never existed.
@Suite("Export artifacts")
@MainActor
struct ExportArtifactsTests {
    private func model() -> KollioModel {
        KollioModel(
            document: SarahFixture.document(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private var csv: ObjectID { ObjectID("object:sarah-csv") }
    private var crm: ObjectID { ObjectID("object:sarah-crm") }

    @Test("The PNG is a real image built from the frozen selection")
    func pngRendersTheFrozenScope() throws {
        let model = model()
        model.selection = [csv]
        let export = PNGExportFile(snapshot: model.exportSnapshot())

        #expect(Array(export.data.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(export.data.isEmpty == false)
        #expect(export.snapshot.objectIDs == [csv])
        let representation = try #require(NSBitmapImageRep(data: export.data))
        #expect(representation.pixelsWide > 0)
        #expect(representation.pixelsHigh > 0)
    }

    @Test("The PNG shows the same text the Markdown export would write")
    func pngMatchesThePreviewedMarkdown() throws {
        let model = model()
        model.selection = [csv, crm]
        let snapshot = model.exportSnapshot()
        let markdown = String(decoding: snapshot.markdown, as: UTF8.self)

        for block in snapshot.blocks where block.role != .spacer {
            #expect(markdown.contains(block.markdownLine))
        }
    }

    @Test("A document with no selection exports everything")
    func wholeDocumentWhenNothingIsSelected() {
        let model = model()
        model.selection = []
        #expect(model.exportSnapshot().objectIDs.count == model.document.objects.count)
    }

    @Test("The archive copies the files that are there and names the ones that are not")
    func archiveIsHonest() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-archive-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let present = directory.appendingPathComponent("report.pdf")
        try Data("pdf".utf8).write(to: present)
        let gone = URL(fileURLWithPath: "/gone/nowhere.csv")
        let link = "https://example.invalid/report"

        let plan = [
            AssetArchiveEntry(sourceID: "src:1", title: "Report", locator: present.path, kind: .pdf, outcome: .copyable),
            AssetArchiveEntry(sourceID: "src:2", title: "Moved", locator: gone.path, kind: .csv, outcome: .missing),
            AssetArchiveEntry(sourceID: "src:3", title: "Link", locator: link, kind: .link, outcome: .linkOnly)
        ]
        let result = try AssetArchiver.archive(plan: plan, into: directory, named: "Sarah Assets")

        #expect(result.copied.count == 1)
        #expect(result.skipped.count == 2)
        #expect(FileManager.default.fileExists(atPath: result.directory.path))
        #expect(FileManager.default.fileExists(atPath: result.directory.appendingPathComponent("report.pdf").path))

        let manifest = try String(contentsOf: result.manifest, encoding: .utf8)
        #expect(manifest.contains("copied"))
        #expect(manifest.contains("missing"))
        #expect(manifest.contains("link only"))
    }

    @Test("A document citing nothing refuses to pretend an archive exists")
    func archiveWithoutAssets() throws {
        let model = model()
        #expect(model.exportAssetPlan().isEmpty)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(model.archiveExportAssets(into: directory) == false)
        #expect(model.status == L10n.assetsArchiveEmpty)
    }

    @Test("A source the export cites is archived when the file is still on disk")
    func archiveFollowsTheCitedSources() throws {
        var document = SarahFixture.document()
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-source-\(UUID().uuidString).pdf")
        try Data("pdf".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        document.sources = SourceLedger(
            sources: [
                SourceReference(
                    id: "src:1",
                    kind: .pdf,
                    title: "Report",
                    locator: file.path,
                    revisions: [
                        SourceRevision(id: "rev:1", sequence: 1, extraction: .ready(text: "42"), digest: "d")
                    ]
                )
            ],
            citations: [
                Citation(id: "cite:1", claimID: csv, sourceID: "src:1", revisionID: "rev:1", locator: SourceLocator(), quote: "42")
            ]
        )
        let model = KollioModel(
            document: document,
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
        model.selection = [csv]
        let plan = model.exportAssetPlan()

        #expect(plan.count == 1)
        #expect(plan.first?.outcome == .copyable)

        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-scope-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: destination) }
        #expect(model.archiveExportAssets(into: destination))
        let archive = destination.appendingPathComponent(document.title + " " + L10n.assetsArchiveSuffix)
        #expect(FileManager.default.fileExists(atPath: archive.appendingPathComponent("MANIFEST.md").path))
    }
}
