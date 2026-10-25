import Foundation
import Testing
@testable import KollioApp

/// The typographic rules, stated as rules rather than as a screenshot.
///
/// The document allows three weights and assigns each one a job: regular reads,
/// medium distinguishes, semibold is exceptional. The previous scale set four of
/// its six roles to medium, which quietly redefined medium as "ordinary" and left
/// the reading text carrying the same weight as the controls around it — so the
/// interface had a size hierarchy and no weight hierarchy at all.
///
/// These are tests because the failure is invisible. A scale that drifts towards
/// medium still looks like a considered scale in a screenshot, and the drift is
/// only obvious when someone has to read the numbers.
@Suite("Typography: three weights, each with one job")
struct TypeScaleTests {
    @Test("Reading is regular, and most of the application is reading")
    func regularIsTheReadingDefault() {
        // Everything a person reads at length: the invitation they finish, the
        // thought they came to read, prose, and the secondary text they scan.
        for role in [TypeRole.invitation, .thought, .body, .metadata] {
            #expect(
                TypeScale.spec(role).weightRank == 0,
                "\(role.rawValue) is set at weight rank \(TypeScale.spec(role).weightRank); reading is regular"
            )
        }
    }

    @Test("Medium distinguishes, and only the two roles that need standing apart")
    func mediumIsUsedToDistinguish() {
        // A context is structurally louder than what it contains. A control's
        // label is not prose. Nothing else earns it.
        for role in [TypeRole.context, .action] {
            #expect(TypeScale.spec(role).weightRank == 1, "\(role.rawValue) should be medium")
        }
        #expect(
            Set(TypeRole.allCases.filter { TypeScale.spec($0).weightRank == 1 }) == [.context, .action],
            "medium has been given to a role that was not supposed to have it"
        )
    }

    @Test("Semibold is the exception, and there is one of them")
    func semiboldIsExceptional() {
        let heavy = TypeRole.allCases.filter { TypeScale.spec($0).weightRank >= 2 }
        #expect(heavy == [.attention], "the heavier weight is on \(heavy.map(\.rawValue))")
    }

    @Test("No more than three weights exist in the application")
    func threeWeightsAtMost() {
        let ranks = Set(TypeRole.allCases.map { TypeScale.spec($0).weightRank })
        #expect(
            ranks.count <= 3,
            "the scale uses \(ranks.sorted()) ranks; the document allows regular, medium and one accent"
        )
        #expect(ranks.min() == 0, "the lightest weight is not regular, so nothing is the reading default")
    }

    @Test("Sizes descend with importance, so the hierarchy is not carried by weight alone")
    func sizesDescend() {
        let ordered: [TypeRole] = [.invitation, .context, .thought, .body, .action]
        let sizes = ordered.map { TypeScale.spec($0).size }
        for (index, size) in sizes.enumerated() where index > 0 {
            #expect(
                size < sizes[index - 1],
                "\(ordered[index].rawValue) at \(size) is not smaller than \(ordered[index - 1].rawValue) at \(sizes[index - 1])"
            )
        }
    }

    @Test("No role falls under the platform's minimum legible size")
    func nothingIsTooSmall() {
        // The HIG's macOS minimum is 10pt. Metadata at 12 and the attention mark
        // at 12 are both above it; this is here so a future addition cannot go
        // under it without the suite saying so.
        for role in TypeRole.allCases {
            #expect(
                TypeScale.spec(role).size >= 10,
                "\(role.rawValue) is \(TypeScale.spec(role).size)pt, under the 10pt floor"
            )
        }
    }

    @Test("Every role has a specification")
    func theScaleIsTotal() {
        // The font each role produces is not asserted here: every one of these
        // fonts is used by a view, so the application compiling is the proof that
        // a role produces one. What is worth asserting is that no role is
        // missing its size and weight, because that would silently fall back.
        for role in TypeRole.allCases {
            #expect(TypeScale.specs[role] != nil, "\(role.rawValue) has no size and weight of its own")
        }
        #expect(
            TypeScale.specs.count == TypeRole.allCases.count,
            "the table has \(TypeScale.specs.count) entries for \(TypeRole.allCases.count) roles"
        )
    }
}
