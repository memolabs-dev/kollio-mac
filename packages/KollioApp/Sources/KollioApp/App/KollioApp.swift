import SwiftUI
import KollioCore
import AppKit
import UniformTypeIdentifiers

struct MarkdownExportFile: FileDocument {
    static let markdownType = UTType(importedAs: "net.daringfireball.markdown")
    static var readableContentTypes: [UTType] { [markdownType] }
    let data: Data

    init(snapshot: DocumentExportSnapshot) {
        data = snapshot.markdown
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct KollioExportFile: FileDocument {
    static let kollioType = UTType(exportedAs: "dev.kollio.document", conformingTo: .json)
    static var readableContentTypes: [UTType] { [kollioType] }
    let data: Data

    init(document: KollioDocument) throws {
        data = try DocumentCodec.encode(document)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

@main
struct KollioApp: App {
    /// Built from the environment at launch, so the app starts with the source it
    /// was actually configured for rather than always the offline engine.
    @State private var model = KollioModel.makeAppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var isRenaming = false
    @State private var isDuplicating = false
    @State private var nameDraft = ""
    @State private var isExportingMarkdown = false
    @State private var markdownExport: MarkdownExportFile?
    @State private var isExportingPNG = false
    @State private var pngExport: PNGExportFile?
    @State private var isExportingKollio = false
    @State private var kollioExport: KollioExportFile?

    var body: some Scene {
        Window("Kollio", id: "main") {
            RootView(
                model: model,
                isRenaming: $isRenaming,
                isDuplicating: $isDuplicating,
                nameDraft: $nameDraft,
                isExportingMarkdown: $isExportingMarkdown,
                markdownExport: $markdownExport,
                isExportingPNG: $isExportingPNG,
                pngExport: $pngExport,
                isExportingKollio: $isExportingKollio,
                kollioExport: $kollioExport
            )
                .kollioThemed()
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    await model.prepareVisualStateForReview()
                }
                // The delegate saves on quit. It has to be handed the same model
                // the window is showing, or every save on quit is a silent no-op.
                .onAppear { delegate.model = model }
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1280, height: 860)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            KollioCommands(
                model: model,
                isRenaming: $isRenaming,
                isDuplicating: $isDuplicating,
                nameDraft: $nameDraft,
                isExportingMarkdown: $isExportingMarkdown,
                markdownExport: $markdownExport,
                isExportingPNG: $isExportingPNG,
                pngExport: $pngExport,
                isExportingKollio: $isExportingKollio,
                kollioExport: $kollioExport
            )
        }
        Window("Spatial Ink V3", id: "spatial-v3") {
            SpatialV3WindowView()
                .frame(minWidth: 920, minHeight: 790)
        }
        .defaultSize(width: 1250, height: 1020)
        Window("Spatial Ink V3 — Document actif", id: "spatial-v3-document") {
            SpatialV3WindowView(model: model)
                .frame(minWidth: 920, minHeight: 790)
        }
        .defaultSize(width: 1250, height: 1020)
        Window("Spatial Ink V3 — Test 100 objets", id: "spatial-v3-stress") {
            SpatialV3WindowView(initialDepth: 2, stressMode: true)
                .frame(minWidth: 920, minHeight: 790)
        }
        .defaultSize(width: 1250, height: 1020)
    }
}

struct RootView: View {
    let model: KollioModel
    @Binding var isRenaming: Bool
    @Binding var isDuplicating: Bool
    @Binding var nameDraft: String
    @Binding var isExportingMarkdown: Bool
    @Binding var markdownExport: MarkdownExportFile?
    @Binding var isExportingPNG: Bool
    @Binding var pngExport: PNGExportFile?
    @Binding var isExportingKollio: Bool
    @Binding var kollioExport: KollioExportFile?

    var body: some View {
        ZStack {
            if model.isEmpty {
                FirstExperienceView(model: model)
            } else {
                CanvasView(model: model)
            }
        }
        .background(Color.clear)
        .alert(L10n.renameDocument, isPresented: $isRenaming) {
            TextField(L10n.documentName, text: $nameDraft)
            Button(L10n.renameDocument) { model.renameDocument(to: nameDraft) }
            Button(L10n.cancel, role: .cancel) {}
        }
        .alert(L10n.duplicateDocument, isPresented: $isDuplicating) {
            TextField(L10n.documentName, text: $nameDraft)
            Button(L10n.duplicateDocument) { model.duplicateDocument(named: nameDraft) }
            Button(L10n.cancel, role: .cancel) {}
        }
        .fileExporter(
            isPresented: $isExportingMarkdown,
            document: markdownExport,
            contentType: MarkdownExportFile.markdownType,
            defaultFilename: model.document.title
        ) { result in
            if case .failure = result { model.status = L10n.errorSaveFailed }
        }
        .fileExporter(
            isPresented: $isExportingPNG,
            document: pngExport,
            contentType: PNGExportFile.pngType,
            defaultFilename: model.document.title
        ) { result in
            if case .failure = result { model.status = L10n.errorSaveFailed }
        }
        .fileExporter(
            isPresented: $isExportingKollio,
            document: kollioExport,
            contentType: KollioExportFile.kollioType,
            defaultFilename: model.document.title
        ) { result in
            if case .failure = result { model.status = L10n.errorSaveFailed }
        }
    }
}

/// System commands live in native macOS menus. The canvas itself stays empty.
struct KollioCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let model: KollioModel
    @Binding var isRenaming: Bool
    @Binding var isDuplicating: Bool
    @Binding var nameDraft: String
    @Binding var isExportingMarkdown: Bool
    @Binding var markdownExport: MarkdownExportFile?
    @Binding var isExportingPNG: Bool
    @Binding var pngExport: PNGExportFile?
    @Binding var isExportingKollio: Bool
    @Binding var kollioExport: KollioExportFile?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.newDocument) { model.newDocument() }
                .keyboardShortcut("n", modifiers: .command)
            Button(L10n.openDemo) { model.loadDemo() }
                .keyboardShortcut("d", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .saveItem) {
            Button(L10n.save) { model.save() }
                .keyboardShortcut("s", modifiers: .command)
            Divider()
            Button(L10n.renameDocument) {
                nameDraft = model.document.title
                isRenaming = true
            }
            Button(L10n.duplicateDocument) {
                nameDraft = model.document.title + L10n.copySuffix
                isDuplicating = true
            }
            Button(L10n.exportMarkdown) {
                markdownExport = MarkdownExportFile(snapshot: model.exportSnapshot())
                isExportingMarkdown = true
            }
            Button(L10n.exportPNG) {
                pngExport = PNGExportFile(snapshot: model.exportSnapshot())
                isExportingPNG = true
            }
            Button(L10n.exportAssets) {
                AssetArchivePicker.chooseDirectory { directory in
                    model.archiveExportAssets(into: directory)
                }
            }
            Button(L10n.exportKollio) {
                if let export = try? KollioExportFile(document: model.exportPortableDocument()) {
                    kollioExport = export
                    isExportingKollio = true
                } else {
                    model.status = L10n.errorSaveFailed
                }
            }
        }
        CommandGroup(replacing: .undoRedo) {
            Button(L10n.undo) { model.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)
            Button(L10n.redo) { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
        }
        CommandGroup(after: .toolbar) {
            Button("Spatial Ink V3 Preview…") {
                openWindow(id: "spatial-v3")
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])
            Button("Spatial Ink V3 — Document actif…") {
                openWindow(id: "spatial-v3-document")
            }
            Button("Spatial Ink V3 — Test 100 objets…") {
                openWindow(id: "spatial-v3-stress")
            }
            Divider()
            Button(L10n.search) { model.openSearch() }
                .keyboardShortcut("f", modifiers: .command)
            Button(model.isPresenting ? L10n.presentationExit : L10n.presentationStart) {
                if model.isPresenting {
                    model.exitPresentation()
                } else {
                    model.beginPresentation()
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            Button(L10n.fit) { model.fitContent() }
                .keyboardShortcut("0", modifiers: .command)
            Button(L10n.actualSize) {
                model.camera = Camera()
            }
            .keyboardShortcut("1", modifiers: .command)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: KollioModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// The macOS client owns the local document: it is saved on quit, and
    /// restored on the next launch.
    ///
    /// Both hooks are deliberate. `applicationShouldTerminate` is the one that
    /// runs for a normal quit, and it can still refuse; the `WillTerminate`
    /// notification is the last chance for the other paths. Neither one reports
    /// success unless `save()` actually returned true.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated { saveOnQuit() }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { saveOnQuit() }
    }

    @MainActor
    private func saveOnQuit() {
        guard let model else {
            // Nothing to save is worse than a visible failure: say so rather
            // than quitting as if the work were safe on disk.
            NSLog("Kollio: quitting with no model attached, the document was not saved")
            return
        }
        if model.save() == false {
            NSLog("Kollio: the document could not be saved on quit: \(model.status ?? "")")
        }
    }
}
