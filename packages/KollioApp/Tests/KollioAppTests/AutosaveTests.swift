import Foundation
import Testing
import KollioCore
@testable import KollioApp

/// What "the document survives a quit" means, and where the proof stops.
///
/// The claim is a property of the product, not of a function: **when a person
/// closes Kollio after a change worth keeping, the next launch finds that
/// change.** It is stated here as that property, and the test drives the real
/// path — the model that the terminate hooks call, writing through the same
/// file store to the same URL, then a second model launched at that URL.
///
/// What this suite deliberately does not claim: that macOS ran the terminate
/// hook. That boundary is XCUITest's, and the one test over there has been
/// intermittent, so pretending to cover it here would be a proof that cannot
/// fail. What is owned here is everything the hook depends on, so that when the
/// end-to-end run does fail, the failure is a race in the harness rather than a
/// document that was never written.
@Suite("A document survives a quit")
@MainActor
struct AutosaveTests {
    /// A store rooted in a directory of this test's own, so two runs cannot see
    /// each other's file. The directory is removed by the test that made it,
    /// because a struct cannot own a deinitializer.
    private func makeStore() -> (store: DocumentFileStore, directory: URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kollio-autosave-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (DocumentFileStore(directory: directory), directory)
    }

    /// A launch, not a document. Passing an explicit one — even an empty one —
    /// short-circuits the file load, which is a trap for a test that means to
    /// prove a file is read.
    private func launch(_ store: DocumentFileStore) -> KollioModel {
        KollioModel(
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: store
        )
    }

    /// The whole claim, in one act: make a change, close, open again.
    @Test("A change worth keeping is there on the next launch")
    func theNextLaunchFindsTheChange() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = launch(store)
        first.loadDemo()

        // A change that is content, not layout: what a person would be upset to
        // lose, and what a file written by an older build would not contain.
        let target = try #require(first.document.objects.first?.id)
        #expect(first.applyEdit(to: target, text: "Texte qui doit survivre"))

        // Closing is the save. The terminate hooks call this and nothing else.
        #expect(first.save())

        // The next launch is a second model at the same URL, as a relaunch is.
        let second = launch(store)
        let reopened = try #require(second.document.object(target))
        #expect(reopened.text.text == "Texte qui doit survivre")
    }

    /// The part that is easy to get wrong: a document that was never written
    /// must not appear as if it had been. An empty document is not persisted,
    /// because writing it is what creates the file that then shadows every real
    /// document on the machine.
    @Test("Closing an untouched document writes no file to shadow a real one")
    func anUntouchedDocumentIsNotWritten() {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let empty = launch(store)
        #expect(empty.save())
        #expect(
            FileManager.default.fileExists(atPath: empty.documentURL.path) == false,
            "an empty document must not leave a file behind"
        )
    }

    /// The failure the claim is really about: a change that cannot be written
    /// is reported, not swallowed. A save that returns true and leaves nothing
    /// on disk is the worst outcome available, because the person believes it.
    @Test("A change is on disk before the save reports success")
    func theFileIsWrittenBeforeTheReport() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject = launch(store)
        subject.loadDemo()
        let target = try #require(subject.document.objects.first?.id)
        #expect(subject.applyEdit(to: target, text: "Écrit avant le rapport"))

        #expect(subject.save())

        // Read the file directly, without going through the model: the claim is
        // about what is on disk, and reading it back through the same loader
        // would pass even if the loader were the thing that made it true.
        let data = try Data(contentsOf: subject.documentURL)
        let decoded = try DocumentCodec.decode(data)
        #expect(decoded.object(target)?.text.text == "Écrit avant le rapport")
    }

    /// The trap this suite fell into first, kept so the next one does too.
    ///
    /// A launch opens the file on disk. Passing a document to the initialiser —
    /// *even an empty one* — is a different thing: it says "this is the document,
    /// do not look for one", and the file is never read. A test that means to
    /// prove a file survives has to launch, not to supply a document, or it
    /// proves that the document it supplied is the document it supplied.
    @Test("A launch reads the file; an explicit document does not")
    func anExplicitDocumentIsNotAFile() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let subject = launch(store)
        subject.loadDemo()
        #expect(subject.save())

        // Two ways to "open" it, and only one of them reads the disk.
        let byLaunch = launch(store)
        #expect(byLaunch.document.content.isEmpty == false)
        let byDocument = KollioModel(
            document: KollioDocument(),
            service: KollioModel.makeDemoService(languageCode: "fr"),
            fileStore: store
        )
        #expect(byDocument.document.content.isEmpty)
    }

    /// The reopen path the timeline depends on, and the one whose contract is
    /// now written down: a reopened document is the origin of what can be
    /// replayed, so nothing before it is claimed.
    @Test("A reopened document keeps its history, and claims nothing before it")
    func reopenedHistoryIsCompleteButBounded() throws {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = launch(store)
        first.loadDemo()
        let target = try #require(first.document.objects.first?.id)
        #expect(first.applyEdit(to: target, text: "Avant le redémarrage"))
        #expect(first.save())

        let second = launch(store)
        #expect(second.document.history.count == first.document.history.count)
        #expect(second.session.journalBaseDocument.history.count == second.document.history.count)
    }
}
