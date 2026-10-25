import AppKit
import SwiftUI
import Testing
import KollioCore
@testable import KollioApp

/// Opt-in, isolated native validation. Captures only our NSHostingView, never
/// the user's screen or another application's windows. No user files touched.
@Suite("Spatial C2.8 — real macOS surface acceptance")
struct SpatialNativeAcceptanceTests {
    @Test("A two-occurrence .kollio scene renders with selected-card controls")
    @MainActor
    func renderTwoOccurrences() throws {
        guard let pngPath = ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C28_CAPTURE"]
        else { return }

        var document = SarahFixture.document()
        let objectID = try #require(document.content.keys.sorted {
            $0.rawValue < $1.rawValue
        }.first)
        document.presentation.instances = [
            NodeInstance(id: "c28-first", objectID: objectID,
                         position: Position(x: 260, y: 220)),
            NodeInstance(id: "c28-second", objectID: objectID,
                         position: Position(x: 680, y: 400))
        ]
        let original = document
        let fileStore = DocumentFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-c28-native-\(UUID().uuidString)"))
        let languageCode = ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C29_LANGUAGE"] == "en" ? "en" : "fr"
        let model = KollioModel(document: document,
                                service: KollioModel.makeDemoService(languageCode: languageCode),
                                fileStore: fileStore, languageCode: languageCode, mode: .demo)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let compact = ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C28_COMPACT"] == "1"
        let frame = NSRect(x: 0, y: 0, width: compact ? 900 : 1280,
                           height: compact ? 700 : 1100)
        // C2.12: opt-in non-mutating UI fixture for a pending draft banner.
        let pending = ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C32_PENDING"] == "1"
        let draft = pending
            ? (languageCode == "en" ? "Not yet committed" : "Texte non encore validé")
            : ""
        let hosting = NSHostingView(rootView: SpatialV3WindowView(
            initialSelectedID: objectID.rawValue, model: model, initialNewIdeaDraft: draft
        ))
        hosting.frame = frame
        let window = NSWindow(
            contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false
        )
        window.title = "Kollio C2.8 — isolated native document"
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: pngPath), options: .atomic)

        let projected = SpatialDocumentScene(projection: SpatialDocumentProjection(
            document: model.document, languageCode: model.languageCode
        ))
        #expect(projected.occurrenceCount(for: objectID.rawValue) == 2)
        #expect(projected.instanceIDByVisualID[objectID.rawValue] == "c28-first")
        #expect(model.document == original)
        print("NATIVE-C28 capture \(pngPath) (\(data.count) bytes)")
    }

    @Test("C2.16 a real native Spatial Ink viewport routes scroll without a document edit")
    @MainActor
    func realViewportScrollRouting() throws {
        guard ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C36_NATIVE"] == "1"
        else { return }

        let initial = SarahFixture.document()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-c36-scroll-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = KollioModel(
            document: initial,
            service: KollioModel.makeDemoService(languageCode: "en"),
            fileStore: DocumentFileStore(directory: directory),
            languageCode: "en", mode: .demo
        )
        NSApplication.shared.setActivationPolicy(.accessory)
        let frame = NSRect(x: 0, y: 0, width: 900, height: 700)
        let hosting = NSHostingView(rootView: SpatialV3WindowView(model: model))
        hosting.frame = frame
        let window = NSWindow(
            contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }

        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        hosting.layoutSubtreeIfNeeded()

        func lookup(_ view: NSView) -> SpatialTrackpadScrollObservationView? {
            if let match = view as? SpatialTrackpadScrollObservationView { return match }
            for child in view.subviews {
                if let found = lookup(child) { return found }
            }
            return nil
        }

        let observer = try #require(lookup(hosting))
        #expect(observer.bounds.width > 180)
        #expect(observer.bounds.height > 180)
        #expect(observer.hitTest(NSPoint(x: 30, y: 30)) == nil)

        // Tests only our own local monitor's routing. No system input is
        // injected, and the user's actual pointer/window focus is untouched.
        let sample = SpatialTrackpadScrollInput(
            delta: CGSize(width: 95, height: -42), isPrecise: true,
            hasReservedModifiers: false, hasMomentum: false, isEnding: false
        )
        let center = observer.convert(
            CGPoint(x: observer.bounds.midX, y: observer.bounds.midY), to: nil
        )
        let before = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: before)
        let beforeData = try #require(before.representation(using: .png, properties: [:]))

        #expect(!observer.route(sample, windowNumber: window.windowNumber + 50, point: center))
        #expect(observer.route(sample, windowNumber: window.windowNumber, point: center))
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        hosting.layoutSubtreeIfNeeded()

        let after = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: after)
        let afterData = try #require(after.representation(using: .png, properties: [:]))
        #expect(beforeData != afterData)
        #expect(model.document == initial)
    }


    @Test("C2.18 selected actions remain discoverable in a compact native window")
    @MainActor
    func compactSelectedActions() throws {
        guard let output = ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C38_CAPTURE"]
        else { return }

        let original = SarahFixture.document()
        let objectID = try #require(original.content.keys.sorted {
            $0.rawValue < $1.rawValue
        }.first)
        let locale = ProcessInfo.processInfo.environment["KOLLIO_SPATIAL_C29_LANGUAGE"] == "en"
            ? "en" : "fr"
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("kollio-c38-compact-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let model = KollioModel(
            document: original,
            service: KollioModel.makeDemoService(languageCode: locale),
            fileStore: DocumentFileStore(directory: folder),
            languageCode: locale, mode: .demo
        )
        NSApplication.shared.setActivationPolicy(.accessory)
        let frame = NSRect(x: 0, y: 0, width: 680, height: 520)
        let hosting = NSHostingView(rootView: SpatialV3WindowView(
            initialSelectedID: objectID.rawValue, model: model
        ))
        hosting.frame = frame
        let window = NSWindow(contentRect: frame, styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFront(nil)
        defer { window.orderOut(nil); window.close() }

        RunLoop.current.run(until: Date().addingTimeInterval(0.9))
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: output), options: .atomic)
        #expect(png.count > 8_000)
        // A raw NSHostingView accessibilityChildren walk was removed after
        // it caused a signal 11 crash on the headless GitHub macOS runner.
        // VoiceOver is a separate human acceptance gate, not a screenshot test.
        #expect(SpatialV3Copy(languageCode: locale).text("spatial.navigation.actions")
                == (locale == "en" ? "Card actions" : "Actions de la carte"))
        #expect(model.document == original)
        print("NATIVE-C38 compact selected actions: \(output) (\(png.count) bytes)")
    }
}
