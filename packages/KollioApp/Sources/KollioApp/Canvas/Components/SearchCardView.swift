import SwiftUI
import KollioCore

/// Find something in the document, including the reasons people wrote.
///
/// The card is shaped by four rules, and each of them is visible on screen rather
/// than in a comment:
///
/// - **A result says what it is.** On the canvas, set aside, or history. A reason
///   whose decision no longer stands is offered as history, because presenting it
///   as the reason that applies today would be worse than not finding it.
/// - **Showing a set-aside direction does not bring it back.** The result reveals
///   it and centres on it; reopening stays a separate, named button on the object.
/// - **Zero results keeps the query.** The field still holds what was typed, so the
///   person corrects a word instead of starting again, and clearing is offered.
/// - **What was not searched is stated.** Rights are applied before the search, and
///   source content is not read to look for words. A result list that looked
///   complete while part of the document was out of scope would be a lie with a
///   count on it.
///
/// No intelligence is involved: this is a textual search over what is already in
/// the document, and there is nothing to ask a model about.
struct SearchCardView: View {
    let model: KollioModel
    let state: KollioModel.SearchState

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            field
            if state.hasSearched {
                if state.isEmpty {
                    emptyBlock
                } else {
                    resultsBlock
                    if let outcome = state.outcome, outcome.isPartial {
                        notSearchedBlock(outcome)
                    }
                }
            }
            HStack(spacing: Space.xs) {
                Spacer(minLength: 0)
                ActionButton(title: L10n.searchClear, isDefault: false) {
                    model.clearSearch()
                }
                .help(L10n.searchClearHint)
            }
        }
        .padding(Space.l)
        .frame(width: 420, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.14), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
        )
        .onAppear { focused = true }
        .accessibilityElement(children: .contain)
    }

    // MARK: Blocks

    private var field: some View {
        TextField(
            L10n.searchPlaceholder,
            text: Binding(
                get: { state.query },
                set: { model.updateSearch($0) }
            ),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(TypeScale.body)
        .foregroundStyle(theme.textPrimary)
        .lineLimit(1...3)
        .focused($focused)
    }

    /// Zero results. The field above still holds the query, which is the point:
    /// the person corrects the word rather than starting again.
    private var emptyBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(L10n.searchNoResults)
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var resultsBlock: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            ForEach(state.results) { result in
                Button {
                    model.revealSearchResult(result)
                } label: {
                    resultRow(result)
                }
                .buttonStyle(.plain)
                .help(result.state == .setAside ? L10n.searchReopenHint : "")
            }
        }
    }

    private func resultRow(_ result: DocumentSearch.Result) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            // The state is the first thing read, because it decides what a person
            // is about to click on.
            Text(model.searchStateLabel(for: result))
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(tint(for: result.state))
                .frame(width: 84, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.excerpt)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(model.searchFieldLabel(for: result))
                    .font(TypeScale.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.xxs)
        .contentShape(Rectangle())
    }

    /// What the result set deliberately left out. Never hidden, and never the same
    /// colour as a result: it is a caveat, not a finding.
    private func notSearchedBlock(_ outcome: DocumentSearch.Outcome) -> some View {
        var skipped = 0
        var lines: [String] = []
        for item in outcome.notSearched {
            skipped += item.count
            if case .sourceContent(let count) = item {
                lines.append(L10n.searchNotSearchedSources(count))
            }
        }
        return VStack(alignment: .leading, spacing: Space.xxs) {
            Text(L10n.searchNotSearched)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(lines, id: \.self) { line in
                Text("· " + line)
                    .font(TypeScale.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            Text(L10n.searchPartial(skipped))
                .font(TypeScale.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    /// Attention for anything that is not on the canvas right now, so the two
    /// never read as the same kind of thing.
    private func tint(for state: DocumentSearch.State) -> Color {
        switch state {
        case .visible: return theme.textSecondary
        case .setAside, .archived: return theme.attention
        }
    }
}
