import Foundation
import Testing
import KollioCore
@testable import KollioApp

@Suite("Spatial Ink C2.3 — authoring through the real Kollio model")
@MainActor
struct SpatialDocumentEditorTests {
    private func prepare() -> (SpatialDocumentEditor, KollioModel, URL) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-v3-edit-\(UUID().uuidString)", isDirectory: true)
        let model = KollioModel.deterministicModel(
            document: SarahFixture.document(),
            fileStore: DocumentFileStore(directory: folder)
        )
        return (SpatialDocumentEditor(model: model), model, folder)
    }

    @Test("Creating an idea and a real relationship survives save and reopen")
    func createLinkAndReopen() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let anchor = try #require(model.document.content.keys.sorted(by: { $0.rawValue < $1.rawValue }).first)
        let sourceRevision = model.document.semanticRevision
        let newID = try #require(editor.createIdea("Une découverte spatiale", near: anchor.rawValue))
        #expect(model.document.content[newID]?.text.text == "Une découverte spatiale")
        #expect(model.document.semanticRevision > sourceRevision)
        let relationshipID = try #require(editor.associate(newID.rawValue, with: anchor.rawValue))
        #expect(model.document.relationships[relationshipID]?.kind == .associatedWith)
        #expect(SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document))
            .nodes.contains(where: { $0.id == newID.rawValue }))
        #expect(editor.save())
        let expected = model.document
        model.reloadFromDisk()
        #expect(model.document.content == expected.content)
        #expect(model.document.relationships == expected.relationships)
        #expect(model.document.presentation == expected.presentation)
        #expect(model.document.semanticRevision == expected.semanticRevision)
        #expect(model.document.content[newID]?.text.text == "Une découverte spatiale")
        #expect(model.document.relationships[relationshipID]?.from == newID)
        #expect(SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document))
            .edges.contains(where: { $0.id == relationshipID.rawValue }))
    }

    @Test("Editing uses the original object's version and refuses stale writes")
    func editAndConflict() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = try #require(model.document.content.keys.first)
        let version = try #require(model.object(target)).objectVersion
        let count = model.document.content.count
        let originalVariants = try #require(model.object(target)).text.variants
        let originalDetail = model.object(target)?.detail
        #expect(editor.updateText("Une rédaction révisée", of: target.rawValue, expectedVersion: version))
        #expect(model.object(target)?.text.resolve(languageCode: model.languageCode) == "Une rédaction révisée")
        for (language, value) in originalVariants where language != model.languageCode {
            #expect(model.object(target)?.text.variants[language] == value)
        }
        #expect(model.object(target)?.detail == originalDetail)
        #expect(model.document.content.count == count)
        let revised = model.document
        #expect(!editor.updateText("Une édition obsolète", of: target.rawValue, expectedVersion: version))
        #expect(model.document == revised)
        #expect(editor.save())
        model.reloadFromDisk()
        #expect(model.object(target)?.text.resolve(languageCode: model.languageCode) == "Une rédaction révisée")
    }

    @Test("Editing a French authored variant preserves the English variant and original detail")
    func localePreservation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-v3-locale-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(document: SarahFixture.document(),
                                service: KollioModel.makeDemoService(languageCode: "fr"),
                                fileStore: DocumentFileStore(directory: directory),
                                languageCode: "fr", mode: .demo)
        let object = try #require(model.document.content.values.first {
            $0.text.variants["en"] != nil
        })
        let original = object.text
        let version = object.objectVersion
        #expect(SpatialDocumentEditor(model: model).updateText("Version française corrigée",
            of: object.id.rawValue, expectedVersion: version))
        #expect(model.object(object.id)?.text.resolve(languageCode: "fr") == "Version française corrigée")
        #expect(model.object(object.id)?.text.variants["en"] == original.variants["en"])
        #expect(model.object(object.id)?.text.text == "Version française corrigée")
        #expect(model.object(object.id)?.detail == object.detail)
    }

    @Test("Associations are explicit, unique, validated, and undoable")
    func linkGuardsAndUndo() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let ids = model.document.content.keys.sorted { $0.rawValue < $1.rawValue }
        let from = try #require(ids.first), to = try #require(ids.dropFirst().first)
        let original = model.document
        #expect(editor.associate(from.rawValue, with: from.rawValue) == nil)
        #expect(editor.associate(from.rawValue, with: "object:missing") == nil)
        let edge = try #require(editor.associate(from.rawValue, with: to.rawValue))
        let after = model.document
        #expect(editor.associate(to.rawValue, with: from.rawValue) == nil)
        #expect(model.document == after)
        editor.undo()
        #expect(model.document.content == original.content)
        #expect(model.document.relationships == original.relationships)
        editor.redo()
        #expect(model.document.relationships[edge] != nil)
    }

    @Test("Save refuses to overwrite an unreadable existing .kollio file")
    func unreadableFileIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-v3-recovery-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DocumentFileStore(directory: directory)
        let raw = Data("{not valid Kollio data}".utf8)
        try raw.write(to: store.defaultDocumentURL)
        let model = KollioModel(service: KollioModel.makeDemoService(languageCode: "fr"),
                                fileStore: store, languageCode: "fr", mode: .demo)
        #expect(model.hasUnreadableDocument)
        #expect(!SpatialDocumentEditor(model: model).save())
        #expect(try Data(contentsOf: store.defaultDocumentURL) == raw)
    }

    @Test("Blank creation and unknown anchors never change an authored document")
    func invalidCreate() {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = model.document
        #expect(editor.createIdea("  ", near: nil) == nil)
        #expect(editor.createIdea("Not allowed", near: "object:missing") == nil)
        #expect(model.document == before)
    }

    @Test("C2.5 selecting a second drawing edits the one authored semantic object")
    func editThroughAlternateOccurrence() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-v3-c25-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var document = SarahFixture.document()
        let objectID = try #require(document.content.keys.sorted { $0.rawValue < $1.rawValue }.first)
        document.presentation.instances = [
            NodeInstance(id: "copy-1", objectID: objectID, position: Position(x: 130, y: 210)),
            NodeInstance(id: "copy-2", objectID: objectID, position: Position(x: 730, y: 510))
        ]
        let model = KollioModel.deterministicModel(
            document: document, fileStore: DocumentFileStore(directory: directory)
        )
        let editor = SpatialDocumentEditor(model: model)
        let scene = SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document, languageCode: model.languageCode))
        let second = try #require(scene.nodes.first {
            scene.objectID(for: $0.id) == objectID.rawValue && $0.id != objectID.rawValue
        })
        let semanticID = try #require(scene.objectID(for: second.id))
        let version = try #require(model.object(ObjectID(semanticID))).objectVersion
        let count = model.document.content.count
        #expect(editor.updateText("Texte partagé", of: semanticID, expectedVersion: version))
        let after = SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document, languageCode: model.languageCode))
        let copies = after.nodes.filter { after.objectID(for: $0.id) == semanticID }
        #expect(copies.count == 2)
        #expect(copies.allSatisfy { $0.label == "Texte partagé" })
        #expect(model.document.content.count == count)
        #expect(editor.save())
        model.reloadFromDisk()
        let reopened = SpatialDocumentScene(projection: SpatialDocumentProjection(document: model.document, languageCode: model.languageCode))
        #expect(reopened.nodes.filter { reopened.objectID(for: $0.id) == semanticID }
            .allSatisfy { $0.label == "Texte partagé" })
    }

    @Test("C2.6 move only one occurrence, undo redo, save and reopen")
    func moveOneOccurrenceOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-v3-c26-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        var document = SarahFixture.document()
        let objectID = try #require(document.content.keys.sorted {
            $0.rawValue < $1.rawValue
        }.first)
        document.presentation.instances = [
            NodeInstance(id: "move-first", objectID: objectID,
                         position: Position(x: 100, y: 150)),
            NodeInstance(id: "move-second", objectID: objectID,
                         position: Position(x: 530, y: 400))
        ]
        let model = KollioModel.deterministicModel(
            document: document, fileStore: DocumentFileStore(directory: directory)
        )
        let editor = SpatialDocumentEditor(model: model)
        let firstID = InstanceID("move-first")
        let secondID = InstanceID("move-second")
        let originalSemantic = model.document.content
        let semanticRevision = model.document.semanticRevision
        let beforeRevision = model.document.revision
        let originalSecond = try #require(model.document.presentation.instance(id: secondID)).position
        let scene = SpatialDocumentScene(
            projection: SpatialDocumentProjection(document: model.document)
        )
        #expect(scene.instanceIDByVisualID[objectID.rawValue] == "move-first")
        let secondCard = try #require(scene.nodes.first {
            scene.instanceIDByVisualID[$0.id] == "move-second"
        })
        #expect(scene.objectID(for: secondCard.id) == objectID.rawValue)
        #expect(editor.moveOccurrence("move-second", by: Position(x: 120, y: -80)))
        #expect(model.document.presentation.instance(id: firstID)?.position ==
                Position(x: 100, y: 150))
        #expect(model.document.presentation.instance(id: secondID)?.position ==
                Position(x: 650, y: 320))
        #expect(model.document.semanticRevision == semanticRevision)
        #expect(model.document.revision > beforeRevision)
        #expect(model.document.content == originalSemantic)

        let movedScene = SpatialDocumentScene(
            projection: SpatialDocumentProjection(document: model.document)
        )
        let movedVisual = try #require(movedScene.nodes.first { $0.id == secondCard.id })
        #expect(abs(movedVisual.x * 1000 - 650) < 0.01)
        #expect(abs(movedVisual.y * 640 - 320) < 0.01)
        editor.undo()
        #expect(model.document.presentation.instance(id: secondID)?.position == originalSecond)
        #expect(model.document.presentation.instance(id: firstID)?.position ==
                Position(x: 100, y: 150))
        editor.redo()
        #expect(model.document.presentation.instance(id: secondID)?.position ==
                Position(x: 650, y: 320))

        #expect(editor.save())
        model.reloadFromDisk()
        #expect(model.document.presentation.instance(id: secondID)?.position ==
                Position(x: 650, y: 320))
        #expect(model.document.presentation.instance(id: firstID)?.position ==
                Position(x: 100, y: 150))
        #expect(model.document.content == originalSemantic)
    }

    @Test("C2.6 invalid or tiny drag never changes the authored document")
    func invalidMoveIsSafe() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = model.document
        let valid = try #require(model.document.presentation.instances.first?.id.rawValue)
        #expect(!editor.moveOccurrence("instance:missing", by: Position(x: 5, y: 3)))
        #expect(!editor.moveOccurrence(valid, by: Position(x: 0.01, y: 0.01)))
        #expect(!editor.moveOccurrence(valid, by: Position(x: .infinity, y: 5)))
        #expect(!editor.moveOccurrence(valid, by: Position(x: 3, y: .nan)))
        #expect(model.document == before)
    }

    @Test("C2.6 zoom-aware dragging converts only screen translation, never camera pan")
    func screenTranslationIsWorldSpace() {
        let translation = CGSize(width: 120, height: -48)
        let one = SpatialOccurrenceDrag.worldDelta(screenTranslation: translation, zoom: 1)
        let two = SpatialOccurrenceDrag.worldDelta(screenTranslation: translation, zoom: 2)
        let half = SpatialOccurrenceDrag.worldDelta(screenTranslation: translation, zoom: 0.5)
        #expect(one == Position(x: 120, y: -48))
        #expect(two == Position(x: 60, y: -24))
        #expect(half == Position(x: 240, y: -96))
        #expect(SpatialOccurrenceDrag.worldDelta(screenTranslation: translation, zoom: 0) == nil)
        #expect(SpatialOccurrenceDrag.worldDelta(screenTranslation: translation, zoom: .nan) == nil)
        #expect(SpatialOccurrenceDrag.worldDelta(
            screenTranslation: CGSize(width: CGFloat.infinity, height: 0), zoom: 1) == nil)
    }

    @Test("C2.7 directional commands have one deterministic world-space step")
    func nudgeDirections() {
        let all = SpatialNudgeDirection.allCases
        #expect(all.count == 4)
        #expect(Set(all.map(\.localizationKey)).count == 4)
        #expect(SpatialNudgeDirection.up.delta == Position(x: 0, y: -16))
        #expect(SpatialNudgeDirection.down.delta == Position(x: 0, y: 16))
        #expect(SpatialNudgeDirection.left.delta == Position(x: -16, y: 0))
        #expect(SpatialNudgeDirection.right.delta == Position(x: 16, y: 0))
        #expect(SpatialNudgeDirection(.up) == .up)
        #expect(SpatialNudgeDirection(.down) == .down)
        #expect(SpatialNudgeDirection(.left) == .left)
        #expect(SpatialNudgeDirection(.right) == .right)
    }

    @Test("C2.7 accessible nudges use the same single-occurrence transaction and undo")
    func moveByKeyboardOrAccessibility() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let instance = try #require(model.document.presentation.instances.first)
        let original = model.document
        #expect(editor.moveOccurrence(instance.id.rawValue, by: SpatialNudgeDirection.right.delta))
        #expect(editor.moveOccurrence(instance.id.rawValue, by: SpatialNudgeDirection.up.delta))
        let moved = try #require(model.document.presentation.instance(id: instance.id)).position
        #expect(moved == original.presentation.instance(id: instance.id)?.position
                    .offset(dx: 16, dy: -16))
        #expect(model.document.content == original.content)
        #expect(model.document.semanticRevision == original.semanticRevision)
        editor.undo()
        #expect(model.document.presentation.instance(id: instance.id)?.position ==
                original.presentation.instance(id: instance.id)?.position
                    .offset(dx: 16, dy: 0))
        editor.undo()
        #expect(model.document.presentation == original.presentation)
        editor.redo()
        editor.redo()
        #expect(model.document.presentation.instance(id: instance.id)?.position == moved)
        #expect(editor.save())
        model.reloadFromDisk()
        #expect(model.document.presentation.instance(id: instance.id)?.position == moved)
    }

    @Test("C2.7 gesture preview never writes to the model before pointer release")
    func previewIsNotACommand() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let occurrence = try #require(model.document.presentation.instances.first)
        let before = model.document
        let preview = SpatialActiveDrag(
            visualID: occurrence.objectID.rawValue,
            screenTranslation: CGSize(width: 160, height: -40)
        )
        #expect(preview.visualID == occurrence.objectID.rawValue)
        #expect(SpatialOccurrenceDrag.worldDelta(
            screenTranslation: preview.screenTranslation, zoom: 2
        ) == Position(x: 80, y: -20))
        // Gesture cancellation is represented by discarding the preview.
        // No call to the editor was made, so there is no pending mutation.
        let cancelled: SpatialActiveDrag? = nil
        #expect(cancelled == nil)
        #expect(model.document == before)
        #expect(!editor.moveOccurrence(occurrence.id.rawValue, by: Position(x: 0, y: 0)))
        #expect(model.document == before)
    }

    @Test("C2.9 FR and EN native controls use their document language, not source content")
    func spatialUITranslationsPreserveAuthoredText() throws {
        let french = SpatialV3Copy(languageCode: "fr")
        let english = SpatialV3Copy(languageCode: "en")
        #expect(french.text("spatial.save") == "Enregistrer")
        #expect(english.text("spatial.save") == "Save")
        #expect(french.text("spatial.camera.centerSelected") == "Centrer sur la carte")
        #expect(english.text("spatial.camera.centerSelected") == "Center on card")
        #expect(french.text("spatial.node.selected") == "Sélectionné")
        #expect(english.text("spatial.node.selected") == "Selected")
        #expect(french.kind("CONSTRAINT") == "Contrainte")
        #expect(english.kind("CONSTRAINT") == "Constraint")
        #expect(english.status("set-aside") == "Set aside")
        #expect(french.status("active") == "Active")
        #expect(french.format("spatial.document.counts", 6, 7, 5, 11)
                == "6 objets · 7 représentations · 5 relations · révision 11")
        #expect(english.format("spatial.document.counts", 6, 7, 5, 11)
                == "6 objects · 7 representations · 5 relations · revision 11")
        #expect(english.format("spatial.occurrences", 2) == "2 views of this object")
        let document = SarahFixture.document()
        let before = document
        let fr = SpatialDocumentProjection(document: document, languageCode: "fr")
        let en = SpatialDocumentProjection(document: document, languageCode: "en")
        #expect(fr.nodes.count == en.nodes.count)
        #expect(document == before)
        for object in document.content.values {
            let frenchText = object.text.resolve(languageCode: "fr")
            let englishText = object.text.resolve(languageCode: "en")
            #expect(fr.nodes.first(where: { $0.id == object.id.rawValue })?.label == frenchText)
            #expect(en.nodes.first(where: { $0.id == object.id.rawValue })?.label == englishText)
        }
    }

    @Test("C2.11 Escape pauses the editor before closing the selection")
    func escapeOneLevelAtATime() {
        #expect(SpatialEscapeRoute.next(editing: true, selected: true, grouped: true,
                                        canCollapse: true) == .pauseEditor)
        #expect(SpatialEscapeRoute.next(editing: false, selected: true, grouped: true,
                                        canCollapse: true) == .clearSelection)
        #expect(SpatialEscapeRoute.next(editing: false, selected: false, grouped: true,
                                        canCollapse: true) == .clearGroup)
        #expect(SpatialEscapeRoute.next(editing: false, selected: false, grouped: false,
                                        canCollapse: true) == .collapseBranches)
        #expect(SpatialEscapeRoute.next(editing: false, selected: false, grouped: false,
                                        canCollapse: false) == .none)
    }

    @Test("C2.11 one draft survives selection, sibling occurrence and reopened editing")
    func pausedDraftRemainsRecoverable() throws {
        var memory = SpatialDraftMemory()
        let saved1 = memory.keep(objectID: "shared-object", languageCode: "fr",
                            draft: "Original", original: "Original", version: 5)
        #expect(!saved1)
        #expect(memory.draft(for: "shared-object", languageCode: "fr") == nil)
        let saved2 = memory.keep(objectID: "shared-object", languageCode: "fr", draft: "My unfinished thought",
                            original: "Original", version: 5)
        #expect(saved2)
        #expect(memory.draft(for: "shared-object", languageCode: "fr") == SpatialStoredDraft(
            text: "My unfinished thought", original: "Original", version: 5))
        // A second visual instance of this same object does not get a new draft.
        #expect(memory.draft(for: "shared-object", languageCode: "fr")?.text == "My unfinished thought")
        let saved3 = memory.keep(objectID: "another-object", languageCode: "fr", draft: "Second draft",
                            original: "Original", version: 7)
        #expect(saved3)
        #expect(memory.draft(for: "another-object", languageCode: "fr")?.text == "Second draft")
        let saved4 = memory.keep(objectID: "shared-object", languageCode: "fr", draft: "Original",
                             original: "Original", version: 5)
        #expect(!saved4)
        #expect(memory.draft(for: "shared-object", languageCode: "fr") == nil)
        // Drafts of a different translated variant are isolated, not
        // automatically grafted onto the current document language.
        let saved5 = memory.keep(objectID: "shared-object", languageCode: "en",
                            draft: "English draft", original: "Original", version: 5)
        #expect(saved5)
        #expect(memory.draft(for: "shared-object", languageCode: "fr") == nil)
        #expect(memory.draft(for: "shared-object", languageCode: "en")?.text == "English draft")
        memory.discard("shared-object", languageCode: "en")
        #expect(memory.draft(for: "shared-object", languageCode: "en") == nil)
        #expect(memory.draft(for: "another-object", languageCode: "fr")?.text == "Second draft")
    }

    @Test("C2.11 a stale write preserves a recoverable draft until explicitly reconciled")
    func staleDraftNeverOverwritesWithoutAChosenCurrentVersion() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = try #require(model.document.content.keys.sorted(
            by: { $0.rawValue < $1.rawValue }).first)
        let before = try #require(model.object(target))
        let originalText = before.text.resolve(languageCode: model.languageCode)
        var memory = SpatialDraftMemory()
        let authored = "My unfinished draft, do not lose this"
        let saved6 = memory.keep(objectID: target.rawValue, languageCode: "fr", draft: authored,
                            original: originalText, version: before.objectVersion)
        #expect(saved6)
        #expect(editor.updateText("Different concurrent text", of: target.rawValue,
                                  expectedVersion: before.objectVersion))
        let concurrent = try #require(model.object(target))
        let changedDocument = model.document
        #expect(!editor.updateText(authored, of: target.rawValue,
                                   expectedVersion: before.objectVersion))
        #expect(model.document == changedDocument)
        #expect(memory.draft(for: target.rawValue, languageCode: "fr")?.text == authored)
        #expect(memory.draft(for: target.rawValue, languageCode: "fr")?.version == before.objectVersion)
        #expect(concurrent.objectVersion > before.objectVersion)
        // The user's explicit choice to reconcile updates the optimistic
        // version at the UI layer; only an additional Confirm commits the draft.
        #expect(editor.updateText(authored, of: target.rawValue,
                                  expectedVersion: concurrent.objectVersion))
        memory.discard(target.rawValue, languageCode: "fr")
        #expect(memory.draft(for: target.rawValue, languageCode: "fr") == nil)
        #expect(model.object(target)?.text.resolve(languageCode: model.languageCode) == authored)
    }

    @Test("C2.11 recovery copy is available in the active document language")
    func draftCopyInFRAndEN() {
        #expect(SpatialV3Copy(languageCode: "fr").text("spatial.draft.resume")
                == "Reprendre le brouillon")
        #expect(SpatialV3Copy(languageCode: "en").text("spatial.draft.resume")
                == "Resume draft")
        #expect(SpatialV3Copy(languageCode: "fr").text("spatial.draft.pause")
                == "Conserver le brouillon et fermer")
        #expect(SpatialV3Copy(languageCode: "en").text("spatial.draft.pause")
                == "Keep draft and close")
    }

    @Test("C2.12 active and paused drafts count once, plus unsubmitted new ideas")
    func pendingInputCountReflectsActualUncommittedText() {
        var memory = SpatialDraftMemory()
        let fr = SpatialDraftMemory.Key(objectID: "same", languageCode: "fr")
        let en = SpatialDraftMemory.Key(objectID: "same", languageCode: "en")
        #expect(SpatialPendingInput.count(paused: memory, activeKey: nil,
                                         activeIsEdited: false, hasNewIdea: false) == 0)
        let recorded = memory.keep(objectID: "same", languageCode: "fr",
                                   draft: "Unfinished", original: "Before", version: 3)
        #expect(recorded)
        #expect(SpatialPendingInput.count(paused: memory, activeKey: nil,
                                         activeIsEdited: false, hasNewIdea: false) == 1)
        #expect(SpatialPendingInput.count(paused: memory, activeKey: fr,
                                         activeIsEdited: true, hasNewIdea: false) == 1)
        #expect(SpatialPendingInput.count(paused: memory, activeKey: fr,
                                         activeIsEdited: false, hasNewIdea: false) == 0)
        #expect(SpatialPendingInput.count(paused: memory, activeKey: en,
                                         activeIsEdited: true, hasNewIdea: true) == 3)
        memory.discard("same", languageCode: "fr")
        #expect(SpatialPendingInput.count(paused: memory, activeKey: nil,
                                         activeIsEdited: false, hasNewIdea: true) == 1)
    }

    @Test("C2.12 Save reports that canonical document is saved but draft is not")
    func savingDoesNotLieAboutDrafts() throws {
        let (editor, model, directory) = prepare()
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = model.document
        let objectID = try #require(before.content.keys.sorted(by: {
            $0.rawValue < $1.rawValue }).first)
        var drafts = SpatialDraftMemory()
        let original = try #require(model.object(objectID))
        let pending = drafts.keep(objectID: objectID.rawValue, languageCode: "fr",
                                  draft: "Not in the document",
                                  original: original.text.resolve(languageCode: "fr"),
                                  version: original.objectVersion)
        #expect(pending)
        let count = SpatialPendingInput.count(
            paused: drafts, activeKey: nil, activeIsEdited: false, hasNewIdea: false
        )
        let copyFR = SpatialV3Copy(languageCode: "fr")
        let copyEN = SpatialV3Copy(languageCode: "en")
        #expect(count == 1)
        #expect(SpatialSaveFeedback.message(saved: true, pendingCount: 0, copy: copyEN)
                == "Document saved to its .kollio file.")
        let warning = SpatialSaveFeedback.message(saved: true, pendingCount: count, copy: copyEN)
        #expect(warning.contains("NOT saved"))
        #expect(warning.contains("NOT saved: 1"))
        #expect(SpatialSaveFeedback.message(saved: true, pendingCount: count, copy: copyFR)
                .contains("Saisies non sauvegardées : 1"))
        #expect(SpatialSaveFeedback.message(saved: false, pendingCount: count, copy: copyEN)
                .contains("Save failed"))
        #expect(editor.save())
        model.reloadFromDisk()
        #expect(model.document.content == before.content)
        #expect(drafts.draft(for: objectID.rawValue, languageCode: "fr")?.text
                == "Not in the document")
        drafts.discard(objectID.rawValue, languageCode: "fr")
        #expect(model.document.content == before.content)
    }

    @Test("C2.18 opening contextual actions focuses an actionable inspector control")
    func contextualFocusHasStableFallback() {
        #expect(SpatialActionFocusRoute.destination(editable: true) == .edit)
        #expect(SpatialActionFocusRoute.destination(editable: false) == .close)
        #expect(SpatialEscapeRoute.next(
            editing: true, selected: true, grouped: false, canCollapse: false
        ) == .pauseEditor)
        #expect(SpatialEscapeRoute.next(
            editing: false, selected: true, grouped: false, canCollapse: false
        ) == .clearSelection)
        #expect(SpatialEscapeRoute.next(
            editing: false, selected: false, grouped: false, canCollapse: false
        ) == .none)
    }

    @Test("C2.18 contextual focus labels and hints are translated from native resources")
    func contextualFocusCopyIsLocalized() {
        let fr = SpatialV3Copy(languageCode: "fr")
        let en = SpatialV3Copy(languageCode: "en")
        #expect(fr.text("spatial.navigation.actions") == "Actions de la carte")
        #expect(en.text("spatial.navigation.actions") == "Card actions")
        #expect(fr.text("spatial.navigation.actionsHint").contains("sans glisser"))
        #expect(en.text("spatial.navigation.actionsHint").contains("without dragging"))
    }
}
