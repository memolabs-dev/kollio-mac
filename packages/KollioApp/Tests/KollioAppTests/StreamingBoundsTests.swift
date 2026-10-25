import Foundation
import Testing
@testable import KollioApp

/// The bounds of a streaming answer, decided before they are needed.
///
/// A stream that keeps producing updates but never produces an answer is the
/// hang a person waits out forever. The bounds exist to cut a hang, not to
/// race a working model: the measured normal case completes in two to six
/// seconds, so both numbers are generous by more than an order of magnitude.
/// What the tests can hold without a model is the shape of the decision: the
/// numbers are the constants the service reads, and the stall is checked
/// between snapshots, which is where a hang is visible.
@Suite("Streaming has bounds")
struct StreamingBoundsTests {
    @Test("The budget is generous against the measured normal case")
    func budgetIsNotARace() {
        // The measured normal case: 0.4 to 5.5 seconds across 18 real cases.
        // A budget within an order of magnitude of that would be a deadline
        // on a working model, which is the thing these numbers must not be.
        #expect(AppleLocalSuggestionService.streamingBudget > 60)
        #expect(AppleLocalSuggestionService.streamingStall > 10)
        #expect(AppleLocalSuggestionService.streamingBudget > AppleLocalSuggestionService.streamingStall)
    }

    @Test("A cancelled run is reported as cancelled, never as a failure")
    func cancellationIsNotAFailure() {
        typealias Ending = AppleLocalSuggestionService.StreamEnding

        // The j13 case from the real evaluation, and the reason the rule exists
        // in one place: a cancelled stream *ends* instead of throwing, so the
        // run a person stopped reached the "no answer produced" guard and was
        // reported as a generation that failed. They did not wait for an answer.
        #expect(AppleLocalSuggestionService.ending(cancelled: true, producedAnswer: false) == .cancelled)
        // Even with a partial answer in hand, stopping it is their decision.
        #expect(AppleLocalSuggestionService.ending(cancelled: true, producedAnswer: true) == .cancelled)
    }

    @Test("A stream that ends with nothing, unstopped, is still a failure")
    func silenceIsAFailure() {
        typealias Ending = AppleLocalSuggestionService.StreamEnding

        // The distinction that makes the first test mean something: if this were
        // also a cancellation, the fix would be hiding a genuine fault.
        #expect(AppleLocalSuggestionService.ending(cancelled: false, producedAnswer: false) == .producedNothing)
        #expect(AppleLocalSuggestionService.ending(cancelled: false, producedAnswer: true) == .answered)
    }

    @Test("The stall window exists so a hang is cut early, not only at the budget")
    func stallCutsEarly() {
        // The real evidence: one case streamed 1407 updates over 169 seconds
        // and never ended. A budget alone would have cut it at 120; the stall
        // cuts it the moment the model stops moving, which on that case was
        // somewhere under 30 seconds. The two bounds are different answers to
        // the same hang, and the earlier one is the one a person feels.
        #expect(AppleLocalSuggestionService.streamingStall < AppleLocalSuggestionService.streamingBudget)
        #expect(AppleLocalSuggestionService.streamingBudget < 200)
    }
}
