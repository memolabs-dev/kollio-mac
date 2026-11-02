import Foundation
import SwiftUI
import KollioCore

/// How a document object's **form** is drawn, decided in one table.
///
/// The problem this answers: a reference and a rich result were both white
/// rounded rectangles, told apart by a four-point radius difference and one
/// having a shadow. At ten objects on a canvas that is not a distinction anybody
/// can use, so the type of a thing was carried by a small icon while the shape
/// carried nothing.
///
/// The rule the design sets is that the *form* of a thing should help say what
/// kind of thing it is, and that a thought is allowed to be text in space rather
/// than a card. So each form gets a silhouette, and the silhouette is data rather
/// than a set of modifiers spread across a view — which is also what makes it
/// checkable: a test can read this table, and it cannot read a screenshot.
public struct NodeAppearance: Equatable, Sendable {
    /// How strong the object's own edge is.
    public enum Boundary: String, Sendable, Equatable {
        /// No edge at rest. For a thought, which is text in space.
        case none
        /// A hairline, and nothing else. A durable outline, not an elevation.
        case hairline
        /// A hairline plus a rule along the leading edge: the shape of a section
        /// of a document rather than the shape of an object sitting on one.
        case ruled
    }

    /// The radius token, named rather than measured, so the number lives in one
    /// place and the choice lives in the table.
    public let radiusToken: String
    public let radius: Double
    public let boundary: Boundary

    /// Whether the object is lifted off the canvas by a shadow.
    ///
    /// `false` for every form, and that is the point. The design says shadows are
    /// not the default way to express hierarchy and that a persistent node carries
    /// little or none; a shadow on a document object makes it look like a card
    /// floating over the work rather than part of it.
    public let isLifted: Bool

    /// A thought is the one form with no surface, and it keeps that.
    public var hasSurface: Bool { boundary != .none }
}

public enum NodeAppearanceTable {
    /// The whole vocabulary. Three forms, three silhouettes, no fourth.
    public static let appearances: [ContentObject.Form: NodeAppearance] = [
        // Text in space. No edge, no surface, nothing to lift. The only form that
        // may not be cardified, because a canvas of cards is the failure mode.
        .thought: NodeAppearance(
            radiusToken: "control",
            radius: Radius.control,
            boundary: .none,
            isLifted: false
        ),
        // A source: compact, durable, bounded by a hairline. It is a thing that
        // exists, not a passage of the document, so it gets a closed shape.
        .reference: NodeAppearance(
            radiusToken: "reference",
            radius: Radius.reference,
            boundary: .hairline,
            isLifted: false
        ),
        // A rich result is content the document produced, so it reads as a
        // *section* of the document: the same surface, plus a rule down the
        // leading edge. Two shapes, no new colour, no new radius token.
        .richResult: NodeAppearance(
            radiusToken: "richBlock",
            radius: Radius.richBlock,
            boundary: .ruled,
            isLifted: false
        )
    ]

    public static func appearance(for form: ContentObject.Form) -> NodeAppearance {
        // Falling back to the quietest form rather than to a card: an unknown
        // form must not acquire an edge it did not ask for.
        appearances[form] ?? appearances[.thought]!
    }
}
