import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// Records every request it receives, so a test can assert the exact text, the
/// target, the document and the revision the server would have been asked about.
final class RecordingService: SuggestionService, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [ProposalRequest] = []
    private let failure: (any Error)?

    init(failingWith failure: (any Error)? = nil) {
        self.failure = failure
    }

    var capabilities: SuggestionCapabilities { .offline }

    var requests: [ProposalRequest] { lock.withLock { stored } }
    var documents: [KollioDocument] { lock.withLock { seen } }
    private var seen: [KollioDocument] = []

    func respond(to request: ProposalRequest, document: KollioDocument) async throws -> ProposalResponse {
        lock.withLock {
            stored.append(request)
            seen.append(document)
        }
        if let failure { throw failure }
        return .noChange()
    }
}

struct BackendUnreachable: Error {}

/// The product's entry point: a person types their own context, it survives on
/// the canvas, reaches a real backend, and comes back as something they can
/// keep or refuse.
@Suite("Initial context to proposal")
@MainActor
struct InitialContextTests {
    private func isolatedStore() -> (DocumentFileStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-entry-\(UUID().uuidString)")
        return (DocumentFileStore(directory: directory), directory)
    }

    // MARK: Launch behaviour

    @Test("A fresh launch with nothing stored shows the initial input")
    func freshLaunchIsEmpty() {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: nil, service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        // No fixture is substituted for a missing document.
        #expect(model.isEmpty)
        #expect(model.hasUnreadableDocument == false)
    }

    @Test("A stored document is restored, not replaced by the demo")
    func storedDocumentIsRestored() {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = KollioModel(document: KollioDocument(), service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        first.start(with: "Récupérer la liste des prospects")
        #expect(first.save())

        let relaunched = KollioModel(document: nil, service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        #expect(relaunched.isEmpty == false)
        #expect(relaunched.document.content.count == 1)
        #expect(relaunched.object(KollioID.object("context"))?.text.text == "Récupérer la liste des prospects")
    }

    @Test("An unreadable document is reported and never overwritten")
    func unreadableDocumentIsReported() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = store.defaultDocumentURL
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try Data("{ this is not a kollio document".utf8).write(to: url)

        let model = KollioModel(document: nil, service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        #expect(model.hasUnreadableDocument)
        // The user's file is still exactly what it was.
        let onDisk = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        #expect(onDisk == "{ this is not a kollio document")
    }

    @Test("New Document does not reuse the previous save target")
    func newDocumentGetsItsOwnFile() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        model.start(with: "First context")
        #expect(model.save())
        let firstURL = model.documentURL
        let firstContents = try Data(contentsOf: firstURL)

        model.newDocument()
        model.start(with: "Second context")
        #expect(model.save())

        #expect(model.documentURL != firstURL)
        // The earlier document is untouched, byte for byte.
        #expect(try Data(contentsOf: firstURL) == firstContents)
    }

    @Test("Renaming updates the document and its registry file without changing its work")
    func renameDocumentUpdatesRegistry() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(
            document: KollioDocument(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: store
        )
        model.start(with: "Keep this exact context")
        let originalURL = model.documentURL
        #expect(FileManager.default.fileExists(atPath: originalURL.path))

        #expect(model.renameDocument(to: " Project/Alpha "))

        #expect(model.document.title == "Project/Alpha")
        #expect(model.documentURL.lastPathComponent == "Project-Alpha.kollio")
        #expect(FileManager.default.fileExists(atPath: originalURL.path) == false)
        let reopened = try store.load(model.documentURL)
        #expect(reopened.title == "Project/Alpha")
        #expect(reopened.content == model.document.content)
    }

    @Test("An invalid rename leaves the document and file untouched")
    func invalidRenameIsAtomic() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(
            document: KollioDocument(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: store
        )
        model.start(with: "Context")
        let before = model.document
        let beforeURL = model.documentURL
        let beforeData = try Data(contentsOf: beforeURL)

        #expect(model.renameDocument(to: "  \n ") == false)
        #expect(model.document == before)
        #expect(model.documentURL == beforeURL)
        #expect(try Data(contentsOf: beforeURL) == beforeData)
    }

    @Test("Duplicating creates an independent document and preserves the source file")
    func duplicateDocumentCreatesIndependentFile() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(
            document: KollioDocument(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: store
        )
        model.start(with: "Original context")
        let original = model.document
        let originalURL = model.documentURL
        let originalData = try Data(contentsOf: originalURL)

        #expect(model.duplicateDocument(named: "Working copy"))

        #expect(model.document.documentId != original.documentId)
        #expect(Set(model.document.content.keys).isDisjoint(with: original.content.keys))
        #expect(model.document.title == "Working copy")
        #expect(model.documentURL != originalURL)
        #expect(try Data(contentsOf: originalURL) == originalData)
        #expect(try store.load(model.documentURL) == model.document)
    }

    // MARK: The authored context

    @Test("The context keeps the exact words that were typed")
    func contextPreservesAuthoredText() {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        let sentence = "Il faut refaire le parcours d'inscription avant la fin du trimestre, sinon on perd les comptes."
        model.start(with: sentence)
        // No summarising, no trimming of the meaning, no translation.
        #expect(model.text(of: KollioID.object("context")) == sentence)
    }

    @Test("An empty submission creates nothing")
    func emptySubmissionIsRejected() {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        #expect(model.start(with: "   \n  ") == nil)
        #expect(model.isEmpty)
    }

    @Test("The context is persisted before any intelligence is asked for")
    func contextIsPersistedFirst() async throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        // A service that always fails: the words must still be on disk.
        let model = KollioModel(
            document: KollioDocument(),
            service: RecordingService(failingWith: BackendUnreachable()),
            fileStore: store
        )
        let context = try #require(model.start(with: "A context that must survive a dead backend"))
        await model.exploreInitialContext(context)

        let relaunched = KollioModel(document: nil, service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        #expect(relaunched.text(of: context) == "A context that must survive a dead backend")
    }

    @Test("Editing changes one object and keeps its identity")
    func editKeepsIdentity() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        let context = try #require(model.start(with: "First version of the context"))
        let revision = model.document.semanticRevision

        #expect(model.applyEdit(to: context, text: "Second version of the context"))

        // Same object, new text, one revision, nothing else touched.
        #expect(model.text(of: context) == "Second version of the context")
        #expect(model.document.content.count == 1)
        #expect(model.document.semanticRevision == revision + 1)
        model.undo()
        #expect(model.text(of: context) == "First version of the context")
    }

    @Test("An empty edit is refused and changes nothing")
    func emptyEditIsRefused() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: KollioModel.makeDemoService(languageCode: "fr"), fileStore: store)
        let context = try #require(model.start(with: "Untouchable"))
        let revision = model.document.semanticRevision
        #expect(model.applyEdit(to: context, text: "  ") == false)
        #expect(model.text(of: context) == "Untouchable")
        #expect(model.document.semanticRevision == revision)
    }

    // MARK: What reaches the intelligence source

    @Test("The request names the real document, the real target and the real revision")
    func requestCarriesTheRealContext() async throws {
        let service = RecordingService()
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: service, fileStore: store)
        let context = try #require(model.start(with: "Reduire le temps de reprise apres incident"))

        await model.exploreInitialContext(context)

        let request = try #require(service.requests.last)
        #expect(request.documentId == model.document.documentId)
        #expect(request.targetIds == [context])
        #expect(request.baseSemanticRevision == model.document.semanticRevision)
        // The service is handed the same document the canvas is showing.
        #expect(service.documents.last?.documentId == model.document.documentId)
    }

    @Test("Two different documents are never confused")
    func twoDocumentsStaySeparate() async throws {
        let (storeA, dirA) = isolatedStore()
        let (storeB, dirB) = isolatedStore()
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }
        let serviceA = RecordingService()
        let serviceB = RecordingService()
        let modelA = KollioModel(document: KollioDocument(), service: serviceA, fileStore: storeA)
        let modelB = KollioModel(document: KollioDocument(), service: serviceB, fileStore: storeB)
        let contextA = try #require(modelA.start(with: "Contexte A"))
        _ = try #require(modelB.start(with: "Contexte B"))

        await modelA.exploreInitialContext(contextA)

        #expect(serviceA.requests.count == 1)
        #expect(serviceB.requests.isEmpty)
        #expect(serviceA.requests.first?.documentId != serviceB.requests.first?.documentId)
    }

    @Test("Editing the context changes what the next request carries")
    func editAffectsTheNextRequest() async throws {
        let service = RecordingService()
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: service, fileStore: store)
        let context = try #require(model.start(with: "Version initiale"))
        await model.exploreInitialContext(context)
        let before = try #require(service.requests.last)
        #expect(before.baseSemanticRevision == model.document.semanticRevision)

        #expect(model.applyEdit(to: context, text: "Version révisée"))
        // The edit moved the document on, so the previous request is now stale.
        #expect(before.baseSemanticRevision < model.document.semanticRevision)
        await model.exploreInitialContext(context)
        let after = try #require(service.requests.last)
        #expect(after.baseSemanticRevision == model.document.semanticRevision)
        // And the text the backend would see is the new one.
        let sent = try model.document.snapshot(targeting: [context])
        #expect(sent.objects[context]?.text.text == "Version révisée")
    }

    @Test("A dead backend never costs the context")
    func deadBackendKeepsTheContext() async throws {
        let service = RecordingService(failingWith: BackendUnreachable())
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: service, fileStore: store)
        let context = try #require(model.start(with: "Rien ne doit disparaitre"))

        await model.exploreInitialContext(context)

        #expect(model.text(of: context) == "Rien ne doit disparaitre")
        #expect(model.document.content.count == 1)
        // The failure is stated, not swallowed, and nothing is proposed.
        #expect(model.status != nil)
        #expect(model.preview == nil)
    }

    @Test("A pending request never blocks the canvas")
    func pendingRequestDoesNotBlock() async throws {
        // A service that never answers, so the model stays busy.
        struct SlowService: SuggestionService {
            var capabilities: SuggestionCapabilities { .offline }
            func respond(to request: ProposalRequest, document: KollioDocument) async throws -> ProposalResponse {
                try await Task.sleep(for: .seconds(5))
                return .noChange()
            }
        }
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), service: SlowService(), fileStore: store)
        let context = try #require(model.start(with: "Le canvas reste utilisable"))

        let task = Task { await model.exploreInitialContext(context) }
        // While the request is in flight the camera and the document are still
        // the user's to move.
        model.camera = Camera(zoom: 1.6, translation: Position(x: -50, y: 20))
        #expect(model.camera.zoom == 1.6)
        model.beginDrag(context, screenTranslation: CGSize(width: 30, height: 10))
        model.endDrag()
        #expect(model.document.content.count == 1)
        task.cancel()
    }

    @Test("The interface language never rewrites what the person wrote")
    func languageDoesNotTranslateTheContext() throws {
        let (store, directory) = isolatedStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: KollioDocument(), fileStore: store, languageCode: "fr")
        let authored = "Le client veut une réponse en francais, meme si l'interface change"
        let context = try #require(model.start(with: authored))
        model.languageCode = "en"
        #expect(model.text(of: context) == authored)
    }
}
