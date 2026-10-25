import SwiftUI
import KollioCore

/// The local action control that appears next to a selected object.
///
/// At most three primary actions. The full action universe is never on screen.
struct ContextualActions: View {
    let model: KollioModel
    let target: ObjectID

    @Environment(\.kollioTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The cluster's real size, published by the layout below.
    ///
    /// The placement used to assume 300 by 52 and clamp, which is a guess that
    /// cannot notice being wrong: it put the bar off the window as soon as a
    /// label was long enough, and a French « Comparer les directions » is longer
    /// than the space the guess allowed for.
    @State private var measured: CGSize = .zero

    var body: some View {
        // A reading mode offers no editing command at all, not a set of buttons
        // that would refuse when pressed. The refusal is proved at the command
        // layer, but a person who is invited to press something during a tour is
        // being invited to find out, and a reading mode that also edits is not one.
        // CAN-10 keeps exit, source and navigation; none of them live here.
        if model.isPresenting {
            EmptyView()
        } else if let object = model.frame(of: target) {
            let placement = ContextualPlacement.resolve(
                object: screenFrame(of: object),
                size: measured,
                viewport: CGSize(width: model.viewport.width, height: model.viewport.height)
            )
            instrumentCluster
                .background(measure)
                .position(placement.point)
                .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : -4)))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(AXID.contextualActions)
        }
    }

    /// The buttons, and nothing else.
    ///
    /// There was a hand-drawn plate here: a white rounded rectangle with a large
    /// shadow, holding buttons that each drew their own fill. That is glass on
    /// glass, or rather neither: a plate pretending to be a material, wrapped
    /// around controls pretending to be buttons. The cluster is now the material,
    /// which is what the system already knows how to draw and how to press.
    private var instrumentCluster: some View {
        InstrumentGroup {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack(spacing: Space.xs) {
                    ForEach(actionSet.primary, id: \.self) { kind in
                        InstrumentButton(
                            L10n.callAsFunction(kind.localizationKey),
                            emphasis: kind == actionSet.isDefault ? .prominent : .normal
                        ) {
                            perform(kind)
                        }
                        .help(L10n.callAsFunction(kind.localizationKey))
                    }
                    if !actionSet.secondary.isEmpty {
                        // One named control, not a row of icons. A native Menu is
                        // keyboard reachable, keeps its own focus, and cannot be
                        // confused with a tooltip that happens to hold buttons.
                        Menu {
                            ForEach(actionSet.secondary, id: \.self) { kind in
                                Button(L10n.callAsFunction(kind.localizationKey)) {
                                    perform(kind)
                                }
                            }
                        } label: {
                            Text(L10n.moreActions)
                                .font(TypeScale.action)
                                .fixedSize()
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.visible)
                        .fixedSize()
                        .help(L10n.moreActions)
                    }
                }
                if !setAsideReason.isEmpty {
                    // Paper, not glass, and deliberately: this is a sentence a
                    // person reads, and glass is for what a person presses. A
                    // reason that fades into whatever is behind it is a reason
                    // that cannot be re-read.
                    Text(setAsideReason)
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, Space.s)
                        .padding(.vertical, Space.xs)
                        .frame(maxWidth: 320, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                .fill(theme.surfacePrimary)
                        )
                }
            }
        }
    }

    /// Publishes the rendered size of the cluster, in the coordinate space the
    /// placement works in.
    private var measure: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ContextualSizeKey.self, value: proxy.size)
        }
        .onPreferenceChange(ContextualSizeKey.self) { size in
            // A zero is the measurement arriving before the layout, not a real
            // size. Keeping the last real one avoids a bar that jumps.
            if size.width > 0, size.height > 0 { measured = size }
        }
    }

    private func screenFrame(of frame: Rect) -> CGRect {
        let topLeft = model.camera.toScreen(Position(x: frame.minX, y: frame.minY))
        let bottomRight = model.camera.toScreen(Position(x: frame.maxX, y: frame.maxY))
        return CGRect(
            x: topLeft.x,
            y: topLeft.y,
            width: bottomRight.x - topLeft.x,
            height: bottomRight.y - topLeft.y
        )
    }

    // MARK: Actions

    /// The set is decided by the model, not by this view, so the limit of three
    /// is one fact rather than a layout that happens to fit.
    private var actionSet: ContextualActionSet {
        model.contextualActions(for: target)
    }

    private func perform(_ kind: ContextualActionSet.Kind) {
        switch kind {
        case .explore:
            Task { await model.explore(target) }
        case .add:
            model.startComposer(anchor: target, intent: .add)
        case .setAside:
            model.requestSetAsideReason(for: target)
        case .reopen:
            model.reopen(target)
        case .edit:
            model.startEditing(anchor: target)
        case .addSource:
            chooseSource()
        case .assertClaim:
            model.startClaim(role: .hypothesis, anchor: target)
        case .duplicateOccurrence:
            // The occurrence the pointer is on, not the object: two drawings of one
            // idea are two different things to duplicate.
            if let instance = model.document.presentation.instance(for: target) {
                model.duplicateOccurrence(of: instance.id)
            }
        case .duplicateVariant:
            model.duplicateAsVariant(of: target)
        case .removeOccurrence:
            if let instance = model.document.presentation.instance(for: target) {
                model.removeOccurrence(instance.id)
            }
        case .removeObject:
            // The destructive one asks first, and the question says what is lost.
            model.requestRemoveFromDocument(target)
        case .reviewImpact:
            _ = model.reviewImpact(of: target)
        case .compareDirections:
            _ = model.startComparison()
        case .composeSynthesis:
            // A synthesis is a deliverable, so it opens as a draft the person has
            // to confirm. Composing is not handing over.
            _ = model.startSummary()
        case .buildExperiment:
            model.startExperiment(anchor: target)
        case .reviewExperiment:
            model.openExperiment(on: target)
        case .reviewHistory:
            model.openHistory(of: target)
        case .groupInFrame:
            // The frame is created around the selection and named immediately: a
            // frame is named by the person who makes it, not by the app.
            if let id = model.createFrame(named: "") {
                model.startRenaming(id)
            }
        case .link, .comment:
            // Not reachable: the set never offers them until they are implemented.
            // An action that exists and does nothing is worse than an absent one.
            break
        }
    }

    /// Asks for a file, reads it, and attaches what came out.
    ///
    /// The panel is a system one and cancellable, because "not now" is a real
    /// answer. Nothing is read until a file is actually chosen, and a file that
    /// cannot be read leaves the document untouched and says so.
    private func chooseSource() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = L10n.addSourceHint
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let read = model.attachSource(at: url, to: target) else { return }
        // The chip reports the state; the line only says the file was attached, so
        // a scan is never announced as a successful read.
        switch read.extraction {
        case .ready:
            model.status = L10n.sourceAttached(read.title)
        case .noText(let reason), .unsupported(let reason), .partial(_, let reason):
            model.status = L10n.sourceAttachedWithoutText(read.title, reason)
        case .notAttempted, .pending, .missing:
            model.status = L10n.sourceAttached(read.title)
        }
    }

    private var setAsideReason: String {
        model.setAsideReason(of: target) ?? ""
    }

/// The size the local action cluster rendered at.
///
/// A preference rather than an assumed width, because an assumed width is a
/// number nobody revisits and a French label is wider than an English one.
private struct ContextualSizeKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}
}

/// The inline composer that opens beside the object being worked on. There is no
/// chat panel: the answer becomes a relation, a question or a proposed branch.
struct ComposerView: View {
    let model: KollioModel
    let anchor: ObjectID

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    private var placeholder: String {
        switch model.composer?.intent {
        case .setAside: return L10n.composerSetAsidePlaceholder
        case .edit: return L10n.composerEditPlaceholder
        default: return L10n.composerAddPlaceholder
        }
    }

    var body: some View {
        if let frame = model.frame(of: anchor) {
            let screen = model.camera.toScreen(Position(x: frame.origin.x, y: frame.maxY + 16))
            VStack(alignment: .leading, spacing: Space.xs) {
                TextField(
                    placeholder,
                    text: Binding(
                        get: { model.composer?.text ?? "" },
                        set: { model.composer?.text = $0 }
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(TypeScale.body)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit { Task { await model.submitComposer() } }

                Text(model.composer?.intent == .setAside ? L10n.composerSetAsideHint : L10n.composerHint)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(Space.m)
            .frame(width: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.composer, style: .continuous)
                    .fill(theme.surfacePrimary)
                    .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.15), radius: 16, y: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.composer, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.5), lineWidth: 1)
            )
            .position(
                x: min(max(screen.x + 170, 180), max(model.viewport.width - 180, 180)),
                y: min(max(screen.y + 70, 90), max(model.viewport.height - 90, 90))
            )
            .onAppear { focused = true }
            .accessibilityLabel(placeholder)
        }
    }
}

/// The first experience: one invitation, one multiline field, one action.
///
/// This is the product's entry point, so it is the same canvas-first screen
/// with nothing added around it. `Enter` inserts a newline because a context is
/// a paragraph, not a query; `Cmd+Enter` submits, and the button does the same.
struct FirstExperienceView: View {
    let model: KollioModel

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool
    @State private var text: String = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(L10n.initialTitle)
                .font(TypeScale.invitation)
                .foregroundStyle(theme.textPrimary)

            Text(L10n.initialSubtitle)
                .font(TypeScale.body)
                .foregroundStyle(theme.textSecondary)

            // A stored document that could not be read is reported here rather
            // than hidden behind a fresh canvas, and its file is left untouched.
            if model.hasUnreadableDocument {
                Text(L10n.errorLoadFailed)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.error)
                    .frame(width: 520, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextEditor(text: $text)
                // Named so a UI test can find the field by what it is rather than
                // by where it happened to be. The identifier is the only thing in
                // this view that exists for a test, and it is one string.
                .accessibilityIdentifier(AXID.entryField)
                .font(TypeScale.primaryThought)
                .foregroundStyle(theme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(Space.s)
                .frame(width: 520, height: 132)
                .background(
                    RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                        .fill(theme.surfacePrimary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                        .strokeBorder(focused ? theme.accent.opacity(0.6) : theme.decorativeBorder, lineWidth: 1)
                )
                .focused($focused)
                .overlay(alignment: .bottomTrailing) {
                    Text(L10n.submitHint)
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .padding(Space.s)
                        .allowsHitTesting(false)
                }

            HStack(spacing: Space.s) {
                Text("⌘↩")
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                ActionButton(title: L10n.explore, isDefault: true) { submit() }
                    .accessibilityIdentifier(AXID.entrySubmit)
                    .disabled(isSubmitting)
            }
            // Cmd+Enter submits from anywhere in the field. `Enter` is left alone
            // on purpose: a context is a paragraph, and a newline belongs in it.
            .background(
                Button("") { submit() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .hidden()
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear { focused = true }
        .onExitCommand { focused = true }
        .accessibilityElement(children: .contain)
    }

    private func submit() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, isSubmitting == false else { return }
        isSubmitting = true
        // The sentence is handed to the model, which persists it before it asks
        // anything of the intelligence source. A failure there cannot cost the
        // user their words, so nothing is restored here.
        guard let context = model.start(with: value) else {
            isSubmitting = false
            return
        }
        text = ""
        Task {
            await model.exploreInitialContext(context)
            isSubmitting = false
        }
    }
}

/// The citations behind a claim, and the one place a check can be recorded.
///
/// It opens beside the claim and closes when the person moves on. There is no
/// citations panel anywhere else in the application, because a permanent home for
/// evidence would be a permanent home for reading instead of thinking.
///
/// What it shows is deliberately literal: the exact quote, the locator, the state,
/// and whether the revision it was read against is still the current one. A
/// citation whose source has moved on says so, rather than presenting a stale
/// check as a current one.
struct CitationListView: View {
    let model: KollioModel
    let claim: ObjectID

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    private var details: [CitationDetail] { model.citations(of: claim) }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.citationsTitle)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            if details.isEmpty {
                Text(L10n.citationsEmpty)
                    .font(TypeScale.body)
                    .foregroundStyle(theme.textSecondary)
            }

            ForEach(details) { detail in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.xs) {
                        Text(detail.sourceTitle)
                            .font(TypeScale.metadata.weight(.medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer(minLength: 0)
                        Text(stateLabel(for: detail))
                            .font(TypeScale.metadata)
                            .foregroundStyle(labelColour(for: detail))
                    }

                    // The quote as it was written, never reworded.
                    Text("“\(detail.citation.quote)”")
                        .font(TypeScale.body)
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let passage = detail.passage {
                        // The lines the locator points at, from the exact revision
                        // the citation was read against.
                        Text(passage)
                            .font(TypeScale.metadata)
                            .foregroundStyle(theme.textSecondary)
                            .padding(Space.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                                    .fill(theme.surfaceSubtle)
                            )
                    } else {
                        Text(L10n.citationNoPassage)
                            .font(TypeScale.metadata)
                            .foregroundStyle(theme.textSecondary)
                    }

                    if detail.isCurrentRevision == false {
                        Label(L10n.citationSuperseded, systemImage: "exclamationmark.triangle")
                            .font(TypeScale.metadata)
                            .foregroundStyle(theme.attention)
                    }

                    if detail.passage != nil {
                        HStack {
                            Spacer(minLength: 0)
                            ActionButton(title: L10n.citationSelectPrompt, isDefault: false) {
                                model.readingSourceID = detail.citation.sourceID
                            }
                        }
                    }

                    if model.verifyingCitationID == detail.id {
                        verificationComposer(for: detail)
                    } else {
                        HStack {
                            Spacer(minLength: 0)
                            ActionButton(title: L10n.citationVerify, isDefault: false) {
                                model.verifyingCitationID = detail.id
                                focused = true
                            }
                            .help(L10n.citationVerifyHint)
                        }
                    }
                }
                .padding(Space.s)
                .background(
                    RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        .fill(theme.surfaceSubtle)
                )
            }
        }
        .padding(Space.m)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 14, y: 6)
        )
    }

    /// A check needs an observation, so the input is the whole action. There is no
    /// button that marks something verified by itself.
    private func verificationComposer(for detail: CitationDetail) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            TextField(
                L10n.citationObservationPlaceholder,
                text: Binding(
                    get: { model.verificationDraft },
                    set: { model.verificationDraft = $0 }
                ),
                axis: .vertical
            )
            .font(TypeScale.body)
            .focused($focused)
            HStack {
                Spacer(minLength: 0)
                ActionButton(title: L10n.citationRecord, isDefault: true) {
                    // The draft is cleared by the model only once the command has
                    // been accepted, so a refused check keeps what was typed.
                    if model.recordVerification(detail.id, observation: model.verificationDraft) {
                        model.verificationDraft = ""
                    }
                }
            }
        }
    }

    private func stateLabel(for detail: CitationDetail) -> String {
        switch detail.citation.status {
        case .unverified: return L10n.citationUnverified
        case .verified: return L10n.citationVerified
        case .needsReview: return L10n.citationNeedsReview
        case .sourceMissing: return detail.state.accessibilityDescription
        }
    }

    private func labelColour(for detail: CitationDetail) -> Color {
        switch detail.citation.status {
        case .verified: return theme.textSecondary
        case .unverified, .needsReview, .sourceMissing: return theme.attention
        }
    }
}

/// Choosing the lines a claim rests on.
///
/// The text comes from the revision on record rather than from the file on disk,
/// so what is cited is what the document believes it read. The selection becomes
/// the quote verbatim: a person selects a passage, they do not retype it, because a
/// quote that differs from its source is not a quote.
struct PassagePickerView: View {
    let model: KollioModel
    let sourceID: SourceID
    let claim: ObjectID

    @Environment(\.kollioTheme) private var theme
    @State private var selection: Set<Int> = []

    private var lines: [String] { model.lines(of: sourceID) }

    /// The range to cite, as a contiguous run. A discontiguous selection would need
    /// a locator the type does not have, and inventing one would be worse than
    /// asking for a single passage.
    private var range: Range<Int>? {
        guard let first = selection.min(), let last = selection.max(), first <= last else { return nil }
        return first..<(last + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.citationSelectPrompt)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            if let table = model.table(for: sourceID) {
                tablePreview(table)
            } else if lines.isEmpty {
                // The source is on record but has no readable text. Saying so beats
                // offering an empty list to select from.
                Text(L10n.citationNoPassage)
                    .font(TypeScale.body)
                    .foregroundStyle(theme.textSecondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            lineRow(line, index: index)
                        }
                    }
                }
                .frame(height: 180)
            }

            HStack {
                Button {
                    model.openInReader(sourceID)
                } label: {
                    Label(L10n.sourceOpenInReader, systemImage: "doc.text.magnifyingglass")
                        .font(TypeScale.metadata)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .help(L10n.sourceOpenInReaderHint)

                Text(L10n.citationSelectHint)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 0)
                ActionButton(
                    title: L10n.citationCiteSelection,
                    isDefault: true
                ) {
                    guard let range else { return }
                    model.citePassage(of: sourceID, lines: range, to: claim)
                }
                .disabled(range == nil)
            }
        }
        .padding(Space.m)
        .frame(width: 380, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 14, y: 6)
        )
    }

    private func lineRow(_ line: String, index: Int) -> some View {
        Text(line.isEmpty ? " " : line)
            .font(TypeScale.metadata)
            .foregroundStyle(theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, 2)
            .background(selection.contains(index) ? theme.accentSurface : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { toggle(index) }
    }

    /// A table is shown as a table: headers, then rows, capped.
    ///
    /// A CSV read correctly and then displayed as raw commas is technically honest
    /// and practically useless, and the whole reason the parser handles quoted
    /// fields is that the columns are the point.
    private func tablePreview(_ table: CSVTable) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                    Text(header)
                        .font(TypeScale.metadata.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, 2)
                }
            }
            .background(theme.surfaceSubtle)
            ForEach(Array(table.rows.prefix(20).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(table.headers.indices), id: \.self) { column in
                        Text(row.indices.contains(column) ? row[column] : "")
                            .font(TypeScale.metadata)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Space.xs)
                            .padding(.vertical, 2)
                    }
                }
                .background(theme.surfaceSubtle.opacity(0.5))
            }
            if table.rows.count > 20 {
                // Capped, and it says so. A file with a hundred thousand rows does
                // not get to fill a card on the canvas.
                Text(L10n.citationTableCapped(table.rows.count))
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, Space.xs)
                    .padding(.vertical, 2)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private func toggle(_ index: Int) {
        // A plain click starts a passage; a second click elsewhere extends it. There
        // is no modifier to learn and no drag to miss.
        if selection.isEmpty || !selection.contains(index) {
            selection = [index]
        } else if let first = selection.min(), let last = selection.max() {
            let low = min(first, index)
            let high = max(last, index)
            selection = Set(low...high)
        }
    }
}


/// Stating a claim: what it is, and what it is about.
///
/// The scope is the current selection, not something typed, because the scope is
/// the part people get wrong. Making the narrow case the easy one and the sweeping
/// case the deliberate one is the whole design of this card.
struct ClaimComposerView: View {
    let model: KollioModel

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        if let draft = model.claimDraft {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(L10n.claimComposerPrompt)
                    .font(TypeScale.metadata.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: Space.xs) {
                    ForEach([Claim.Role.hypothesis, .constraint], id: \.rawValue) { role in
                        Button {
                            model.startClaim(role: role, anchor: draft.anchor)
                        } label: {
                            Text(label(for: role))
                                .font(TypeScale.metadata)
                                .padding(.horizontal, Space.s)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(
                                        draft.role == role ? theme.accentSurface : theme.surfaceSubtle
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(draft.role == role ? theme.accent : theme.textSecondary)
                    }
                }

                Text(L10n.claimScopeHint)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField(
                    L10n.claimCriterionPlaceholder,
                    text: Binding(
                        get: { model.claimDraft?.criterion ?? "" },
                        set: { model.claimDraft?.criterion = $0 }
                    )
                )
                .font(TypeScale.body)
                .focused($focused)

                HStack {
                    Spacer(minLength: 0)
                    ActionButton(title: L10n.claimStateIt, isDefault: true) {
                        model.submitClaim()
                    }
                }
            }
            .padding(Space.m)
            .frame(width: 320, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                    .fill(theme.surfacePrimary)
                    .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 14, y: 6)
            )
        }
    }

    private func label(for role: Claim.Role) -> String {
        switch role {
        case .hypothesis: return L10n.claimStateHypothesis
        case .constraint: return L10n.claimStateConstraint
        }
    }
}

/// Building a validation experiment: what is being asked, and what would count.
///
/// The two required fields are required here as they are in the command layer,
/// and for the same reason: an experiment with no criterion cannot lose. The
/// submit button does not grey out while the fields are empty — the refusal
/// says what is missing, which a greyed button never does.
struct ExperimentComposerView: View {
    let model: KollioModel

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        if let draft = model.experimentDraft {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(L10n.experimentComposerPrompt)
                    .font(TypeScale.metadata.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)

                TextField(
                    L10n.experimentQuestionPlaceholder,
                    text: Binding(
                        get: { model.experimentDraft?.question ?? "" },
                        set: { model.experimentDraft?.question = $0 }
                    )
                )
                .font(TypeScale.body)
                .focused($focused)

                TextField(
                    L10n.experimentCriterionPlaceholder,
                    text: Binding(
                        get: { model.experimentDraft?.criterion ?? "" },
                        set: { model.experimentDraft?.criterion = $0 }
                    )
                )
                .font(TypeScale.body)

                TextField(
                    L10n.experimentMethodPlaceholder,
                    text: Binding(
                        get: { model.experimentDraft?.method ?? "" },
                        set: { model.experimentDraft?.method = $0 }
                    )
                )
                .font(TypeScale.body)

                if draft.expectedEvidence.isEmpty == false {
                    Text(L10n.experimentEvidenceHint)
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Toggle(isOn: Binding(
                    get: { model.experimentDraft?.isSimulation ?? false },
                    set: { model.experimentDraft?.isSimulation = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.experimentIsSimulation)
                            .font(TypeScale.metadata)
                        Text(L10n.experimentSimulationHint)
                            .font(TypeScale.metadata)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)

                HStack {
                    Spacer(minLength: 0)
                    ActionButton(title: L10n.experimentBuild, isDefault: true) {
                        model.submitExperiment()
                    }
                }
            }
            .padding(Space.m)
            .frame(width: 340, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                    .fill(theme.surfacePrimary)
                    .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 14, y: 6)
            )
        }
    }
}

/// How a claim stands, and the only two actions that change it.
///
/// Every stance needs an observation, so the input is the action. There is no
/// control that marks a claim supported, refuted, satisfied or not applicable by
/// itself, and the list of stances offered depends on the role: a constraint cannot
/// be refuted and a hypothesis cannot be satisfied.
struct ClaimStanceView: View {
    let model: KollioModel
    let anchor: ObjectID

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    private var summary: ClaimSummary? { model.claimSummary(for: anchor) }

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.xs) {
                    Text(summary.role == .hypothesis
                         ? L10n.claimStateHypothesis
                         : L10n.claimStateConstraint)
                        .font(TypeScale.metadata.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    // "Supported" is not truth, and the label is the difference
                    // between a claim and a conclusion.
                    Text(stateLabel(summary))
                        .font(TypeScale.metadata)
                        .foregroundStyle(summary.isAsserted ? theme.textPrimary : theme.textSecondary)
                }
                Text(L10n.claimScopeCount(summary.scopeCount))
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                if let criterion = summary.criterion, criterion.isEmpty == false {
                    Text(criterion)
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if model.stanceDraft?.anchor == anchor {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        TextField(
                            L10n.claimObservationPlaceholder,
                            text: Binding(
                                get: { model.stanceDraft?.observation ?? "" },
                                set: { model.stanceDraft?.observation = $0 }
                            ),
                            axis: .vertical
                        )
                        .font(TypeScale.body)
                        .focused($focused)
                        HStack {
                            Spacer(minLength: 0)
                            ActionButton(title: L10n.claimRecordStance, isDefault: true) {
                                // No draft, no record. Writing this as a forced
                                // unwrap with a comment saying it was wrong would
                                // have been the same bug wearing a note.
                                guard let draft = model.stanceDraft else { return }
                                _ = model.recordStance(draft)
                            }
                        }
                    }
                } else {
                    HStack(spacing: Space.xs) {
                        ForEach(KollioModel.Stance.applicable(to: summary.role)) { stance in
                            if stance != .open {
                                ActionButton(title: shortLabel(stance), isDefault: false) {
                                    model.stanceDraft = .init(anchor: anchor, stance: stance)
                                    focused = true
                                }
                                .font(TypeScale.metadata)
                            }
                        }
                    }
                }
            }
            .padding(Space.s)
            .frame(width: 300, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                    .fill(theme.surfacePrimary)
                    .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 14, y: 6)
            )
        }
    }

    private func stateLabel(_ summary: ClaimSummary) -> String {
        if let hypothesis = summary.hypothesis {
            switch hypothesis {
            case .open: return L10n.claimStateOpen
            case .supported: return L10n.claimStateSupported
            case .contradicted: return L10n.claimStateContradicted
            case .refuted: return L10n.claimStateRefuted
            }
        }
        if let constraint = summary.constraint {
            switch constraint {
            case .open: return L10n.claimStateOpen
            case .satisfied: return L10n.claimStateSatisfied
            case .notApplicable: return L10n.claimStateNotApplicable
            }
        }
        return L10n.claimStateOpen
    }

    private func shortLabel(_ stance: KollioModel.Stance) -> String {
        switch stance {
        case .supported: return L10n.claimStateSupported
        case .contradicted: return L10n.claimStateContradicted
        case .refuted: return L10n.claimStateRefuted
        case .satisfied: return L10n.claimStateSatisfied
        case .notApplicable: return L10n.claimStateNotApplicable
        case .open: return L10n.claimStateOpen
        }
    }
}

/// A question intelligence asked, with an input attached to it.
///
/// AI-04 says "a local question and an attached input", and "no chat": there is no
/// transcript here, no scrollback, and no conversation. The question is a thing in
/// the document that can be answered, and "I don't know" is offered as a real
/// answer rather than leaving the field empty, because an empty answer reads as
/// something a person considered and had nothing to say about.
///
/// It appears beside the object the question is about and goes away when it is
/// answered. There is no panel anywhere else in the application.
struct ClarificationView: View {
    let model: KollioModel
    let clarification: Clarification

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .top, spacing: Space.xs) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text(clarification.question.resolve(languageCode: model.languageCode))
                    .font(TypeScale.body.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.openClarificationID == clarification.id, model.clarificationDraft != nil {
                TextField(
                    L10n.clarificationAnswerPlaceholder,
                    text: Binding(
                        get: { model.clarificationDraft?.text ?? "" },
                        set: { model.clarificationDraft?.text = $0 }
                    ),
                    axis: .vertical
                )
                .font(TypeScale.body)
                .focused($focused)
                .onSubmit { _ = model.resolveClarification() }

                HStack(spacing: Space.s) {
                    ActionButton(title: L10n.clarificationAnswer, isDefault: true) {
                        _ = model.resolveClarification()
                    }
                    // Offered on its own terms, not as a way of clearing the field.
                    ActionButton(title: L10n.clarificationUnknown, isDefault: false) {
                        _ = model.resolveClarification(asUnknown: true)
                    }
                    .help(L10n.clarificationUnknownHint)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Space.l)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.14), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(clarification.question.resolve(languageCode: model.languageCode))
        .onAppear { focused = true }
    }
}

/// What new information touched, and what it left alone.
///
/// CTX-05 asks for three things at once: what needs review, what stays valid, and
/// why. So the card has two lists and never hides the second one: an assessment
/// that only names the problems reads as "everything is now suspect", which is the
/// opposite of what a scoped dependency walk actually established.
///
/// The buttons are *mark* and *not now*. There is no "apply" that rewrites
/// anything, because the operation is not a rewrite: it records one precise mark
/// per object and leaves every object, every branch and every decision exactly
/// where it was. `Cmd+Z` puts the whole thing back in one step.
struct ImpactReviewView: View {
    let model: KollioModel
    let assessment: ImpactAssessment

    @Environment(\.kollioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.impactTitle)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            Text(assessment.trigger.reason)
                .font(TypeScale.body)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            section(title: L10n.impactNeedsReview, count: assessment.proposedChanges.count) {
                ForEach(assessment.proposedChanges) { change in
                    row(
                        text: model.text(of: change.objectID),
                        detail: reasonLabel(change.reason),
                        emphasised: true
                    )
                }
            }

            if assessment.unaffectedRefs.isEmpty == false {
                section(title: L10n.impactStaysValid, count: assessment.unaffectedRefs.count) {
                    ForEach(assessment.unaffectedRefs) { ref in
                        row(
                            text: model.text(of: ref.objectID),
                            detail: unaffectedLabel(ref.why),
                            emphasised: false
                        )
                    }
                }
            }

            // What was read, so the answer can be checked rather than believed. And
            // the bound, when the walk stopped early: a truncated answer that does
            // not say it was truncated is a lie of omission.
            Text(readSetLabel)
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Space.s) {
                ActionButton(title: L10n.impactNotNow, isDefault: false) {
                    model.dismissImpactReview()
                }
                ActionButton(title: L10n.impactMark, isDefault: true) {
                    _ = model.applyImpactReview()
                }
                .help(L10n.impactMarkHint)
            }
        }
        .padding(Space.l)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.14), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .strokeBorder(theme.attention.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func section<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("\(title) · \(count)")
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func row(text: String, detail: String, emphasised: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text.isEmpty ? "—" : text)
                .font(TypeScale.body.weight(emphasised ? .medium : .regular))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(TypeScale.metadata)
                .foregroundStyle(emphasised ? theme.attention : theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reasonLabel(_ reason: ImpactReason) -> String {
        switch reason {
        case .evidenceMoved: return L10n.impactReasonMoved
        case .evidenceLost: return L10n.impactReasonLost
        case .reliesOnImpactedObject: return L10n.impactReasonRelies
        }
    }

    private func unaffectedLabel(_ why: UnaffectedRef.Why) -> String {
        switch why {
        case .citationStillCurrent: return L10n.impactUnaffectedCurrent
        case .linkIsNotADependence: return L10n.impactUnaffectedLink
        case .setAside: return L10n.impactUnaffectedSetAside
        }
    }

    private var readSetLabel: String {
        let read = L10n.impactReadSet(
            assessment.readSet.citationIDs.count,
            assessment.readSet.visitedObjectIDs.count,
            assessment.readSet.relationshipIDs.count
        )
        guard assessment.wasTruncated else { return read }
        return "\(read) \(L10n.impactTruncated)"
    }
}

/// What a link says, and the three ways a person can change it.
///
/// CAN-06: selecting a link "exposes meaning and provenance", and editing "changes
/// the meaning explicitly, not just the arrow". So the card leads with the sentence
/// and the arrow is not the only thing on offer.
///
/// Reversing is a button and not a drag, deliberately. The two ends look the same
/// before and after and only the sentence inverts, so the change is named, spelled
/// out in the label, and never something a movement of the hand does by accident.
struct RelationshipCardView: View {
    let model: KollioModel
    let id: RelationshipID

    @Environment(\.kollioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if let relationship = model.document.relationship(id) {
                if let sentence = model.sentence(for: id) {
                    // The sentence, not the arrow: it says which end is the source
                    // and what is being claimed about it.
                    Text(sentence.text)
                        .font(TypeScale.body.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(sentence.text)
                } else {
                    // An end is missing, so there is nothing true to say. Saying the
                    // kind alone would read as a claim about something absent.
                    Text(L10n.relationshipIncomplete)
                        .font(TypeScale.body)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                provenanceLine(for: relationship)

                HStack(spacing: Space.s) {
                    Menu {
                        ForEach(Relationship.Kind.choosable(languageCode: model.languageCode), id: \.self) { kind in
                            Button {
                                model.editRelationship(id, .changeKind(kind))
                            } label: {
                                Text(kind.readsAs(languageCode: model.languageCode))
                            }
                        }
                    } label: {
                        ActionButton(title: L10n.relationshipChangeKind, isDefault: false) { }
                    }
                    .help(L10n.relationshipChangeKindHint)

                    ActionButton(title: L10n.relationshipReverse, isDefault: false) {
                        model.editRelationship(id, .reverse)
                    }
                    .help(L10n.relationshipReverseHint)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Space.l)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
                .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.14), radius: 18, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    /// Who said it, and that it was a person if it was.
    ///
    /// A link is a claim like any other, so where it came from belongs next to what
    /// it says. A generated link says so rather than passing for a person's.
    private func provenanceLine(for relationship: Relationship) -> some View {
        // The kind, not the actor's spelling: whether a link came from a person or a
        // model is a property the document records, and matching on a prefix of a
        // name would be a guess that stops being true the day a provider changes.
        let machine = relationship.provenance.kind != .human
        return HStack(spacing: Space.xs) {
            Image(systemName: machine ? "sparkles" : "person")
                .font(.system(size: 10))
                .foregroundStyle(theme.textSecondary.opacity(0.7))
            Text(machine ? L10n.relationshipFromModel : L10n.relationshipFromPerson)
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary.opacity(0.7))
        }
    }
}

public extension Relationship.Kind {
    /// How the kind is offered in a menu: the verb, in the interface's language.
    ///
    /// The same wording the sentence uses, so a person choosing "contraint" knows
    /// they will get "A contraint B" and not a different claim.
    func readsAs(languageCode: String) -> String {
        verb(languageCode: languageCode)
    }
}
