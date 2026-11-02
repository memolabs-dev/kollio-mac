import Foundation
import KollioCore
import SwiftUI

/// The temporary contextual timeline of one object (DEC-06).
///
/// It answers one question the document cannot: **how did this get here?** The
/// rows come from the journal, and every row carries the label the person
/// acted under, which is the only record of *why* that exists. A reversal is
/// already folded into the action it cancels, so a person does not have to do
/// the arithmetic between "added a branch" and "undid it".
///
/// Each row offers preview (read-only view of the document at that revision),
/// restore (a new transaction that brings the document to that state, DEC-06
/// AC03), and the card as a whole offers purge (removes old entries by a
/// retention horizon). Opening the card writes nothing; closing it writes
/// nothing; the present is exactly where the person left it.
struct HistoryTimelineView: View {
    let model: KollioModel
    let anchor: ObjectID

    @Environment(\.kollioTheme) private var theme
    @State private var previewDocument: KollioDocument?
    @State private var previewDifference: HistoryDifference?
    @State private var showPreview = false
    @State private var confirmingPurge = false

    private var items: [HistoryNarrativeItem] { model.history(of: anchor) }

    /// How many recorded actions the retention horizon would remove.
    private var purgeableCount: Int {
        model.document.history.entries.filter { $0.at < retentionCutoff }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(L10n.historyTitle)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            ForEach(items.reversed(), id: \.id) { item in
                HStack(alignment: .top, spacing: Space.xs) {
                    Text(item.at, format: .dateTime.day().month().hour().minute())
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 118, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.label)
                            .font(item.movedMeaning ? TypeScale.body : TypeScale.metadata)
                            .foregroundStyle(item.movedMeaning ? theme.textPrimary : theme.textSecondary)
                        if item.wasLaterReverted {
                            Text(L10n.historyLaterReverted)
                                .font(TypeScale.metadata)
                                .foregroundStyle(theme.textSecondary)
                        }
                        HStack(spacing: Space.xs) {
                            Button(L10n.historyPreview) { preview(at: item.entryID) }
                                .font(TypeScale.caption)
                                .foregroundStyle(theme.accent)
                            Button(L10n.historyRestore) { restore(to: item.entryID) }
                                .font(TypeScale.caption)
                                .foregroundStyle(theme.attention)
                        }
                    }
                }
            }

            HStack {
                Button(L10n.historyPurge) { confirmingPurge = true }
                    .font(TypeScale.caption)
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 0)
                ActionButton(title: L10n.historyClose, isDefault: false) {
                    model.openHistoryID = nil
                }
            }
        }
        .padding(Space.l)
        .frame(width: 380, alignment: .leading)
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
        .confirmationDialog(
            L10n.historyPurgeTitle,
            isPresented: $confirmingPurge,
            titleVisibility: .visible
        ) {
            // Says what goes, and that it does not come back: a purge is not an
            // edit, and an edit is the one thing in this application that can be
            // taken back.
            Button(L10n.historyPurgeConfirm(Self.retentionDays, purgeableCount), role: .destructive) {
                purge()
            }
            Button(L10n.historyClose, role: .cancel) {}
        } message: {
            Text(L10n.historyPurgeWarning)
        }
        .sheet(isPresented: $showPreview) {
            if let doc = previewDocument {
                HistoryPreviewView(
                    document: doc,
                    difference: previewDifference,
                    languageCode: model.languageCode,
                    onClose: { showPreview = false }
                )
            }
        }
    }

    private func preview(at entryID: HistoryEntryID) {
        previewDocument = try? model.previewHistory(at: entryID)
        // The difference is about this object, because the timeline is: a diff
        // of the whole document would bury the one thing being read in
        // everything else that moved.
        previewDifference = previewDocument.map {
            HistoryDifference.between(
                objectID: anchor, past: $0, present: model.document, languageCode: model.languageCode
            )
        }
        showPreview = true
    }

    private func restore(to entryID: HistoryEntryID) {
        _ = model.restoreHistory(to: entryID, label: L10n.historyRestoreLabel)
    }

    /// The retention offered, in days. A number the person can see, because
    /// "explicit retention" means the horizon is stated rather than implied.
    static let retentionDays = 30

    private var retentionCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: Date()) ?? Date()
    }

    private func purge() {
        _ = model.purgeHistory(olderThan: retentionCutoff)
    }
}

/// A read-only preview of the document at a past revision.
struct HistoryPreviewView: View {
    let document: KollioDocument
    let difference: HistoryDifference?
    let languageCode: String
    let onClose: () -> Void

    @Environment(\.kollioTheme) private var theme

    /// The difference as lines a person reads: what the text was, what it is,
    /// and what joined or left. The wording is the interface's, from the
    /// catalogue, so the same change says the same thing in French and English.
    private struct Line: Identifiable {
        var id: String
        var symbol: String
        var isAddition: Bool
        var text: String
    }

    private var lines: [Line] {
        guard let difference else { return [] }
        var made: [Line] = []

        switch difference.text {
        case .unchanged:
            break
        case .changed(let from, let to):
            made.append(Line(
                id: "text", symbol: "pencil", isAddition: false,
                text: L10n.historyDiffText(from, to)
            ))
        case .added(let now):
            made.append(Line(
                id: "text", symbol: "plus", isAddition: true,
                text: L10n.historyDiffAdded(now)
            ))
        case .removed(let then):
            made.append(Line(
                id: "text", symbol: "minus", isAddition: false,
                text: L10n.historyDiffRemoved(then)
            ))
        }

        for other in difference.connections.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let change = difference.connections[other] else { continue }
            switch change {
            case .unchanged:
                continue
            case .added(let kind):
                made.append(Line(
                    id: "link-\(other.rawValue)", symbol: "link.badge.plus", isAddition: true,
                    text: L10n.historyDiffLinkAdded(kind.verb(languageCode: languageCode), other.rawValue)
                ))
            case .removed(let kind):
                made.append(Line(
                    id: "link-\(other.rawValue)", symbol: "link.badge.minus", isAddition: false,
                    text: L10n.historyDiffLinkRemoved(kind.verb(languageCode: languageCode), other.rawValue)
                ))
            case .changed(let from, let to):
                made.append(Line(
                    id: "link-\(other.rawValue)-old", symbol: "link.badge.minus", isAddition: false,
                    text: L10n.historyDiffLinkRemoved(from.verb(languageCode: languageCode), other.rawValue)
                ))
                made.append(Line(
                    id: "link-\(other.rawValue)-new", symbol: "link.badge.plus", isAddition: true,
                    text: L10n.historyDiffLinkAdded(to.verb(languageCode: languageCode), other.rawValue)
                ))
            }
        }
        return made
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(L10n.historyPreviewTitle)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            Text(L10n.historyPreviewSummary(
                document.objects.count,
                document.relationships.count,
                document.revision
            ))
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: Space.xs) {
                    // What changed, not what the document was. A past document
                    // shown in full answers a question nobody asked while the
                    // one on the timeline is "what has happened since".
                    if let difference, difference.isEmpty == false {
                        ForEach(lines, id: \.id) { line in
                            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                                Image(systemName: line.symbol)
                                    .foregroundStyle(line.isAddition ? theme.connector : theme.attention)
                                Text(line.text)
                                    .font(TypeScale.caption)
                                    .foregroundStyle(theme.textPrimary)
                            }
                        }
                    } else {
                        Text(L10n.historyPreviewNothingChanged)
                            .font(TypeScale.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            HStack {
                Spacer(minLength: 0)
                ActionButton(title: L10n.historyClose, isDefault: true, action: onClose)
            }
        }
        .padding(Space.l)
        .frame(width: 420, height: 320)
        .background(
            RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                .fill(theme.surfacePrimary)
        )
    }
}
