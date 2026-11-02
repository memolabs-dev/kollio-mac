import SwiftUI

/// Kollio identity: PAPER, INK, BRANCH.
///
/// PAPER is a calm working surface. INK makes an idea durable and readable.
/// BRANCH is the signature behaviour: a thought visibly growing from another.
///
/// Views never use raw colours: they read these tokens, which resolve per colour
/// scheme and per accessibility setting.
public enum Palette {
    // MARK: Hex, the source of truth
    //
    // The values live as numbers so a contrast ratio can be computed from them in a
    // test. A `Color` cannot be measured without a rendered window behind it, and a
    // colour that cannot be measured is a colour that is only ever checked by eye.
    public static let lightCanvasBackgroundHex: UInt32 = 0xF7F7F3
    public static let lightSurfacePrimaryHex: UInt32 = 0xFFFFFF
    public static let lightSurfaceSubtleHex: UInt32 = 0xF0F1EB
    public static let lightTextPrimaryHex: UInt32 = 0x242724
    public static let lightTextSecondaryHex: UInt32 = 0x62675F
    public static let lightBorderDecorativeHex: UInt32 = 0xDDE1D8
    public static let lightLineEssentialHex: UInt32 = 0x7A8278
    public static let lightAccentHex: UInt32 = 0x4058D8
    public static let lightAccentSurfaceHex: UInt32 = 0xEEF1FF
    public static let lightOnAccentHex: UInt32 = 0xFFFFFF
    public static let lightAttentionHex: UInt32 = 0x8A5A18
    public static let lightErrorHex: UInt32 = 0xAA4146
    public static let darkCanvasBackgroundHex: UInt32 = 0x171A1D
    public static let darkSurfacePrimaryHex: UInt32 = 0x22262A
    public static let darkSurfaceSubtleHex: UInt32 = 0x292E33
    public static let darkTextPrimaryHex: UInt32 = 0xEFF1EC
    public static let darkTextSecondaryHex: UInt32 = 0xADB5AE
    public static let darkBorderDecorativeHex: UInt32 = 0x394047
    public static let darkLineEssentialHex: UInt32 = 0x7D878F
    public static let darkAccentHex: UInt32 = 0x9CACFF
    public static let darkAccentSurfaceHex: UInt32 = 0x2A3355
    public static let darkOnAccentHex: UInt32 = 0x171A1D
    public static let darkAttentionHex: UInt32 = 0xE6B97A
    public static let darkErrorHex: UInt32 = 0xF4A6AA

    // MARK: Colors, derived
    public static var lightCanvasBackground: Color { Color(hex: lightCanvasBackgroundHex) }
    public static var lightSurfacePrimary: Color { Color(hex: lightSurfacePrimaryHex) }
    public static var lightSurfaceSubtle: Color { Color(hex: lightSurfaceSubtleHex) }
    public static var lightTextPrimary: Color { Color(hex: lightTextPrimaryHex) }
    public static var lightTextSecondary: Color { Color(hex: lightTextSecondaryHex) }
    public static var lightBorderDecorative: Color { Color(hex: lightBorderDecorativeHex) }
    public static var lightLineEssential: Color { Color(hex: lightLineEssentialHex) }
    public static var lightAccent: Color { Color(hex: lightAccentHex) }
    public static var lightAccentSurface: Color { Color(hex: lightAccentSurfaceHex) }
    public static var lightOnAccent: Color { Color(hex: lightOnAccentHex) }
    public static var lightAttention: Color { Color(hex: lightAttentionHex) }
    public static var lightError: Color { Color(hex: lightErrorHex) }
    public static var darkCanvasBackground: Color { Color(hex: darkCanvasBackgroundHex) }
    public static var darkSurfacePrimary: Color { Color(hex: darkSurfacePrimaryHex) }
    public static var darkSurfaceSubtle: Color { Color(hex: darkSurfaceSubtleHex) }
    public static var darkTextPrimary: Color { Color(hex: darkTextPrimaryHex) }
    public static var darkTextSecondary: Color { Color(hex: darkTextSecondaryHex) }
    public static var darkBorderDecorative: Color { Color(hex: darkBorderDecorativeHex) }
    public static var darkLineEssential: Color { Color(hex: darkLineEssentialHex) }
    public static var darkAccent: Color { Color(hex: darkAccentHex) }
    public static var darkAccentSurface: Color { Color(hex: darkAccentSurfaceHex) }
    public static var darkOnAccent: Color { Color(hex: darkOnAccentHex) }
    public static var darkAttention: Color { Color(hex: darkAttentionHex) }
    public static var darkError: Color { Color(hex: darkErrorHex) }
}

/// Semantic tokens resolved for the current environment.
public struct Theme: Equatable, Sendable {
    public var isDark: Bool
    public var increaseContrast: Bool
    public var reduceTransparency: Bool

    public init(isDark: Bool, increaseContrast: Bool = false, reduceTransparency: Bool = false) {
        self.isDark = isDark
        self.increaseContrast = increaseContrast
        self.reduceTransparency = reduceTransparency
    }

    public var canvasBackground: Color { isDark ? Palette.darkCanvasBackground : Palette.lightCanvasBackground }
    public var surfacePrimary: Color { isDark ? Palette.darkSurfacePrimary : Palette.lightSurfacePrimary }
    public var surfaceSubtle: Color { isDark ? Palette.darkSurfaceSubtle : Palette.lightSurfaceSubtle }
    public var textPrimary: Color { isDark ? Palette.darkTextPrimary : Palette.lightTextPrimary }
    public var textSecondary: Color { isDark ? Palette.darkTextSecondary : Palette.lightTextSecondary }
    public var borderDecorative: Color { isDark ? Palette.darkBorderDecorative : Palette.lightBorderDecorative }
    public var lineEssential: Color { isDark ? Palette.darkLineEssential : Palette.lightLineEssential }
    public var accent: Color { isDark ? Palette.darkAccent : Palette.lightAccent }
    public var accentSurface: Color { isDark ? Palette.darkAccentSurface : Palette.lightAccentSurface }
    public var attention: Color { isDark ? Palette.darkAttention : Palette.lightAttention }
    public var error: Color { isDark ? Palette.darkError : Palette.lightError }

    /// Decorative borders get stronger when the user asks for more contrast.
    public var decorativeBorder: Color {
        increaseContrast ? (isDark ? Color(hex: 0x5A636B) : Color(hex: 0xB7BDB2)) : borderDecorative
    }

    /// Essential lines must always stay readable, so they never lighten away.
    public var connector: Color {
        increaseContrast ? (isDark ? Color(hex: 0xA8B2BA) : Color(hex: 0x515A50)) : lineEssential
    }

    public var proposalAccent: Color { accent }

    /// What is legible **on** the accent, which is not white everywhere.
    ///
    /// The two accents are not the same colour: the light theme's cobalt is dark
    /// enough to carry white, and the dark theme's is a light periwinkle that
    /// cannot. Measured with the relative-luminance formula in
    /// `docs/design/04-visual-language-and-surfaces.md`:
    ///
    /// - light `0x4058D8` under white: **5.82:1** — usable.
    /// - dark `0x9CACFF` under white: **2.15:1** — a failure, and the reason a
    ///   primary action used to disappear into its own button in dark mode.
    /// - dark `0x9CACFF` under `0x171A1D`: **8.12:1** — comfortable.
    ///
    /// The dark foreground is the dark canvas ink, so the light accent is read as
    /// paper carrying the same ink as everything else, rather than as a second
    /// colour invented for buttons.
    public var onAccent: Color { isDark ? Palette.darkOnAccent : Palette.lightOnAccent }
}

public extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// The spacing scale. Nothing else is allowed.
public enum Space {
    public static let xxs: Double = 2
    public static let xs: Double = 4
    public static let s: Double = 8
    public static let m: Double = 12
    public static let l: Double = 16
    public static let xl: Double = 24
    public static let xxl: Double = 32
    public static let huge: Double = 48
    public static let giant: Double = 64
}

public enum Radius {
    public static let control: Double = 8
    public static let reference: Double = 10
    public static let richBlock: Double = 14
    public static let composer: Double = 16
}

/// Motion explains change, never decoration.
public enum Motion {
    public static let feedback: Double = 0.10
    public static let reveal: Double = 0.14
    public static let dismiss: Double = 0.16
    public static let expand: Double = 0.22
    public static let branch: Double = 0.28
    public static let camera: Double = 0.26
    public static let stagger: Double = 0.04

    /// Entrance displacement of a growing branch, in points. Small on purpose.
    public static let branchEntranceOffset: Double = 6
}

/// What a piece of text is *for*, which is what decides how it is set.
///
/// The role is the unit. A size on its own cannot carry a hierarchy: when two
/// roles are close, or when a person raises the text size, size alone stops
/// being the difference. Weight is the part that survives that, so the weight
/// and the size are decided together, in one place, per role.
public enum TypeRole: String, CaseIterable, Sendable {
    /// The first thing a person reads, and the only one that is a title.
    case invitation
    /// Structurally important: the thing everything else hangs from.
    case context
    /// The reading body of a thought.
    case thought
    /// Prose.
    case body
    /// A control's label.
    case action
    /// Secondary information, and the most used role in the application.
    case metadata
    /// The single exception: something that needs to be looked at.
    case attention
    /// Small supporting text.
    case caption
}

/// A size and a weight, as numbers, so the scale can be checked rather than read.
public struct TypeSpec: Equatable, Sendable {
    public let size: Double
    /// 0 regular, 1 medium, 2 semibold. A rank, not a `Font.Weight`, because a
    /// rank is what can be compared in a test and what the rule is written in.
    public let weightRank: Int

    public init(size: Double, weightRank: Int) {
        self.size = size
        self.weightRank = weightRank
    }

    public var font: Font {
        switch weightRank {
        case 0: return .system(size: size, weight: .regular)
        case 1: return .system(size: size, weight: .medium)
        default: return .system(size: size, weight: .semibold)
        }
    }
}

/// Native system typography.
///
/// Three weights, and the rule for which one is not negotiable:
/// **regular reads, medium distinguishes, semibold is exceptional.** That is the
/// limit `docs/design/04-visual-language-and-surfaces.md` sets — "regular pour
/// lire, medium pour distinguer, un accent supplémentaire exceptionnel" — and the
/// previous scale broke it by setting four of the six roles to medium, which made
/// medium mean "ordinary" and left nothing to distinguish with.
///
/// Sizes are Kollio's own, from the same document. They are indicative, not
/// immutable.
public enum TypeScale {
    /// The whole scale, as data. The named fonts below are read from here, so a
    /// size and its weight cannot drift apart.
    public static let specs: [TypeRole: TypeSpec] = [
        // Read, not displayed: the invitation is a sentence somebody is meant to
        // finish, and setting it heavy would make it look like a poster.
        .invitation: TypeSpec(size: 28, weightRank: 0),
        // The anchor of a document. Medium, because this is the one role whose
        // job is to be structurally louder than what it contains.
        .context: TypeSpec(size: 22, weightRank: 1),
        // A thought is read, so it is regular. It was medium, which made the
        // commonest text on the canvas the second-heaviest thing in it.
        .thought: TypeSpec(size: 18, weightRank: 0),
        .body: TypeSpec(size: 15, weightRank: 0),
        // A control's label is distinguished from prose, and is not read at
        // length, so medium is honest here.
        .action: TypeSpec(size: 13, weightRank: 1),
        .metadata: TypeSpec(size: 12, weightRank: 0),
        .caption: TypeSpec(size: 11, weightRank: 0),
        // The one exception the rule allows: the single marker that says the
        // ground moved. Semibold is what makes it findable in a scan, and it is
        // used in one place.
        .attention: TypeSpec(size: 12, weightRank: 2)
    ]

    public static func spec(_ role: TypeRole) -> TypeSpec {
        specs[role] ?? TypeSpec(size: 12, weightRank: 0)
    }

    public static func font(for role: TypeRole) -> Font { spec(role).font }

    public static var invitation: Font { font(for: .invitation) }
    public static var mainContext: Font { font(for: .context) }
    public static var primaryThought: Font { font(for: .thought) }
    public static var body: Font { font(for: .body) }
    public static var action: Font { font(for: .action) }
    public static var metadata: Font { font(for: .metadata) }
    public static var needsAttention: Font { font(for: .attention) }
    public static var caption: Font { font(for: .caption) }
}

/// Depth: three levels, and no more.
public enum Elevation {
    public static func content(_ theme: Theme) -> Double { 0 }
    public static func lifted(_ theme: Theme) -> Double { increase(theme, base: 0.10) }
    public static func control(_ theme: Theme) -> Double { increase(theme, base: 0.16) }

    static func increase(_ theme: Theme, base: Double) -> Double {
        theme.increaseContrast ? 0 : base
    }
}
