import Foundation
import KollioCore

/// The names a UI test looks for.
///
/// Every one of these is a fact about what a thing **is**, never where it is and
/// never what it happens to be called in this build. A test that has to know a
/// coordinate, or a label, is a test that breaks when somebody moves something, and
/// the day it breaks is the day somebody deletes the test rather than the button.
///
/// The identifiers are here rather than inline in the views for one reason: a test
/// and the view it drives must agree, and two string literals in two files do not
/// agree, they merely happen to. `AXIDTests` reads every value out of the running
/// interface and fails if one of them is not there, so a rename cannot leave a test
/// pointing at nothing.
public enum AXID {
    /// The sentence a person types to start a document.
    public static let entryField = "kollio.entry.field"
    /// The action that turns that sentence into a document.
    public static let entrySubmit = "kollio.entry.explore"

    /// The canvas itself, so a test can tell a blank window from a canvas.
    public static let canvas = "kollio.canvas"
    /// One object on the canvas. Suffix the object id, never a screen position.
    public static func node(_ objectID: ObjectID) -> String { "kollio.node.\(objectID.rawValue)" }

    /// The contextual actions of the current selection.
    public static let contextualActions = "kollio.actions"
    /// One contextual action, by its kind rather than by its label.
    public static func action(_ kind: String) -> String { "kollio.action.\(kind)" }

    /// The cards. Each is named so a test can say "the search card is on screen"
    /// instead of "some text is somewhere".
    public static let searchCard = "kollio.card.search"
    public static let presentationCard = "kollio.card.presentation"
    public static let attributionPanel = "kollio.card.attribution"
    public static let summaryCard = "kollio.card.summary"
    public static let comparisonCard = "kollio.card.comparison"
    public static let impactCard = "kollio.card.impact"

    /// The quiet line at the foot of the canvas.
    public static let status = "kollio.status"
    /// The line of running text while an answer is arriving.
    public static let progress = "kollio.progress"

    /// The name the application is launched under, and therefore the one a test
    /// asks for when it says "the app".
    public static let application = "dev.kollio.app"
}
