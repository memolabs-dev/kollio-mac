import Foundation
import KollioCore
import SwiftUI

/// Reading a built experiment.
///
/// This card exists for one acceptance criterion, and it is the one a text
/// field cannot carry: the criterion a person committed to before knowing the
/// outcome has to stay readable. So the card shows the committed fields from
/// the *current revision*, the number of revisions beneath them, and nothing
/// that would judge the experiment — there is no result yet, and DEC-04 does
/// not pretend otherwise. It is a reading of the document: it writes nothing,
/// and closing it writes nothing either.
struct ExperimentCardView: View {
    let model: KollioModel
    let id: ExperimentID

    @Environment(\.kollioTheme) private var theme

    private var experiment: Experiment? { model.document.experiments.experiment(id) }

    var body: some View {
        if let experiment {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(L10n.experimentCardTitle)
                    .font(TypeScale.metadata.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)

                block(L10n.experimentCardQuestion, experiment.currentRevision.question.resolve(languageCode: model.languageCode))
                if let method = experiment.currentRevision.method {
                    block(L10n.experimentCardMethod, method.resolve(languageCode: model.languageCode))
                }
                block(L10n.experimentCardCriterion, experiment.currentRevision.successCriterion.resolve(languageCode: model.languageCode))

                if experiment.currentRevision.expectedEvidence.isEmpty == false {
                    block(
                        L10n.experimentCardEvidence,
                        evidenceNames(experiment.currentRevision.expectedEvidence)
                    )
                }

                if experiment.isSimulation {
                    Text(L10n.experimentIsSimulation)
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                }

                if experiment.revisions.count > 1 {
                    Text(L10n.experimentCardRevisions(experiment.revisions.count))
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                }

                if let result = experiment.results.last {
                    Divider()
                    Text(L10n.resultRecorded(experiment.results.count))
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                    block(L10n.resultObservedLabel, result.observation)
                    if result.measurements.isEmpty == false {
                        block(
                            L10n.resultMeasuredLabel,
                            result.measurements
                                .map { "\($0.value.formatted()) \($0.unit)" }
                                .joined(separator: " · ")
                        )
                    }
                    if let limits = result.limits, limits.isEmpty == false {
                        block(L10n.resultLimitsLabel, limits)
                    }
                    block(L10n.resultOutcomeLabel, outcomeLabel(result.outcome))
                    learningDraft(experiment)
                } else {
                    Button {
                        model.startRecordingResult(experiment.id)
                    } label: {
                        Text(L10n.resultPrompt)
                            .font(TypeScale.metadata)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }

                HStack {
                    Spacer(minLength: 0)
                    ActionButton(title: L10n.experimentCardClose, isDefault: false) {
                        model.openExperimentID = nil
                    }
                }
            }
            .padding(Space.l)
            .frame(width: 400, alignment: .leading)
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
    }

    private func block(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(TypeScale.metadata)
                .foregroundStyle(theme.textSecondary)
            Text(value)
                .font(TypeScale.body)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The outcome in words, in the language being read. It is the person's
    /// stance restated, not a computation: nothing here derives it from the
    /// numbers above it.
    private func outcomeLabel(_ outcome: ExperimentResultVersion.Outcome) -> String {
        switch outcome {
        case .conclusive(.criterionMet): return L10n.resultCriterionMet
        case .conclusive(.criterionNotMet): return L10n.resultCriterionNotMet
        case .inconclusive(let reason): return L10n.resultInconclusive + " — " + reason
        }
    }

    /// The proposed learning: one line, written by the person, proposed about
    /// the selection. Accepting it is a decision, and no button here takes one.
    @ViewBuilder
    private func learningDraft(_ experiment: Experiment) -> some View {
        let draft = model.learningDraft(for: experiment.id)
        TextField(
            L10n.resultLearningPlaceholder,
            text: Binding(
                get: { draft ?? "" },
                set: { model.setLearningDraft($0, for: experiment.id) }
            )
        )
        .font(TypeScale.metadata)
        .onSubmit {
            model.submitLearningDraft(for: experiment.id)
        }
    }

    /// The evidence by its authored text, because an id is for the document and
    /// a name is for the person.
    private func evidenceNames(_ ids: [ObjectID]) -> String {
        ids.compactMap { model.object($0)?.text.resolve(languageCode: model.languageCode) }
            .joined(separator: " · ")
    }
}

/// Recording a result against an experiment (DEC-05).
///
/// The two fields the specification separates stay separated by layout, not
/// by hope: the observation at the top is where what was seen is written, the
/// outcome block below is where the stance on the criterion is taken, and
/// nothing between them computes one from the other. Choosing "inconclusive"
/// trades the criterion buttons for a reason field, because an inconclusive
/// answer that cannot say what is missing is a shrug, and the composer does
/// not accept shrugs.
struct ResultComposerView: View {
    let model: KollioModel

    @Environment(\.kollioTheme) private var theme
    @FocusState private var focused: Bool

    var body: some View {
        if let draft = model.resultDraft {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(L10n.resultPrompt)
                    .font(TypeScale.metadata.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)

                TextField(
                    L10n.resultObservationPlaceholder,
                    text: Binding(
                        get: { model.resultDraft?.observation ?? "" },
                        set: { model.resultDraft?.observation = $0 }
                    )
                )
                .font(TypeScale.body)
                .focused($focused)

                HStack(spacing: Space.xs) {
                    TextField(
                        L10n.resultMeasurementPlaceholder,
                        text: Binding(
                            get: { model.resultDraft?.measurementValue ?? "" },
                            set: { model.resultDraft?.measurementValue = $0 }
                        )
                    )
                    .font(TypeScale.body)
                    TextField(
                        L10n.resultUnitPlaceholder,
                        text: Binding(
                            get: { model.resultDraft?.measurementUnit ?? "" },
                            set: { model.resultDraft?.measurementUnit = $0 }
                        )
                    )
                    .font(TypeScale.metadata)
                }

                TextField(
                    L10n.resultLimitsPlaceholder,
                    text: Binding(
                        get: { model.resultDraft?.limits ?? "" },
                        set: { model.resultDraft?.limits = $0 }
                    )
                )
                .font(TypeScale.body)

                if let source = draft.sourceObjectID {
                    Text(L10n.presentationKindSource + " · " + model.text(of: source))
                        .font(TypeScale.metadata)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }

                Text(L10n.resultOutcomeLabel)
                    .font(TypeScale.metadata)
                    .foregroundStyle(theme.textSecondary)

                Toggle(isOn: Binding(
                    get: { model.resultDraft?.inconclusive ?? false },
                    set: { model.resultDraft?.inconclusive = $0 }
                )) {
                    Text(L10n.resultInconclusive)
                        .font(TypeScale.metadata)
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)

                if draft.inconclusive {
                    TextField(
                        L10n.resultReasonPlaceholder,
                        text: Binding(
                            get: { model.resultDraft?.inconclusiveReason ?? "" },
                            set: { model.resultDraft?.inconclusiveReason = $0 }
                        )
                    )
                    .font(TypeScale.body)
                } else {
                    Picker(selection: Binding(
                        get: { model.resultDraft?.criterionMet ?? true },
                        set: { model.resultDraft?.criterionMet = $0 }
                    )) {
                        Text(L10n.resultCriterionMet).tag(true)
                        Text(L10n.resultCriterionNotMet).tag(false)
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack {
                    Spacer(minLength: 0)
                    ActionButton(title: L10n.resultRecord, isDefault: true) {
                        model.submitResult()
                    }
                }
            }
            .padding(Space.m)
            .frame(width: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.richBlock, style: .continuous)
                    .fill(theme.surfacePrimary)
                    .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.13), radius: 14, y: 6)
            )
        }
    }
}
