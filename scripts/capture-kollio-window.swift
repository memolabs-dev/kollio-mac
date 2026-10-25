import AppKit
import Darwin
import Foundation
import ScreenCaptureKit

// A screenshot is only evidence of Kollio if ScreenCaptureKit isolates Kollio's
// exact bundle identity. Never fall back to full-screen capture on failure.
enum KollioCaptureError: LocalizedError {
    case windowCount(Int)
    case encoding

    var errorDescription: String? {
        switch self {
        case .windowCount(let count):
            return "Expected exactly one visible dev.kollio.app window, found \(count). No screenshot saved."
        case .encoding:
            return "Could not encode the Kollio window as PNG. No screenshot saved."
        }
    }
}

@main
struct CaptureKollioWindow {
    static func main() async {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: capture-kollio-window /absolute/path/to/kollio.png\n", stderr)
            exit(64)
        }

        do {
            try await capture(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        } catch {
            fputs("Kollio window capture failed: \(error.localizedDescription)\n", stderr)
            fputs("Check macOS Screen Recording permission for the terminal/launcher. No desktop fallback is allowed.\n", stderr)
            exit(1)
        }
    }

    private static func capture(to destination: URL) async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        let matching = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == "dev.kollio.app"
                && window.frame.width >= 320
                && window.frame.height >= 200
        }

        guard matching.count == 1, let window = matching.first else {
            throw KollioCaptureError.windowCount(matching.count)
        }

        let settings = SCStreamConfiguration()
        settings.width = min(3840, max(640, Int(window.frame.width * 2)))
        settings.height = min(2160, max(400, Int(window.frame.height * 2)))
        settings.showsCursor = false

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: settings
        )
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw KollioCaptureError.encoding
        }
        try data.write(to: destination, options: .atomic)
        print("Captured isolated Kollio window (\(image.width)x\(image.height)): \(destination.path)")
        print("Review the actual pixels and visible document before using this as product evidence.")
    }
}
