import AppKit
import SwiftUI

/// A precise two-finger scroll moves only the local canvas camera. A text
/// editor, macOS accessibility zoom or the document's outer ScrollView must
/// never receive a synthetic gesture or document mutation from this adapter.
struct SpatialTrackpadScrollInput: Equatable, Sendable {
    let delta: CGSize
    let isPrecise: Bool
    let hasReservedModifiers: Bool
    let hasMomentum: Bool
    let isEnding: Bool

    /// The incoming deltas are incremental and measured in screen points.
    /// Discard terminal/momentum events; a cancelled gesture has no retained
    /// delta, so the next scroll starts from the current camera.
    func translation(insideViewport: Bool, canPan: Bool) -> CGSize? {
        guard insideViewport, canPan, isPrecise,
              !hasReservedModifiers, !hasMomentum, !isEnding,
              delta.width.isFinite, delta.height.isFinite,
              delta.width != 0 || delta.height != 0
        else { return nil }
        return delta
    }

    func translatedCamera(
        from camera: SpatialV3Camera,
        insideViewport: Bool,
        canPan: Bool
    ) -> SpatialV3Camera? {
        guard let delta = translation(insideViewport: insideViewport, canPan: canPan)
        else { return nil }
        return camera.panned(dx: delta.width, dy: delta.height)
    }
}

/// AppKit scroll-wheel events are delivered to the hosting hierarchy. Observe
/// them without participating in hit testing: buttons, cards, clicks, keyboard
/// focus and native scrolling outside the canvas keep their usual behavior.
struct SpatialTrackpadScrollCapture: NSViewRepresentable {
    let canPan: Bool
    let onPan: (CGSize) -> Void

    func makeNSView(context: Context) -> SpatialTrackpadScrollObservationView {
        let view = SpatialTrackpadScrollObservationView(frame: .zero)
        view.canPan = canPan
        view.onPan = onPan
        return view
    }

    func updateNSView(_ view: SpatialTrackpadScrollObservationView, context: Context) {
        view.canPan = canPan
        view.onPan = onPan
        view.refreshMonitor()
    }

    static func dismantleNSView(
        _ view: SpatialTrackpadScrollObservationView, coordinator: ()
    ) {
        view.removeMonitor()
    }
}

@MainActor
final class SpatialTrackpadScrollObservationView: NSView {
    var canPan = true
    var onPan: ((CGSize) -> Void)?
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshMonitor()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { removeMonitor() }
        super.viewWillMove(toWindow: newWindow)
    }

    func refreshMonitor() {
        guard window != nil else { removeMonitor(); return }
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            // Do not send a non-Sendable NSEvent across actor isolation. Copy
            // only Sendable scalar/geometry fields before the synchronous hop.
            let input = SpatialTrackpadScrollInput(
                delta: CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY),
                isPrecise: event.hasPreciseScrollingDeltas,
                hasReservedModifiers: !event.modifierFlags.intersection(
                    [.command, .control, .option]
                ).isEmpty,
                hasMomentum: !event.momentumPhase.isEmpty,
                isEnding: event.phase.contains(.ended) || event.phase.contains(.cancelled)
            )
            let windowNumber = event.windowNumber
            let point = event.locationInWindow
            let consumed = MainActor.assumeIsolated {
                self?.route(input, windowNumber: windowNumber, point: point) ?? false
            }
            return consumed ? nil : event
        }
    }

    func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    @discardableResult
    func route(
        _ input: SpatialTrackpadScrollInput,
        windowNumber: Int,
        point: CGPoint
    ) -> Bool {
        guard let window, window.windowNumber == windowNumber,
              !isHiddenOrHasHiddenAncestor else { return false }
        let local = convert(point, from: nil)
        let inside = bounds.contains(local) && visibleRect.contains(local)
        guard let delta = input.translation(insideViewport: inside, canPan: canPan),
              let onPan else { return false }
        onPan(delta)
        return true
    }
}
