import SwiftUI

/// How much weight one local control carries.
///
/// One prominent control per cluster. The design fixes this because a cluster
/// where everything is emphasised is a cluster where nothing is, and the person
/// has to read three labels to work out which one they meant.
public enum KollioControlEmphasis: Sendable, Equatable {
    case normal
    case prominent
}

/// A control that acts on the document, rather than being part of it.
///
/// This is the only place in Kollio that asks for Liquid Glass, and it is asked
/// for deliberately: the document is matte, and the things a person presses
/// against it are instruments. That is the whole of the rule — glass marks what
/// is temporary and actionable, so a node never becomes an instrument.
///
/// Two things it deliberately does **not** do, both of which the previous
/// version did:
///
/// - it does not draw its own background. The material is the system's, so the
///   shape, the highlight and the press response come from the platform rather
///   than from a rectangle this repository also has to maintain;
/// - it does not add glass to text. A label that a person reads stays on Paper.
///
/// ## Compatibility
///
/// The floor is macOS 26, which is where `.glass` and `.glassProminent` were
/// introduced, so the system style is used directly and there is no second
/// appearance to keep in step. If the floor is ever lowered below 26, this file
/// is the only one that has to change: the fallback belongs here and nowhere
/// else, because the alternative is availability checks scattered across every
/// control in the application.
public struct InstrumentButton: View {
    let title: String
    var emphasis: KollioControlEmphasis = .normal
    /// A step that does not exist is not offered as a control that does nothing.
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.kollioTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        _ title: String,
        emphasis: KollioControlEmphasis = .normal,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.emphasis = emphasis
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        // The label colour is stated rather than left to the material. It is not
        // redundancy: the tint is ours (cobalt, and a light periwinkle in dark
        // mode), so the foreground has to be the one measured against *that*
        // colour. White is 2.15:1 on the dark theme's accent.
        //
        // The material is decided, not assumed. Under reduced transparency a
        // control has to stay findable without help from what is behind it, and
        // "the system will probably handle it" is not a decision.
        //
        // The system styles are different types from each other and from the
        // fallback, so this is a branch rather than a ternary: a ternary would
        // have to name one type and would resolve against `ButtonStyle`, which
        // has neither member.
        Group {
            switch InstrumentMaterial.resolve(reduceTransparency: reduceTransparency) {
            case .opaque:
                content
                    .buttonStyle(OpaqueInstrumentButtonStyle(theme: theme, emphasis: emphasis))
                    .foregroundStyle(emphasis == .prominent ? theme.onAccent : theme.textPrimary)
            case .glass, .glassProminent:
                if emphasis == .prominent {
                    content
                        .buttonStyle(.glassProminent)
                        .tint(theme.accent)
                        .foregroundStyle(theme.onAccent)
                } else {
                    content
                        .buttonStyle(.glass)
                }
            }
        }
        .disabled(isEnabled == false)
    }

    private var content: some View {
        Button(action: action) {
            Text(title)
                .font(TypeScale.action)
                .fixedSize()
        }
    }
}

/// What an instrument is made of, given what the person has asked the system for.
///
/// Pure, and therefore testable without a window: this is the one decision the
/// design requires to be made rather than delegated, because a control that
/// depends on the material behind it to be found is not a control.
public enum InstrumentMaterial: String, Sendable, Equatable, CaseIterable {
    case glass
    case glassProminent
    case opaque

    public static func resolve(reduceTransparency: Bool) -> InstrumentMaterial {
        // Reduced transparency is a request that meaning not depend on seeing
        // through. A material that samples what is behind it cannot honour that
        // request, so the instrument becomes a surface of its own.
        reduceTransparency ? .opaque : .glass
    }

    /// Whether this material is a system material, which is the only reason the
    /// repository is allowed to ask for one.
    public var isSystemMaterial: Bool { self != .opaque }
}

/// The non-glass instrument: a surface, a border, and no blur.
///
/// Deliberately plain. When the system material is not available to this person,
/// the control still has to read as a control, so it keeps the border that
/// carries the outline and drops everything else.
public struct OpaqueInstrumentButtonStyle: ButtonStyle {
    let theme: Theme
    let emphasis: KollioControlEmphasis

    public init(theme: Theme, emphasis: KollioControlEmphasis) {
        self.theme = theme
        self.emphasis = emphasis
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Space.m)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(emphasis == .prominent ? theme.accent : theme.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(
                        emphasis == .prominent ? theme.accent : theme.decorativeBorder,
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// One glass system per local group.
///
/// Several glass controls that belong together are grouped here rather than each
/// sampling the background on its own. Beyond the rendering, this is what lets
/// the system treat them as one instrument: consistent material across the
/// cluster, and a single layer to composite.
public struct InstrumentGroup<Content: View>: View {
    @ViewBuilder let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GlassEffectContainer(spacing: 4) {
            content
        }
    }
}
