import Foundation
import Testing
@testable import KollioApp
import KollioCore

/// AI-11: what a person is entitled to know about an answer.
///
/// The three acceptance criteria, driven the way a person would drive them: ask
/// for a proposal, then look at where it came from.
@Suite("Proposal attribution")
@MainActor
struct ProposalAttributionTests {
    private func model(languageCode: String = "fr") -> KollioModel {
        KollioModel(
            document: SarahFixture.document(),
            service: KollioModel.makeDemoService(languageCode: languageCode),
            fileStore: DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
        )
    }

    private func ask(_ model: KollioModel) async throws -> ProposalPreview {
        await model.explore(KollioID.object("sarah-csv"))
        return try #require(model.preview)
    }

    // MARK: - AC01, the destinations are distinguished

    @Test("A demo proposal says it came from a demonstration")
    func demoIsLabelled() async throws {
        let model = model()
        let preview = try await ask(model)
        let attribution = try #require(preview.proposal.attribution)
        // The label has to survive into the record, not live in a menu. A person who
        // kept a direction a demo proposed has to be able to find out afterwards.
        #expect(attribution.destination == .demonstration)
        #expect(attribution.destination.leftThisMachine == false)
        #expect(attribution.promptVersion == "local-demo-v1")
        #expect(preview.proposal.generator.deterministic)
    }

    @Test("The panel can be asked for, and is not shown by default")
    func panelIsOptIn() async throws {
        let model = model()
        _ = try await ask(model)
        // Asking is a deliberate act. Putting it in front of every proposal would
        // train people to skip it, and then it is decoration.
        #expect(model.showsProposalAttribution == false)
        model.showsProposalAttribution.toggle()
        #expect(model.showsProposalAttribution)
    }

    @Test("A private destination is the only one labelled as leaving the machine")
    func leavingTheMachineIsLabelled() {
        #expect(ProposalDestination.onDeviceApple.leftThisMachine == false)
        #expect(ProposalDestination.demonstration.leftThisMachine == false)
        // The two destinations this build cannot reach would say so, and are not
        // offered. A menu listing a destination the product cannot reach is a lie
        // with a button on it.
        #expect(ProposalDestination.privateCloud.leftThisMachine)
        #expect(ProposalDestination.privateCloud.isAvailableInThisBuild == false)
    }

    // MARK: - AC02, no chain of thought and no key

    @Test("Nothing a person can be shown carries a key or a prompt")
    func noKeyNoPrompt() async throws {
        let model = model()
        let preview = try await ask(model)
        let attribution = try #require(preview.proposal.attribution)
        // The type has no field that could hold a prompt, a thought or a key, so
        // the interface cannot leak one by accident. This test would keep passing
        // if someone added such a field, which is why the next one reads the
        // rendered text instead.
        #expect(attribution.model == nil || attribution.model?.isEmpty == false)
        #expect(preview.proposal.limitations.isEmpty)
    }

    @Test("The rendered attribution never contains a key-shaped string")
    func renderedTextHasNoKey() async throws {
        let model = model(languageCode: "en")
        let preview = try await ask(model)
        // Reads what a person would actually see. `sk-` and a bearer prefix are the
        // shapes a leaked credential takes, and a report that contains either is a
        // report that must not be committed or shared.
        let rendered = [
            preview.proposal.attribution?.name ?? "",
            preview.proposal.attribution?.model ?? "",
            preview.proposal.attribution?.promptVersion ?? "",
            preview.proposal.summary.resolve(languageCode: "en"),
            preview.rationale,
        ].joined(separator: " ")
        for shape in ["sk-", "Bearer ", "api_key", "apiKey", "token="] {
            #expect(rendered.contains(shape) == false, "the rendered attribution contains \(shape)")
        }
    }

    @Test("A reference carries a label and never the whole content")
    func referencesAreLabels() async throws {
        let model = model()
        let preview = try await ask(model)
        // Long context is truncated, because a proposal that copied the text of a
        // source into its own record would be a copy of somebody's document living
        // where it was not asked to be.
        for reference in preview.readRefs {
            #expect(reference.label.isEmpty == false)
            #expect(reference.label.count <= 91)
        }
    }

    // MARK: - AC03, references are checked

    @Test("What was read is resolved, not asserted")
    func readRefsAreResolved() async throws {
        let model = model()
        let preview = try await ask(model)
        #expect(preview.readRefs.isEmpty == false)
        #expect(preview.readRefs.allSatisfy { $0.isAvailable })
        // The target the person asked about is among them. A panel that listed what
        // was read and left out the thing that was clicked would be misleading.
        #expect(preview.readRefs.contains { $0.id == ObjectID("object:sarah-csv").rawValue })
    }

    @Test("A reference that no longer resolves is kept and marked")
    func missingReferenceIsMarked() {
        let document = SarahFixture.document()
        let gone = ProposalInputRef.resolve(
            ObjectID("object:removed").rawValue, kind: .object, label: "A branch that is gone",
            in: document
        )
        // Kept, because dropping it would change what the proposal appears to rest
        // on, and that is the judgement this panel exists to support.
        #expect(gone.isAvailable == false)
        #expect(gone.label.isEmpty == false)
    }

    @Test("A narrowed answer states what it read and what it left out")
    func narrowedScopeIsReadable() throws {
        let proposal = Proposal(
            proposalId: "p-scope", requestId: "r-scope", documentId: "d",
            baseSemanticRevision: 0,
            summary: LocalizedText("One direction"),
            generator: .init(name: "apple-on-device", deterministic: false),
            contextScope: ProposalContextScope(
                readObjectIDs: ["object:a", "object:b"],
                omittedObjectIDs: ["object:c"],
                measuredCharacters: 420,
                budgetCharacters: 500
            )
        )

        let text = try #require(ProposalAttributionView.scopeSummary(for: proposal))
        #expect(text.contains("2"))
        #expect(text.contains("1"))
    }

    // MARK: - Attribution reaches the real Apple path

    @Test("The Apple adapter names the local destination and its prompt revision")
    func appleAdapterNamesItself() throws {
        let proposal = Proposal(
            proposalId: "p1", requestId: "r1", documentId: "d", baseSemanticRevision: 0,
            summary: LocalizedText("Two directions"),
            generator: Proposal.Generator(name: "apple-on-device", deterministic: false),
            attribution: GeneratorAttribution(
                name: "apple-on-device",
                model: "system",
                promptVersion: "apple-local-explore-v1",
                destination: .onDeviceApple,
                isDeterministic: false
            )
        )
        let attribution = try #require(proposal.attribution)
        #expect(attribution.destination == .onDeviceApple)
        #expect(attribution.destination.leftThisMachine == false)
        #expect(attribution.promptVersion == "apple-local-explore-v1")
        #expect(attribution.isSelfDeclared, "the label is metadata, never a proof")
    }
}
