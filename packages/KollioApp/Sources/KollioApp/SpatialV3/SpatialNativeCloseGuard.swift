import AppKit
import SwiftUI

/// Protects window-local, unconfirmed Spatial Ink text from an accidental
/// native close. This does not persist drafts or change the document model.
struct SpatialNativeCloseGuard: NSViewRepresentable {
    let pendingCount: Int
    let copy: SpatialV3Copy

    func makeNSView(context: Context) -> SpatialCloseObservationView {
        let view = SpatialCloseObservationView(frame: .zero)
        view.guardDelegate.pendingCount = pendingCount
        view.guardDelegate.copy = copy
        return view
    }

    func updateNSView(_ view: SpatialCloseObservationView, context: Context) {
        view.guardDelegate.pendingCount = pendingCount
        view.guardDelegate.copy = copy
        view.attachToWindow()
    }

    /// Quit does not necessarily send windowShouldClose. Catch Cmd+Q as well,
    /// before AppDelegate writes the canonical document and terminates.
    static func confirmQuitIfNeeded(
        windows: [NSWindow] = NSApp.windows,
        testConfirmation: ((Int, SpatialV3Copy) -> Bool)? = nil
    ) -> Bool {
        let guards = windows.compactMap { $0.delegate as? SpatialNativeCloseDelegate }
            .filter { !$0.hasClosed }
        let total = guards.reduce(0) { $0 + max(0, $1.pendingCount) }
        guard total > 0, let copy = guards.first?.copy else { return true }
        if let testConfirmation { return testConfirmation(total, copy) }
        return SpatialNativeCloseDelegate.confirm(
            title: copy.text("spatial.close.title"),
            detail: copy.format("spatial.quit.detail", total),
            cancel: copy.text("spatial.close.stay"),
            destructive: copy.text("spatial.quit.discard")
        )
    }
}

@MainActor
final class SpatialCloseObservationView: NSView {
    let guardDelegate = SpatialNativeCloseDelegate()
    private weak var observedWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachToWindow()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { guardDelegate.detach() }
        super.viewWillMove(toWindow: newWindow)
    }

    func attachToWindow() {
        guard let window else { return }
        if observedWindow !== window {
            guardDelegate.attach(to: window)
            observedWindow = window
        } else if window.delegate !== guardDelegate {
            // SwiftUI can refresh its own delegate as the window changes.
            guardDelegate.attach(to: window)
        }
    }
}

/// A delegate proxy: preserve the original SwiftUI/AppKit delegate and forward
/// its optional methods, including its veto when no unfinished text exists.
@MainActor
final class SpatialNativeCloseDelegate: NSObject, NSWindowDelegate {
    private weak var observedWindow: NSWindow?
    // NSObject forwarding hooks are nonisolated even though AppKit invokes
    // window delegates on the UI thread. Keep the reference explicitly unsafe
    // to bridge that Objective-C boundary without exporting a non-Sendable
    // delegate from MainActor.assumeIsolated (rejected by Swift 6 CI).
    nonisolated(unsafe) private weak var previousDelegate: (any NSWindowDelegate)?
    var pendingCount = 0
    private(set) var hasClosed = false
    var copy = SpatialV3Copy(languageCode: nil)
    /// Injectable only for deterministic native tests; default uses NSAlert.
    var testConfirmation: (() -> Bool)?

    func attach(to window: NSWindow) {
        if observedWindow === window && window.delegate === self { return }
        detach()
        observedWindow = window
        hasClosed = false
        previousDelegate = window.delegate
        window.delegate = self
    }

    func detach() {
        if let observedWindow, observedWindow.delegate === self {
            observedWindow.delegate = previousDelegate
        }
        observedWindow = nil
        previousDelegate = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // A native delegate veto must win before asking to lose a draft.
        guard previousDelegate?.windowShouldClose?(sender) ?? true else { return false }
        if pendingCount > 0 {
            let confirmed = testConfirmation?() ?? Self.confirm(
                title: copy.text("spatial.close.title"),
                detail: copy.format("spatial.close.detail", pendingCount),
                cancel: copy.text("spatial.close.stay"),
                destructive: copy.text("spatial.close.discard")
            )
            if !confirmed { return false }
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        // A confirmed close can leave a retained NSWindow in NSApp.windows.
        // Exclude it from future Cmd+Q counts, including last-window quit.
        hasClosed = true
        previousDelegate?.windowWillClose?(notification)
    }

    nonisolated override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || previousDelegate?.responds(to: selector) == true
    }

    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        if previousDelegate?.responds(to: selector) == true {
            return previousDelegate
        }
        return super.forwardingTarget(for: selector)
    }

    static func confirm(title: String, detail: String,
                        cancel: String, destructive: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: cancel)
        alert.addButton(withTitle: destructive)
        return alert.runModal() == .alertSecondButtonReturn
    }
}
