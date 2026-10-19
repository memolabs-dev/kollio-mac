import AppKit
import SwiftUI
import Testing
import KollioCore
@testable import KollioApp

/// C2.14: drive a real AppKit window hosting the real document canvas.
/// Opt-in: do not open native windows in unrelated package test runs.
@Suite("Spatial C2.14 — actual macOS window journey")
@MainActor
struct SpatialNativeWindowJourneyTests {
    @Test("An unsubmitted idea survives a cancelled native close, but not a confirmed close and reopen")
    func closeAndReopen() throws {
        guard ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C34_NATIVE"] == "1" else { return }

        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-c34-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = SarahFixture.document()
        let model = KollioModel.deterministicModel(
            document: original, fileStore: DocumentFileStore(directory: directory)
        )

        func window(draft: String) -> NSWindow {
            let frame = NSRect(x: 0, y: 0, width: 900, height: 700)
            let window = NSWindow(
                contentRect: frame, styleMask: [.titled, .closable],
                backing: .buffered, defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SpatialV3WindowView(
                model: model, initialNewIdeaDraft: draft
            ))
            window.orderFront(nil)
            RunLoop.current.run(until: Date().addingTimeInterval(0.7))
            return window
        }

        let first = window(draft: "Not committed. C2.14 close should warn.")
        defer { first.orderOut(nil) }
        let delegate = try #require(first.delegate as? SpatialNativeCloseDelegate)
        #expect(delegate.pendingCount == 1)
        var closeAttempts = 0
        delegate.testConfirmation = {
            closeAttempts += 1
            return false
        }
        first.performClose(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        #expect(closeAttempts == 1)
        #expect(first.isVisible)
        #expect(model.document == original)

        delegate.testConfirmation = {
            closeAttempts += 1
            return true
        }
        first.performClose(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        #expect(closeAttempts == 2)
        #expect(!first.isVisible)
        #expect(delegate.hasClosed)
        var quitPromptedForClosedWindow = false
        #expect(SpatialNativeCloseGuard.confirmQuitIfNeeded(windows: [first]) { _, _ in
            quitPromptedForClosedWindow = true
            return false
        })
        #expect(!quitPromptedForClosedWindow)
        #expect(model.document == original)

        // A new native window has a fresh @State draft buffer, not a hidden
        // recovery mechanism. The canonical semantic document is unchanged.
        let reopened = window(draft: "")
        defer { reopened.orderOut(nil) }
        let freshDelegate = try #require(reopened.delegate as? SpatialNativeCloseDelegate)
        #expect(freshDelegate.pendingCount == 0)
        #expect(model.document == original)
        #expect(freshDelegate.windowShouldClose(reopened))
    }
}
