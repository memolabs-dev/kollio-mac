import SwiftUI
import KollioCore

/// A proposed object, shown exactly where it would enter the graph.
///
/// It is a ghost, not a card in a panel: dashed relationship, lighter content,
/// cobalt accent, and a small "Proposition" indicator.
struct GhostNodeView: View {
    let kind: ContentObject.Kind
    let text: String
    let width: Double

    @Environment(\.kollioTheme) private var theme

    private var form: ContentObject.Form {
        ContentObject(id: "ghost", kind: kind, text: LocalizedText(text), provenance: .human("ghost")).form
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .semibold))
                Text(L10n.proposal)
                    .font(TypeScale.metadata.weight(.medium))
            }
            .foregroundStyle(theme.proposalAccent)
            .opacity(0.9)

            Text(text)
                .font(form == .thought ? TypeScale.body : TypeScale.primaryThought)
                .foregroundStyle(theme.textPrimary.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: width, alignment: .leading)
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(theme.accentSurface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(theme.proposalAccent.opacity(0.55), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4]))
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The decision controls shown next to a proposal: Retenir / Écarter, and the
/// short reason that will be remembered if the branch is set aside.
struct ProposalDecisionView: View {
    @Bindable var model: KollioModel

    @Environment(\.kollioTheme) private var theme

    var body: some View {
        if let preview = model.preview {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.xs) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .semibold))
                    Text(preview.summary)
                        .font(TypeScale.action.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                }

                if !preview.rationale.isEmpty {
                    Text(preview.rationale)
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                }

                // Offered only when the branch cannot be seen. A marker that is
                // always there is a marker the person learns to ignore.
                if model.previewIsOffScreen() {
                    ActionButton(title: L10n.seeProposal, isDefault: false) {
                        model.revealPreview()
                    }
                    .help(L10n.seeProposalHint)
                }

                HStack(spacing: Space.s) {
                    ActionButton(title: L10n.keep, isDefault: true) { model.keepPreview() }
                    ActionButton(title: L10n.setAside) { model.discardPreview() }
                    Spacer(minLength: 0)
                    // Asked for rather than shown. Where an answer came from and
                    // what it was based on are things a person wants before they
                    // keep it, not a paragraph in front of them every time.
                    ActionButton(title: L10n.proposalWhy, isDefault: false) {
                        model.showsProposalAttribution.toggle()
                    }
                }
            }
            .padding(Space.l)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                    .fill(theme.surfacePrimary)
                    .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.14), radius: 18, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                    .strokeBorder(theme.decorativeBorder, lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.proposal)
        }
    }
}

/// A small quiet button. No chrome, no gradient.
struct ActionButton: View {
    let title: String
    var isDefault: Bool = false
    /// A step that does not exist is not offered as a button that does nothing.
    /// Added for the presentation card, where the first and last steps have one
    /// neighbour each and a button that ignores its press is a lie about what the
    /// keyboard will do.
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.kollioTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeScale.action)
                .foregroundStyle(isDefault && isEnabled ? Color.white : theme.textPrimary)
                .padding(.horizontal, Space.m)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(isDefault && isEnabled ? theme.accent : theme.surfaceSubtle)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
