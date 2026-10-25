import AppKit
import Foundation
import KollioCore
import SwiftUI
import UniformTypeIdentifiers

/// The frozen scope, drawn.
///
/// A PNG export is a rendering of `DocumentExportSnapshot`, not a screenshot of
/// whatever happened to be on screen. That is the whole point of freezing the
/// scope: the image and the Markdown come from the same blocks, so a person who
/// previewed the export cannot receive a different one.
enum ExportRaster {
    static let pageWidth: CGFloat = 900
    static let margin: CGFloat = 56
    static let scale: CGFloat = 2

    static func pngData(for snapshot: DocumentExportSnapshot) -> Data? {
        let contentWidth = pageWidth - margin * 2
        let attributed = snapshot.blocks.map { attributed($0) }
        let heights = attributed.map { $0.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height }
        let total = heights.reduce(margin * 2, +)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pageWidth * scale),
            pixelsHigh: Int(total * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        representation.size = NSSize(width: pageWidth, height: total)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: pageWidth, height: total).fill()
        NSColor.black.setStroke()

        var y = total - margin
        for (line, height) in zip(attributed, heights) {
            y -= height
            line.draw(
                with: NSRect(x: margin, y: y, width: contentWidth, height: height),
                options: [.usesLineFragmentOrigin]
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        return representation.representation(using: .png, properties: [:])
    }

    static func attributed(_ block: DocumentExportBlock) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 3
        let font: NSFont
        switch block.role {
        case .title: font = .boldSystemFont(ofSize: 28)
        case .heading: font = .boldSystemFont(ofSize: 18)
        case .meta: font = .systemFont(ofSize: 12)
        case .bullet: font = .systemFont(ofSize: 13)
        case .spacer: font = .systemFont(ofSize: 8)
        }
        let color: NSColor = block.role == .meta ? .secondaryLabelColor : .labelColor
        return NSAttributedString(
            string: block.markdownLine,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        )
    }
}

struct PNGExportFile: FileDocument {
    static let pngType = UTType.png
    static var readableContentTypes: [UTType] { [pngType] }
    let data: Data
    let snapshot: DocumentExportSnapshot

    init(snapshot: DocumentExportSnapshot) {
        self.snapshot = snapshot
        self.data = ExportRaster.pngData(for: snapshot) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        snapshot = DocumentExportSnapshot(
            documentID: "",
            revision: 0,
            objectIDs: [],
            blocks: [],
            markdown: Data()
        )
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// What an archive actually managed to do, so the person is told the difference
/// between "everything travelled" and "three of your five files are not there".
public struct AssetArchiveResult: Hashable, Sendable {
    public var directory: URL
    public var copied: [AssetArchiveEntry]
    public var skipped: [AssetArchiveEntry]
    public var manifest: URL
}

/// Asks where the archive should go. Cancelling writes nothing: an export that
/// the person did not ask for is not a polite default.
enum AssetArchivePicker {
    @MainActor
    static func chooseDirectory(_ completion: @escaping @MainActor (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.exportAssets
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        completion(directory)
    }
}

public enum AssetArchiver {
    /// Copies the authorised assets of an exported scope next to a manifest.
    ///
    /// The manifest is written even when nothing could be copied: an archive
    /// that silently omits a file reads as an archive that never had one.
    @discardableResult
    public static func archive(
        plan: [AssetArchiveEntry],
        into parent: URL,
        named name: String
    ) throws -> AssetArchiveResult {
        let directory = parent.appendingPathComponent(sanitized(name), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var copied: [AssetArchiveEntry] = []
        var skipped: [AssetArchiveEntry] = []
        var usedNames: Set<String> = []
        for entry in plan {
            guard entry.outcome == .copyable else {
                skipped.append(entry)
                continue
            }
            let source = URL(fileURLWithPath: entry.locator)
            var filename = sanitized(source.lastPathComponent)
            if filename.isEmpty { filename = sanitized(entry.sourceID.idString) }
            if filename.isEmpty { filename = "asset" }
            if usedNames.contains(filename) {
                var attempt = 2
                var candidate = filename
                while usedNames.contains(candidate) {
                    candidate = "\(filename) \(attempt)"
                    attempt += 1
                }
                filename = candidate
            }
            usedNames.insert(filename)
            let target = directory.appendingPathComponent(filename)
            do {
                try FileManager.default.copyItem(at: source, to: target)
                copied.append(entry)
            } catch {
                // A file that moved between the plan and the copy is a warning,
                // not a reason to throw away the assets that did travel.
                skipped.append(entry)
            }
        }

        let manifestURL = directory.appendingPathComponent("MANIFEST.md")
        try manifestText(plan: plan, copied: copied, documentTitle: name)
            .write(to: manifestURL, atomically: true, encoding: .utf8)

        return AssetArchiveResult(
            directory: directory,
            copied: copied,
            skipped: skipped,
            manifest: manifestURL
        )
    }

    static func manifestText(plan: [AssetArchiveEntry], copied: [AssetArchiveEntry], documentTitle: String) -> String {
        let copiedIDs = Set(copied.map(\.sourceID))
        var lines = ["# \(documentTitle)", ""]
        for entry in plan {
            let state: String
            switch entry.outcome {
            case .copyable where copiedIDs.contains(entry.sourceID): state = "copied"
            case .copyable: state = "not copied, the file moved"
            case .linkOnly: state = "link only, nothing to copy"
            case .missing: state = "missing"
            }
            lines.append("- \(entry.title): \(state) (\(entry.locator))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func sanitized(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\0")
        let cleaned = name.unicodeScalars.map { scalar -> String in
            forbidden.contains(scalar) ? "-" : String(scalar)
        }.joined()
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
