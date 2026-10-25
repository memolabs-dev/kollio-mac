import SwiftUI
import KollioCore

/// Reading the document along a chosen path.
///
/// The card is small on purpose. CAN-10 asks for a *complete keyboard path* and
/// "presentation mode hides editing commands but keeps exit, source and
/// navigation", so what is on screen is the step, where you are in the path, and
/// the three things that must stay reachable. Everything else is a keystroke:
///
/// - `Cmd+Return` starts, and again leaves
/// - the arrow keys move between points
/// - `Escape` leaves, through the same level stack as every other card
///
/// It says which state it is in rather than only where you are: a step can be an
/// object, a piece of evidence, or a decision, and a reader who cannot tell those
/// apart cannot follow an argument. A point that is no longer in the document is
/// counted and named, never replaced by whatever is next.
struct PresentationView: View {
    let model: KollioModel
    let session: KollioModel.PresentationSession

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            header
            if let entry = session.entry {
                step(entry)
            } else {
                // Reached only if the document emptied under the tour, which the
                // read-only rule makes hard, and which is still answered rather
                // than drawn as an empty card.
                Text(L10n.presentationNothingToPresent)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
            }
            if session.resolution.isPartial {
                skippedLine
            }
            navigation
        }
        .padding(Space.m)
        .frame(width: 380, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.reference, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.14), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.reference, style: .continuous)
                .strokeBorder(theme.decorativeBorder, lineWidth: 1)
        )
        .onAppear { focused = true }
        .accessibilityElement(children: .contain)
    }

    // MARK: Blocks

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(L10n.presentation)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            Spacer(minLength: 0)
            Text(L10n.presentationProgress(session.position, session.count))
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func step(_ entry: ReadingPath.Entry) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // The kind comes first: an object, a piece of evidence and a decision
            // are three different things to be shown, and a reader who cannot tell
            // them apart is not following anything.
            Text(kindLabel(entry.kind))
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.proposalAccent)
            Text(entry.label)
                .font(TypeScale.body)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if entry.anchorObjectID == nil {
                Text(L10n.presentationNoAnchor)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if case .source = entry.point {
                // Opening a source is reading, so it stays available in the mode
                // that forbids changing anything.
                ActionButton(title: L10n.presentationOpenSource, isDefault: false) {
                    model.openPresentedSource(entry.point)
                }
            }
        }
    }

    private var skippedLine: some View {
        Text(L10n.presentationSkipped + " · " + String(session.resolution.skipped.count))
            .font(TypeScale.metadata)
            .foregroundStyle(theme.attention)
    }

    private var navigation: some View {
        HStack(spacing: Space.xs) {
            ActionButton(
                title: L10n.presentationPrevious,
                isDefault: false,
                isEnabled: session.index > 0
            ) {
                model.rewindPresentation()
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            ActionButton(
                title: L10n.presentationNext,
                isDefault: false,
                isEnabled: session.index + 1 < session.count
            ) {
                model.advancePresentation()
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            Spacer(minLength: 0)
            // Always reachable. A reading mode a person cannot leave is a trap, and
            // the exit is not the thing that gets hidden to keep the mode tidy.
            ActionButton(title: L10n.presentationExit, isDefault: true) {
                model.exitPresentation()
            }
        }
    }

    private func kindLabel(_ kind: ReadingPath.Point.Kind) -> String {
        switch kind {
        case .object: return L10n.presentationKindObject
        case .source: return L10n.presentationKindSource
        case .decision: return L10n.presentationKindDecision
        }
    }
}
