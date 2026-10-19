import Foundation
import KollioCore

/// What a relationship looks like, decided in one table.
///
/// The reason this is a table and not the drawing code: a relationship's kind is
/// the reasoning of the document, and the design says the reasoning must be
/// readable from the topology. Through spring 2026 the layer drew every kind the
/// same way — one solid stroke, one colour — so the only way to tell that a thing
/// *contradicts* rather than *supports* was to read a twelve-point label at every
/// connector. A document with ten relations is not readable that way; it is ten
/// small reading tasks.
///
/// The rule the design sets is a small vocabulary, because a connector vocabulary
/// with a separate style per meaning becomes UML, and then the lines stop being
/// read at all. So this table has one axis: the pairs of kinds whose meanings
/// oppose each other get a **marker on the stroke**, and nothing else gets
/// anything. Marker, not colour — a second colour would say "special" before it
/// says what, and the kind's label is already the honest place for the detail.
///
/// Nothing here touches the text itself: the label keeps its own colour and
/// weight, because opacity and weight of *meaning* must not be expressed by
/// making meaning hard to read.
public enum RelationshipAppearance {
    /// What distinguishes kinds that oppose each other.
    public enum Treatment: String, Sendable, Equatable {
        /// Plain. The common case, and the only one that was drawn before.
        case plain
        /// A single short bar across the stroke: the sign of a relation that
        /// *asserts* something's support, read as a plus at a distance.
        case support
        /// Two short bars across the stroke: the negation of the above. Two
        /// rather than a different shape because the pairing is the meaning.
        case contradiction
    }

    /// The one pairing the table encodes, and why there are not more.
    ///
    /// `supports` and `contradicts` are the only two kinds in the document whose
    /// relationship to each other is a negation. `dependsOn` and `constrains` look
    /// like a pair but are not: one says the reasoning leans on a thing, the other
    /// says it holds a thing back, and neither cancels the other. Encoding them
    /// with more markers is how a connector vocabulary turns into a diagram
    /// notation nobody reads.
    public static func treatment(for kind: Relationship.Kind?) -> Treatment {
        switch kind {
        case .supports: return .support
        case .contradicts: return .contradiction
        default: return .plain
        }
    }

    /// The gap a marking stroke keeps from the mid-point of a connector, in
    /// points, so the marker reads as "at the middle" rather than as a tick.
    public static let markerSpan: Double = 7
}
