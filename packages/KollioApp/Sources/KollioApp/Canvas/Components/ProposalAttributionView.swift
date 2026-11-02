import SwiftUI
import KollioCore

/// What a proposal is, and where it came from.
///
/// ## What this panel is for
///
/// A proposal that says "two directions" tells a person nothing they can act on.
/// This names the four things they are entitled to know — where the answer came
/// from, what was read, what the model said it could not do, and which prompt
/// asked — and it deliberately shows **none** of the prompt itself.
///
/// ## What it must never do
///
/// - **Show a destination that does not work.** Private Cloud is a real Apple API
///   that this build does not wire up, so a proposal that came from one cannot
///   exist, and the label set is checked against availability rather than printed
///   as a list of possibilities.
/// - **Show a chain of thought.** A model's reasoning is not the person's business
///   and reading it is not what they need. The rationale the model *wrote* is; it
///   is a sentence addressed to the user, and it is already on the ghost branch.
/// - **Show a key.** There is no field that could carry one, and a test asserts the
///   rendered text never contains anything shaped like one.
struct ProposalAttributionView: View {
    let proposal: Proposal
    let readRefs: [ProposalInputRef]

    @Environment(\.kollioTheme) private var theme
    @State private var showsRead = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            destinationRow
            promptRow
            if proposal.limitations.isEmpty == false {
                limitationsRow
            }
            if let scopeSummary = Self.scopeSummary(for: proposal) {
                scopeRow(scopeSummary)
            }
            if readRefs.isEmpty == false {
                readRow
            }
        }
        .padding(Space.m)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.reference, style: .continuous)
                .fill(theme.surfaceSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.reference, style: .continuous)
                .strokeBorder(theme.decorativeBorder, lineWidth: 1)
        )
    }

    // MARK: Rows

    /// The destination, named. Not a menu of possibilities: what this answer was,
    /// and whether the content left the machine.
    private var destinationRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Image(systemName: destinationIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(destinationTint)
            Text(destinationLabel)
                .font(TypeScale.metadata.weight(.medium))
                .foregroundStyle(theme.textPrimary)
            if attribution?.destination.leftThisMachine == true {
                Text(L10n.proposalLeftThisMachine)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.attention)
            }
        }
    }

    private var promptRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text(generatorName)
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)
            // A record from before the prompt version was kept says so, rather than
            // showing a gap that looks like a missing piece of work.
            if let version = attribution?.promptVersion {
                Text("·")
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                Text(version)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text("·")
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
                Text(L10n.proposalPromptVersionUnknown)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    /// What the generator said it could not do. Read before the answer, because a
    /// limitation nobody sees is a limitation nobody accounts for.
    private var limitationsRow: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(L10n.proposalLimitations)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(proposal.limitations, id: \.self) { limitation in
                Text("· " + limitation.resolve(languageCode: L10n.bundle.preferredLocalizations.first ?? "en"))
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scopeRow(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(L10n.proposalScopeTitle)
                .font(TypeScale.metadata.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            Text(summary)
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The scope is rendered from recorded counts, never reconstructed from the
    /// current document. A document may have moved since the answer, while what
    /// the model saw cannot move retroactively.
    static func scopeSummary(for proposal: Proposal) -> String? {
        guard let scope = proposal.contextScope else { return nil }
        return scope.isNarrowed
            ? L10n.proposalScopeNarrowed(scope.readObjectIDs.count, scope.omittedObjectIDs.count)
            : L10n.proposalScopeComplete(scope.readObjectIDs.count)
    }

    /// What was read, and what is no longer there. A reference that cannot be
    /// resolved stays in the list and says so, because dropping it would change
    /// what the proposal appears to have been based on.
    private var readRow: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Button {
                showsRead.toggle()
            } label: {
                HStack(spacing: Space.xs) {
                    Image(systemName: showsRead ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text(L10n.proposalRead(showsRead ? readRefs.count : 0))
                        .font(TypeScale.metadata)
                }
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)

            if showsRead {
                ForEach(readRefs) { reference in
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        Text(reference.label)
                            .font(TypeScale.metadata)
                            .foregroundStyle(reference.isAvailable ? theme.textPrimary : theme.textSecondary)
                            .strikethrough(reference.isAvailable == false)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        if reference.isAvailable == false {
                            Text(L10n.proposalReferenceMissing)
                                .font(TypeScale.metadata)
                                .foregroundStyle(theme.attention)
                        }
                    }
                }
            }
        }
    }

    // MARK: Derived

    private var attribution: GeneratorAttribution? { proposal.attribution }

    private var destination: ProposalDestination {
        // Older records carry none, so it is read from the generator rather than
        // assumed. A record that cannot say where it came from says "on device",
        // which is the least alarming of the four and the one the store enforces.
        attribution?.destination
            ?? (proposal.generator.deterministic ? .demonstration : .onDeviceApple)
    }

    private var generatorName: String {
        attribution?.name ?? proposal.generator.name
    }

    private var destinationLabel: String {
        switch destination {
        case .onDeviceApple: return L10n.proposalDestinationOnDevice
        case .privateCloud: return L10n.proposalDestinationPrivateCloud
        case .remoteService: return L10n.proposalDestinationRemote
        case .demonstration: return L10n.proposalDestinationDemo
        }
    }

    private var destinationIcon: String {
        switch destination {
        case .onDeviceApple: return "laptopcomputer"
        case .privateCloud: return "icloud"
        case .remoteService: return "network"
        case .demonstration: return "testtube.2"
        }
    }

    /// Red for a demonstration, attention for anything that left the machine, and
    /// the ordinary secondary ink for the local case. Three signals, because the
    /// one that matters is "did this leave my machine" and it should not be the
    /// same weight as the other three.
    private var destinationTint: Color {
        switch destination {
        case .demonstration: return theme.attention
        case .privateCloud, .remoteService: return theme.attention
        case .onDeviceApple: return theme.proposalAccent
        }
    }
}
