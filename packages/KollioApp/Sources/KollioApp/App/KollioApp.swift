import SwiftUI
import KollioCore
import AppKit

@main
struct KollioApp: App {
    /// Built from the environment at launch, so the app starts with the source it
    /// was actually configured for rather than always the offline engine.
    @State private var model = KollioModel.makeAppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Kollio", id: "main") {
            RootView(model: model)
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
        .commands { KollioCommands(model: model) }
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

    var body: some View {
        ZStack {
            if model.isEmpty {
                FirstExperienceView(model: model)
            } else {
                CanvasView(model: model)
            }
        }
        .background(Color.clear)
    }
}

/// System commands live in native macOS menus. The canvas itself stays empty.
struct KollioCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let model: KollioModel

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
        MainActor.assumeIsolated {
            // Native Cmd+Q bypasses per-window windowShouldClose. Never let
            // window-local unfinished drafts silently disappear on quit.
            guard SpatialNativeCloseGuard.confirmQuitIfNeeded() else {
                return .terminateCancel
            }
            saveOnQuit()
            return .terminateNow
        }
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
