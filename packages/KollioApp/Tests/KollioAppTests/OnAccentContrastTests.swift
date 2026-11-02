import Foundation
import Testing
@testable import KollioApp

/// The foreground on an accent, measured rather than assumed.
///
/// `docs/design/04-visual-language-and-surfaces.md` records the numbers this file
/// re-derives. The reason they are a test and not a comment is that the failing
/// case is invisible in a light-mode screenshot and obvious in a dark one, and a
/// regression would be reintroduced by someone tidying a colour.
@Suite("Design system: what is legible on the accent")
struct OnAccentContrastTests {
    /// WCAG relative luminance, sRGB.
    private static func luminance(_ hex: UInt32) -> Double {
        func channel(_ byte: UInt32) -> Double {
            let c = Double(byte) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let r = channel((hex >> 16) & 0xFF)
        let g = channel((hex >> 8) & 0xFF)
        let b = channel(hex & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// WCAG AA for body text. The action labels are 13pt medium, which is not
    /// large text, so 4.5:1 is the bar and not the 3:1 that large text gets.
    private static let textThreshold = 4.5

    @Test("A label on the accent is readable in both themes")
    func onAccentPassesInBothThemes() {
        let cases: [(name: String, accent: UInt32, foreground: UInt32)] = [
            ("light", Palette.lightAccentHex, Palette.lightOnAccentHex),
            ("dark", Palette.darkAccentHex, Palette.darkOnAccentHex)
        ]
        for testCase in cases {
            let ratio = Self.contrast(testCase.accent, testCase.foreground)
            #expect(
                ratio >= Self.textThreshold,
                "\(testCase.name): \(ratio.formatted(.number.precision(.fractionLength(2)))):1 is under \(Self.textThreshold):1"
            )
        }
    }

    @Test("White is not assumed to work on the dark theme's accent")
    func whiteIsRejectedOnTheDarkAccent() {
        // The specific failure this file exists for. 2.15:1 is a label that is
        // physically present and cannot be read.
        let white = Self.contrast(Palette.darkAccentHex, 0xFFFFFF)
        #expect(white < Self.textThreshold, "white on the dark accent was expected to fail; the accent changed")

        let onAccent = Self.contrast(Palette.darkAccentHex, Palette.darkOnAccentHex)
        #expect(onAccent > white, "the dark theme's own foreground must beat white on the same accent")
    }

    @Test("The dark foreground is the document's own ink, not a second black")
    func darkForegroundIsTheCanvasInk() {
        #expect(Palette.darkOnAccentHex == Palette.darkCanvasBackgroundHex)
    }

    @Test("The quiet button keeps its contrast on the subtle surface too")
    func quietButtonContrast() {
        let cases: [(name: String, surface: UInt32, foreground: UInt32)] = [
            ("light", Palette.lightSurfaceSubtleHex, Palette.lightTextPrimaryHex),
            ("dark", Palette.darkSurfaceSubtleHex, Palette.darkTextPrimaryHex)
        ]
        for testCase in cases {
            let ratio = Self.contrast(testCase.surface, testCase.foreground)
            #expect(ratio >= Self.textThreshold, "\(testCase.name) quiet button: \(ratio):1")
        }
    }
}
