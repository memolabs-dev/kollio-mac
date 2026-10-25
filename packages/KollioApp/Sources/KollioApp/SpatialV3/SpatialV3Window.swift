import SwiftUI
import KollioCore

/// An isolated native preview of the shared Spatial Ink contract.
/// Does not alter existing .kollio documents, app state or persistence.
struct SpatialV3WindowView: View {
    private let stressMode: Bool
    private let model: KollioModel?
    @State private var depth = 1
    @State private var selectedID: String?
    @State private var focusHistory: [String] = []
    @State private var search = ""
    @State private var focusedGroup: Int? = nil
    @State private var newIdeaDraft = ""
    @State private var editingID: String?
    @State private var editDraft = ""
    @State private var editOriginalText = ""
    @State private var editLanguageCode = "fr"
    @State private var editVersion: Int?
    @State private var pausedDrafts = SpatialDraftMemory()
    @State private var showingDiscardConfirmation = false
    @FocusState private var editingFieldFocused: Bool
    @FocusState private var editActionFocused: Bool
    @FocusState private var closeActionFocused: Bool
    @FocusState private var navigatorFocused: Bool
    @AccessibilityFocusState private var editActionAXFocused: Bool
    @AccessibilityFocusState private var closeActionAXFocused: Bool
    @AccessibilityFocusState private var navigatorAXFocused: Bool
    @State private var actionFocusRequest = 0
    @State private var navigationReturnRequest = 0
    @State private var relationTargetID = ""
    @State private var focusRequest = 0
    @State private var editFeedback: String?


    /// Demo-only initial state for deterministic Web/Mac screenshot comparisons.
    /// The actual native app continues to open with the initial three-node state.
    init(initialDepth: Int = 1, initialSelectedID: String? = nil, stressMode: Bool = false,
         model: KollioModel? = nil, initialNewIdeaDraft: String = "") {
        self.stressMode = stressMode
        self.model = model
        let boundedDepth = model != nil ? 2 : (initialDepth == 2 ? 2 : 1)
        _depth = State(initialValue: boundedDepth)
        _selectedID = State(initialValue: initialSelectedID)
        _newIdeaDraft = State(initialValue: initialNewIdeaDraft)
    }

    private var copy: SpatialV3Copy { SpatialV3Copy(languageCode: model?.languageCode) }

    private var realScene: SpatialDocumentScene? {
        model.map { SpatialDocumentScene(projection: SpatialDocumentProjection(document: $0.document, languageCode: $0.languageCode)) }
    }
    private var allNodes: [SpatialV3Node] {
        if let realScene { return realScene.nodes }
        return stressMode ? SpatialV3StressFixture.nodes : SpatialV3Fixture.nodes
    }
    private var allEdges: [SpatialV3Edge] {
        if let realScene { return realScene.edges }
        return stressMode ? SpatialV3StressFixture.edges : SpatialV3Fixture.edges
    }
    /// Spatial IDs name drawings; Kollio commands always require semantic IDs.
    private func semanticID(_ visualID: String?) -> String? {
        guard let visualID else { return nil }
        return realScene?.objectID(for: visualID) ?? visualID
    }
    private struct RelationTargetChoice: Identifiable {
        let id: String  // Semantic object ID, never an occurrence ID.
        let label: String
    }
    private var relationTargets: [RelationTargetChoice] {
        // Compute the real scene only once, not once per menu item.
        let scene = realScene
        let candidates = scene?.nodes ?? (stressMode ? SpatialV3StressFixture.nodes : SpatialV3Fixture.nodes)
        let source = selectedID.flatMap { scene?.objectID(for: $0) } ?? selectedID
        var seen: Set<String> = []
        return candidates.compactMap { node in
            let identity = scene?.objectID(for: node.id) ?? node.id
            guard identity != source, seen.insert(identity).inserted else { return nil }
            return RelationTargetChoice(id: identity, label: node.label)
        }
    }
    private var groupCount: Int { (allNodes.count + 11) / 12 }
    private var focusedIDs: Set<String>? {
        guard let focusedGroup else { return nil }
        return Set(allNodes.dropFirst(focusedGroup * 12).prefix(12).map(\.id))
    }
    private var visibleNodes: [SpatialV3Node] {
        allNodes.filter { node in
            node.depth <= depth && (focusedIDs?.contains(node.id) ?? true)
        }
    }
    private var visibleEdges: [SpatialV3Edge] {
        allEdges.filter { edge in
            edge.depth <= depth && (focusedIDs.map { $0.contains(edge.source) && $0.contains(edge.target) } ?? true)
        }
    }
    private var matches: [SpatialV3Node] {
        guard !search.isEmpty else { return [] }
        return allNodes.filter { $0.label.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) }
    }
    private var focusedNeighbors: [SpatialV3Node] {
        guard let selectedID else { return [] }
        let scene = realScene
        let objectID = scene?.objectID(for: selectedID) ?? selectedID
        let appearances = Set(scene?.visualIDsByObjectID[objectID] ?? [selectedID])
        let ids = Set(allEdges.compactMap { edge -> String? in
            if appearances.contains(edge.source) { return edge.target }
            if appearances.contains(edge.target) { return edge.source }
            return nil
        })
        return allNodes.filter { ids.contains($0.id) && !appearances.contains($0.id) }
    }
    private func navigate(to node: SpatialV3Node) {
        depth = 2
        focusedGroup = nil
        selectedID = node.id
        // Navigation through search/history is an explicit request to see
        // another card. Clicking a card in place must never recenter the world.
        focusRequest += 1
        if focusHistory.last != node.id { focusHistory.append(node.id) }
        if focusHistory.count > 12 { focusHistory.removeFirst() }
    }
    private var spotlightIDs: Set<String>? {
        guard let selectedID else { return nil }
        let scene = realScene
        let objectID = scene?.objectID(for: selectedID) ?? selectedID
        var ids = Set(scene?.visualIDsByObjectID[objectID] ?? [selectedID])
        for edge in allEdges {
            if ids.contains(edge.source) { ids.insert(edge.target) }
            if ids.contains(edge.target) { ids.insert(edge.source) }
        }
        return ids
    }
    private var selected: SpatialV3Node? {
        visibleNodes.first { $0.id == selectedID }
    }

    private func addIdea() {
        guard let model else { return }
        let editor = SpatialDocumentEditor(model: model)
        if let created = editor.createIdea(newIdeaDraft, near: semanticID(selectedID)) {
            newIdeaDraft = ""
            depth = 2
            selectedID = created.rawValue
            focusedGroup = nil
            editFeedback = copy.text("spatial.feedback.ideaAdded")
        } else {
            editFeedback = copy.text("spatial.feedback.ideaRefused")
        }
    }

    private func pauseEditing() {
        guard let editingID,
              let semanticID = semanticID(editingID),
              let editVersion else { return }
        let remembered = pausedDrafts.keep(
            objectID: semanticID, languageCode: editLanguageCode, draft: editDraft,
            original: editOriginalText, version: editVersion
        )
        self.editingID = nil
        self.editVersion = nil
        editingFieldFocused = false
        if remembered { editFeedback = copy.text("spatial.draft.saved") }
        // This explicitly exits the editor: focus its owning Edit action after
        // the text field disappears. A background update never uses this route.
        Task { @MainActor in
            if selectedID != nil { focusInspectorAction() }
        }
    }

    private func beginEdit(_ id: String) {
        guard let model, let objectID = semanticID(id),
              let object = model.object(ObjectID(objectID)) else { return }
        if editingID != nil { pauseEditing() }
        let currentText = object.text.resolve(languageCode: model.languageCode)
        let recovered = pausedDrafts.draft(for: objectID, languageCode: model.languageCode)
        editingID = id
        editLanguageCode = model.languageCode
        editVersion = recovered?.version ?? object.objectVersion
        editOriginalText = recovered?.original ?? currentText
        editDraft = recovered?.text ?? currentText
        editFeedback = recovered == nil ? nil : copy.text("spatial.draft.recovered")
    }

    /// Counts authored edits and unsubmitted ideas which Save does not write.
    /// The active editor and its paused snapshot count as just one draft.
    private var pendingInputCount: Int {
        let editingKey = editingID.flatMap { semanticID($0) }.map {
            SpatialDraftMemory.Key(objectID: $0, languageCode: editLanguageCode)
        }
        return SpatialPendingInput.count(
            paused: pausedDrafts,
            activeKey: editingKey,
            activeIsEdited: editingKey != nil && editDraft != editOriginalText,
            hasNewIdea: !newIdeaDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private func discardActiveDraft() {
        guard let editingID, let objectID = semanticID(editingID) else { return }
        pausedDrafts.discard(objectID, languageCode: editLanguageCode)
        self.editingID = nil
        self.editVersion = nil
        self.editDraft = ""
        editingFieldFocused = false
        editFeedback = copy.text("spatial.draft.discarded")
    }

    private var editIsStale: Bool {
        guard let model, let editingID,
              let id = semanticID(editingID), let version = editVersion
        else { return false }
        return model.object(ObjectID(id))?.objectVersion != version
    }

    private func adoptLatestVersion() {
        guard let model, let editingID, let id = semanticID(editingID),
              let object = model.object(ObjectID(id)) else { return }
        // Explicit human reconciliation: keep the user's draft untouched,
        // but compare it to the latest current text when pausing again.
        editVersion = object.objectVersion
        editOriginalText = object.text.resolve(languageCode: model.languageCode)
        editFeedback = copy.text("spatial.draft.rebased")
    }

    private func closeSelectedFromInspector() {
        selectedID = nil
        navigationReturnRequest += 1
    }

    private func focusInspectorAction() {
        guard selected != nil else { return }
        switch SpatialActionFocusRoute.destination(editable: model != nil) {
        case .edit:
            editActionFocused = true
            editActionAXFocused = true
        case .close:
            closeActionFocused = true
            closeActionAXFocused = true
        }
    }

    private func showSelectedActions() {
        guard selected != nil else { return }
        actionFocusRequest += 1
    }

    private func closeOneLevel() {
        switch SpatialEscapeRoute.next(
            editing: editingID != nil, selected: selectedID != nil,
            grouped: focusedGroup != nil, canCollapse: depth > 1 && model == nil
        ) {
        case .pauseEditor: pauseEditing()
        case .clearSelection: closeSelectedFromInspector()
        case .clearGroup: focusedGroup = nil
        case .collapseBranches: depth = 1
        case .none: break
        }
    }

    private func finishEdit() {
        guard let model, let editingID, let editVersion,
              let objectID = semanticID(editingID) else { return }
        // Changing the document's UI language cannot reassign a previously
        // drafted French text to the English variant (or vice versa).
        guard editLanguageCode == model.languageCode else {
            editFeedback = copy.text("spatial.draft.languageChanged")
            return
        }
        let succeeded = SpatialDocumentEditor(model: model)
            .updateText(editDraft, of: objectID, expectedVersion: editVersion)
        if succeeded {
            pausedDrafts.discard(objectID, languageCode: editLanguageCode)
            self.editingID = nil
            self.editVersion = nil
            editingFieldFocused = false
            editFeedback = copy.text("spatial.feedback.editApplied")
        } else {
            editFeedback = copy.text("spatial.feedback.editRefused")
        }
    }

    private func addAssociation(from sourceID: String) {
        guard let model else { return }
        guard let objectID = semanticID(sourceID) else { return }
        let created = SpatialDocumentEditor(model: model)
            .associate(objectID, with: relationTargetID)
        editFeedback = created == nil
            ? copy.text("spatial.feedback.linkRefused")
            : copy.text("spatial.feedback.linkAdded")
        if created != nil { relationTargetID = "" }
    }

    private func moveSelectedOccurrence(_ instanceID: String, by delta: Position) {
        guard let model else { return }
        let applied = SpatialDocumentEditor(model: model)
            .moveOccurrence(instanceID, by: delta)
        editFeedback = copy.text(applied ? "spatial.drag.saved" : "spatial.drag.refused")
    }

    private func saveDocument() {
        guard let model else { return }
        let saved = SpatialDocumentEditor(model: model).save()
        editFeedback = SpatialSaveFeedback.message(
            saved: saved, pendingCount: pendingInputCount, copy: copy
        )
    }

    @ViewBuilder
    private var selectionPanel: some View {
        if let selected {
            selectedInspector(for: selected)
            editPanel(for: selected)
        } else {
            Text(model == nil
                 ? copy.text("spatial.fixtureSelectionHint")
                 : copy.text("spatial.drag.hint"))
                .font(.caption)
                .foregroundStyle(KollioV3Tokens.Light.muted)
        }
    }

    private func selectedInspector(for selected: SpatialV3Node) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(copy.kind(selected.eyebrow)) · \(copy.status(selected.status))")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(KollioV3Tokens.Light.muted)
                Text(selected.label)
                    .font(.headline)
                if let id = semanticID(selected.id),
                   let count = realScene?.occurrenceCount(for: id), count > 1 {
                    Text(copy.format("spatial.occurrences", count))
                        .font(.caption)
                        .foregroundStyle(KollioV3Tokens.Light.muted)
                        .accessibilityIdentifier("spatial-v3-occurrence-count")
                }
                Text(selected.detail)
                    .font(.subheadline)
                    .foregroundStyle(KollioV3Tokens.Light.muted)
            }
            Spacer()
            if model != nil {
                VStack(alignment: .trailing, spacing: 9) {
                    Button(copy.text(
                        semanticID(selected.id).flatMap {
                            pausedDrafts.draft(for: $0, languageCode: model?.languageCode ?? "fr")
                        } == nil
                            ? "spatial.edit" : "spatial.draft.resume"
                    )) { beginEdit(selected.id) }
                        .focused($editActionFocused)
                        .accessibilityFocused($editActionAXFocused)
                        .accessibilityIdentifier("spatial-v3-edit")
                    Button(copy.text("spatial.camera.centerSelected")) {
                        focusRequest += 1
                    }
                    .accessibilityIdentifier("spatial-v3-center-selected")
                    if let instanceID = realScene?.instanceIDByVisualID[selected.id] {
                        HStack(spacing: 5) {
                            ForEach(SpatialNudgeDirection.allCases) { direction in
                                Button {
                                    moveSelectedOccurrence(instanceID, by: direction.delta)
                                } label: {
                                    Image(systemName: direction.symbol)
                                }
                                .accessibilityLabel(copy.text(direction.localizationKey))
                                .help(copy.text(direction.localizationKey))
                                .accessibilityIdentifier("spatial-v3-move-\(direction.rawValue)")
                            }
                        }
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(copy.text("spatial.move.controls"))
                    }
                    if !relationTargets.isEmpty {
                        Picker(copy.text("spatial.associate"), selection: $relationTargetID) {
                            Text(copy.text("spatial.chooseObject")).tag("")
                            ForEach(relationTargets) { target in
                                Text(target.label).tag(target.id)
                            }
                        }
                        .frame(maxWidth: 245)
                        .accessibilityIdentifier("spatial-v3-relation-target")
                        Button(copy.text("spatial.createLink")) { addAssociation(from: selected.id) }
                            .disabled(relationTargetID.isEmpty || relationTargetID == semanticID(selected.id))
                            .accessibilityIdentifier("spatial-v3-link")
                    }
                }
                .buttonStyle(.bordered)
            }
            Button(copy.text("spatial.close")) { closeSelectedFromInspector() }
                .focused($closeActionFocused)
                .accessibilityFocused($closeActionAXFocused)
                .accessibilityIdentifier("spatial-v3-close-selection")
                .buttonStyle(.bordered)
        }
        .padding(14)
        .background(KollioV3Tokens.Light.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KollioV3Tokens.Light.border))
    }

    @ViewBuilder
    private func editPanel(for selected: SpatialV3Node) -> some View {
        if model != nil && editingID == selected.id {
            HStack(spacing: 8) {
                if editIsStale, let model, let id = semanticID(editingID),
                   let current = model.object(ObjectID(id)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(copy.text("spatial.draft.conflict"))
                            .font(.caption).foregroundStyle(KollioV3Tokens.Light.ink)
                        Text(copy.text("spatial.draft.current"))
                            .font(.caption2).foregroundStyle(KollioV3Tokens.Light.muted)
                        Text(current.text.resolve(languageCode: model.languageCode))
                            .textSelection(.enabled)
                        Text(copy.text("spatial.draft.mine"))
                            .font(.caption2).foregroundStyle(KollioV3Tokens.Light.muted)
                        Button(copy.text("spatial.draft.rebase")) { adoptLatestVersion() }
                            .accessibilityIdentifier("spatial-v3-rebase-draft")
                    }
                    .accessibilityIdentifier("spatial-v3-stale-edit")
                }
                TextField(copy.text("spatial.editInput"), text: $editDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($editingFieldFocused)
                    .onAppear { editingFieldFocused = true }
                    .onKeyPress(.escape) {
                        // Handle here so this same key cannot also dismiss
                        // the selected card through the ancestor Exit command.
                        pauseEditing()
                        return .handled
                    }
                    .onKeyPress(keys: [.return], phases: .down) { event in
                        guard event.modifiers.contains(.command) else { return .ignored }
                        finishEdit()
                        return .handled
                    }
                    .accessibilityIdentifier("spatial-v3-edit-input")
                Button(copy.text("spatial.confirm")) { finishEdit() }
                    .disabled(editDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("spatial-v3-edit-confirm")
                Button(copy.text("spatial.draft.pause")) { pauseEditing() }
                    .accessibilityIdentifier("spatial-v3-edit-cancel")
                Button(copy.text("spatial.draft.discard")) {
                    showingDiscardConfirmation = true
                }
                .accessibilityIdentifier("spatial-v3-edit-discard")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var pendingInputNotice: some View {
        if pendingInputCount > 0 {
            Text(copy.format("spatial.pending.notice", pendingInputCount))
                .font(.caption)
                .foregroundStyle(KollioV3Tokens.Light.ink)
                .accessibilityIdentifier("spatial-v3-unsaved-inputs")
                .padding(.vertical, 6)
        }
    }

    var body: some View {
        // The canvas plus its selected-card actions may exceed the window height.
        // Scroll the content instead of vertically centering and clipping the
        // header and inspector off-screen on smaller macOS windows.
        ScrollViewReader { scroll in
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("◇  Kollio")
                    .font(.system(size: 17, weight: .bold))
                Text("Spatial Ink V3")
                    .font(.caption)
                    .foregroundStyle(KollioV3Tokens.Light.muted)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(KollioV3Tokens.Light.accentSoft, in: RoundedRectangle(cornerRadius: 7))
                Spacer()
                Text(model == nil ? copy.text("spatial.mode.fixture") : copy.text("spatial.mode.document"))
                    .font(.caption)
                    .foregroundStyle(KollioV3Tokens.Light.muted)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 17)
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(copy.text("spatial.section.exploration"))
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(KollioV3Tokens.Light.muted)
                        Text(model == nil ? (stressMode ? SpatialV3StressFixture.title : SpatialV3Fixture.title) : copy.text("spatial.document.active"))
                            .font(.system(size: 32, weight: .semibold, design: .default))
                            .tracking(-1.1)
                        Text(model == nil ? (stressMode ? SpatialV3StressFixture.subtitle : SpatialV3Fixture.subtitle) : copy.format("spatial.document.counts", realScene?.semanticObjectCount ?? 0, allNodes.count, allEdges.count, realScene?.revision ?? 0))
                            .font(.system(size: 14))
                            .foregroundStyle(KollioV3Tokens.Light.muted)
                    }
                    Spacer()
                    if model == nil {
                        Button(depth == 1 ? copy.text("spatial.expand") : copy.text("spatial.collapse")) {
                            depth = depth == 1 ? 2 : 1
                            if let selectedID, !visibleNodes.contains(where: { $0.id == selectedID }) {
                                self.selectedID = nil
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(KollioV3Tokens.Light.accent)
                        .accessibilityIdentifier("spatial-v3-expand")
                    }
                }
                if model != nil {
                    HStack(spacing: 10) {
                        TextField(copy.text("spatial.createPlaceholder"), text: $newIdeaDraft)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("spatial-v3-create-input")
                        Button(copy.text("spatial.create")) { addIdea() }
                            .disabled(newIdeaDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("spatial-v3-create")
                        Button(copy.text("spatial.save")) { saveDocument() }
                            .accessibilityIdentifier("spatial-v3-save")
                        if let model {
                            Button(copy.text("spatial.undo")) { SpatialDocumentEditor(model: model).undo() }
                                .disabled(!model.canUndo)
                                .accessibilityIdentifier("spatial-v3-undo")
                            Button(copy.text("spatial.redo")) { SpatialDocumentEditor(model: model).redo() }
                                .disabled(!model.canRedo)
                                .accessibilityIdentifier("spatial-v3-redo")
                        }
                    }
                    .buttonStyle(.bordered)
                    pendingInputNotice
                    if let editFeedback {
                        Text(editFeedback)
                            .font(.caption)
                            .foregroundStyle(KollioV3Tokens.Light.muted)
                            .accessibilityIdentifier("spatial-v3-edit-status")
                    }
                }
                if stressMode || model != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            TextField(copy.text("spatial.search"), text: $search)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 330)
                            // Native menu is a full non-pointer route through the
                            // actual visible graph, even when no search is typed.
                            // Selection is explicit: opening it never mutates a document.
                            Menu(copy.format("spatial.navigation.count", visibleNodes.count)) {
                                ForEach(SpatialV3ReadingOrder.ordered(visibleNodes, edges: visibleEdges)) { node in
                                    Button("\(copy.kind(node.eyebrow)) · \(node.label)") {
                                        navigate(to: node)
                                    }
                                    .accessibilityIdentifier("spatial-v3-navigate-\(node.id)")
                                }
                            }
                            .disabled(visibleNodes.isEmpty)
                            .accessibilityLabel(copy.text("spatial.navigation.label"))
                            .accessibilityHint(copy.text("spatial.navigation.hint"))
                            .accessibilityIdentifier("spatial-v3-navigator")
                            .id("spatial-v3-navigation")
                            .focused($navigatorFocused)
                            .accessibilityFocused($navigatorAXFocused)
                        }
                        // Keep this contextual action on its own row: at 680pt
                        // the search field + menu + button would clip horizontally.
                        if selected != nil {
                            Button(copy.text("spatial.navigation.actions")) {
                                showSelectedActions()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint(copy.text("spatial.navigation.actionsHint"))
                            .accessibilityIdentifier("spatial-v3-show-actions")
                        }
                        if !search.isEmpty {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(Array(matches.prefix(8))) { item in
                                        Button(item.label) {
                                            navigate(to: item)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    if matches.isEmpty { Text(copy.text("spatial.noResults")).font(.caption) }
                                }
                            }
                        }
                        if stressMode || allNodes.count > 20 {
                            ScrollView(.horizontal) {
                                HStack {
                                    Button(copy.text("spatial.overview")) { focusedGroup = nil }
                                    ForEach(0..<groupCount, id: \.self) { index in
                                        Button(copy.format("spatial.group", index + 1)) {
                                            focusedGroup = index
                                            depth = 2
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                if !focusHistory.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            Button(copy.text("spatial.overview")) { selectedID = nil; focusHistory = []; focusedGroup = nil }
                            ForEach(Array(focusHistory.enumerated()), id: \.offset) { index, id in
                                Button(allNodes.first(where: { $0.id == id })?.label ?? id) {
                                    focusHistory = Array(focusHistory.prefix(index + 1))
                                    if let node = allNodes.first(where: { $0.id == id }) { navigate(to: node) }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .accessibilityLabel(copy.text("spatial.explorationHistory"))
                }
                if !focusedNeighbors.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(focusedNeighbors.prefix(12))) { node in
                                Button(node.label + " ↗") { navigate(to: node) }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .accessibilityLabel(copy.text("spatial.objectRelations"))
                }
                if let spotlightIDs {
                    HStack {
                        Text(copy.format("spatial.focus", spotlightIDs.count))
                            .font(.caption)
                        Spacer()
                        Button(copy.text("spatial.returnToContext")) {
                            selectedID = nil
                            focusHistory = []
                            focusedGroup = nil
                            depth = 2
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(KollioV3Tokens.Light.accentSoft, in: RoundedRectangle(cornerRadius: 10))
                }
                if model != nil && allNodes.isEmpty {
                    Text(copy.text("spatial.emptyDocument"))
                        .font(.callout)
                        .foregroundStyle(KollioV3Tokens.Light.muted)
                        .accessibilityIdentifier("spatial-v3-empty-document")
                }
                ScrollView(.horizontal) {
                    SpatialV3Stage(
                        nodes: visibleNodes,
                        allNodes: focusedGroup == nil ? allNodes : visibleNodes,
                        edges: visibleEdges,
                        selectedID: $selectedID,
                        spotlightIDs: spotlightIDs,
                        copy: copy,
                        focusRequest: focusRequest,
                        instanceIDByVisualID: realScene?.instanceIDByVisualID ?? [:],
                        onMoveOccurrence: { instanceID, delta in
                            moveSelectedOccurrence(instanceID, by: delta)
                        },
                        onShowSelectedActions: showSelectedActions
                    )
                    .frame(minWidth: 900, minHeight: 580)
                }
                .background(KollioV3Tokens.Light.paper)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(KollioV3Tokens.Light.border))
                .accessibilityIdentifier("spatial-v3-canvas")
                .id("spatial-v3-canvas")
                .onChange(of: selectedID) { _, id in
                    if editingID != id && editingID != nil { pauseEditing() }
                    relationTargetID = ""
                    if let id, focusHistory.last != id {
                        focusHistory.append(id)
                        if focusHistory.count > 12 { focusHistory.removeFirst() }
                    }
                }
                selectionPanel
                .frame(minHeight: 65, alignment: .topLeading)
                .id("spatial-v3-actions")
                Text(model == nil
                     ? copy.text("spatial.fixtureSafety")
                     : copy.text("spatial.documentEditingHint"))
                    .font(.caption2)
                    .foregroundStyle(KollioV3Tokens.Light.muted)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityIdentifier("spatial-v3-document-scroll")
        .onChange(of: focusRequest) { _, _ in
            // Only explicit navigation requests move the document scroll.
            // Click/selection updates never jump the reader while typing.
            scroll.scrollTo("spatial-v3-canvas", anchor: .center)
        }
        .onChange(of: actionFocusRequest) { _, _ in
            scroll.scrollTo("spatial-v3-actions", anchor: .center)
            Task { @MainActor in focusInspectorAction() }
        }
        .onChange(of: navigationReturnRequest) { _, _ in
            scroll.scrollTo("spatial-v3-navigation", anchor: .top)
            Task { @MainActor in
                navigatorFocused = true
                navigatorAXFocused = true
            }
        }
        }
        .background(KollioV3Tokens.Light.paper)
        .background {
            if model != nil {
                SpatialNativeCloseGuard(pendingCount: pendingInputCount, copy: copy)
                    .frame(width: 0, height: 0)
            }
        }
        .foregroundStyle(KollioV3Tokens.Light.ink)
        .preferredColorScheme(.light)
        .onExitCommand { closeOneLevel() }
        .confirmationDialog(
            copy.text("spatial.draft.discardPrompt"),
            isPresented: $showingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(copy.text("spatial.draft.discard"), role: .destructive) {
                discardActiveDraft()
            }
            Button(copy.text("spatial.cancel"), role: .cancel) {}
        } message: {
            Text(copy.text("spatial.draft.discardDetails"))
        }
    }
}

struct SpatialV3Stage: View {
    let nodes: [SpatialV3Node]
    let allNodes: [SpatialV3Node]
    let edges: [SpatialV3Edge]
    @Binding var selectedID: String?
    let spotlightIDs: Set<String>?
    let copy: SpatialV3Copy
    let focusRequest: Int
    /// Only real authored instances can move; fixture and derived cards cannot.
    let instanceIDByVisualID: [String: String]
    let onMoveOccurrence: (String, Position) -> Void
    let onShowSelectedActions: () -> Void

    // @GestureState clears itself on cancellation, view removal and completed
    // gestures. No document mutation can occur until onEnded fires.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var keyboardFocusedID: String?
    @AccessibilityFocusState private var voiceOverFocusedID: String?
    @GestureState private var activeDrag: SpatialActiveDrag?
    @GestureState private var panPreview = CGSize.zero
    @GestureState private var pinchPreview: SpatialPinchPreview?
    @State private var camera = SpatialV3Camera()
    @State private var cameraEdited = false

    private func bounds(for nodes: [SpatialV3Node]) -> CGRect {
        guard !nodes.isEmpty else {
            return CGRect(origin: .zero, size: SpatialV3Camera.world)
        }
        var left = CGFloat.infinity
        var top = CGFloat.infinity
        var right = -CGFloat.infinity
        var bottom = -CGFloat.infinity
        for node in nodes {
            let w: CGFloat = node.kind == "mission" ? 247 : node.kind == "question" ? 170 : 210
            let h: CGFloat = node.kind == "mission" ? 115 : node.kind == "question" ? 60 : 96
            let x = node.x * SpatialV3Camera.world.width
            let y = node.y * SpatialV3Camera.world.height
            left = min(left, x - w / 2)
            top = min(top, y - h / 2)
            right = max(right, x + w / 2)
            bottom = max(bottom, y + h / 2)
        }
        return CGRect(x: left - 30, y: top - 30,
                      width: right - left + 60, height: bottom - top + 60)
    }
    private var contentBounds: CGRect { bounds(for: nodes) }
    private var fullBounds: CGRect { bounds(for: allNodes) }
    private var contentOrigin: CGPoint {
        CGPoint(x: min(0, fullBounds.minX), y: min(0, fullBounds.minY))
    }
    private var canvasSize: CGSize {
        CGSize(width: max(SpatialV3Camera.world.width, fullBounds.maxX - contentOrigin.x),
               height: max(SpatialV3Camera.world.height, fullBounds.maxY - contentOrigin.y))
    }

    private var movingWorldDelta: CGSize {
        guard let activeDrag,
              let delta = SpatialOccurrenceDrag.worldDelta(
                screenTranslation: activeDrag.screenTranslation, zoom: camera.zoom
              ) else { return .zero }
        return CGSize(width: delta.x, height: delta.y)
    }

    @ViewBuilder
    private func drawing(_ node: SpatialV3Node) -> some View {
        let isMoving = activeDrag?.visualID == node.id
        SpatialV3MeaningNode(node: node, selected: selectedID == node.id, copy: copy) {
            selectedID = selectedID == node.id ? nil : node.id
        }
        .opacity(spotlightIDs == nil || spotlightIDs?.contains(node.id) == true ? 1 : 0.17)
        .position(x: SpatialV3Camera.world.width * node.x - contentOrigin.x,
                  y: SpatialV3Camera.world.height * node.y - contentOrigin.y)
        .offset(x: isMoving ? movingWorldDelta.width : 0,
                y: isMoving ? movingWorldDelta.height : 0)
        .zIndex(isMoving ? 10 : 0)
    }

    private func moveGesture(for visualID: String, instanceID: String) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("spatial-v3-screen"))
            .updating($activeDrag) { value, state, _ in
                // The preview is ephemeral. If the pointer gesture gets
                // cancelled, SwiftUI resets the state to nil automatically.
                state = SpatialActiveDrag(visualID: visualID,
                                          screenTranslation: value.translation)
            }
            .onEnded { value in
                guard let delta = SpatialOccurrenceDrag.worldDelta(
                    screenTranslation: value.translation, zoom: camera.zoom
                ), abs(delta.x) > 0.5 || abs(delta.y) > 0.5
                else { return }
                onMoveOccurrence(instanceID, delta)
            }
    }

    private func fit(_ size: CGSize) {
        camera = SpatialV3Camera.fitted(in: size, bounds: contentBounds.offsetBy(dx: -contentOrigin.x, dy: -contentOrigin.y))
        cameraEdited = false
    }
    private func zoom(_ factor: CGFloat, in size: CGSize) {
        camera = camera.zoomed(by: factor, around: CGPoint(x: size.width / 2, y: size.height / 2))
        cameraEdited = true
    }
    private func centerSelected(in size: CGSize) {
        guard let selectedID, let target = allNodes.first(where: { $0.id == selectedID }) else { return }
        let worldPosition = CGPoint(x: target.x * SpatialV3Camera.world.width - contentOrigin.x,
                                    y: target.y * SpatialV3Camera.world.height - contentOrigin.y)
        camera = camera.centered(on: worldPosition, in: size)
        cameraEdited = true
    }

    var body: some View {
        GeometryReader { geometry in
            let renderedCamera = SpatialPinchTransaction.camera(
                from: camera,
                magnification: pinchPreview?.magnification ?? 1,
                viewport: geometry.size,
                anchor: pinchPreview?.anchor,
                allowed: activeDrag == nil && panPreview == .zero
            )
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .updating($panPreview) { value, state, _ in
                                    // No persisted gesture delta. An interrupted background pan
                                    // snaps back cleanly, rather than leaking into the next pan.
                                    state = value.translation
                                }
                                .onEnded { value in
                                    camera = camera.panned(dx: value.translation.width,
                                                           dy: value.translation.height)
                                    cameraEdited = true
                                }
                        )
                    Canvas { context, size in
                        let step: CGFloat = 26
                        for x in stride(from: CGFloat(12), through: size.width, by: step) {
                            for y in stride(from: CGFloat(12), through: size.height, by: step) {
                                context.fill(
                                    Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                    with: .color(KollioV3Tokens.Light.border)
                                )
                            }
                        }
                    }
                    .allowsHitTesting(false)
                    ForEach(edges) { edge in
                        SpatialV3Branch(
                            edge: edge, origin: contentOrigin,
                            movingVisualID: activeDrag?.visualID, movingWorldDelta: movingWorldDelta
                        )
                        .opacity(spotlightIDs == nil || spotlightIDs?.contains(edge.source) == true
                            || spotlightIDs?.contains(edge.target) == true ? 1 : 0.09)
                    }
                    ForEach(nodes) { node in
                        if let instanceID = instanceIDByVisualID[node.id] {
                            drawing(node)
                                .focused($keyboardFocusedID, equals: node.id)
                                .accessibilityFocused($voiceOverFocusedID, equals: node.id)
                                .highPriorityGesture(moveGesture(for: node.id, instanceID: instanceID))
                                .accessibilityAction(named: Text(copy.text("spatial.move.up"))) {
                                    onMoveOccurrence(instanceID, SpatialNudgeDirection.up.delta)
                                }
                                .accessibilityAction(named: Text(copy.text("spatial.move.down"))) {
                                    onMoveOccurrence(instanceID, SpatialNudgeDirection.down.delta)
                                }
                                .accessibilityAction(named: Text(copy.text("spatial.move.left"))) {
                                    onMoveOccurrence(instanceID, SpatialNudgeDirection.left.delta)
                                }
                                .accessibilityAction(named: Text(copy.text("spatial.move.right"))) {
                                    onMoveOccurrence(instanceID, SpatialNudgeDirection.right.delta)
                                }
                        } else {
                            drawing(node)
                                .focused($keyboardFocusedID, equals: node.id)
                                .accessibilityFocused($voiceOverFocusedID, equals: node.id)
                        }
                    }
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .scaleEffect(renderedCamera.zoom, anchor: .topLeading)
                .offset(x: renderedCamera.x + panPreview.width,
                        y: renderedCamera.y + panPreview.height)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .clipped()
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($pinchPreview) { value, state, _ in
                            // The viewport is only previewed until release.
                            // Interrupted gestures reset this state without a
                            // stale magnification leaking into the next pinch.
                            guard activeDrag == nil && panPreview == .zero else {
                                state = nil
                                return
                            }
                            state = SpatialPinchPreview(
                                magnification: value.magnification,
                                unitAnchor: CGPoint(x: value.startAnchor.x,
                                                    y: value.startAnchor.y),
                                viewport: geometry.size
                            )
                        }
                        .onEnded { value in
                            guard activeDrag == nil && panPreview == .zero else { return }
                            let finished = SpatialPinchPreview(
                                magnification: value.magnification,
                                unitAnchor: CGPoint(x: value.startAnchor.x,
                                                    y: value.startAnchor.y),
                                viewport: geometry.size
                            )
                            let next = SpatialPinchTransaction.camera(
                                from: camera, magnification: finished.magnification,
                                viewport: geometry.size, anchor: finished.anchor,
                                allowed: true
                            )
                            if next != camera {
                                camera = next
                                cameraEdited = true
                            }
                        }
                )

                HStack(spacing: 5) {
                    Button("−") { zoom(1 / 1.2, in: geometry.size) }
                        .accessibilityLabel(copy.text("spatial.camera.zoomOut"))
                    Text("\(Int((renderedCamera.zoom * 100).rounded())) %")
                        .monospacedDigit()
                        .font(.caption2)
                        .frame(minWidth: 40)
                    Button("+") { zoom(1.2, in: geometry.size) }
                        .accessibilityLabel(copy.text("spatial.camera.zoomIn"))
                    Button(copy.text("spatial.camera.fit")) { fit(geometry.size) }
                        .accessibilityIdentifier("spatial-v3-fit")
                }
                .buttonStyle(.bordered)
                .padding(8)
                .background(KollioV3Tokens.Light.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(KollioV3Tokens.Light.border))
                .padding(18)
                .accessibilityIdentifier("spatial-v3-camera")

                if selectedID != nil && nodes.contains(where: { $0.id == selectedID }) {
                    VStack {
                        HStack {
                            Button(copy.text("spatial.navigation.actions")) {
                                onShowSelectedActions()
                            }
                            .buttonStyle(.bordered)
                            .accessibilityHint(copy.text("spatial.navigation.actionsHint"))
                            .accessibilityIdentifier("spatial-v3-canvas-actions")
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 44)
                }

                VStack {
                    HStack {
                        Text(copy.text("spatial.stage.exploration"))
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(KollioV3Tokens.Light.muted)
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text(copy.format("spatial.stage.legend", nodes.count))
                            .font(.caption2)
                            .foregroundStyle(KollioV3Tokens.Light.muted)
                            .padding(10)
                            .background(KollioV3Tokens.Light.surface, in: RoundedRectangle(cornerRadius: 9))
                        Spacer()
                    }
                }
                .padding(20)
                .allowsHitTesting(false)
            }
            .coordinateSpace(name: "spatial-v3-screen")
            .background {
                // A local AppKit monitor owns only precise two-finger scrolls
                // inside this viewport. The outer document ScrollView and its
                // text inputs retain native scrolling outside the canvas.
                SpatialTrackpadScrollCapture(
                    canPan: activeDrag == nil && panPreview == .zero && pinchPreview == nil
                ) { delta in
                    camera = camera.panned(dx: delta.width, dy: delta.height)
                    cameraEdited = true
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .onAppear { fit(geometry.size) }
            .onChange(of: focusRequest) { _, _ in
                // A menu choice follows the object and moves keyboard/VoiceOver
                // focus with it. Merely clicking a card does not steal focus.
                if let selectedID, nodes.contains(where: { $0.id == selectedID }) {
                    keyboardFocusedID = selectedID
                    voiceOverFocusedID = selectedID
                }
                // Camera follows only an explicit navigation or Center command.
                if reduceMotion {
                    centerSelected(in: geometry.size)
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        centerSelected(in: geometry.size)
                    }
                }
            }
            .onChange(of: nodes.count) { _, _ in
                if !cameraEdited { fit(geometry.size) }
            }
            .onChange(of: geometry.size) { _, next in
                if !cameraEdited { fit(next) }
            }
        }
    }
}

private struct SpatialV3Branch: View {
    let edge: SpatialV3Edge
    let origin: CGPoint
    let movingVisualID: String?
    let movingWorldDelta: CGSize

    var body: some View {
        Path { path in
            var points = edge.points
            guard !points.isEmpty else { return }
            // Keep both endpoints attached to the moving card in the live
            // preview. Reroute fully from the committed document on release.
            if edge.source == movingVisualID {
                points[0].x += movingWorldDelta.width
                points[0].y += movingWorldDelta.height
            }
            if edge.target == movingVisualID {
                let last = points.count - 1
                points[last].x += movingWorldDelta.width
                points[last].y += movingWorldDelta.height
            }
            path.move(to: CGPoint(x: points[0].x - origin.x, y: points[0].y - origin.y))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x - origin.x, y: point.y - origin.y))
            }
        }
        .stroke(
            edge.type == "proposes" ? KollioV3Tokens.Light.accent
            : edge.type == "evidence" ? KollioV3Tokens.Light.verified
            : edge.type == "questions" ? KollioV3Tokens.Light.question
            : KollioV3Tokens.Light.muted.opacity(0.55),
            style: StrokeStyle(lineWidth: 1.8, dash: (edge.type == "proposes" || edge.type == "questions") ? [5, 7] : [])
        )
        .accessibilityHidden(true)
    }
}


/// A pause is local to the window, not a document transaction. Each
/// semantic object has one recoverable authored-language draft, regardless of
/// how many cards show it. A failed optimistic edit keeps the original version.
struct SpatialStoredDraft: Equatable {
    let text: String
    let original: String
    let version: Int
}

struct SpatialDraftMemory {
    struct Key: Hashable {
        let objectID: String
        let languageCode: String
    }

    private(set) var drafts: [Key: SpatialStoredDraft] = [:]

    @discardableResult
    mutating func keep(objectID: String, languageCode: String,
                       draft: String, original: String, version: Int) -> Bool {
        let key = Key(objectID: objectID, languageCode: languageCode)
        guard draft != original else {
            // Explicitly restoring the original text discards the pending
            // edit. No invisible stale draft should come back later.
            drafts.removeValue(forKey: key)
            return false
        }
        drafts[key] = SpatialStoredDraft(text: draft, original: original, version: version)
        return true
    }

    func draft(for objectID: String, languageCode: String) -> SpatialStoredDraft? {
        drafts[Key(objectID: objectID, languageCode: languageCode)]
    }

    mutating func discard(_ objectID: String, languageCode: String) {
        drafts.removeValue(forKey: Key(objectID: objectID, languageCode: languageCode))
    }
}

/// Pure count of user input not included in the current canonical save.
enum SpatialPendingInput {
    static func count(paused: SpatialDraftMemory,
                      activeKey: SpatialDraftMemory.Key?,
                      activeIsEdited: Bool,
                      hasNewIdea: Bool) -> Int {
        var keys = Set(paused.drafts.keys)
        if let activeKey {
            if activeIsEdited {
                keys.insert(activeKey)
            } else {
                // A resumed draft explicitly reverted to the original text
                // must not trigger a false unsaved-input warning.
                keys.remove(activeKey)
            }
        }
        return keys.count + (hasNewIdea ? 1 : 0)
    }
}

/// Save is permitted: it writes only canonical content, never a draft.
/// The feedback must never call uncommitted text "saved".
enum SpatialSaveFeedback {
    static func message(saved: Bool, pendingCount: Int, copy: SpatialV3Copy) -> String {
        guard saved else { return copy.text("spatial.feedback.saveFailed") }
        guard pendingCount > 0 else { return copy.text("spatial.feedback.saved") }
        return copy.format("spatial.pending.savedButPending", pendingCount)
    }
}

/// Explicit focus route after opening the selected-card actions.
enum SpatialActionFocusRoute: Equatable {
    case edit, close

    static func destination(editable: Bool) -> Self {
        editable ? .edit : .close
    }
}

/// Escape always closes only the innermost context. It never commits a draft.
enum SpatialEscapeRoute: Equatable {
    case pauseEditor, clearSelection, clearGroup, collapseBranches, none

    static func next(editing: Bool, selected: Bool, grouped: Bool,
                     canCollapse: Bool) -> Self {
        if editing { return .pauseEditor }
        if selected { return .clearSelection }
        if grouped { return .clearGroup }
        if canCollapse { return .collapseBranches }
        return .none
    }
}

/// A predictable reading route through graph relations, then document
/// position. This navigation-only projection never writes positions or content.
enum SpatialV3ReadingOrder {
    static func ordered(_ nodes: [SpatialV3Node], edges: [SpatialV3Edge]) -> [SpatialV3Node] {
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        func less(_ lhs: SpatialV3Node, _ rhs: SpatialV3Node) -> Bool {
            let ly = lhs.y.isFinite ? lhs.y : .infinity
            let ry = rhs.y.isFinite ? rhs.y : .infinity
            if ly != ry { return ly < ry }
            let lx = lhs.x.isFinite ? lhs.x : .infinity
            let rx = rhs.x.isFinite ? rhs.x : .infinity
            if lx != rx { return lx < rx }
            return lhs.id < rhs.id
        }
        let anchors = nodes.sorted(by: less)
        var inbound: [String: Int] = [:]
        var outgoing: [String: Set<String>] = [:]
        for edge in edges where edge.source != edge.target
            && byID[edge.source] != nil && byID[edge.target] != nil {
            if outgoing[edge.source, default: []].insert(edge.target).inserted {
                inbound[edge.target, default: 0] += 1
            }
        }
        var visited: Set<String> = []
        var result: [SpatialV3Node] = []
        func visit(_ anchor: SpatialV3Node) {
            guard visited.insert(anchor.id).inserted else { return }
            var queue = [anchor.id]
            var head = 0
            while head < queue.count {
                let current = queue[head]
                head += 1
                guard let node = byID[current] else { continue }
                result.append(node)
                let successors = (outgoing[current] ?? [])
                    .compactMap { byID[$0] }.sorted(by: less)
                for successor in successors where visited.insert(successor.id).inserted {
                    queue.append(successor.id)
                }
            }
        }
        for anchor in anchors where inbound[anchor.id, default: 0] == 0 {
            visit(anchor)
        }
        // Cycles and disconnected cards remain reachable, even without roots.
        for anchor in anchors { visit(anchor) }
        return result
    }
}

/// Native spatial controls follow the document language, never translate its
/// authored content, and keep the preview in the system interface language.
struct SpatialV3Copy {
    let locale: Locale
    private let localizedBundle: Bundle

    init(languageCode: String?) {
        let fallback = Locale.current.language.languageCode?.identifier == "en" ? "en" : "fr"
        let code = ["fr", "en"].contains(languageCode ?? "") ? languageCode ?? fallback : fallback
        locale = Locale(identifier: code)
        // `String(localized:, locale:)` alone does not force the catalog language
        // under SwiftPM on macOS (the host app still chooses English). Select
        // the compiled language resources explicitly from the same bundle.
        localizedBundle = L10n.bundle.path(forResource: code, ofType: "lproj")
            .flatMap { Bundle(path: $0) } ?? L10n.bundle
    }

    func text(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: args)
    }

    func kind(_ value: String) -> String {
        let name = value.lowercased()
        guard Self.kinds.contains(name) else { return value }
        return text("spatial.kind." + name)
    }

    func status(_ value: String) -> String {
        let name = value.lowercased()
        guard Self.statuses.contains(name) else { return value }
        return text("spatial.status." + name)
    }

    private static let kinds: Set<String> = [
        "context", "constraint", "idea", "hypothesis", "goal", "question",
        "evidence", "contribution", "decision", "action", "source",
        "proposal", "mission"
    ]
    private static let statuses: Set<String> = [
        "active", "set-aside", "saved", "pending", "open", "unverified"
    ]
}

private struct SpatialV3MeaningNode: View {
    let node: SpatialV3Node
    let selected: Bool
    let copy: SpatialV3Copy
    let onSelect: () -> Void

    private var background: Color {
        if node.kind == "mission" { return KollioV3Tokens.Light.accent }
        if node.kind == "proposal" { return KollioV3Tokens.Light.accentSoft }
        if node.kind == "source" { return KollioV3Tokens.Light.surface }
        return KollioV3Tokens.Light.paper
    }
    private var foreground: Color {
        node.kind == "mission" ? .white : KollioV3Tokens.Light.ink
    }
    private var stroke: Color {
        if selected { return KollioV3Tokens.Light.accent }
        if node.kind == "proposal" { return KollioV3Tokens.Light.accent }
        if node.kind == "source" { return KollioV3Tokens.Light.verified.opacity(0.55) }
        if node.kind == "mission" { return KollioV3Tokens.Light.accent }
        return .clear
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: node.kind == "mission" ? .center : .leading, spacing: 6) {
                Text(copy.kind(node.eyebrow).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(node.kind == "mission" ? Color.white.opacity(0.8) : KollioV3Tokens.Light.muted)
                Text(node.label)
                    .font(.system(size: node.kind == "mission" ? 19 : 15, weight: .semibold))
                    .multilineTextAlignment(node.kind == "mission" ? .center : .leading)
                if node.kind == "mission" {
                    Text(copy.text("spatial.missionFooter"))
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.8))
                }
            }
            .frame(width: node.kind == "mission" ? 235 : node.kind == "question" ? 175 : 195,
                   alignment: node.kind == "mission" ? .center : .leading)
            .frame(minHeight: node.kind == "mission" ? 88 : 65, alignment: .center)
            .padding(12)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .stroke(stroke, style: StrokeStyle(lineWidth: selected ? 2.5 : 1.5, dash: node.kind == "proposal" ? [5, 5] : [])))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copy.format("spatial.node.accessible",
            copy.kind(node.eyebrow), node.label, copy.status(node.status)))
        .accessibilityValue(copy.text(selected ? "spatial.node.selected" : "spatial.node.unselected"))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("spatial-v3-node-\(node.id)")
    }
}

/// Immutable gesture preview: never persisted. SwiftUI resets @GestureState
/// on cancellation instead of waiting for an onEnded that will never fire.
struct SpatialActiveDrag: Equatable {
    let visualID: String
    let screenTranslation: CGSize
}

/// Same one-instance command from focused arrow keys, the inspector controls
/// and VoiceOver accessibility actions. Fixed world step, independent of zoom.
enum SpatialNudgeDirection: String, CaseIterable, Identifiable {
    case up, down, left, right

    var id: String { rawValue }
    var localizationKey: String { "spatial.move.\(rawValue)" }
    var symbol: String { "arrow.\(rawValue)" }
    var delta: Position {
        switch self {
        case .up: Position(x: 0, y: -16)
        case .down: Position(x: 0, y: 16)
        case .left: Position(x: -16, y: 0)
        case .right: Position(x: 16, y: 0)
        }
    }

    init?(_ command: MoveCommandDirection) {
        switch command {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        @unknown default: return nil
        }
    }
}

/// A drag happens in the viewport's screen coordinates. Persistence is in
/// document world coordinates: camera translation never enters this delta.
enum SpatialOccurrenceDrag {
    static func worldDelta(screenTranslation: CGSize, zoom: CGFloat) -> Position? {
        guard zoom.isFinite, zoom > 0,
              screenTranslation.width.isFinite, screenTranslation.height.isFinite else {
            return nil
        }
        return Position(x: screenTranslation.width / zoom, y: screenTranslation.height / zoom)
    }
}
