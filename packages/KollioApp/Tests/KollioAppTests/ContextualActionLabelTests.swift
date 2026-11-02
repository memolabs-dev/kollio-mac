import Foundation
import Testing
@testable import KollioApp

/// The local action labels have to exist, not merely be spelled plausibly.
///
/// `String(localized:)` does not report a missing key. It returns the key. So a
/// key that was never in the catalog produces an interface that looks almost
/// right and is not: the French action bar read `explore`, `clarify` and
/// `setAside`, in English, in a French window, and nothing failed.
///
/// This is the check that would have caught it, and it is here because the same
/// mistake is cheap to make again: a key is added to an enum, the string is
/// forgotten, and the button still works.
@Suite("The local actions are labelled in both languages")
struct ContextualActionLabelTests {
    /// Every kind, including the two the model does not currently offer, because
    /// the day it offers them the label has to be there.
    private static let allKinds: [ContextualActionSet.Kind] = [
        .explore, .add, .setAside, .reopen, .edit, .addSource, .assertClaim,
        .link, .comment, .duplicateOccurrence, .duplicateVariant,
        .removeOccurrence, .removeObject, .reviewImpact, .groupInFrame,
        .compareDirections, .composeSynthesis
    ]

    @Test("Every action resolves to a key the catalog actually has")
    func everyKindResolves() {
        for kind in Self.allKinds {
            let key = kind.localizationKey
            let label = L10n.callAsFunction(key)
            #expect(
                label != key,
                "\(key) is not in the String Catalog, so the button would read \(key)"
            )
            #expect(!label.isEmpty, "\(key) resolved to an empty label")
        }
    }

    @Test("A key that is genuinely missing comes back as itself")
    func theFailureModeIsWhatWeThink() {
        // If this ever stops being true the test above stops being able to fail,
        // and a green suite would mean nothing again.
        #expect(L10n.callAsFunction("definitely.not.a.key") == "definitely.not.a.key")
    }

    @Test("No key is a bare name without its namespace")
    func keysAreNamespaced() {
        // The specific shape of the bug: `explore` instead of `canvas.explore`.
        for kind in Self.allKinds {
            #expect(
                kind.localizationKey.contains("."),
                "\(kind.localizationKey) has no namespace and cannot be a catalog key"
            )
        }
    }
}
