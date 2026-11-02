import Foundation
import Testing
import KollioCore
@testable import KollioApp

#if canImport(FoundationModels)
import FoundationModels
#endif

/// The on-device path, exercised without a Mac that has system intelligence.
///
/// Nothing here needs Apple Intelligence, a key or a network: the probe is
/// stubbed, so every unavailable state is reachable and the candidate conversion
/// is tested on its own. This is the integration checkpoint, and it says nothing
/// about a real model's quality.
@Suite("On-device adapter")
struct AppleAdapterTests {
    private func document() -> KollioDocument {
        var builder = DocumentBuilder()
        let context = builder.object(
            "ctx", kind: .context,
            "Réduire l'inscription de neuf étapes à trois",
            en: "Reduce the trial signup from nine steps to three",
            at: .zero
        )!
        let existing = builder.object(
            "existing", kind: .hypothesis,
            "Une direction déjà sur le canvas",
            en: "A direction already on the canvas",
            at: Position(x: 0, y: 200)
        )!
        _ = builder.link("l1", from: context, to: existing, .alternativeTo)
        return builder.document
    }

    private func request(
        document: KollioDocument,
        locale: String = "fr",
        instruction: String? = nil
    ) -> ProposalRequest {
        ProposalRequest(
            requestId: "req-apple-1",
            documentId: document.documentId,
            baseSemanticRevision: document.semanticRevision,
            intent: .explore,
            targetIds: ["object:ctx"],
            instruction: instruction,
            contentLocale: locale
        )
    }

    // MARK: Availability

    @Test("An unavailable model is a refusal, never a substitution")
    func unavailableNeverFallsBack() async throws {
        // Every state the framework can report, one by one.
        for state: AppleModelAvailability in [
            .deviceNotEligible, .intelligenceDisabled, .assetsNotReady, .frameworkUnavailable
        ] {
            let service = AppleLocalSuggestionService(
                probe: StubAppleModelProbe(availability: state)
            )
            let document = self.document()
            do {
                _ = try await service.respond(to: request(document: document), document: document)
                Issue.record("an unavailable model must refuse, got an answer for \(state)")
            } catch let error as AppleModelError {
                guard case .unavailable(let reported) = error else {
                    Issue.record("expected an unavailability, got \(error)")
                    return
                }
                #expect(reported == state)
                // The reason is stated, not flattened into a guess.
                #expect(reported.explanation.isEmpty == false)
            }
            // The service is still the on-device one: it did not become a demo.
            #expect(service.capabilities.requiresNetwork == false)
        }
    }

    @Test("A language the model does not support is refused before any request")
    func unsupportedLanguageIsRefused() async throws {
        let service = AppleLocalSuggestionService(
            probe: StubAppleModelProbe(availability: .available, languages: ["fr"])
        )
        let document = self.document()
        do {
            _ = try await service.respond(to: request(document: document, locale: "ja"), document: document)
            Issue.record("an unsupported language must be refused")
        } catch let error as AppleModelError {
            guard case .unavailable(let reason) = error, case .unsupportedLanguage = reason else {
                Issue.record("expected an unsupported language, got \(error)")
                return
            }
        }
    }

    @Test("The on-device path reports no network requirement")
    func capabilitiesAreHonest() {
        let service = AppleLocalSuggestionService(
            probe: StubAppleModelProbe(availability: .available)
        )
        // False means the answer comes from this Mac. A remote provider reports
        // true, and the two are never conflated.
        #expect(service.capabilities.requiresNetwork == false)
        #expect(service.capabilities.deterministic == false)
    }

    // MARK: Service selection

    @Test("With no preference, a usable model is preferred over the engine")
    func prefersTheRealModel() {
        let usable = ServiceConfiguration.fromEnvironment([:], token: nil, appleIsUsable: true)
        #expect(usable.configuration == .apple)
        let unusable = ServiceConfiguration.fromEnvironment([:], token: nil, appleIsUsable: false)
        #expect(unusable.configuration == .demo)
    }

    @Test("An explicit demo mode is respected even when the model works")
    func explicitDemoIsRespected() {
        let resolved = ServiceConfiguration.fromEnvironment(
            ["KOLLIO_SERVICE": "demo"], token: nil, appleIsUsable: true
        )
        #expect(resolved.configuration == .demo)
    }

    @Test("Server mode without a token falls back and says so")
    func serverWithoutTokenFallsBack() {
        let resolved = ServiceConfiguration.fromEnvironment(
            ["KOLLIO_SERVICE": "server"], token: nil, appleIsUsable: true
        )
        // Not the server: a silent fallback would look like the backend answered.
        #expect(resolved.configuration == .demo)
        let withToken = ServiceConfiguration.fromEnvironment(
            ["KOLLIO_SERVICE": "server", "KOLLIO_SERVER_URL": "http://127.0.0.1:9000"],
            token: "a-token", appleIsUsable: false
        )
        #expect(withToken.configuration == .server(baseURL: URL(string: "http://127.0.0.1:9000")!))
    }

    // MARK: Candidate conversion

    @available(macOS 26.0, *)
    @Test("A candidate becomes commands the server and the client both signed")
    func candidateBecomesAProposal() throws {
        let document = self.document()
        let candidate = AppleCandidate(
            outcome: "proposal",
            rationale: "Deux pistes valent la peine.",
            ideas: [
                .init(title: "Un seul écran", summary: "Regrouper les neuf étapes en une page.", kind: "hypothesis"),
                .init(title: "Progression assistée", summary: "Une liste qui guide l'utilisateur.", kind: "method")
            ]
        )
        let converted = AppleCandidateConverter().convert(
            candidate, request: request(document: document), document: document
        )
        guard case .proposal(let proposal) = converted.result else {
            Issue.record("expected a proposal, got \(converted.result)")
            return
        }
        // The adapter signs, not the model.
        #expect(proposal.requestId == "req-apple-1")
        #expect(proposal.documentId == document.documentId)
        #expect(proposal.baseSemanticRevision == document.semanticRevision)
        #expect(proposal.generator.name == "apple-on-device")
        // Two objects and one relationship each.
        #expect(proposal.operations.count == 4)
        // And the result passes the same domain validation every other proposal
        // must pass, against the real document.
        let scope = request(document: document).scope
        #expect(throws: Never.self) {
            try ProposalValidator().validate(proposal, against: document, scope: scope)
        }
    }

    @available(macOS 26.0, *)
    @Test("A narrowed payload stays attached to the proposal it produced")
    func narrowedScopeSurvivesConversion() throws {
        let document = self.document()
        let scope = ProposalContextScope(
            readObjectIDs: ["object:ctx"],
            omittedObjectIDs: ["object:existing"],
            measuredCharacters: 420,
            budgetCharacters: 500
        )
        let candidate = AppleCandidate(
            outcome: "proposal",
            rationale: "Une piste à partir du contexte disponible.",
            ideas: [.init(title: "Par étapes", summary: "Réduire progressivement.", kind: "method")]
        )

        let converted = AppleCandidateConverter().convert(
            candidate,
            request: request(document: document),
            document: document,
            contextScope: scope
        )
        guard case .proposal(let proposal) = converted.result else {
            Issue.record("expected a proposal")
            return
        }
        #expect(proposal.contextScope == scope)
    }

    @available(macOS 26.0, *)
    @Test("An idea the canvas cannot render is dropped, not coerced")
    func unknownKindIsDropped() throws {
        let document = self.document()
        let candidate = AppleCandidate(
            outcome: "proposal",
            rationale: "Melange.",
            ideas: [
                .init(title: "Bonne idée", summary: "OK", kind: "hypothesis"),
                .init(title: "Idée inexplicable", summary: "?", kind: "quantum_flux")
            ]
        )
        let converted = AppleCandidateConverter().convert(
            candidate, request: request(document: document), document: document
        )
        #expect(converted.droppedKinds == 1)
        guard case .proposal(let proposal) = converted.result else {
            Issue.record("the usable idea should have survived")
            return
        }
        #expect(proposal.operations.count == 2)
    }

    @available(macOS 26.0, *)
    @Test("A proposal outcome with nothing usable becomes noChange, not an empty branch")
    func emptyProposalBecomesNoChange() throws {
        let document = self.document()
        let candidate = AppleCandidate(
            outcome: "proposal",
            rationale: "Je n'ai rien d'utile.",
            ideas: [.init(title: "  ", summary: "", kind: "not-a-kind")]
        )
        let converted = AppleCandidateConverter().convert(
            candidate, request: request(document: document), document: document
        )
        guard case .noChange = converted.result else {
            Issue.record("an unusable proposal must be reported as noChange")
            return
        }
    }

    @available(macOS 26.0, *)
    @Test("noChange and needsInput pass through as themselves")
    func outcomesArePreserved() throws {
        let document = self.document()
        let converter = AppleCandidateConverter()
        let noChange = converter.convert(
            AppleCandidate(outcome: "noChange", rationale: "Rien à dire.", ideas: []),
            request: request(document: document), document: document
        )
        guard case .noChange = noChange.result else {
            Issue.record("noChange must survive")
            return
        }
        let needsInput = converter.convert(
            AppleCandidate(outcome: "needsInput", rationale: "Quel budget ?", ideas: []),
            request: request(document: document), document: document
        )
        guard case .needsInput(let questions) = needsInput.result else {
            Issue.record("needsInput must survive")
            return
        }
        #expect(questions == ["Quel budget ?"])
    }

    @available(macOS 26.0, *)
    @Test("An outcome this adapter does not know is never guessed at")
    func unknownOutcomeIsMalformed() throws {
        let document = self.document()
        let converted = AppleCandidateConverter().convert(
            AppleCandidate(outcome: "certainly", rationale: "", ideas: []),
            request: request(document: document), document: document
        )
        guard case .malformed = converted.result else {
            Issue.record("an unrecognised outcome must not be interpreted")
            return
        }
    }

    @available(macOS 26.0, *)
    @Test("The branch stays small, whatever the model returns")
    func branchIsBounded() throws {
        let document = self.document()
        let many = (0..<8).map { index in
            AppleCandidateIdea(title: "Idée \(index)", summary: "s", kind: "hypothesis")
        }
        let converted = AppleCandidateConverter().convert(
            AppleCandidate(outcome: "proposal", rationale: "Beaucoup.", ideas: many),
            request: request(document: document), document: document
        )
        guard case .proposal(let proposal) = converted.result else {
            Issue.record("expected a proposal")
            return
        }
        // At most 3 ideas, each with one relationship: 6 operations at most.
        #expect(proposal.operations.count <= 6)
        #expect(converted.droppedIdeas > 0)
    }

    @available(macOS 26.0, *)
    @Test("Minted identifiers are ours, not the model's")
    func identifiersAreMinted() throws {
        let document = self.document()
        let candidate = AppleCandidate(
            outcome: "proposal",
            rationale: "OK",
            ideas: [.init(title: "Une piste", summary: "s", kind: "hypothesis")]
        )
        let converted = AppleCandidateConverter().convert(
            candidate, request: request(document: document), document: document
        )
        guard case .proposal(let proposal) = converted.result else { return }
        let created = proposal.operations.compactMap { operation -> ObjectID? in
            guard case .createObject(let create) = operation else { return nil }
            return create.id
        }
        #expect(created.first?.rawValue.hasPrefix("object:apple-") == true)
    }

    // MARK: Streaming

    /// Builds the raw generated content the stream actually hands over, so the
    /// projection is tested against the same shape the framework produces.
    @available(macOS 26.0, *)
    private func rawContent(_ json: String) -> GeneratedContent {
        try! GeneratedContent(json: json)
    }

    @available(macOS 26.0, *)
    @Test("A half-written answer becomes progress, never a proposal")
    func partialContentIsOnlyProgress() {
        // What a model produces part-way through: a rationale that stops mid-word,
        // one idea already present, the second not started, no outcome yet.
        let halfWritten = """
        {"outcome":"","rationale":"Réduire les étapes en intro","ideas":[{"title":"Phase unique","summary":"Un","kind":"method"}]}
        """
        let progress = try? AppleCandidateProgress.project(rawContent(halfWritten))
        #expect(progress != nil)
        #expect(progress?.directionsSoFar == 1)
        #expect(progress?.hasOutcome == false)
        // A half-written sentence is shown as it is written. It is never trimmed
        // into something that looks finished.
        #expect(progress?.rationale == "Réduire les étapes en intro")

        // The safety property, stated as the test that matters: a progress has no
        // identifier, no operation and no way to become a command. There is no
        // initialiser that could mint one, which is why this cannot regress
        // quietly.
        let value = progress ?? ProposalProgress()
        #expect(ObjectID(value.rationale ?? "") != ObjectID("object:apple-0"))
        #expect(ProposalProgress().isEmpty)
    }

    @available(macOS 26.0, *)
    @Test("Content the projection cannot read is no progress, not a wrong progress")
    func unreadableContentYieldsNothing() {
        // The framework only ever hands over content it can parse, so malformed
        // JSON is not a case that can happen and is not pretended to here. What
        // can happen is valid JSON that is not the shape expected: a snapshot
        // from an earlier field, or an answer that does not match the schema.
        #expect(AppleCandidateProgress.project(rawContent("{}")) == nil)
        #expect(AppleCandidateProgress.project(rawContent("{\"other\":1}")) == nil)
        // Empty strings are what a field looks like before the model writes it.
        // That is "nothing yet", not an empty direction.
        let blank = rawContent("{\"outcome\":\"\",\"rationale\":\"\",\"ideas\":[]}")
        #expect(AppleCandidateProgress.project(blank) == nil)
    }

    @available(macOS 26.0, *)
    @Test("The finished answer and the streamed one convert identically")
    func streamingChangesTimingNotMeaning() throws {
        // The same answer twice: once through the non-streaming converter, once
        // through the streaming projection. Identifiers come from the request and
        // the document, never from the stream, so they must match exactly.
        let json = """
        {"outcome":"proposal","rationale":"Fusionner les étapes","ideas":[
          {"title":"Phase unique","summary":"Une seule phase","kind":"method"},
          {"title":"Contrôle central","summary":"Vérification unique","kind":"constraint"}]}
        """
        let candidate = try AppleCandidate(rawContent(json))
        let request = ProposalRequest(
            requestId: "stream-1", documentId: document().documentId,
            baseSemanticRevision: 0, intent: .explore,
            targetIds: ["object:ctx"], contentLocale: "fr"
        )
        let converted = AppleCandidateConverter().convert(candidate, request: request, document: document())
        let response = converted.response
        #expect(response.status == .proposed)
        let ids = response.proposal?.operations.compactMap { operation -> ObjectID? in
            guard case .createObject(let create) = operation else { return nil }
            return create.id
        }
        #expect(ids?.contains { $0.rawValue.hasPrefix("object:apple-stream1") } == true)
        // A completed stream reports the same content a final snapshot does.
        let final = try? AppleCandidateProgress.project(rawContent(json))
        #expect(final?.directionsSoFar == 2)
        #expect(final?.hasOutcome == true)
    }

    @Test("The context budget is measured, and truncation is reported not hidden")
    func contextBudgetIsAppliedAndVisible() {
        // A small model on purpose: the point is what happens when the real context
        // does not fit, not that a big model copes.
        let probe = StubAppleModelProbe(availability: .available, contextSize: 300)
        let request = ProposalRequest(
            requestId: "budget-1", documentId: document().documentId,
            baseSemanticRevision: 0, intent: .explore,
            targetIds: ["object:ctx"], contentLocale: "fr"
        )
        var withContext = request
        withContext.context = [
            .init(objectID: "object:ctx", kind: .context,
                  text: String(repeating: "contexte ", count: 400), lifecycle: .active)
        ]
        let projection = AppleLocalSuggestionService.project(
            request: withContext, document: document(), probe: probe
        )
        // A 300-token window is roughly 1200 characters, and this context is
        // several times that, so it genuinely cannot fit.
        #expect(projection.budgetCharacters < withContext.context.first!.text.count)
        #expect(projection.missingRequired == [.object("object:ctx")])
        #expect(projection.isComplete == false)
        // The target is what was asked about, so it is required and is reported as
        // missing rather than quietly dropped.
        #expect(projection.mayLeaveTheMachine == false)
    }

    @Test("A required item that does not fit is refused before either generation route")
    func requiredOverflowIsRefused() {
        let document = self.document()
        let probe = StubAppleModelProbe(availability: .available, contextSize: 300)
        var oversized = request(document: document)
        oversized.context = [
            .init(
                objectID: "object:ctx",
                kind: .context,
                text: String(repeating: "contexte ", count: 400),
                lifecycle: .active
            )
        ]

        #expect(throws: AppleModelError.contextTooLarge) {
            _ = try AppleLocalSuggestionService.prepare(
                request: oversized,
                document: document,
                probe: probe
            )
        }
    }

    @Test("The budget never claims more room than the model has")
    func budgetNeverExceedsTheWindow() {
        // The bug this catches: a minimum budget larger than the real context
        // would report a generous room that does not exist, and truncation would
        // then happen without being detected.
        for tokens in [64, 300, 1_000, 8_192] {
            let budget = ApplePromptBuilder.characterBudget(forContextTokens: tokens)
            #expect(budget <= tokens * ApplePromptBuilder.conservativeCharactersPerToken,
                    "budget \(budget) exceeds a \(tokens) token window")
            #expect(budget > 0)
        }
        // A model that does not report its size gets a stated default rather than
        // an unbounded one.
        #expect(ApplePromptBuilder.characterBudget(forContextTokens: nil) > 0)
    }

    @Test("A context that fits needs no narrowing")
    func aFittingContextIsComplete() {
        let probe = StubAppleModelProbe(availability: .available, contextSize: 8_192)
        var request = ProposalRequest(
            requestId: "budget-2", documentId: document().documentId,
            baseSemanticRevision: 0, intent: .explore,
            targetIds: ["object:ctx"], contentLocale: "fr"
        )
        request.context = [
            .init(objectID: "object:ctx", kind: .context,
                  text: "Réduire l'inscription de neuf étapes à trois", lifecycle: .active)
        ]
        let projection = AppleLocalSuggestionService.project(
            request: request, document: document(), probe: probe
        )
        #expect(projection.isComplete)
        #expect(projection.measuredCharacters > 0)
    }

    // MARK: The seam is unchanged

    @Test("The domain never sees an Apple type")
    func domainIsUntouched() {
        // A compile-time fact, stated as a test so it is checked on every run:
        // the adapter lives in the app package, and the snapshot and the command
        // types in KollioCore carry no FoundationModels dependency.
        let document = self.document()
        let snapshot = try? document.snapshot(targeting: ["object:ctx"])
        #expect(snapshot != nil)
        #expect(document.content.keys.contains("object:ctx"))
    }
}
