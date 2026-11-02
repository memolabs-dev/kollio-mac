import Foundation
import Testing
import KollioCore
@testable import KollioApp

@Suite("Presentation mode")
@MainActor
struct PresentationModeTests {
    private func model(service: CapturingSuggestionService = CapturingSuggestionService()) -> (KollioModel, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-presentation-\(UUID().uuidString)")
        return (
            KollioModel(
                document: SarahFixture.document(),
                service: service,
                fileStore: DocumentFileStore(directory: directory)
            ),
            directory
        )
    }

    @Test("CAN-10 AC01 and AC02: navigation follows the path and exit restores the camera")
    func navigationAndExit() throws {
        let (model, directory) = model()
        defer { try? FileManager.default.removeItem(at: directory) }
        model.viewport = Size(width: 1_000, height: 700)
        model.camera = Camera(zoom: 1.25, translation: Position(x: 37, y: -19))
        let cameraBefore = model.camera
        let first = KollioID.object("sarah-context")
        let second = KollioID.object("sarah-csv")

        #expect(model.beginPresentation(path: ReadingPath(objects: [first, second])))
        #expect(model.presentation?.entry?.point == .object(first))
        #expect(model.advancePresentation())
        #expect(model.presentation?.entry?.point == .object(second))
        #expect(model.rewindPresentation())
        #expect(model.presentation?.entry?.point == .object(first))

        model.exitPresentation()
        #expect(model.presentation == nil)
        #expect(model.camera == cameraBefore)
    }

    @Test("CAN-10 AC03: presenting calls no model and refuses every document write")
    func presentationIsLocalAndReadOnly() {
        let service = CapturingSuggestionService()
        let (model, directory) = model(service: service)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = KollioID.object("sarah-csv")
        let documentBefore = model.document

        #expect(model.beginPresentation(path: ReadingPath(objects: [target])))
        #expect(model.perform([.updateObjectText(.init(
            id: target,
            text: LocalizedText("Must not be written"),
            provenance: .human("tester")
        ))], label: "forbidden") == false)

        #expect(model.document == documentBefore)
        #expect(service.requests.isEmpty)
    }
}
