import AppKit
import Testing
@testable import KollioApp

@Suite("Spatial C2.13 — native close protects unfinished drafts")
@MainActor
struct SpatialNativeCloseGuardTests {
    private func window() -> NSWindow {
        NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
    }

    @Test("Cancel prevents native close; explicit confirmation permits it")
    func closeDecision() {
        let window = window()
        let guardDelegate = SpatialNativeCloseDelegate()
        guardDelegate.attach(to: window)
        guardDelegate.pendingCount = 2
        var questions = 0
        guardDelegate.testConfirmation = {
            questions += 1
            return false
        }
        #expect(guardDelegate.windowShouldClose(window) == false)
        #expect(questions == 1)
        guardDelegate.testConfirmation = { true }
        #expect(guardDelegate.windowShouldClose(window) == true)
        #expect(questions == 1)
        guardDelegate.pendingCount = 0
        #expect(guardDelegate.windowShouldClose(window) == true)
        guardDelegate.detach()
    }

    @Test("Original AppKit delegate retains its independent veto")
    func preservesOriginalDelegate() {
        final class VetoDelegate: NSObject, NSWindowDelegate {
            func windowShouldClose(_ sender: NSWindow) -> Bool { false }
        }
        let window = window()
        let veto = VetoDelegate()
        window.delegate = veto
        let guardDelegate = SpatialNativeCloseDelegate()
        guardDelegate.attach(to: window)
        guardDelegate.pendingCount = 0
        #expect(guardDelegate.windowShouldClose(window) == false)
        guardDelegate.pendingCount = 1
        var askedToLoseDraft = false
        guardDelegate.testConfirmation = {
            askedToLoseDraft = true
            return true
        }
        #expect(guardDelegate.windowShouldClose(window) == false)
        #expect(!askedToLoseDraft)
        guardDelegate.detach()
        #expect(window.delegate === veto)
    }

    @Test("Cmd+Q aggregates open Spatial Ink windows and can refuse termination")
    func quitDecision() {
        let first = window(), second = window(), ordinary = window()
        let a = SpatialNativeCloseDelegate(), b = SpatialNativeCloseDelegate()
        a.attach(to: first)
        b.attach(to: second)
        a.pendingCount = 2
        b.pendingCount = 3
        var total = 0
        let allowed = SpatialNativeCloseGuard.confirmQuitIfNeeded(windows: [first, second, ordinary]) {
            count, _ in
            total = count
            return false
        }
        #expect(allowed == false)
        #expect(total == 5)
        a.pendingCount = 0
        b.pendingCount = 0
        #expect(SpatialNativeCloseGuard.confirmQuitIfNeeded(windows: [first, second, ordinary]) == true)
        a.detach()
        b.detach()
    }

    @Test("Native observation attaches and restores original delegate")
    func nativeAttachment() {
        let window = window()
        let observation = SpatialCloseObservationView(frame: .zero)
        observation.guardDelegate.pendingCount = 1
        window.contentView?.addSubview(observation)
        observation.attachToWindow()
        #expect(window.delegate === observation.guardDelegate)
        observation.guardDelegate.testConfirmation = { false }
        #expect(observation.guardDelegate.windowShouldClose(window) == false)
        observation.removeFromSuperview()
        #expect(window.delegate !== observation.guardDelegate)
    }

    @Test("Closing labels exist in French and English")
    func localizedClose() {
        for language in ["fr", "en"] {
            let copy = SpatialV3Copy(languageCode: language)
            for key in ["spatial.close.title", "spatial.close.detail",
                        "spatial.close.stay", "spatial.close.discard",
                        "spatial.quit.detail", "spatial.quit.discard"] {
                #expect(copy.text(key) != key)
            }
        }
    }
}
