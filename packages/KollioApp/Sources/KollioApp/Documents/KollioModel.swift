import Foundation
import Observation
import KollioCore

/// Where a `.kollio` document lives on this machine.
public struct DocumentFileStore: Sendable {
    public let directory: URL

    /// Where documents live, and why that can be pointed somewhere else.
    ///
    /// `KOLLIO_DOCUMENTS` names a directory, and the app uses it instead of its own
    /// folder. It exists because a UI test that drives the real window has to start
    /// from a known state, and because a test that writes to somebody's documents
    /// is a test that loses their work. It is also the difference between two copies
    /// of the app sharing one set of files and not.
    ///
    /// It is not a setting a person is offered: there is no control panel, and
    /// nothing in the interface changes when it is set.
    public static func documentsDirectoryFromEnvironment() -> URL? {
        guard let path = ProcessInfo.processInfo.environment["KOLLIO_DOCUMENTS"],
              path.isEmpty == false else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else if let overridden = Self.documentsDirectoryFromEnvironment() {
            self.directory = overridden
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = base.appendingPathComponent("Kollio/Documents", isDirectory: true)
        }
    }

    public var defaultDocumentURL: URL {
        directory.appendingPathComponent("Kollio.\(DocumentCodec.fileExtension)")
    }

    /// The document a launch should open.
    ///
    /// The default file when it exists, and otherwise the most recently written
    /// document in the directory. This is what makes "a new document gets its
    /// own file" work across launches: the previous document stays on disk and
    /// is not overwritten, and the newest one is the one that was being worked
    /// on.
    /// The newest document on disk, whatever its name.
    ///
    /// The default file used to win whenever it existed, on the grounds that it was
    /// the one a launch means to open. That made an empty document immortal: a
    /// launch that found nothing saved an empty document to the default name, and
    /// from then on every launch preferred it over real work written later. On this
    /// machine that file was written at 12:08 and every launch since opened nothing,
    /// while documents written minutes earlier sat on disk unopened. A name is not a
    /// claim about which document is the work; the date is.
    public var mostRecentDocumentURL: URL? {
        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ))?.filter { $0.pathExtension == DocumentCodec.fileExtension } ?? []
        return candidates.max { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if left != right { return left < right }
            // Two documents written inside the same second share a modification
            // date, and a comparison that ties leaves the winner to whatever order
            // the directory happens to be read in. The names are minted with a
            // sortable stamp, `Kollio-yyyyMMdd-HHmmss-XXXX`, so the name is a
            // second, deterministic ordering. It depends on that stamp, which is
            // why it is written down here rather than left implicit.
            return lhs.lastPathComponent < rhs.lastPathComponent
        }
    }

    public func url(named name: String) -> URL {
        directory.appendingPathComponent("\(name).\(DocumentCodec.fileExtension)")
    }

    /// A stable, human-readable file target for a document title.
    ///
    /// The title remains untouched in the document. Only characters that can
    /// change path meaning are replaced in the registry filename.
    public func availableURL(named title: String, excluding currentURL: URL? = nil) -> URL {
        let forbidden = CharacterSet(charactersIn: "/:\0")
        let filename = title.unicodeScalars.map { scalar in
            forbidden.contains(scalar) ? "-" : String(scalar)
        }.joined().trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        let base = filename.isEmpty ? "Kollio" : String(filename.prefix(120))
        var candidate = url(named: base)
        var suffix = 2
        while candidate.standardizedFileURL != currentURL?.standardizedFileURL,
              FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url(named: "\(base) \(suffix)")
            suffix += 1
        }
        return candidate
    }

    public func load(_ url: URL) throws -> KollioDocument {
        try DocumentCodec.read(from: url)
    }

    public func save(_ document: KollioDocument, to url: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try DocumentCodec.write(document, to: url)
    }
}

/// A proposal being previewed as a ghost branch, before the user keeps it.
public struct ProposalPreview: Identifiable, Equatable {
    public var id: String { proposal.proposalId }
    public var proposal: Proposal
    /// Where each proposed object would appear.
    public var placements: [ObjectID: Position]
    public var objectIDs: [ObjectID]
    public var relationshipIDs: [RelationshipID]
    /// The object the branch grows from.
    public var anchorID: ObjectID
    /// The short, user-facing sentence shown next to the proposal.
    public var rationale: String
    public var summary: String
    /// What the generator was shown, resolved against the document.
    ///
    /// Carried on the preview rather than recomputed on demand, so the panel and
    /// the ghost branch always describe the same request. A reference that no longer
    /// resolves is kept and marked: dropping it would change what the proposal
    /// appears to have been based on.
    public var readRefs: [ProposalInputRef] = []

    public static func == (lhs: ProposalPreview, rhs: ProposalPreview) -> Bool {
        lhs.id == rhs.id && lhs.placements == rhs.placements
    }
}

/// The live editor state: the document, the camera, the selection, and the
/// proposal currently being previewed. Views read it; they never mutate the
/// document behind its back.
@MainActor
@Observable
public final class KollioModel {
    public enum Intent {
        case explore
        case add
        case setAside
        case edit
    }

    // MARK: State
    public private(set) var session: KollioSession
    public var camera: Camera = .identity
    public var viewport: Size = Size(width: 1200, height: 800)
    public var selection: Set<ObjectID> = []
    /// The relation on screen, if one is. Never alongside an object selection.
    public var selectedRelationshipID: RelationshipID?
    public var hoveredObjectID: ObjectID?
    public var frames: [ObjectID: Rect] = [:]
    public var preview: ProposalPreview?
    /// The synthesis the card is showing, if one is open. Transient like every
    /// other card: it is where a person is looking, not a fact about the document.
    public var openSummaryID: SummaryID?
    /// The experiment card that is open, if one is.
    ///
    /// Transient like every card on this canvas, and a reading of what was built:
    /// it writes nothing, so closing it writes nothing either.
    public var openExperimentID: ExperimentID?
    /// The history timeline that is open, if one is.
    ///
    /// DEC-06: a temporary contextual timeline. It reads the journal and writes
    /// nothing, so the present is always exactly where the person left it.
    public var openHistoryID: ObjectID?
    /// Whether the proposal's attribution panel is open. Transient, and closed by
    /// default: the destination and what was read are things a person asks for, not
    /// something the interface puts in front of them every time.
    public var showsProposalAttribution = false
    /// The request behind the proposal currently on screen, kept so the attribution
    /// panel and the ghost branch always describe the same one.
    public var lastRequest: ProposalRequest?
    public var isThinking = false
    /// How far a streaming answer has got. It is display only: a progress carries
    /// no identifier and cannot be kept, so it is never a preview and never
    /// reaches the command system. It is cleared the moment the request ends,
    /// whatever the outcome.
    public var progress: ProposalProgress?
    public var status: String?
    public var composer: ComposerState?
    public var languageCode: String = KollioModel.systemLanguage
    public var documentURL: URL
    /// Set when a stored document existed but could not be read. The canvas shows
    /// the problem instead of quietly loading something else, and the unreadable
    /// file is never written over.
    public private(set) var loadFailure: (any Error)?

    /// The intelligence source. Offline and deterministic by default; the
    /// backend adapter is interchangeable.
    public var service: any SuggestionService

    /// What the app is really talking to, so the status line can say so without
    /// a control panel.
    public private(set) var serviceMode: ServiceConfiguration = .demo

    public let fileStore: DocumentFileStore

    public struct ComposerState: Equatable, Identifiable {
        public var id = UUID()
        /// The object the input is attached to.
        public var anchorID: ObjectID
        public var text: String = ""
        public var intent: Intent = .add
        /// The object's version when this draft was opened, for an edit.
        ///
        /// CAN-04: a conflict "shows my version and the current one, and never
        /// closes the input without recovery". Remembering what the person was
        /// looking at is what lets the interface say so instead of overwriting.
        public var baseVersion: Int?
    }

    public static let systemLanguage: String = {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        return ["fr", "en"].contains(code) ? code : "en"
    }()

    // MARK: Life cycle

    public init(
        document: KollioDocument? = nil,
        service: (any SuggestionService)? = nil,
        fileStore: DocumentFileStore = DocumentFileStore(),
        languageCode: String = KollioModel.systemLanguage,
        mode: ServiceConfiguration? = nil
    ) {
        self.fileStore = fileStore
        self.languageCode = languageCode
        // A launch opens the default file when there is one, and otherwise the
        // document that was written most recently.
        let url = fileStore.mostRecentDocumentURL ?? fileStore.defaultDocumentURL
        self.documentURL = url
        if let service {
            // An explicit service, as the tests use.
            self.service = service
            self.serviceMode = mode ?? .demo
        } else {
            // The source the environment actually configured, resolved once.
            let resolved = KollioModel.makeConfiguredService(languageCode: languageCode)
            self.service = resolved.service
            self.serviceMode = resolved.mode
        }
        if let document {
            // Explicit document, as the tests and the demo use.
            self.session = KollioSession(document: document)
            self.loadFailure = nil
        } else if FileManager.default.fileExists(atPath: url.path) {
            // A document exists. If it cannot be read, that is reported and the
            // file is left alone: overwriting it with a demo would destroy work
            // the user could still recover by hand.
            do {
                self.session = KollioSession(document: try fileStore.load(url))
                self.loadFailure = nil
            } catch {
                self.session = KollioSession(document: KollioDocument())
                self.loadFailure = error
            }
        } else {
            // Nothing stored: the first experience, and no fixture.
            self.session = KollioSession(document: KollioDocument())
            self.loadFailure = nil
        }
    }

    static func makeDemoService(languageCode: String) -> LocalDemoSuggestionService {
        LocalDemoSuggestionService(context: .init(
            language: languageCode,
            authored: SarahFixture.authoredExpansions
        ))
    }

    /// The model a normal launch gets. Separate from `init` so the default
    /// arguments used by tests stay deterministic.
    public static func makeAppModel() -> KollioModel {
        KollioModel()
    }

    /// A model pinned to the deterministic engine, for tests and previews.
    ///
    /// The deterministic suite must never depend on whether the Mac it runs on
    /// has a usable on-device model, and must never make a real generation. Every
    /// test that needs a service asks for this one explicitly rather than
    /// inheriting the launch default.
    public static func deterministicModel(
        document: KollioDocument? = nil,
        fileStore: DocumentFileStore = DocumentFileStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()))
    ) -> KollioModel {
        KollioModel(
            document: document,
            service: makeDemoService(languageCode: "fr"),
            fileStore: fileStore,
            mode: .demo
        )
    }

    /// What the app says about on-device intelligence right now, and nothing
    /// more. The status line uses this; no panel is added to the canvas.
    public var appleAvailability: AppleModelAvailability? {
        (service as? AppleLocalSuggestionService)?.availability
    }

    /// Builds the service the environment asks for, and records what was really
    /// chosen. A server that cannot be reached is reported as an error, never
    /// quietly replaced by the demo engine, and an unavailable on-device model is
    /// reported as a refusal, never quietly replaced either.
    public static func makeConfiguredService(
        languageCode: String,
        configuration: ServiceConfiguration = ServiceConfiguration.fromEnvironment().configuration,
        token: String? = nil
    ) -> (service: any SuggestionService, mode: ServiceConfiguration) {
        switch configuration {
        case .apple:
            return (AppleLocalSuggestionService(), .apple)
        case .demo:
            return (makeDemoService(languageCode: languageCode), .demo)
        case .server(let baseURL):
            guard let token, token.isEmpty == false else {
                return (makeDemoService(languageCode: languageCode), .demo)
            }
            return (RemoteSuggestionService(baseURL: baseURL, token: token), configuration)
        }
    }

    // MARK: Document access

    public var document: KollioDocument { session.document }

    /// How a chosen file is read. Injectable so a test can hand over a file it made
    /// itself rather than reaching for the user's disk.
    public var sourceReader = SourceReader()

    public func object(_ id: ObjectID) -> ContentObject? { document.object(id) }

    public func text(of id: ObjectID) -> String {
        guard let object = document.object(id) else { return "" }
        return object.text.resolve(languageCode: languageCode)
    }

    public func detail(of id: ObjectID) -> String? {
        document.object(id)?.detail?.resolve(languageCode: languageCode)
    }

    public func label(of id: RelationshipID) -> String? {
        document.relationship(id)?.label?.resolve(languageCode: languageCode)
    }

    /// Reason of the active decision that set this object aside, if any.
    public func setAsideReason(of id: ObjectID) -> String? {
        guard let decisionID = document.object(id)?.setAsideByDecision,
              let decision = document.decisions[decisionID] else { return nil }
        return decision.rationale?.resolve(languageCode: languageCode)
    }

    /// A direction closed by a durable decision can be reopened.
    public func canReopen(_ id: ObjectID) -> Bool {
        document.object(id)?.isSetAside == true
    }

    /// The roots of the branches that were set aside. They stay on the canvas:
    /// a rejected direction is compact, not deleted.
    public var collapsedRoots: Set<ObjectID> {
        Set(
            document.decisions.values
                .filter { $0.status == .active && $0.kind == .setAside }
                .map(\.targetObjectID)
        )
    }

    /// Objects the canvas actually draws: everything active, plus the root of
    /// each collapsed direction, plus whatever a search has opened up.
    public var visibleInstances: [NodeInstance] {
        let roots = collapsedRoots
        // Folded frames hide the drawings they hold, in this view only. An object
        // drawn again outside the frame is a different occurrence and stays.
        let folded = document.presentation.hiddenInstanceIDs()
        return document.presentation.instances.filter { instance in
            guard let object = document.object(instance.objectID) else { return false }
            // A search result is shown by showing it. This is the whole of the
            // reveal: the view changes, the document does not.
            if revealedBySearch.contains(object.id) { return true }
            if folded.contains(instance.id) { return false }
            if object.isSetAside { return roots.contains(object.id) }
            return !isHiddenByCollapsedAncestor(instance.objectID)
        }
    }

    /// A collapsed direction hides its exclusive descendants, but nothing else.
    func isHiddenByCollapsedAncestor(_ objectID: ObjectID) -> Bool {
        for root in collapsedRoots {
            guard root != objectID,
                  document.exclusiveDescendants(of: root).contains(objectID) else { continue }
            return true
        }
        return false
    }

    public func relationshipsToRender() -> [Relationship] {
        let visibleIDs = Set(visibleInstances.map(\.objectID))
        return document.relationships.values
            .filter { visibleIDs.contains($0.from) && visibleIDs.contains($0.to) }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    // MARK: Selecting a relation

    /// The relation under a point on screen, if the point is close enough to it.
    ///
    /// CAN-06 AC01: "the line is clickable at several zooms." The tolerance is the
    /// link's own `hitArea` at the current zoom, which is wider than the stroke and
    /// grows as the view shrinks, so a distant link stays as easy to catch as a
    /// nearby one. Hit testing uses the same routed path the layer draws, so what
    /// is catchable is what is visible.
    public func relationship(near point: Position) -> RelationshipID? {
        let zoom = camera.zoom
        let obstacles = RelationshipGeometry.ObstacleSet(hitTestObstacles())
        var best: (RelationshipID, Double)?
        for relationship in relationshipsToRender() {
            guard let anchors = screenAnchors(for: relationship) else { continue }
            let tolerance = relationship.hitArea(zoom: zoom) / 2
            // Every route, direct or detoured, stays inside the corridor
            // routedRoute draws around the chord, so a point outside that
            // corridor (grown by the tolerance) cannot be within tolerance of
            // any route. The check is four comparisons; the routing it skips is
            // what cost 10 ms per click at 200 relationships, because it used to
            // run for every link on every click, including the ones nowhere
            // near the pointer.
            let dx = anchors.end.point.x - anchors.start.point.x
            let dy = anchors.end.point.y - anchors.start.point.y
            let chordLength = (dx * dx + dy * dy).squareRoot()
            let corridor = RelationshipGeometry.corridorFor(
                start: anchors.start.point,
                end: anchors.end.point,
                width: chordLength * 0.8 + RelationshipGeometry.clearance * 2 + 68 + tolerance
            )
            guard corridor.contains(point) else { continue }
            guard let route = route(for: relationship, anchors: anchors, in: obstacles) else { continue }
            let distance = route.distance(to: point)
            guard distance <= tolerance else { continue }
            // Two links crossing: the nearer one wins, so the answer does not depend
            // on the order the document happens to store them in.
            if best == nil || distance < best!.1 {
                best = (relationship.id, distance)
            }
        }
        return best?.0
    }

    private func hitTestObstacles() -> [(id: ObjectID, rect: Rect)] {
        var rects: [(id: ObjectID, rect: Rect)] = []
        rects.reserveCapacity(document.presentation.instances.count)
        for instance in visibleInstances {
            guard let frame = frame(of: instance.objectID) else { continue }
            rects.append((instance.objectID, camera.toScreen(frame)))
        }
        return rects
    }

    /// The two screen anchors of one relationship, drag offset folded in, before
    /// any routing decision.
    private func screenAnchors(for relationship: Relationship) -> (start: AnchorPoint, end: AnchorPoint)? {
        guard let fromFrame = frame(of: relationship.from),
              let toFrame = frame(of: relationship.to) else { return nil }
        let fromRect = offsetRect(fromFrame, by: relationship.from)
        let toRect = offsetRect(toFrame, by: relationship.to)
        let (start, end) = RelationshipGeometry.endpoints(of: relationship, from: fromRect, to: toRect)
        return (
            AnchorPoint(point: camera.toScreen(start.point), direction: start.direction),
            AnchorPoint(point: camera.toScreen(end.point), direction: end.direction)
        )
    }

    private func route(
        for relationship: Relationship,
        anchors: (start: AnchorPoint, end: AnchorPoint),
        in obstacles: RelationshipGeometry.ObstacleSet
    ) -> ConnectorRoute? {
        RelationshipGeometry.routedRoute(
            from: anchors.start,
            to: anchors.end,
            obstacles: obstacles.excluding(relationship.from, relationship.to)
        )
    }

    private func offsetRect(_ rect: Rect, by objectID: ObjectID) -> Rect {
        let offset = dragOffset(for: objectID)
        guard offset != .zero else { return rect }
        return Rect(origin: rect.origin.offset(dx: offset.x, dy: offset.y), size: rect.size)
    }

    /// The relation on screen, or nothing.
    ///
    /// Selecting a relation is its own thing, separate from the object selection:
    /// a link is not an object, and selecting it must not quietly add two nodes to
    /// the selection and put their inspector up.
    public func selectRelationship(_ id: RelationshipID?, extending: Bool = false) {
        if let id, extending {
            if selectedRelationshipID == id { selectedRelationshipID = nil } else { selectedRelationshipID = id }
        } else {
            selectedRelationshipID = id
        }
        if selectedRelationshipID != nil { selection = [] }
    }

    public var selectedRelationship: Relationship? {
        selectedRelationshipID.flatMap { document.relationship($0) }
    }

    /// What a selected relation says, or nothing.
    ///
    /// Nil when either end is not in the document: a sentence with a missing end
    /// reads as a fact about something that is not there.
    public func sentence(for id: RelationshipID) -> RelationshipSentence? {
        document.relationship(id)?.sentence(in: document, languageCode: languageCode)
    }

    /// Change what a relation says.
    ///
    /// CAN-06 makes this explicit rather than a drag, so it goes through a named
    /// command and the same validated transaction as everything else. A refused edit
    /// is reported, not swallowed: "this link already says that" is the answer a
    /// person needs when they try to reverse something that means the same either
    /// way.
    @discardableResult
    public func editRelationship(_ id: RelationshipID, _ edit: RelationshipEdit) -> Bool {
        perform(
            [.editRelationship(.init(id: id, edit: edit, provenance: .human(ActorID("owner"))))],
            label: "undo.editRelationship"
        )
    }

    public func connectionsToRender(around objectID: ObjectID) -> [Relationship] {
        relationshipsToRender().filter { $0.from == objectID || $0.to == objectID }
    }

    // MARK: Geometry

    /// World rectangle of an object: the measured one when available.
    public func frame(of objectID: ObjectID) -> Rect? {
        if let measured = frames[objectID] { return measured }
        guard let object = document.object(objectID),
              let instance = document.presentation.instance(for: objectID) else { return nil }
        let size = instance.size ?? NodeLayout.estimatedSize(for: object)
        return Rect(origin: instance.position, size: size)
    }

    public func recordFrame(_ rect: Rect, for objectID: ObjectID) {
        guard frames[objectID] != rect else { return }
        frames[objectID] = rect
    }

    public func contentBounds() -> Rect? {
        let rects = visibleInstances.compactMap { document.object($0.objectID) }.compactMap { frame(of: $0.id) }
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    public func fitContent(animated: Bool = true) {
        guard let bounds = contentBounds() else { return }
        camera = Camera.fitting(content: bounds, viewport: viewport, padding: 120)
        _ = animated
    }

    // MARK: Selection

    public func select(_ id: ObjectID?, extending: Bool = false) {
        // Choosing an object puts the selected link down. A link and an object are
        // two different selections with two different inspectors, and holding both
        // after one click is a state nothing in the interface can explain.
        if id != nil { selectedRelationshipID = nil }
        if let id {
            if extending {
                if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
            } else {
                selection = [id]
            }
        } else {
            selection = []
        }
        if selection.count > 1 { preview = nil }
    }

    public var primarySelection: ObjectID? { selection.sorted { $0.rawValue < $1.rawValue }.first }

    /// Drops from the selection any object that is no longer in the document.
    ///
    /// CAN-02: an object removed elsewhere "clears the selection and explains if
    /// an edit was active, and never selects something else." Pruning is the only
    /// place that rule lives, so undo, redo and a remote change all obey it.
    public func pruneSelection() {
        selection = selection.filter { document.object($0) != nil }
    }

    /// The transient surfaces that Escape can close, in the order a person leaves
    /// them: the deepest open thing first, the selection last.
    ///
    /// CAN-02 AC03: "Escape closes one level, then the selection." Closing
    /// everything at once is a different behaviour, and a worse one — a person who
    /// meant to dismiss a draft loses the selection they had built up.
    public enum TransientLevel: Equatable {
        case composer
        case claimDraft
        case stanceDraft
        case citation
        case readingSource
        case frameName
        case search
        case presentation
        case resultDraft
        case experiment
        case history
        case comparison
        case impactReview
        case preview
        case selection

        /// The level Escape would close right now, or nil when there is nothing
        /// transient left. A drag owns the pointer, so it is not dismissible here.
        @MainActor
        public static func topmost(in model: KollioModel) -> TransientLevel? {
            if model.composer != nil { return .composer }
            if model.claimDraft != nil { return .claimDraft }
            if model.stanceDraft != nil { return .stanceDraft }
            if model.openCitationClaim != nil { return .citation }
            if model.readingSourceID != nil { return .readingSource }
            if model.renamingFrameID != nil { return .frameName }
            // The search is above everything it can be reading: it is the one card
            // that is about the whole document rather than about a selection.
            if model.search != nil { return .search }
            // A tour is a mode rather than a card, so it is above everything: Escape
            // leaves the reading rather than closing one field inside it.
            if model.presentation != nil { return .presentation }
            if model.resultDraft != nil { return .resultDraft }
            if model.openExperimentID != nil { return .experiment }
            if model.openHistoryID != nil { return .history }
            if model.openComparison != nil { return .comparison }
            // The impact review sits above the selection, and below the citations it
            // is read from: it is a card about a claim, so it closes before the
            // claim's own evidence list does.
            if model.impactAssessment != nil { return .impactReview }
            if model.preview != nil { return .preview }
            if !model.selection.isEmpty { return .selection }
            return nil
        }
    }

    /// Closes exactly one level. Returns the level it closed, so a caller can
    /// report it and a test can assert it.
    @discardableResult
    public func dismissOneLevel() -> TransientLevel? {
        switch TransientLevel.topmost(in: self) {
        case .composer:
            // A closed composer keeps its draft; the draft belongs to the target,
            // not to the surface.
            composer = nil
            return .composer
        case .claimDraft:
            claimDraft = nil
            return .claimDraft
        case .stanceDraft:
            stanceDraft = nil
            return .stanceDraft
        case .citation:
            openCitationClaim = nil
            return .citation
        case .readingSource:
            readingSourceID = nil
            return .readingSource
        case .resultDraft:
            // A closed draft keeps nothing and changes nothing: what was typed
            // and never submitted was never recorded.
            resultDraft = nil
            return .resultDraft
        case .experiment:
            // Closing the card writes nothing: it is a reading of what was built,
            // and the experiments stay exactly as they are.
            openExperimentID = nil
            return .experiment
        case .history:
            // DEC-06 AC02: returning to the present mutates nothing. The
            // timeline is a reading of the journal, and closing it is leaving
            // a reading, which is not a change.
            openHistoryID = nil
            return .history
        case .comparison:
            // Closing the comparison writes nothing: it is a reading of the document
            // and the cells already recorded stay exactly where they are.
            openComparison = nil
            return .comparison
        case .search:
            // Closing a search forgets the reveal and writes nothing. The person
            // looked; looking is not a decision and there is nothing to undo.
            search = nil
            revealedBySearch = []
            return .search
        case .presentation:
            // Leaving a tour puts the view back exactly where it was, and writes
            // nothing: a reading is not a change.
            exitPresentation()
            return .presentation
        case .frameName:
            // Closing the field keeps what was typed nowhere and changes nothing: a
            // rename that was never submitted was never asked for.
            renamingFrameID = nil
            renamingFrameDraft = ""
            return .frameName
        case .impactReview:
            // Closing the review applies nothing and forgets nothing: the
            // assessment was never in the document, and the citation that prompted
            // it is still marked.
            impactAssessment = nil
            impactReviewAnchor = nil
            return .impactReview
        case .preview:
            // Closing a proposal hides it. It is not a rejection and not a
            // deletion: nothing was applied and nothing is forgotten.
            preview = nil
            return .preview
        case .selection:
            selection = []
            return .selection
        case .none:
            return nil
        }
    }

    /// Used when a document is closed or reset, where there is no level to
    /// preserve.
    public func clearContextualState() {
        selection = []
        preview = nil
        composer = nil
        impactAssessment = nil
        impactReviewAnchor = nil
        renamingFrameID = nil
        renamingFrameDraft = ""
        openComparison = nil
        openExperimentID = nil
        openHistoryID = nil
        resultDraft = nil
        search = nil
        revealedBySearch = []
        presentation = nil
    }

    /// The actions offered for a selected object: at most three shown, the rest
    /// behind one named control.
    ///
    /// The set is a model fact so that `ContextualActionSet.maximumPrimary` can be
    /// checked by a test rather than trusted to a `HStack`.
    public func contextualActions(for id: ObjectID) -> ContextualActionSet {
        // The set is a model fact, and during a reading tour the fact is that there
        // are none. The command layer refuses a write either way; this is what
        // stops the buttons from being there to press.
        guard isPresenting == false else {
            return ContextualActionSet(primary: [], secondary: [], isDefault: nil)
        }
        let object = document.object(id)
        return ContextualActionSet.forObject(
            id: id,
            kind: object?.kind ?? .need,
            canReopen: canReopen(id),
            canAttachSource: object != nil,
            canAssertClaim: object != nil,
            canReviewImpact: document.needsImpactReview(id),
            canGroupInFrame: selection.isEmpty == false,
            canCompareDirections: selection.count >= 2,
            // A synthesis reads the document rather than a selection, so it is
            // offered whenever the document has anything in it. With nothing in it
            // the composer would produce four empty sections and a card saying
            // nothing, which is a worse answer than no action.
            canComposeSynthesis: document.content.isEmpty == false,
            canReviewExperiment: document.experiments.experiments(targeting: id).isEmpty == false,
            canReviewHistory: document.history.narrative(for: id, in: document).isEmpty == false
        )
    }

    // MARK: Search (CAN-09)

    /// The search that is open, if one is.
    ///
    /// Transient, like every other card on this canvas. It is a reading of the
    /// document and not a change to it, which is why closing it writes nothing and
    /// why nothing it shows is ever undoable: there is nothing to undo.
    public var search: SearchState?

    public struct SearchState: Equatable {
        /// What has been typed, kept verbatim.
        ///
        /// Kept when nothing is found, on purpose. A person who searched for
        /// something and got nothing should be able to correct the word, not to
        /// start again from an empty field.
        public var query: String
        public var outcome: DocumentSearch.Outcome?
        /// The result the person is reading, if any. The card keeps its place
        /// rather than jumping on every keystroke.
        public var selectedObjectID: ObjectID?

        public init(query: String = "", outcome: DocumentSearch.Outcome? = nil, selectedObjectID: ObjectID? = nil) {
            self.query = query
            self.outcome = outcome
            self.selectedObjectID = selectedObjectID
        }

        public var results: [DocumentSearch.Result] { outcome?.results ?? [] }
        public var hasSearched: Bool { outcome != nil }
        public var isEmpty: Bool { results.isEmpty }
    }

    /// Objects a search has opened up in this view, and nothing else.
    ///
    /// CAN-09: "Choosing a result centres on it deliberately, temporarily
    /// revealing a folded path. A revealed set-aside result is not a reversed
    /// decision." The set is the reveal, it lives here rather than in the document,
    /// and it is emptied when the card closes. Reopening stays a named action.
    public var revealedBySearch: Set<ObjectID> = []

    /// Opens the search, keeping the last query so the card is not empty every
    /// time it is summoned.
    public func openSearch() {
        if let search {
            self.search = search
        } else {
            search = SearchState()
        }
    }

    /// Runs a textual search.
    ///
    /// No model, no network, no command: the seam is not touched at all, which is
    /// CAN-09's "no intelligence for a textual search" and the reason a search
    /// costs nothing and cannot fail in a way that changes the document.
    public func updateSearch(_ text: String) {
        var state = search ?? SearchState()
        state.query = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // An empty field is not a search that found nothing, so it reports
        // nothing at all rather than "0 results".
        state.outcome = trimmed.isEmpty
            ? nil
            : DocumentSearch().search(text, in: document, languageCode: languageCode)
        state.selectedObjectID = nil
        search = state
    }

    /// Clears the query and the filter, and puts the canvas back as it was.
    public func clearSearch() {
        search = nil
        revealedBySearch = []
    }

    /// Centres on a result and opens up whatever is folded around it.
    ///
    /// Three things happen and nothing else: the object becomes visible, the view
    /// moves to it, and it is selected. No decision is touched, no lifecycle
    /// changes, and the revision does not move, which is AC02 checked by the model
    /// rather than by the interface's good manners.
    @discardableResult
    public func revealSearchResult(_ result: DocumentSearch.Result) -> Bool {
        guard document.object(result.objectID) != nil else { return false }
        revealedBySearch.insert(result.objectID)
        // The branch is opened up as well, or a result buried inside a collapsed
        // direction would show a card about something the canvas still hides.
        for id in document.descendants(of: result.objectID) { revealedBySearch.insert(id) }
        selection = [result.objectID]
        centre(on: result.objectID)
        return true
    }

    /// Moves the view onto an object without changing what is on the canvas.
    private func centre(on id: ObjectID) {
        guard let rect = frame(of: id) else { return }
        let zoom = camera.zoom
        let target = Position(
            x: viewport.width / 2 - rect.center.x * zoom,
            y: viewport.height / 2 - rect.center.y * zoom
        )
        camera = Camera(zoom: zoom, translation: target)
    }

    /// What a result means, in the interface's language. Kept out of the view so
    /// the wording can be tested and the search stays a pure value.
    public func searchStateLabel(for result: DocumentSearch.Result) -> String {
        switch result.state {
        case .visible: return L10n.searchStateVisible
        case .setAside: return L10n.searchStateSetAside
        case .archived: return L10n.searchStateArchived
        }
    }

    public func searchFieldLabel(for result: DocumentSearch.Result) -> String {
        switch result.field {
        case .title: return L10n.searchFieldTitle
        case .body: return L10n.searchFieldBody
        case .reason: return L10n.searchFieldReason
        }
    }

    // MARK: Presentation (CAN-10)

    /// The tour being followed, if one is running.
    ///
    /// Transient like every other reading surface on this canvas, and read-only by
    /// construction: a presentation cannot change the document, and the one path
    /// that applies commands refuses while it runs.
    public var presentation: PresentationSession?

    public var isPresenting: Bool { presentation != nil }

    public struct PresentationSession: Equatable {
        public var path: ReadingPath
        /// Resolved once, when the tour began. The document cannot change while a
        /// tour is running, so re-resolving on every step would be work whose
        /// answer is already known.
        public var resolution: ReadingPath.Resolution
        public var index: Int
        /// The camera as it was before the first step. CAN-10 AC02: exit returns to
        /// the previous context, so this is remembered exactly and restored
        /// exactly, not approximated by a reframe.
        public var cameraBefore: Camera
        /// Whether the camera was moved at all. A path whose points have nowhere to
        /// stand leaves the view alone, and exiting must not then "restore" a
        /// camera that never moved.
        public var didMoveCamera: Bool

        public init(
            path: ReadingPath,
            resolution: ReadingPath.Resolution,
            index: Int = 0,
            cameraBefore: Camera,
            didMoveCamera: Bool = false
        ) {
            self.path = path
            self.resolution = resolution
            self.index = index
            self.cameraBefore = cameraBefore
            self.didMoveCamera = didMoveCamera
        }

        public var entry: ReadingPath.Entry? {
            resolution.entries.indices.contains(index) ? resolution.entries[index] : nil
        }
        public var count: Int { resolution.entries.count }
        /// One-based, for a person counting. A progress line that starts at zero
        /// reads as "nothing done yet" on the first step.
        public var position: Int { count == 0 ? 0 : index + 1 }
    }

    /// Starts a tour, following the document's reading order unless a path is
    /// given.
    ///
    /// Refused on an empty tour rather than opened over nothing: a presentation with
    /// no steps is a card that says "0 of 0" and a reader's time.
    @discardableResult
    public func beginPresentation(path: ReadingPath? = nil) -> Bool {
        let chosen = path ?? ReadingPath.automatic(in: document)
        let resolution = chosen.resolved(in: document, languageCode: languageCode)
        guard resolution.isEmpty == false else {
            status = L10n.presentationNothingToPresent
            return false
        }
        presentation = PresentationSession(path: chosen, resolution: resolution, cameraBefore: camera)
        // Cards opened before the tour would sit on top of it, and a reading mode
        // with a claim editor open is a trap rather than a reading. The search goes
        // too: its query is kept in the card, which can be summoned again, and a
        // tour has its own navigation.
        search = nil
        composer = nil
        claimDraft = nil
        stanceDraft = nil
        openCitationClaim = nil
        openComparison = nil
        preview = nil
        impactAssessment = nil
        status = nil
        return presentCurrentStep()
    }

    /// One step forward, and no further than the last one.
    @discardableResult
    public func advancePresentation() -> Bool {
        guard var session = presentation, session.index + 1 < session.count else { return false }
        session.index += 1
        presentation = session
        return presentCurrentStep()
    }

    /// One step back, and no further than the first one.
    ///
    /// It stops at the ends rather than wrapping. A tour that wraps is a carousel,
    /// and the reader loses track of where they are in the document.
    @discardableResult
    public func rewindPresentation() -> Bool {
        guard var session = presentation, session.index > 0 else { return false }
        session.index -= 1
        presentation = session
        return presentCurrentStep()
    }

    /// Leaves the tour and puts the view back where it was.
    public func exitPresentation() {
        guard let session = presentation else { return }
        if session.didMoveCamera { camera = session.cameraBefore }
        presentation = nil
    }

    /// Opens the source a step points at.
    ///
    /// Reading is not changing, so this stays available while a tour is running,
    /// which is the whole of "keeps source and navigation".
    public func openPresentedSource(_ point: ReadingPath.Point) {
        guard case .source(let id) = point else { return }
        readingSourceID = id
    }

    /// Moves the view onto the current point, when there is one to move onto.
    private func presentCurrentStep() -> Bool {
        guard var session = presentation, let entry = session.entry else { return false }
        guard let anchor = entry.anchorObjectID else {
            // A source nothing cites has no place on the canvas. The card says so;
            // the view does not move to nowhere.
            return true
        }
        revealedBySearch.insert(anchor)
        selection = [anchor]
        centre(on: anchor)
        session.didMoveCamera = true
        presentation = session
        return true
    }

    // MARK: Impact of new information

    /// The assessment being read, if one is open.
    ///
    /// Transient, like the composer and the citations: it appears where the person
    /// is working and goes away when they move on. It is never in the document,
    /// because an assessment is a reading of the document rather than a change to
    /// it. What is in the document is what applying it records.
    public var impactAssessment: ImpactAssessment?

    /// The object the review was opened from, so the card sits beside the claim the
    /// person was looking at rather than beside whatever happened to be first in
    /// the list.
    public var impactReviewAnchor: ObjectID?

    /// Whether a person should be offered the review for this object.
    public func needsImpactReview(_ id: ObjectID) -> Bool {
        document.needsImpactReview(id)
    }

    /// Works out what new information touched, and opens the answer beside the
    /// object.
    ///
    /// Local, synchronous and immediate. No intelligence is consulted, and that is
    /// not a shortcut: the assessment is built from the document's own citations
    /// and links, and the specification asks for propagation that "does not depend
    /// on the provider". A model is allowed to *interpret* the result afterwards
    /// and is refused the command that would apply it.
    ///
    /// Returns false and says why when there is nothing to assess, rather than
    /// opening an empty card: a review of nothing is a dead end.
    @discardableResult
    public func reviewImpact(of objectID: ObjectID) -> Bool {
        let moved = document.sources.citations(supporting: objectID)
            .first { citation in
                switch citation.status {
                case .needsReview, .sourceMissing: return true
                case .unverified, .verified: return false
                }
            }
        guard let assessment = moved.flatMap({ document.impactAssessment(for: $0) }) else {
            status = L10n.impactNothingMoved
            return false
        }
        impactAssessment = assessment
        impactReviewAnchor = objectID
        // One card under one object. The citations card would otherwise open at the
        // same point as this one, which is two overlapping cards and neither of them
        // readable. The citations are still on the object, one click away.
        openCitationClaim = nil
        readingSourceID = nil
        // Reading an assessment is not a commitment, so it leaves the selection
        // alone: the person is still working on the same object.
        return true
    }

    /// Records the objects the assessment marks, as one transaction and one undo.
    ///
    /// The decision identifiers are minted here rather than in the store, because
    /// the model is the actor that owns this document and identifiers are not
    /// something a value type should invent while applying a patch.
    @discardableResult
    public func applyImpactReview() -> Bool {
        guard let assessment = impactAssessment, assessment.isEmpty == false else {
            status = L10n.impactNothingMoved
            return false
        }
        let decisionIDs = assessment.proposedChanges.map { _ in
            DecisionID("decision:" + UUID().uuidString)
        }
        guard perform([.applyImpact(.init(
            assessment: assessment, decisionIDs: decisionIDs, provenance: .human("local-user")
        ))], label: L10n.undoApplyImpact) else { return false }
        // The marks are in the document now, so the reading of it is spent. What
        // was marked is still on the canvas, still active, and still readable.
        impactAssessment = nil
        impactReviewAnchor = nil
        status = L10n.impactMarked(assessment.proposedChanges.count)
        return true
    }

    /// Closes the assessment without recording anything.
    public func dismissImpactReview() {
        impactAssessment = nil
        impactReviewAnchor = nil
    }


    // MARK: Comparison

    /// The comparison being read, if one is open. Transient like every other card:
    /// it appears beside the work and goes away when the person moves on.
    public var openComparison: ComparisonID?

    public func comparison(_ id: ComparisonID) -> Comparison? {
        document.comparisons.comparison(id)
    }

    public var openSummaryBlock: SummaryExport.CompactBlock? {
        guard let summary = openSummary else { return nil }
        return SummaryExport.compact(summary, against: document, languageCode: languageCode)
    }

    public var openComparisonModel: Comparison? {
        openComparison.flatMap { comparison($0) }
    }

    /// Opens a comparison over the current selection, as a draft.
    ///
    /// Draft because the criteria are a question the person has not agreed to yet,
    /// and a draft accepts no cell at all: a criterion nobody confirmed can never
    /// hold a value, so nothing is recorded against a question that was never asked.
    @discardableResult
    public func startComparison(over selected: Set<ObjectID>? = nil) -> ComparisonID? {
        let directions = (selected ?? selection).sorted { $0.rawValue < $1.rawValue }
        guard directions.count >= 2 else {
            // Comparing one thing with nothing is a note, and offering a comparison
            // for it would be an empty card pretending to be an analysis.
            status = L10n.comparisonNeedsTwo
            return nil
        }
        for direction in directions where object(direction) == nil {
            status = L10n.errorGeneric
            return nil
        }
        let comparison = Comparison(
            id: ComparisonID("comparison:" + UUID().uuidString),
            title: L10n.comparisonDefaultTitle,
            directionIDs: directions,
            criteria: proposedCriteria(for: directions),
            isDraft: true
        )
        guard perform([.startComparison(.init(
            comparison: comparison, provenance: .human("local-user")
        ))], label: L10n.undoStartComparison) else { return nil }
        openComparison = comparison.id
        return comparison.id
    }

    // MARK: What a proposal was based on

    // MARK: Syntheses

    public func summary(_ id: SummaryID) -> SummaryArtifact? {
        document.summaries.summary(id)
    }

    public var openSummary: SummaryArtifact? {
        openSummaryID.flatMap { summary($0) }
    }

    /// Composes a synthesis over the selection and writes it down as a draft.
    ///
    /// Deterministic, and that is the point rather than a limitation of the first
    /// version: the composer writes only what it can point at, so every line in it
    /// carries a reference and none of it can be caught by the rule that refuses an
    /// engine assertion with nothing behind it. A synthesis is a deliverable, and a
    /// deliverable nobody agreed to is the one failure this document is built to
    /// prevent, so it opens as a draft and stays one until it is confirmed.
    @discardableResult
    public func startSummary(over selected: Set<ObjectID>? = nil) -> SummaryID? {
        let scope = selected ?? selection
        let target = scope.isEmpty ? Set(document.content.keys) : scope
        // The composer reads the document, so a person who has selected nothing
        // gets a synthesis of everything rather than a refusal.
        let title = scope.isEmpty
            ? L10n.summaryDefaultTitle
            : L10n.summaryTitle(forSelection: scope.count)
        let outcome = SummaryComposer.compose(
            id: SummaryID("summary:" + UUID().uuidString),
            title: title,
            objective: SummaryArtifact.SummaryLine(
                id: SummaryLineID("objective"),
                text: LocalizedText(L10n.summaryDefaultObjective, variants: [:]),
                provenance: .human("local-user")
            ),
            in: document,
            languageCode: languageCode
        )
        guard perform([.startSummary(.init(
            summary: outcome.summary, provenance: .human("local-user")
        ))], label: L10n.undoStartSummary) else { return nil }
        openSummaryID = outcome.summary.id
        _ = target
        return outcome.summary.id
    }

    /// Confirms a synthesis, which is what makes it a deliverable.
    ///
    /// Refused while any section is silently blank, which is the rule that stops a
    /// template from being handed over as though the blanks were answers. The card
    /// says which section is empty rather than letting the press fail silently.
    @discardableResult
    public func confirmSummary(_ id: SummaryID) -> Bool {
        guard let summary = summary(id) else {
            status = L10n.errorGeneric
            return false
        }
        let missing = SummaryArtifact.Section.allCases.first { section in
            let value = summary.sections(section)
            return value.isEmpty || value.allSatisfy { $0.lines.isEmpty && !$0.isNothingRecorded }
        }
        if let missing {
            status = L10n.summaryCannotConfirm(section: missing.title)
            return false
        }
        return perform([.confirmSummary(.init(summaryID: id, provenance: .human("local-user")))],
                       label: L10n.undoConfirmSummary)
    }

    /// Writes the deliverable out, and returns where it went.
    ///
    /// The export names the revision it read, so a person handing this over can say
    /// which version of the document they are handing over an account of. The file
    /// is written where the app already keeps documents, and a failure says so
    /// rather than reporting a success nobody can find.
    @discardableResult
    public func exportSummary(_ id: SummaryID) -> URL? {
        guard let summary = summary(id) else {
            status = L10n.errorGeneric
            return nil
        }
        let export = SummaryExport.markdown(summary, against: document, languageCode: languageCode)
        let directory = fileStore.directory.appendingPathComponent("syntheses", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(export.filename)
            try export.text.write(to: url, atomically: true, encoding: .utf8)
            status = export.isOutdated ? L10n.summaryExportedOutdated : L10n.summaryExported
            return url
        } catch {
            status = L10n.errorGeneric
            return nil
        }
    }

    /// The criteria a draft starts from: the resolution criteria people have already
    /// written on the claims in this selection.
    ///
    /// Local, deterministic and already the person's own words, which is why it is
    /// used instead of asking a model. A model's criteria would be an interpretation
    /// of the document's reasoning, and this is a place where an invented question
    /// is the whole failure. It is a draft either way, and it says where it came from.
    private func proposedCriteria(for directions: [ObjectID]) -> [Criterion] {
        var seen: Set<String> = []
        var proposed: [Criterion] = []
        for direction in directions {
            for claim in document.claims.allClaims() where claim.objectID == direction {
                guard let text = claim.criterion,
                      text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                      seen.insert(text).inserted
                else { continue }
                proposed.append(Criterion(
                    id: CriterionID("criterion:" + UUID().uuidString),
                    title: text
                ))
            }
        }
        return Array(proposed.prefix(4))
    }

    /// Confirms the criteria, which is what lets a cell be recorded.
    @discardableResult
    public func confirmComparisonCriteria(_ id: ComparisonID) -> Bool {
        guard let comparison = comparison(id) else {
            status = L10n.errorGeneric
            return false
        }
        guard comparison.isDraft else { return true }
        return perform([.confirmComparisonCriteria(.init(
            comparisonID: id, provenance: .human("local-user")
        ))], label: L10n.undoConfirmComparison)
    }

    /// Adds a criterion the person typed, or removes one.
    @discardableResult
    public func addCriterion(_ title: String, to id: ComparisonID) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            status = L10n.comparisonCriterionEmpty
            return false
        }
        guard var comparison = comparison(id) else { return false }
        comparison.criteria.append(Criterion(
            id: CriterionID("criterion:" + UUID().uuidString), title: trimmed
        ))
        // Setting criteria is not confirming them. A draft stays a draft until the
        // person presses the button that says so.
        return perform([.setComparisonCriteria(.init(
            comparisonID: id, criteria: comparison.criteria, provenance: .human("local-user")
        ))], label: L10n.undoSetComparisonCriteria)
    }

    @discardableResult
    public func removeCriterion(_ criterionID: CriterionID, from id: ComparisonID) -> Bool {
        guard let comparison = comparison(id) else { return false }
        let remaining = comparison.criteria.filter { $0.id != criterionID }
        return perform([.setComparisonCriteria(.init(
            comparisonID: id, criteria: remaining, provenance: .human("local-user")
        ))], label: L10n.undoSetComparisonCriteria)
    }

    /// Records one cell, with the references it rests on read off the document.
    ///
    /// A number is only accepted for a criterion that has a measure, and the
    /// interface never offers a number field for one that does not, so the refusal
    /// in the command layer is the backstop rather than the friction.
    @discardableResult
    public func recordCell(
        _ value: Cell.Value,
        criterion: CriterionID,
        direction: ObjectID,
        in id: ComparisonID
    ) -> Bool {
        guard let comparison = comparison(id) else {
            status = L10n.errorGeneric
            return false
        }
        guard comparison.isDraft == false else {
            status = L10n.comparisonIsDraft
            return false
        }
        let references = references(for: direction)
        var cell = Cell(
            criterionID: criterion,
            directionID: direction,
            value: value,
            references: references,
            recordedBy: ActorID("local-user"),
            recordedAt: Date()
        )
        // The revision each cited source was read against, so a cell whose source has
        // moved on can be found later without re-reading anything.
        for citation in document.sources.citations(supporting: direction) {
            cell.referenceRevisions[citation.sourceID.rawValue] = citation.revisionID
        }
        // And the text each referenced object had, for the same reason.
        for reference in references where reference.kind == .object {
            cell.referenceFingerprints[reference.id] =
                document.semanticFingerprint(for: [ObjectID(reference.id)])
        }
        return perform([.recordComparisonCell(.init(
            comparisonID: id, cell: cell, provenance: .human("local-user")
        ))], label: L10n.undoRecordCell)
    }

    /// What a cell can point at, read off the document rather than asked for.
    private func references(for direction: ObjectID) -> [ComparisonReference] {
        var found: [ComparisonReference] = []
        for citation in document.sources.citations(supporting: direction) {
            found.append(.init(kind: .citation, id: citation.id.rawValue))
            found.append(.init(kind: .source, id: citation.sourceID.rawValue))
        }
        if let claim = claim(on: direction) {
            found.append(.init(kind: .claim, id: claim.id.rawValue))
        }
        found.append(.init(kind: .object, id: direction.rawValue))
        return found
    }

    /// States what a criterion is measured in, and which way is better. Nil means
    /// "judged in words", which is a state the person chooses rather than a value
    /// that is missing.
    @discardableResult
    public func setMeasure(
        _ unit: String?,
        higherIsBetter: Bool,
        criterion: CriterionID,
        in id: ComparisonID
    ) -> Bool {
        let trimmed = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let measure: Measure? = trimmed.isEmpty ? nil : Measure(unit: trimmed, higherIsBetter: higherIsBetter)
        return perform([.setCriterionMeasure(.init(
            comparisonID: id, criterionID: criterion, measure: measure,
            provenance: .human("local-user")
        ))], label: L10n.undoSetMeasure)
    }

    @discardableResult
    public func setWeight(_ weight: Double?, criterion: CriterionID, in id: ComparisonID) -> Bool {
        perform([.setCriterionWeight(.init(
            comparisonID: id, criterionID: criterion, weight: weight,
            provenance: .human("local-user")
        ))], label: L10n.undoSetWeight)
    }

    /// Keeps a direction. Nothing else is removed, and the reason is kept with it.
    @discardableResult
    public func keepDirection(_ direction: ObjectID, in id: ComparisonID) -> Bool {
        perform([.keepDirection(.init(
            comparisonID: id, directionID: direction, rationale: nil,
            provenance: .human("local-user")
        ))], label: L10n.undoKeepDirection)
    }

    /// Why the comparison needs looking at again, or nil.
    public func comparisonNeedsReview(_ id: ComparisonID) -> ComparisonReviewReason? {
        comparison(id)?.needsReview(in: document)
    }

    /// One line per direction for the card: its text, how many cells it has, and
    /// whether it is kept.
    public func comparisonRows(_ id: ComparisonID) -> [ComparisonDirectionRow] {
        guard let comparison = comparison(id) else { return [] }
        return comparison.directionIDs.compactMap { direction in
            guard let object = object(direction) else { return nil }
            return ComparisonDirectionRow(
                id: direction,
                title: object.text.text,
                kind: object.kind,
                cellCount: comparison.cells(for: direction).filter(\.value.isRecorded).count,
                total: comparison.total(for: direction),
                isKept: comparison.isKept(direction)
            )
        }
    }

    // MARK: Frames

    /// The frames on the canvas, in a stable order. Named apart from `frames`,
    /// which is the measured node rectangles, for the reason given on
    /// `frameContaining(_:)`: the two are different things and the canvas needs both.
    public var canvasFrames: [Frame] { document.presentation.framesSorted() }

    public func frame(_ id: FrameID) -> Frame? { document.presentation.frame(id) }

    /// The frame whose name is being typed, and what has been typed. On the model so
    /// a refused rename, an empty name or a lost focus all leave the sentence where
    /// the person put it.
    public var renamingFrameID: FrameID?
    public var renamingFrameDraft: String = ""

    /// Opens the name field for a frame.
    public func startRenaming(_ id: FrameID) {
        renamingFrameID = id
        renamingFrameDraft = frame(id)?.name.text ?? ""
    }

    /// Submits the name. An empty field is refused rather than stored: a frame whose
    /// name is blank is a label nobody can read back.
    @discardableResult
    public func submitFrameName() -> Bool {
        guard let id = renamingFrameID else { return false }
        guard renameFrame(id, to: renamingFrameDraft) else { return false }
        renamingFrameID = nil
        renamingFrameDraft = ""
        return true
    }

    /// A live drag on a frame, in world space. The document is untouched while the
    /// pointer moves: the offset is drawn, and one transaction is committed on
    /// release, exactly as for a node.
    public struct FrameDragState: Equatable {
        public var id: FrameID
        public var worldDelta: Position
    }

    public var frameDrag: FrameDragState?

    /// Offsets every member and the frame itself by the live delta, for drawing.
    public func frameDragOffset(for id: FrameID) -> Position {
        guard let frameDrag, frameDrag.id == id else { return .zero }
        return frameDrag.worldDelta
    }

    public func nodeDragOffset(for instanceID: InstanceID) -> Position {
        let offset = dragOffset(forInstance: instanceID)
        guard let frameDrag, let frame = frame(frameDrag.id), frame.contains(instanceID) else {
            return offset
        }
        return offset.offset(dx: frameDrag.worldDelta.x, dy: frameDrag.worldDelta.y)
    }

    public func beginFrameDrag(_ id: FrameID, screenTranslation: CGSize) {
        if let frameDrag, frameDrag.id != id { return }
        frameDrag = FrameDragState(
            id: id,
            worldDelta: camera.worldDelta(forScreenDelta: Position(
                x: screenTranslation.width, y: screenTranslation.height
            ))
        )
    }

    /// One transaction for the whole frame, so one undo puts the arrangement back
    /// rather than one node at a time.
    public func endFrameDrag() {
        guard let frameDrag else { return }
        self.frameDrag = nil
        let delta = frameDrag.worldDelta
        guard abs(delta.x) > 0.5 || abs(delta.y) > 0.5 else { return }
        moveFrame(frameDrag.id, by: delta)
    }

    public func cancelFrameDrag() {
        frameDrag = nil
    }

    /// The frame a drawing is in, if any.
    ///
    /// Named apart from `frame(of:) -> Rect?`, which is a *measured* node frame. Two
    /// meanings behind one selector is exactly the kind of ambiguity Swift resolves
    /// by guessing at the call site, and a canvas that drew the wrong rectangle is a
    /// hard bug to see.
    public func frameContaining(_ objectID: ObjectID) -> Frame? {
        document.presentation.frame(of: objectID)
    }

    /// Whether a drawing is hidden because its frame is folded.
    public func isHiddenByFoldedFrame(_ instanceID: InstanceID) -> Bool {
        document.presentation.hiddenInstanceIDs().contains(instanceID)
    }

    /// Puts the current selection into a named frame.
    ///
    /// The members are occurrences, taken from the selection's first instance, so a
    /// second drawing of the same object on another branch is left where it is
    /// rather than dragged along. With nothing selected this refuses rather than
    /// inventing a frame around nothing, because a frame's whole content is what a
    /// person put in it.
    @discardableResult
    public func createFrame(named name: String, containing selected: Set<ObjectID>? = nil) -> FrameID? {
        let scope = selected ?? selection
        let members = scope.compactMap { objectID -> InstanceID? in
            document.presentation.instance(for: objectID)?.id
        }
        guard members.isEmpty == false else {
            status = L10n.frameNothingSelected
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let frame = Frame(
            id: FrameID("frame:" + UUID().uuidString),
            name: LocalizedText(trimmed.isEmpty ? L10n.frameDefaultName : trimmed),
            position: origin(of: members),
            memberInstanceIDs: members.sorted { $0.rawValue < $1.rawValue }
        )
        guard perform([.createFrame(.init(frame: frame))], label: L10n.undoCreateFrame) else { return nil }
        return frame.id
    }

    /// Adds occurrences to a frame, keeping the ones already there.
    @discardableResult
    public func addToFrame(_ id: FrameID, objects selected: Set<ObjectID>) -> Bool {
        guard let frame = frame(id) else {
            status = L10n.errorGeneric
            return false
        }
        let members = frame.memberInstanceIDs
            + selected.compactMap { document.presentation.instance(for: $0)?.id }
        return perform([.setFrameMembers(.init(id: id, memberInstanceIDs: unique(members)))], label: L10n.undoSetFrameMembers)
    }

    /// Takes one occurrence out of a frame. The drawing stays exactly where it is.
    @discardableResult
    public func removeFromFrame(_ id: FrameID, instanceID: InstanceID) -> Bool {
        guard let frame = frame(id) else {
            status = L10n.errorGeneric
            return false
        }
        let members = frame.memberInstanceIDs.filter { $0 != instanceID }
        return perform([.setFrameMembers(.init(id: id, memberInstanceIDs: members))], label: L10n.undoSetFrameMembers)
    }

    /// Renames the frame. Nothing else changes, and in particular nothing that is
    /// inside it: a branch's name is not its sources' name.
    @discardableResult
    public func renameFrame(_ id: FrameID, to name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            // A frame with no name is still a frame, but a person who typed nothing
            // has not named it, and saving an empty label is not what they meant.
            status = L10n.frameNameEmpty
            return false
        }
        return perform([.renameFrame(.init(id: id, name: LocalizedText(trimmed)))], label: L10n.undoRenameFrame)
    }

    /// Folds or unfolds. One transaction, one undo, and no decision involved.
    @discardableResult
    public func setFolded(_ id: FrameID, _ folded: Bool) -> Bool {
        perform([.setFrameFolded(.init(id: id, isFolded: folded))], label: L10n.undoFoldFrame)
    }

    @discardableResult
    public func toggleFold(_ id: FrameID) -> Bool {
        guard let frame = frame(id) else { return false }
        return setFolded(id, !frame.isFolded)
    }

    /// Moves the frame and everything in it, as one transaction.
    ///
    /// The same delta for every member, so the arrangement inside the frame is
    /// preserved exactly, and an occurrence of the same object that is not a member
    /// does not move. That is AC02 and AC03 in one gesture.
    @discardableResult
    public func moveFrame(_ id: FrameID, by delta: Position) -> Bool {
        guard abs(delta.x) > 0.5 || abs(delta.y) > 0.5 else { return true }
        return perform([.moveFrame(.init(id: id, delta: delta))], label: L10n.undoMoveFrame)
    }

    /// Removes the frame and leaves every member where it is.
    @discardableResult
    public func removeFrame(_ id: FrameID) -> Bool {
        return perform([.removeFrame(.init(id: id))], label: L10n.undoRemoveFrame)
    }

    /// The world rectangle a frame draws around, padded so the members sit inside
    /// it rather than on its border.
    ///
    /// Measured sizes are used when the object has exactly one drawing, and the
    /// layout estimate otherwise: the measured dictionary is keyed by object, so
    /// reading it for a second occurrence would place the frame around the wrong
    /// one. A frame that is slightly the wrong size until the next estimate is a
    /// cosmetic problem, and guessing from another occurrence's measurement is a
    /// positional one.
    public func bounds(of frame: Frame) -> Rect? {
        guard let bounds = enclosingRect(of: frame.memberInstanceIDs) else { return nil }
        return bounds.insetBy(dx: -FrameLayout.padding, dy: -FrameLayout.padding)
    }

    private func enclosingRect(of members: [InstanceID]) -> Rect? {
        var bounds: Rect?
        for id in members {
            guard let instance = document.presentation.instance(id: id),
                  let object = document.object(instance.objectID)
            else { continue }
            let measured = document.presentation.instances(of: instance.objectID).count == 1
                ? frames[instance.objectID]
                : nil
            let rect = Rect(origin: instance.position, size: measured?.size ?? instance.size
                ?? NodeLayout.estimatedSize(for: object))
            bounds = bounds.map { $0.union(rect) } ?? rect
        }
        return bounds
    }

    /// Where a frame starts: above and to the left of its members, so the members
    /// are inside it from the moment it appears rather than after a correction.
    private func origin(of members: [InstanceID]) -> Position {
        guard let bounds = enclosingRect(of: members) else { return .zero }
        return bounds.origin
    }

    private func unique(_ ids: [InstanceID]) -> [InstanceID] {
        var seen: Set<InstanceID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    // MARK: Direct manipulation

    /// Live drag state. The document is not touched while the pointer moves: the
    /// offset is applied visually, and one single transaction is committed on
    /// release.
    ///
    /// `ids` is a set, not one id, because CAN-03 moves a *group*: the chosen
    /// instances keep their relative positions and undo restores them together.
    public struct DragState: Equatable {
        /// The instance under the pointer. It is the anchor of the gesture and the
        /// one that decides whether an update belongs to this drag.
        public var anchor: InstanceID
        /// Every instance that follows the pointer. Order is not significant; the
        /// relative positions are preserved by applying the same delta to each.
        public var ids: Set<InstanceID>
        public var worldDelta: Position
    }

    public var dragState: DragState?

    /// The live offset for one instance. Addressing an instance rather than an
    /// object is what lets two occurrences of the same object move independently.
    public func dragOffset(forInstance instanceID: InstanceID) -> Position {
        guard let dragState, dragState.ids.contains(instanceID) else { return .zero }
        return dragState.worldDelta
    }

    /// The live offset of the first instance of an object, which is what a canvas
    /// that has not resolved instances yet needs.
    public func dragOffset(for objectID: ObjectID) -> Position {
        guard let instance = document.presentation.instance(for: objectID) else { return .zero }
        return dragOffset(forInstance: instance.id)
    }

    public func isDragging(_ instanceID: InstanceID) -> Bool {
        dragState?.ids.contains(instanceID) ?? false
    }

    public func beginDrag(_ id: ObjectID, screenTranslation: CGSize) {
        guard let instance = document.presentation.instance(for: id) else { return }
        beginDrag([instance.id], screenTranslation: screenTranslation)
    }

    /// Starts a group drag.
    ///
    /// The caller passes the instances that should follow the pointer. The canvas
    /// resolves the selection to instances before calling, because a selection is
    /// a set of *objects* and a move is a set of *places*.
    public func beginDrag(_ instanceIDs: [InstanceID], screenTranslation: CGSize) {
        guard let anchor = instanceIDs.first else { return }

        // A gesture reports the cumulative translation from its start, so an
        // update for the same anchor replaces the delta instead of being ignored.
        // A different anchor is a different gesture and is refused rather than
        // merging two gestures into one delta.
        if let dragState, dragState.anchor != anchor { return }

        dragState = DragState(
            anchor: anchor,
            ids: Set(instanceIDs),
            worldDelta: camera.worldDelta(forScreenDelta: Position(x: screenTranslation.width, y: screenTranslation.height))
        )
    }

    /// The instances a drag on this object should move: its own, plus the other
    /// selected objects' first instance when the object is part of a multi-selection.
    ///
    /// An unselected object dragged while something else is selected moves alone.
    /// That is the difference between "move what I picked" and "move what I
    /// happened to touch", and only the first is what a person means.
    public func draggableInstances(for id: ObjectID) -> [InstanceID] {
        guard let instance = document.presentation.instance(for: id) else { return [] }
        guard selection.contains(id), selection.count > 1 else { return [instance.id] }
        return selection
            .compactMap { document.presentation.instance(for: $0)?.id }
    }

    /// One transaction, one undo entry, whatever the path the objects took.
    public func endDrag() {
        guard let dragState else { return }
        self.dragState = nil
        let delta = dragState.worldDelta
        guard abs(delta.x) > 0.5 || abs(delta.y) > 0.5 else { return }
        moveInstances(dragState.ids, by: delta)
    }

    /// Cancels the gesture without writing. CAN-03: "cancelling mid-gesture
    /// restores all positions."
    public func cancelDrag() {
        dragState = nil
    }

    /// Moves several instances in one transaction, so one undo restores the group.
    ///
    /// CAN-03 AC02. The domain already accepts a list of moves; this is where a
    /// group drag stops being a set of single drags. Addressing by instance is
    /// what keeps two occurrences of one object independent.
    public func moveInstances(_ instanceIDs: Set<InstanceID>, by delta: Position) {
        let moves = instanceIDs.compactMap { id -> MoveNodeInstance? in
            guard let instance = document.presentation.instance(id: id) else { return nil }
            return MoveNodeInstance(
                instanceID: instance.id,
                position: instance.position.offset(dx: delta.x, dy: delta.y)
            )
        }
        guard moves.isEmpty == false else { return }
        apply(
            [.moveNodeInstances(MoveNodeInstances(moves: moves))],
            label: L10n.undoMove
        )
    }

    /// Convenience for a whole object, used by the tests and by any call site that
    /// genuinely means "everywhere this object is drawn".
    public func moveObject(_ id: ObjectID, by delta: Position) {
        moveInstances(
            Set(document.presentation.instances(of: id).map(\.id)),
            by: delta
        )
    }


    // MARK: Commands

    /// The one way anything changes the document from outside.
    ///
    /// Views call this rather than mutating anything: the transaction, the undo
    /// entry and the error handling all live here, so there is one path to get right
    /// rather than one per call site. A refused command changes nothing and says
    /// so, because a command that half-applied would be a corrupted document.
    @discardableResult
    public func perform(_ commands: [Command], label: String) -> Bool {
        apply(commands, label: label)
    }

    /// Every write goes through here, and none of them goes through while a
    /// presentation is running.
    ///
    /// CAN-10: "A reader cannot trigger a modification by accident." The guarantee
    /// is placed here rather than in each action, because a guard that has to be
    /// remembered at forty call sites is a guard that will be missed once. This was
    /// not true before: `perform` claimed to be the single path while five call
    /// sites used `session.apply` directly, so any of them could have written during
    /// a reading tour.
    @discardableResult
    private func apply(_ commands: [Command], label: String) -> Bool {
        guard isPresenting == false else {
            // Said plainly, and not as an error the person caused: they pressed a
            // key that does not exist in this mode, and the mode is what says so.
            status = L10n.presentationReadOnly
            return false
        }
        guard commands.isEmpty == false else { return true }
        guard session.apply(commands, label: label) else {
            status = L10n.errorGeneric
            return false
        }
        return true
    }

    // MARK: Create, duplicate, remove

    /// Writes an idea down, without asking what kind of idea it is.
    ///
    /// CAN-05: "Create an idea without choosing a category, then clarify its
    /// meaning." This is local and immediate. It does not call a model, because a
    /// person who already knows what they want to say should never wait on a network
    /// to say it, and a model cannot be assumed to be there (invariant 7). The
    /// object is created as `.unclear` and its meaning is settled later, by editing
    /// it or by exploring from it.
    @discardableResult
    public func createIdea(
        _ text: String,
        near anchor: ObjectID?,
        at position: Position? = nil
    ) -> ObjectID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let id = ObjectID("object:" + UUID().uuidString)
        // The creation point is previewed at the anchor when there is one, and
        // offset from it so the new idea does not land exactly on the thing it was
        // written next to.
        let place = position
            ?? anchor.flatMap { document.presentation.instance(for: $0)?.position.offset(dx: 0, dy: 180) }
            ?? .zero
        let create = CreateObject(
            id: id,
            kind: .unclear,
            text: LocalizedText(trimmed),
            position: place,
            provenance: .human("local-user")
        )
        guard perform([.createObject(create)], label: L10n.undoCreate) else { return nil }
        select(id)
        return id
    }

    /// A second drawing of the same idea, in another place.
    ///
    /// This is the operation people mean most of the time by "duplicate", and it is
    /// the one that must not touch meaning: no new object, no new author, no second
    /// share. Offsets by a visible step so the copy is not hidden under the
    /// original.
    @discardableResult
    public func duplicateOccurrence(of instanceID: InstanceID) -> InstanceID? {
        guard document.presentation.instance(id: instanceID) != nil else { return nil }
        let newID = InstanceID("instance:" + UUID().uuidString)
        let source = document.presentation.instance(id: instanceID)
        let command = Command.duplicateNodeInstance(
            DuplicateNodeInstance(
                instanceID: instanceID,
                id: newID,
                position: source?.position.offset(dx: 40, dy: 40)
            )
        )
        guard perform([command], label: L10n.undoDuplicateOccurrence) else { return nil }
        return newID
    }

    /// The same thought said again as a new idea, related to the original.
    ///
    /// A variant can be changed without changing what it came from, which is the
    /// reason it is a new object and not a second occurrence. The link is
    /// `derivedFrom`, so the document can still answer "why is this here".
    @discardableResult
    public func duplicateAsVariant(of id: ObjectID) -> ObjectID? {
        guard document.object(id) != nil else { return nil }
        let newObject = ObjectID("object:" + UUID().uuidString)
        let command = Command.duplicateObject(
            DuplicateObject(
                sourceID: id,
                id: newObject,
                instanceID: InstanceID("instance:" + UUID().uuidString),
                relationshipID: RelationshipID("relationship:" + UUID().uuidString),
                position: document.presentation.instance(for: id)?.position.offset(dx: 40, dy: 40),
                provenance: .human("local-user")
            )
        )
        guard perform([command], label: L10n.undoDuplicateVariant) else { return nil }
        select(newObject)
        return newObject
    }

    /// Takes one drawing off the canvas and keeps the idea.
    @discardableResult
    public func removeOccurrence(_ instanceID: InstanceID) -> Bool {
        perform(
            [.removeNodeInstance(RemoveNodeInstance(instanceID: instanceID))],
            label: L10n.undoRemoveOccurrence
        )
    }

    /// Removes the idea from the document.
    ///
    /// Deliberately a separate call from `removeOccurrence`, with its own label, so
    /// the two are never the same gesture. The interface asks for a confirmation
    /// here and not there, because this one loses the thinking and that one does
    /// not.
    @discardableResult
    public func removeFromDocument(_ id: ObjectID) -> Bool {
        perform([.removeObject(RemoveObject(id: id))], label: L10n.undoRemoveObject)
    }

    /// An object waiting for the person to answer the one question the two removals
    /// share: does this keep the idea or remove it.
    ///
    /// The two are never the same gesture and never the same button, but they are
    /// also never both applied on a first click. This is that moment, held in the
    /// model so the view does not have to hold a destructive intent of its own.
    public var pendingRemoval: ObjectID?

    public func requestRemoveFromDocument(_ id: ObjectID) {
        guard document.object(id) != nil else { return }
        pendingRemoval = id
    }

    /// Answers the pending question, either way. Cancelling is a first-class answer
    /// and leaves the document untouched.
    public func resolvePendingRemoval(keepingIdea: Bool) {
        guard let id = pendingRemoval else { return }
        pendingRemoval = nil
        if keepingIdea {
            if let instance = document.presentation.instance(for: id) {
                _ = removeOccurrence(instance.id)
            }
        } else {
            _ = removeFromDocument(id)
        }
    }

    // MARK: Adding information at a precise place

    /// Writes the sentence down, linked to the thing it is about.
    ///
    /// CTX-01: "The sentence becomes an authored note linked to the target" and
    /// "`CreateObject` plus `associatedWith` in one transaction." The whole point is
    /// that this is *local*. What the person typed is already theirs and already
    /// true, so it is stored before anything is asked of a model, and asking is a
    /// separate later action. If that later action fails, this is still here.
    ///
    /// A note rather than a hypothesis on purpose: the person has not decided what
    /// this sentence *is*, only that it belongs next to that object. "No ontology
    /// knowledge required" is the requirement, and requiring a kind here would put
    /// the burden back on the person.
    @discardableResult
    public func addNote(_ sentence: String, to anchor: ObjectID) -> ObjectID? {
        guard document.object(anchor) != nil else { return nil }
        // What is stored is what was typed, minus the whitespace at the ends and
        // nothing else. The folded form exists only to compare two submissions, and
        // storing it would quietly rewrite the person's sentence, which is the one
        // thing this project never does.
        let authored = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let folded = normalise(authored) else { return nil }

        // A double submission is deduplicated. Pressing the key twice is a fact
        // about the person, not two pieces of information, and two identical notes
        // would read as corroboration that nobody provided.
        if let existing = existingNote(matching: folded, at: anchor) {
            select(existing)
            return existing
        }

        let noteID = ObjectID("object:" + UUID().uuidString)
        let commands: [Command] = [
            .createObject(CreateObject(
                id: noteID,
                kind: .note,
                text: LocalizedText(authored),
                position: document.presentation.instance(for: anchor)?.position
                    .offset(dx: 0, dy: 180),
                provenance: .human("local-user")
            )),
            .addRelationship(AddRelationship(
                id: RelationshipID("relationship:" + UUID().uuidString),
                from: noteID,
                to: anchor,
                kind: .associatedWith,
                provenance: .human("local-user")
            ))
        ]
        // One transaction: a note with no link, or a link to a note that was never
        // written, are both states nobody asked for.
        guard perform(commands, label: L10n.undoAddNote) else { return nil }
        select(noteID)
        return noteID
    }

    /// The note already at this anchor with these words, if there is one.
    private func existingNote(matching sentence: String, at anchor: ObjectID) -> ObjectID? {
        let linked = document.relationships.values
            .filter { $0.kind == .associatedWith && $0.to == anchor }
            .map(\.from)
        return linked.first { id in
            guard let object = document.object(id), object.kind == .note else { return false }
            return normalise(object.text.text) == sentence
        }
    }

    /// Trims, and folds runs of whitespace, so that the same sentence typed with a
    /// stray line break is recognised as the same sentence.
    private func normalise(_ sentence: String) -> String? {
        let folded = sentence
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return folded.isEmpty ? nil : folded
    }

    /// Asks what this note would change, which is a different question from having
    /// written it down.
    ///
    /// Kept apart from `addNote` so the two failures are separate: this one can time
    /// out, be refused, or find no intelligence, and none of that is a reason the
    /// sentence stops existing.
    public func revealConsequences(of note: ObjectID) async {
        await explore(note, intent: .explore)
    }

    /// The kinds intelligence may not choose on its own.
    ///
    /// CTX-01: "A type proposed by intelligence asks for confirmation when it
    /// changes the reasoning." A note states something; a hypothesis, a constraint or
    /// a piece of evidence each *argue* something, and the difference is the whole
    /// content of the document. So a proposal that would create anything other than a
    /// note is held until a person says yes.
    public static func kindNeedsConfirmation(_ kind: ContentObject.Kind) -> Bool {
        switch kind {
        case .note, .unclear:
            return false
        case .context, .need, .method, .technicalBlock, .product, .hypothesis,
             .constraint, .question, .evidence, .scenario, .decision, .contribution:
            return true
        }
    }

    /// A proposal waiting for a person to agree with the kind intelligence chose.
    public var pendingKindConfirmation: Proposal?

    /// Whether a proposal would change the reasoning rather than add a note, and so
    /// has to be confirmed before it is applied.
    public func kindConfirmation(for proposal: Proposal) -> [ObjectID] {
        proposal.operations.compactMap { operation in
            guard case .createObject(let create) = operation,
                  Self.kindNeedsConfirmation(create.kind) else { return nil }
            return create.id
        }
    }

    // MARK: Sources
    // MARK: Clarifications

    /// The question being answered, and what has been typed into it.
    ///
    /// A draft that lives on the model rather than in the view, because a refused
    /// answer must not lose the sentence: AC01 is about the answer surviving, and
    /// the first place it is lost is on the way in.
    public struct ClarificationDraft: Equatable, Identifiable {
        public var id = UUID()
        public var clarificationID: ClarificationID
        public var text: String = ""

        public init(clarificationID: ClarificationID) {
            self.clarificationID = clarificationID
        }
    }

    /// Which answer is still wanted. Every request takes a nonce, and an answer
    /// that does not carry the current one is dropped rather than published.
    public var lifecycle = RequestLifecycle()
    /// The request a retry would continue from, when the person asked for one.
    public var retryingRequestId: String?
    /// The request this model last started, so a completion can tell whether it is
    /// still the one that was asked for.
    private var requestIdForLifecycle: String?

    public var openClarificationID: ClarificationID?
    public var clarificationDraft: ClarificationDraft?

    /// The open question about an object, if there is one.
    public func openClarification(for objectID: ObjectID) -> Clarification? {
        document.clarifications.open(for: objectID)
    }

    /// Records an answer, or an explicit "I don't know".
    ///
    /// Both are the same gesture: the person has dealt with the question. Neither is
    /// the absence of a gesture, which is why an empty field is refused rather than
    /// stored.
    @discardableResult
    public func resolveClarification(asUnknown: Bool = false) -> Bool {
        guard let draft = clarificationDraft else { return false }
        let by = ActorID("local-user")
        let command: Command
        if asUnknown {
            command = .markClarificationUnknown(.init(
                clarificationID: draft.clarificationID, provenance: .human(by)
            ))
        } else {
            let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else {
                status = L10n.clarificationEmpty
                return false
            }
            command = .answerClarification(.init(
                clarificationID: draft.clarificationID, text: text, provenance: .human(by)
            ))
        }
        guard perform([command], label: asUnknown
            ? L10n.undoMarkUnknown
            : L10n.undoAnswerClarification
        ) else { return false }
        openClarificationID = nil
        clarificationDraft = nil
        return true
    }

    // MARK: Claims

    /// A claim being written, before it is stated.
    ///
    /// The scope is not typed: it is what the person has selected, or the object
    /// they are working on. A scope is the part people get wrong, and deriving it
    /// from a selection makes the narrow case the easy one and the sweeping case the
    /// deliberate one.
    public struct ClaimDraft: Equatable, Identifiable {
        public var id = UUID()
        public var anchor: ObjectID
        public var role: Claim.Role
        public var scopeObjects: Set<ObjectID>
        public var criterion: String = ""

        public init(anchor: ObjectID, role: Claim.Role, scopeObjects: Set<ObjectID>) {
            self.anchor = anchor
            self.role = role
            self.scopeObjects = scopeObjects
        }
    }

    public var claimDraft: ClaimDraft?

    /// Opens the claim composer for an object.
    ///
    /// With several objects selected, the claim is about all of them: a person
    /// selecting two branches and stating a constraint means "this applies to
    /// these", which is the scoped case and should not be the fiddly one.
    public func startClaim(role: Claim.Role, anchor: ObjectID) {
        // One commitment at a time: the two drafts are cards over the same
        // anchor, and two of them would overlap rather than stack.
        experimentDraft = nil
        let scope = selection.isEmpty ? [anchor] : Array(selection)
        claimDraft = ClaimDraft(anchor: anchor, role: role, scopeObjects: Set(scope))
    }

    /// States the drafted claim.
    ///
    /// Refused with a reason rather than stated loosely: a claim whose scope is
    /// empty would be a law of the universe, and the command layer refuses it too.
    @discardableResult
    public func submitClaim() -> Bool {
        guard let draft = claimDraft else { return false }
        guard draft.scopeObjects.isEmpty == false else {
            status = L10n.claimScopeEmpty
            return false
        }
        let claim = Claim(
            id: ClaimID("claim:" + UUID().uuidString),
            objectID: draft.anchor,
            role: draft.role,
            scope: ClaimScope(
                id: ScopeID("scope:" + UUID().uuidString),
                title: L10n.claimScopeTitle(default: object(draft.anchor)?.text.text ?? draft.anchor.rawValue),
                objectIDs: draft.scopeObjects
            ),
            criterion: draft.criterion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : draft.criterion
        )
        guard perform([.assertClaim(.init(
            claim: claim, provenance: .human("local-user")
        ))], label: L10n.undoAssertClaim) else { return false }
        claimDraft = nil
        return true
    }

    // MARK: Experiments (DEC-04)

    /// An experiment being built.
    ///
    /// The same shape as a claim draft on purpose: the person is committing to
    /// something they will be held to later, and the fields that cost something
    /// to get wrong are required here as they are in the command layer. Evidence
    /// is prefilled from the selection, because the usual way to build an
    /// experiment is to have just looked at the things it will judge.
    public struct ExperimentDraft: Equatable, Identifiable {
        public var id = UUID()
        public var anchor: ObjectID
        public var question: String = ""
        public var method: String = ""
        public var criterion: String = ""
        public var expectedEvidence: Set<ObjectID> = []
        public var isSimulation: Bool = false

        public init(anchor: ObjectID, expectedEvidence: Set<ObjectID> = []) {
            self.anchor = anchor
            self.expectedEvidence = expectedEvidence
        }
    }

    public var experimentDraft: ExperimentDraft?

    /// Opens the experiment composer for an object.
    public func startExperiment(anchor: ObjectID) {
        // One commitment at a time, as above.
        claimDraft = nil
        let evidence = selection.isEmpty ? [] : selection.subtracting([anchor])
        experimentDraft = ExperimentDraft(anchor: anchor, expectedEvidence: evidence)
    }

    /// Builds the drafted experiment.
    ///
    /// Refused with a reason rather than built loose, for the two fields the
    /// command layer refuses too: a question nobody asked and a criterion that
    /// judges nothing. Whitespace-only is empty in meaning.
    @discardableResult
    public func submitExperiment() -> Bool {
        guard let draft = experimentDraft else { return false }
        let question = draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let criterion = draft.criterion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false else {
            status = L10n.experimentQuestionEmpty
            return false
        }
        guard criterion.isEmpty == false else {
            status = L10n.experimentCriterionEmpty
            return false
        }
        let method = draft.method.trimmingCharacters(in: .whitespacesAndNewlines)
        guard perform([.createExperiment(.init(
            id: KollioID.experiment("experiment-" + UUID().uuidString),
            targetObjectID: draft.anchor,
            question: LocalizedText(question),
            method: method.isEmpty ? nil : LocalizedText(method),
            successCriterion: LocalizedText(criterion),
            expectedEvidence: Array(draft.expectedEvidence).sorted { $0.rawValue < $1.rawValue },
            isSimulation: draft.isSimulation,
            provenance: .human("local-user")
        ))], label: L10n.undoCreateExperiment) else { return false }
        experimentDraft = nil
        return true
    }

    /// The experiments built on an object's reasoning, oldest first.
    public func experiments(on objectID: ObjectID) -> [Experiment] {
        document.experiments.experiments(targeting: objectID)
    }

    /// The local history of one object, newest last, reversals folded in.
    ///
    /// DEC-06: the origin of a decision is answerable because every recorded
    /// action carries the label the person acted under, and a reversal is
    /// folded into the action it cancels rather than listed beside it.
    public func history(of objectID: ObjectID) -> [HistoryNarrativeItem] {
        document.history.narrative(for: objectID, in: document)
    }

    /// Opens the timeline for an object.
    @discardableResult
    public func openHistory(of objectID: ObjectID) -> Bool {
        guard history(of: objectID).isEmpty == false else { return false }
        openHistoryID = objectID
        return true
    }

    // MARK: History preview / restore / purge (DEC-06)

    /// A read-only view of the document as it stood at a history entry.
    ///
    /// Rebuilt by replaying the commands of the entries before it. Two things
    /// the replay must not do, and did:
    ///
    /// - **It must not replay a reversal.** A reversal entry carries the payload
    ///   of the action it undid, and applying it would resurrect exactly what the
    ///   person took back. Only `.applied` entries are replayed.
    /// - **It must not empty the journal.** The history is the record of what
    ///   happened, not part of the state being looked at. A restore built from
    ///   this would otherwise delete the very timeline the person is reading.
    ///
    /// The revision of the rebuilt document counts the batches replayed rather
    /// than reproducing the original number, so it is a position, not an identity.
    public func previewHistory(at entryID: HistoryEntryID) throws -> KollioDocument? {
        guard document.history.entry(entryID) != nil else { return nil }
        var store = DocumentStore(document: session.journalBaseDocument)
        for entry in document.history.entries {
            if entry.id == entryID { break }
            guard case .applied = entry.kind, entry.commands.isEmpty == false else { continue }
            try store.apply(entry.commands, at: entry.at)
        }
        var target = store.document
        target.history = document.history
        return target
    }

    /// Restores the document to the state at a history entry by applying
    /// a new transaction (DEC-06 AC03). The current state is not rolled back;
    /// a fresh batch of commands is recorded with its own label.
    @discardableResult
    public func restoreHistory(to entryID: HistoryEntryID, label: String) -> Bool {
        guard let target = try? previewHistory(at: entryID) else { return false }
        guard let command = try? RestoreDocument(document: target) else { return false }
        // A restore is an ordinary validated transaction. It therefore gets one
        // undo entry and a replayable journal command instead of replacing the
        // live store behind the undo stack.
        return perform([.restoreDocument(command)], label: label)
    }

    /// Removes history entries older than a retention horizon.
    ///
    /// Returns the number of entries purged. A purged entry leaves a
    /// trace (its label and date) so the timeline shows what was removed
    /// without inventing content.
    @discardableResult
    public func purgeHistory(olderThan date: Date) -> Int {
        let before = document.history.entries.count
        var updated = session.document
        var ledger = updated.history
        ledger.removeAll { $0.at < date }
        updated.history = ledger
        session.replaceDocument(with: updated)
        return before - updated.history.entries.count
    }

    // MARK: Results (DEC-05)

    /// A result being recorded against an experiment.
    ///
    /// The observation and the interpretation are two fields here as they are
    /// in the domain, and the composer keeps them apart: the observation is
    /// what the person saw, the outcome is their stance on the criterion, and
    /// the proposal of a learning is a separate act after the result exists.
    public struct ResultDraft: Equatable, Identifiable {
        public var id = UUID()
        public var experimentID: ExperimentID
        public var observation: String = ""
        public var measurementValue: String = ""
        public var measurementUnit: String = ""
        public var limits: String = ""
        /// The document object that carries the observation, when the person
        /// selected one before opening the result composer.
        public var sourceObjectID: ObjectID?
        public var inconclusive: Bool = false
        public var inconclusiveReason: String = ""
        /// The stance on the criterion, when the person says the run concluded.
        public var criterionMet: Bool = true

        public init(experimentID: ExperimentID, sourceObjectID: ObjectID? = nil) {
            self.experimentID = experimentID
            self.sourceObjectID = sourceObjectID
        }
    }

    public var resultDraft: ResultDraft?

    /// The learning being written into a card, per experiment. Transient text:
    /// it belongs to the card, and closing the card forgets it.
    public var learningDrafts: [ExperimentID: String] = [:]

    public func learningDraft(for id: ExperimentID) -> String? {
        learningDrafts[id]
    }

    public func setLearningDraft(_ text: String, for id: ExperimentID) {
        learningDrafts[id] = text
    }

    /// Proposes the drafted learning about the experiment's target.
    @discardableResult
    public func submitLearningDraft(for id: ExperimentID) -> Bool {
        guard let experiment = document.experiments.experiment(id) else { return false }
        let scope: Set<ObjectID> = selection.isEmpty
            ? [experiment.targetObjectID]
            : selection
        defer { learningDrafts[id] = nil }
        return proposeLearning(from: id, statement: learningDrafts[id] ?? "", scope: scope)
    }

    /// The object the open result draft sits beside, for positioning.
    public var resultDraftAnchor: ObjectID? {
        document.experiments.experiment(resultDraft?.experimentID ?? ExperimentID(""))?.targetObjectID
    }

    /// Opens the result composer for an experiment.
    public func startRecordingResult(_ experimentID: ExperimentID) {
        experimentDraft = nil
        let target = document.experiments.experiment(experimentID)?.targetObjectID
        let source = selection
            .filter { $0 != target && document.object($0) != nil }
            .sorted { $0.rawValue < $1.rawValue }
            .first
        resultDraft = ResultDraft(experimentID: experimentID, sourceObjectID: source)
    }

    /// Records the drafted result.
    ///
    /// Refused with a reason for the two things the command layer refuses: an
    /// observation with nothing observed, and an inconclusive answer that
    /// cannot say what is missing. A measurement row is kept only when a
    /// number has both halves of itself filled in; a half-written one is
    /// dropped rather than half-recorded.
    @discardableResult
    public func submitResult() -> Bool {
        guard let draft = resultDraft else { return false }
        let observation = draft.observation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard observation.isEmpty == false else {
            status = L10n.resultObservationEmpty
            return false
        }
        var measurements: [ExperimentMeasurement] = []
        let rawValue = draft.measurementValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawUnit = draft.measurementUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawValue.isEmpty == false || rawUnit.isEmpty == false {
            if let value = Double(rawValue.replacingOccurrences(of: ",", with: ".")), rawUnit.isEmpty == false {
                measurements = [ExperimentMeasurement(value: value, unit: rawUnit)]
            } else {
                status = L10n.resultMeasurementIncomplete
                return false
            }
        }
        let outcome: ExperimentResultVersion.Outcome
        if draft.inconclusive {
            let reason = draft.inconclusiveReason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard reason.isEmpty == false else {
                status = L10n.resultReasonMissing
                return false
            }
            outcome = .inconclusive(reason)
        } else {
            outcome = .conclusive(draft.criterionMet ? .criterionMet : .criterionNotMet)
        }
        let limits = draft.limits.trimmingCharacters(in: .whitespacesAndNewlines)
        guard perform([.recordExperimentResult(RecordExperimentResult(
            id: draft.experimentID,
            observation: observation,
            measurements: measurements,
            limits: limits.isEmpty ? nil : limits,
            sourceObjectID: draft.sourceObjectID,
            outcome: outcome,
            provenance: .human("local-user")
        ))], label: L10n.undoRecordResult) else { return false }
        resultDraft = nil
        return true
    }

    /// Proposes a learning from the newest result of an experiment.
    @discardableResult
    public func proposeLearning(from experimentID: ExperimentID, statement: String, scope: Set<ObjectID>) -> Bool {
        let text = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            status = L10n.resultLearningEmpty
            return false
        }
        guard scope.isEmpty == false else {
            status = L10n.claimScopeEmpty
            return false
        }
        guard perform([.proposeLearning(ProposeLearning(
            id: FindingID("finding-" + UUID().uuidString),
            experimentID: experimentID,
            statement: LocalizedText(text),
            scopeObjectIDs: scope.sorted { $0.rawValue < $1.rawValue },
            provenance: .human("local-user")
        ))], label: L10n.undoProposeLearning) else { return false }
        return true
    }

    /// Opens the experiment card for an object's newest experiment.
    @discardableResult
    public func openExperiment(on objectID: ObjectID) -> ExperimentID? {
        guard let experiment = experiments(on: objectID).last else { return nil }
        openExperimentID = experiment.id
        return experiment.id
    }

    /// The claim made on an object, if there is one.
    public func claim(on objectID: ObjectID) -> Claim? {
        document.claims.allClaims().first { $0.objectID == objectID }
    }

    /// The two stances in one place, so a claim can be read at a glance.
    public func claimSummary(for objectID: ObjectID) -> ClaimSummary? {
        guard let claim = claim(on: objectID) else { return nil }
        return ClaimSummary(
            id: claim.id,
            role: claim.role,
            scopeCount: claim.scope.objectIDs.count,
            isAsserted: claim.isAsserted,
            hypothesis: claim.role == .hypothesis ? claim.assessment : nil,
            constraint: claim.role == .constraint ? claim.resolution : nil,
            criterion: claim.criterion
        )
    }

    /// Records a stance. Both cases need an observation, and neither one is
    /// reachable without one.
    @discardableResult
    public func recordStance(_ draft: StanceDraft) -> Bool {
        let trimmed = draft.observation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let claim = claim(on: draft.anchor) else { return false }
        // The two evidence types are separate on purpose, so a hypothesis and a
        // constraint cannot end up sharing a verdict by accident.
        let by = ActorID("local-user")
        let now = Date()
        let command: Command
        switch claim.role {
        case .hypothesis:
            let assessment: HypothesisAssessment = switch draft.stance {
            case .supported: .supported(.init(observation: trimmed, by: by, at: now))
            case .contradicted: .contradicted(.init(observation: trimmed, by: by, at: now))
            case .refuted: .refuted(.init(observation: trimmed, by: by, at: now))
            case .satisfied, .notApplicable, .open: .open
            }
            command = .assessHypothesis(.init(
                claimID: claim.id, assessment: assessment, provenance: .human(by)
            ))
        case .constraint:
            let resolution: ConstraintResolution = switch draft.stance {
            case .satisfied: .satisfied(.init(observation: trimmed, by: by, at: now))
            case .notApplicable: .notApplicable(.init(observation: trimmed, by: by, at: now))
            case .supported, .contradicted, .refuted, .open: .open
            }
            command = .resolveConstraint(.init(
                claimID: claim.id, resolution: resolution, provenance: .human(by)
            ))
        }
        guard perform([command], label: L10n.undoRecordStance) else { return false }
        stanceDraft = nil
        return true
    }

    public struct StanceDraft: Equatable, Identifiable {
        public var id = UUID()
        public var anchor: ObjectID
        public var stance: Stance
        public var observation: String = ""

        public init(anchor: ObjectID, stance: Stance) {
            self.anchor = anchor
            self.stance = stance
        }
    }

    /// The stances a person can take, as one vocabulary for the interface.
    ///
    /// Which of them apply depends on the role, and the interface only offers the
    /// ones that do. A constraint cannot be "refuted" and a hypothesis cannot be
    /// "satisfied": those are the two mistakes this split exists to prevent.
    public enum Stance: String, CaseIterable, Identifiable {
        case supported
        case contradicted
        case refuted
        case satisfied
        case notApplicable
        case open

        public var id: String { rawValue }

        public static func applicable(to role: Claim.Role) -> [Stance] {
            switch role {
            case .hypothesis: [.open, .supported, .contradicted, .refuted]
            case .constraint: [.open, .satisfied, .notApplicable]
            }
        }
    }

    public var stanceDraft: StanceDraft?

    // MARK: Citations

    /// The system's reader, for a file too long to read as text on the canvas.
    ///
    /// Held by the model rather than by a view so that opening and closing it is
    /// one decision in one place, and so the same file cannot be opened twice from
    /// two different cards.
    @MainActor public let sourcePreview = SourcePreviewPanel()

    /// Opens the person's own file in the system reader, beside the canvas.
    public func openInReader(_ sourceID: SourceID) {
        guard let locator = document.sources.source(sourceID)?.locator,
              let url = URL(string: locator)
        else { return }
        sourcePreview.present(url)
    }

    /// A source open for reading, so a passage can be chosen from it.
    ///
    /// The text comes from the revision on record, never re-read from disk: what a
    /// person cites has to be the text the document believes it read.
    public var readingSourceID: SourceID?

    /// The lines of a source, addressable so a citation can point at one.
    public func lines(of sourceID: SourceID) -> [String] {
        guard let text = document.sources.source(sourceID)?.latest?.extraction.text else { return [] }
        return text.components(separatedBy: .newlines)
    }

    /// The source as a table, parsed from the text on record.
    ///
    /// Parsed from the revision rather than from the file on disk, for the same
    /// reason the lines are: what is shown has to be what the document believes it
    /// read. A file that changed underneath must not silently change a preview.
    public func table(for sourceID: SourceID) -> CSVTable? {
        guard let source = document.sources.source(sourceID),
              source.kind == .csv,
              let text = source.latest?.extraction.text,
              let parsed = try? CSVTable.parse(text)
        else { return nil }
        return parsed
    }

    /// Cites a passage of a source, from the revision currently on record.
    ///
    /// The quote is taken from the chosen lines rather than typed, because a quote
    /// that differs from the source is not a quote. The locator is the range that
    /// was actually chosen, so opening the citation later lands on the same lines.
    @discardableResult
    public func citePassage(
        of sourceID: SourceID,
        lines range: Range<Int>,
        to claim: ObjectID
    ) -> Bool {
        let all = lines(of: sourceID)
        guard range.lowerBound >= 0, range.upperBound <= all.count, range.lowerBound < range.upperBound,
              let revision = document.sources.source(sourceID)?.latest
        else { return false }
        let quote = all[range].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard quote.isEmpty == false else { return false }

        let citation = Citation(
            id: CitationID("citation:" + UUID().uuidString),
            claimID: claim,
            sourceID: sourceID,
            revisionID: revision.id,
            locator: SourceLocator(lineRange: range),
            quote: quote
        )
        guard perform([.addCitation(.init(
            citation: citation, claimID: claim, provenance: .human("local-user")
        ))], label: L10n.undoAddCitation) else { return false }
        readingSourceID = nil
        return true
    }

    /// The claim whose citations are open, and the one being checked.
    ///
    /// Transient, like the composer and the decision card: it appears where the
    /// person is working and goes away when they move on. There is no citations
    /// panel anywhere in the application, because a permanent home for evidence
    /// would be a permanent home for reading rather than for thinking.
    public var openCitationClaim: ObjectID?
    public var verifyingCitationID: CitationID?
    /// What the person is writing into the verification input. It lives on the model
    /// so a refused check does not lose the sentence.
    public var verificationDraft: String = ""

    /// The citations of a claim, in a stable order.
    public func citations(of objectID: ObjectID) -> [CitationDetail] {
        document.sources.citations(supporting: objectID).map { citation in
            let source = document.sources.source(citation.sourceID)
            let revision = source?.revision(citation.revisionID)
            return CitationDetail(
                citation: citation,
                sourceTitle: source?.title ?? citation.sourceID.rawValue,
                /// The text of the exact revision the citation was read against. Not
                /// the current one: a claim has to be re-checkable against what it
                /// was actually based on, which is the whole point of keeping the
                /// history.
                passage: Self.passage(in: revision?.extraction.text, at: citation.locator),
                state: SourceChipState(revision?.extraction ?? .notAttempted),
                isCurrentRevision: source?.latest?.id == citation.revisionID
            )
        }
    }

    /// The lines a locator points at, when the text is line-addressable.
    ///
    /// A page locator in a PDF has no line numbers, so the passage is nil and the
    /// interface shows the locator and the quote instead of pretending it opened
    /// something. Returning nil is the honest answer; a wrong slice would be worse.
    static func passage(in text: String?, at locator: SourceLocator) -> String? {
        guard let text, let range = locator.lineRange else { return nil }
        let lines = text.components(separatedBy: .newlines)
        guard range.lowerBound >= 0, range.upperBound <= lines.count, range.lowerBound < range.upperBound
        else { return nil }
        return lines[range].joined(separator: "\n")
    }

    public func toggleCitations(of objectID: ObjectID) {
        openCitationClaim = openCitationClaim == objectID ? nil : objectID
        verifyingCitationID = nil
    }

    /// Records that a person checked a citation, with what they saw.
    ///
    /// Refused when the observation is empty, because a check that says nothing is
    /// not a check. The draft is only cleared once the command has been accepted,
    /// so a refused verification keeps what was typed.
    @discardableResult
    public func recordVerification(
        _ citationID: CitationID,
        observation: String
    ) -> Bool {
        let trimmed = observation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return false }
        let command = Command.recordVerification(.init(
            citationID: citationID,
            observation: trimmed,
            author: ActorID("local-user")
        ))
        guard perform([command], label: L10n.undoRecordVerification) else { return false }
        verifyingCitationID = nil
        return true
    }


    /// Reads a file the person chose and attaches it, as one transaction.
    ///
    /// The read happens first and the two commands are applied together, so a file
    /// that cannot be read leaves nothing behind: no half-attached source, and no
    /// source pointing at a revision that was never recorded. What comes back is
    /// what was read, so a caller can say "no text in this file" instead of
    /// reporting a success.
    @discardableResult
    public func attachSource(
        at url: URL,
        to objectID: ObjectID
    ) -> SourceReader.Read? {
        guard object(objectID) != nil else {
            status = L10n.errorGeneric
            return nil
        }
        let read: SourceReader.Read
        do {
            read = try sourceReader.read(url: url)
        } catch {
            status = L10n.sourceReadFailed
            return nil
        }

        // A stable id from the content, so attaching the same file twice is a
        // recognisable duplicate rather than a second copy of the same source.
        let sourceID = SourceID("source:" + String(read.digest.prefix(16)))
        let revision = SourceRevision(
            id: SourceRevisionID("revision:" + String(read.digest.prefix(16))),
            sequence: (document.sources.source(sourceID)?.attempts.count ?? 0) + 1,
            extraction: read.extraction,
            digest: read.digest
        )
        let reference = SourceReference(
            id: sourceID,
            kind: read.kind,
            title: read.title,
            locator: read.locator,
            revisions: document.sources.source(sourceID)?.revisions ?? []
        )
        let provenance = Provenance.human(ActorID("local-user"))
        let commands: [Command] = document.sources.source(sourceID) == nil
            ? [.attachSource(.init(source: reference, attachedTo: objectID, provenance: provenance))]
            : []
        guard perform(commands + [.importSourceRevision(.init(
            sourceID: sourceID, revision: revision, provenance: provenance
        ))], label: L10n.undoAttachSource) else {
            return nil
        }
        return read
    }


    /// What a source chip says about one resource cited by an object.
    ///
    /// Read straight from the ledger and never cached: the chip is the document's
    /// own state, and a cached copy of it would be a second truth free to disagree.
    public func sourceChips(for objectID: ObjectID) -> [SourceChip] {
        let citations = document.sources.citations(supporting: objectID)
        guard citations.isEmpty == false else { return [] }

        // One chip per source, however many passages of it are cited.
        var order: [SourceID] = []
        var counts: [SourceID: Int] = [:]
        for citation in citations {
            if counts[citation.sourceID] == nil { order.append(citation.sourceID) }
            counts[citation.sourceID, default: 0] += 1
        }
        return order.compactMap { id in
            guard let source = document.sources.source(id) else { return nil }
            return SourceChip(
                id: id,
                title: source.title,
                state: SourceChipState(source.extraction),
                citations: counts[id] ?? 0
            )
        }
    }

    // MARK: Intelligence

    /// What a request about this target actually reads.
    ///
    /// AI-03: "Use the useful global context, the target, applicable constraints and
    /// directions already rejected." Those four are not the same list, and the last
    /// one is the one that is easy to leave out and the most expensive to leave out:
    /// without it, intelligence re-proposes what the person already turned down, and
    /// the rejection looks like it never happened.
    ///
    /// A rejected direction travels with the reason it was rejected for. "No budget
    /// for it" and "we tried this in March and it did not hold" are different
    /// instructions, and a bare list of dead ends reads to a generator as a ban
    /// rather than as reasoning.
    ///
    /// Reachable objects only: a constraint three branches away is not applicable to
    /// this target, and sending it would spend the context budget on noise.
    public func readSet(for target: ObjectID) -> [ProposalRequest.ContextItem] {
        // Keyed by id and emitted in a stable order, because an object can be reached
        // by more than one route: a constraint that is both a neighbour and a rejected
        // direction must arrive *once*, carrying the reason it was rejected for.
        // Collecting "first writer wins" lost that reason whenever the object happened
        // to be mentioned before the rejections were walked, which made the same
        // document produce two different read sets depending on iteration order.
        var items: [ObjectID: ProposalRequest.ContextItem] = [:]

        func mention(_ object: ContentObject) {
            guard items[object.id] == nil else { return }
            items[object.id] = ProposalRequest.ContextItem(
                objectID: object.id,
                kind: object.kind,
                text: object.text.text,
                lifecycle: object.lifecycle,
                reason: nil
            )
        }

        if let target = object(target) { mention(target) }

        // Everything within reach: what it links to directly, and one step beyond.
        // A constraint three branches away is not applicable to this target, and
        // sending it would spend the context budget on noise.
        let neighbours = directNeighbours(of: target)
        for id in neighbours { if let object = object(id) { mention(object) } }
        for id in neighbours.flatMap({ secondDegreeNeighbours(of: $0) }) where !neighbours.contains(id) {
            if let object = object(id) { mention(object) }
        }

        // The rejected directions, and the reason each was rejected for. This runs
        // last on purpose: it *upgrades* what is already there rather than skipping
        // it, because "this was refused, and here is why" is strictly more than
        // "this is nearby".
        for decision in activeSetAsideDecisions() {
            let reason = decision.rationale?.text
            for id in decision.branchObjectIDs + [decision.targetObjectID] {
                guard let object = object(id), object.isSetAside else { continue }
                items[id] = ProposalRequest.ContextItem(
                    objectID: object.id,
                    kind: object.kind,
                    text: object.text.text,
                    lifecycle: object.lifecycle,
                    reason: reason
                )
            }
        }

        // Sorted so the fingerprint, and anything else reading the set, does not
        // depend on how a dictionary happened to iterate.
        return items.keys.sorted { $0.rawValue < $1.rawValue }.compactMap { items[$0] }
    }

    private func directNeighbours(of id: ObjectID) -> [ObjectID] {
        var found: Set<ObjectID> = []
        for relationship in document.relationships.values {
            if relationship.from == id { found.insert(relationship.to) }
            if relationship.to == id { found.insert(relationship.from) }
        }
        return found.filter { $0 != id }
    }

    private func secondDegreeNeighbours(of id: ObjectID) -> [ObjectID] {
        directNeighbours(of: id).filter { $0 != id }
    }

    /// The set-aside decisions that still stand.
    ///
    /// A reopened direction is not a rejected one any more, and consulting it as
    /// though it were would be the model quietly undoing a decision the person made.
    private func activeSetAsideDecisions() -> [Decision] {
        document.decisions.values
            .filter { $0.kind == .setAside && $0.status == .active }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// The stable signature of what a request read, sent as its precondition.
    public func readSetFingerprint(for target: ObjectID) -> String {
        ProposalRequest.fingerprint(of: readSet(for: target))
    }


    /// Asks the current source for a proposal and previews it as a ghost branch.
    ///
    /// `instruction` carries what the person actually typed. It is optional
    /// because a plain Explore has nothing to carry, and it is part of the
    /// request because a sentence that never leaves the composer is a sentence
    /// the application silently threw away.
    @discardableResult
    public func explore(
        _ id: ObjectID,
        intent: Intent = .explore,
        instruction: String? = nil
    ) async -> Bool {
        // A new request supersedes the one in flight rather than being refused.
        // Refusing meant a person could not change their mind while waiting, which
        // is the case the nonce exists to handle: the older answer becomes stale and
        // is dropped when it lands, and only the newest publishes. The first version
        // of this kept the old guard, and a test for the race hung on it.
        isThinking = true
        defer {
            // Only the request that is still current may clear the busy state. Two
            // overlapping requests would otherwise have the first one to finish
            // report "not thinking" while the second is still working.
            if lifecycle.currentRequestId == requestIdForLifecycle { isThinking = false }
        }
        status = nil

        let trimmed = instruction?.trimmingCharacters(in: .whitespacesAndNewlines)
        // The exact sentence travels, not a paraphrase of it. AI-03 AC01 is about
        // transmission, and the words a person chose are the part that cannot be
        // reconstructed from the target alone.
        let context = readSet(for: id)
        // A retry is a visible link to the request it continues, never an
        // invisible repeat of the same identifier.
        let requestId = UUID().uuidString
        requestIdForLifecycle = requestId
        let nonce = lifecycle.begin(requestId: requestId, retrying: retryingRequestId)
        let request = ProposalRequest(
            requestId: requestId,
            documentId: document.documentId,
            baseSemanticRevision: session.semanticRevision,
            intent: intent == .explore ? .explore : .add,
            targetIds: [id],
            instruction: (trimmed?.isEmpty == false) ? trimmed : nil,
            contentLocale: languageCode,
            context: context,
            // The signature of what was just read, so a source can tell whether it is
            // answering against the same document it was given rather than a stale
            // understanding of it.
            preconditions: ProposalRequest.Preconditions(
                semanticRevision: session.semanticRevision,
                readSetFingerprint: ProposalRequest.fingerprint(of: context)
            ),
            generationNonce: nonce
        )
        do {
            let response: ProposalResponse
            if let streaming = service as? any StreamingSuggestionService {
                // A source that can stream is asked to stream. The answer is
                // identical; the only difference is that the person sees it
                // arriving instead of waiting on a spinner for seconds.
                response = try await streaming.stream(to: request, document: document) { [weak self] update in
                    Task { @MainActor in self?.progress = update }
                }
            } else {
                response = try await service.respond(to: request, document: document)
            }
            // A late answer is dropped. This is the whole point of the nonce: a
            // person who asked again, undid, or closed the window must not have
            // this answer land on top of whatever replaced it. Nothing is published,
            // and nothing is removed either: whatever is on screen now was put there
            // by a request the person is still waiting on.
            guard lifecycle.accepts(nonce: nonce, requestId: request.requestId) else {
                progress = nil
                status = L10n.statusAnswerSuperseded
                return false
            }
            progress = nil
            lastRequest = request
            handle(response, anchor: id, requestId: request.requestId)
            // An answer produced from part of the request says so on the status
            // line, and not only inside a panel the person has to ask for: the
            // scope of an answer is part of the answer. It never overwrites a more
            // important status such as a refusal.
            if status == nil,
               let scope = response.proposal?.contextScope,
               scope.isNarrowed {
                status = L10n.statusContextNarrowed(scope.omittedObjectIDs.count)
            }
            return true
        } catch is CancellationError {
            // A cancelled request publishes nothing. The draft and the context
            // stay exactly as they were, and no half-received answer is left on
            // screen pretending to be progress towards something.
            progress = nil
            return false
        } catch let error as AppleModelError {
            // The real reason, in the user's language, and no substitution: the
            // context is untouched and the demo engine is not quietly used.
            progress = nil
            status = error.errorDescription
            return false
        } catch {
            progress = nil
            status = L10n.errorGeneric
            return false
        }
    }

    /// The offline engine can be driven directly, with no request round-trip.
    /// Handles a response the service did not produce itself, such as the demo
    /// engine's. `requestId` attributes a question to something; without one the
    /// question still exists, it is simply not traceable to a request.
    public func handle(
        _ response: ProposalResponse,
        anchor: ObjectID,
        requestId: String = "local-request"
    ) {
        switch response.status {
        case .noChange:
            // AI-03 AC03: "a new request offers to keep or hide the previous one
            // rather than erasing it." Nothing arrived, so nothing is taken away:
            // the proposal already on screen is still somebody's thinking and stays
            // there. Clearing it here used to destroy a pending branch because a
            // later question produced no answer.
            status = L10n.statusNoChange
        case .needsInput:
            // A question is a thing in the document now, not a line of status that
            // disappears. It has to survive a failure, a restart and a share, which
            // is the whole of AI-04's first criterion, and none of that is true of a
            // transient message.
            guard let question = response.questions.first else {
                status = L10n.statusNoChange
                return
            }
            let text = question.resolve(languageCode: languageCode)
            guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                status = L10n.statusNoChange
                return
            }
            let clarification = Clarification(
                id: ClarificationID("clarification:" + UUID().uuidString),
                originatingRequestId: requestId,
                objectID: anchor,
                question: LocalizedText(text)
            )
            guard perform([.askClarification(.init(
                clarification: clarification,
                provenance: Provenance(actor: "local-user", kind: .human)
            ))], label: L10n.undoAskClarification) else { return }
            openClarificationID = clarification.id
            // The input is attached to the question, not replaced by a generic
            // composer: answering a question and adding an idea are different acts.
            clarificationDraft = .init(clarificationID: clarification.id)
            status = nil
        case .proposed:
            guard let proposal = response.proposal else {
                status = L10n.statusNoChange
                return
            }
            // One working group per window, so the new one takes the stage, and the
            // previous one is *offered* rather than dropped. Whether the person
            // wants it is their answer to give, not a default.
            if let previous = preview {
                supersededProposal = previous
                keptProposals.append(previous)
            }
            preview = makePreview(proposal: proposal, anchor: anchor)
        }
    }

    /// Proposals that were on the canvas and are not any more, still readable.
    public private(set) var keptProposals: [ProposalPreview] = []

    /// The proposal a new request displaced, waiting for an answer about its fate.
    public var supersededProposal: ProposalPreview?

    /// Keeps the proposal a new request displaced. It stays readable rather than
    /// being restored to the canvas, because two branches from one target at once is
    /// not what the canvas is for.
    public func keepPreviousProposal() {
        supersededProposal = nil
    }

    /// Hides the proposal a new request displaced, and forgets it.
    ///
    /// Hiding is not deleting: the objects it would have created were never created,
    /// so nothing that anybody wrote is lost, and the history of what was proposed
    /// stays in the document's revision.
    public func hidePreviousProposal() {
        if let previous = supersededProposal {
            keptProposals.removeAll { $0.id == previous.id }
        }
        supersededProposal = nil
    }

    /// Whether a preview is entirely outside what the person can currently see.
    ///
    /// A proposal placed on a crowded canvas can land off screen, and the decision
    /// card then floats over an empty area with nothing to point at. This says so,
    /// so the card can offer a way to go and look.
    public func previewIsOffScreen() -> Bool {
        guard let preview, preview.placements.isEmpty == false else { return false }
        let visible = camera.visibleWorldRect(viewport: viewport)
        // One visible object is enough: the card is useful as soon as part of the
        // branch can be seen, and centring on a partly visible branch is exactly the
        // disorienting jump this avoids.
        return preview.placements.values.allSatisfy { position in
            let rect = Rect(
                origin: position,
                size: estimatedGhostSize(of: preview, at: position)
            )
            return visible.intersects(rect) == false
        }
    }

    /// Centres the view on a proposal, because the person asked to see it.
    ///
    /// Deliberate, never automatic. A camera that jumps on its own when an answer
    /// arrives takes the person's view away from whatever they were reading, and
    /// there is no way to get it back by accident.
    public func revealPreview() {
        guard let preview, preview.placements.isEmpty == false else { return }
        let positions = Array(preview.placements.values)
        let left = positions.map(\.x).min() ?? 0
        let top = positions.map(\.y).min() ?? 0
        let right = positions.map(\.x).max() ?? 0
        let bottom = positions.map(\.y).max() ?? 0
        let centre = Position(x: (left + right) / 2, y: (top + bottom) / 2)
        let size = estimatedGhostSize(of: preview, at: centre)
        let bounds = Rect(
            origin: Position(x: left - size.width / 2, y: top - size.height / 2),
            size: Size(width: (right - left) + size.width, height: (bottom - top) + size.height)
        )
        camera = Camera.fitting(content: bounds, viewport: viewport, padding: 120)
    }

    /// The size a previewed object is laid out at, measured the same way the
    /// placement was computed so a reveal frames what is really there.
    private func estimatedGhostSize(of preview: ProposalPreview, at position: Position) -> Size {
        guard let id = preview.placements.first(where: { $0.value == position })?.key else {
            return Size(width: NodeLayout.minimumWidth, height: NodeLayout.thoughtHeight)
        }
        return estimatedSize(of: id, in: preview.proposal)
    }

    /// Turns a proposal into a preview: where each proposed object would sit.
    ///
    /// Placement is intent, never pixels chosen by the generator, and it never
    /// lands on top of what is already on the canvas: a proposed object that
    /// would overlap an existing one is pushed down until the document stays
    /// readable.
    /// What was read, taken from the request rather than rebuilt from the document.
    private func readRefs(for scope: ProposalContextScope?) -> [ProposalInputRef] {
        guard let request = lastRequest else { return [] }
        // What was read, taken from the request rather than rebuilt from the
        // document, and then narrowed to what the source actually sent. A list
        // read off the request alone would claim credit for material the model
        // never saw, which is the one claim this list must not make.
        let sent = scope.map { Set($0.readObjectIDs) }
        return ProposalInputRef.resolveAll(
            request.context
                .filter { sent?.contains($0.objectID) ?? true }
                .map { item in
                    (
                        id: item.objectID.rawValue,
                        kind: ProposalInputRef.Kind.object,
                        // A label, never the content: a proposal that copied the text of
                        // a source into its own record would be a copy of somebody's
                        // document living where it was not asked to be.
                        label: item.text.count > 90
                            ? String(item.text.prefix(90)) + "…"
                            : item.text
                    )
                },
            in: document
        )
    }

    func makePreview(proposal: Proposal, anchor: ObjectID) -> ProposalPreview {
        var objectIDs: [ObjectID] = []
        var relationshipIDs: [RelationshipID] = []
        for operation in proposal.operations {
            switch operation {
            case .createObject(let create):
                objectIDs.append(create.id)
            case .addRelationship(let add):
                relationshipIDs.append(add.id)
            default:
                break
            }
        }

        let occupancy = occupiedRects(excluding: objectIDs)
        var placements: [ObjectID: Position] = [:]
        var taken: [Rect] = []

        for hint in proposal.placementHints {
            guard objectIDs.contains(hint.objectID) else { continue }
            let anchorCentre = hint.relativeTo.flatMap { frame(of: $0)?.center }
                ?? frame(of: anchor)?.center
                ?? .zero
            let size = estimatedSize(of: hint.objectID, in: proposal)
            var candidate = Position(
                x: anchorCentre.x + hint.offsetX,
                y: anchorCentre.y + hint.offsetY
            )
            candidate = separate(
                candidate,
                size: size,
                from: occupancy + taken
            )
            placements[hint.objectID] = candidate
            taken.append(Rect(origin: candidate, size: size))
        }

        // Anything created without a placement hint still gets a readable slot.
        for (index, id) in objectIDs.enumerated() where placements[id] == nil {
            let base = frame(of: anchor)?.center ?? .zero
            let size = estimatedSize(of: id, in: proposal)
            let candidate = separate(
                Position(x: base.x, y: base.y + Double(index + 1) * 170),
                size: size,
                from: occupancy + taken
            )
            placements[id] = candidate
            taken.append(Rect(origin: candidate, size: size))
        }

        let reason = proposal.rationale?.resolve(languageCode: languageCode) ?? ""
        return ProposalPreview(
            proposal: proposal,
            placements: placements,
            objectIDs: objectIDs,
            relationshipIDs: relationshipIDs,
            anchorID: anchor,
            rationale: reason,
            summary: proposal.summary.resolve(languageCode: languageCode),
            readRefs: readRefs(for: proposal.contextScope)
        )
    }

    private func estimatedSize(of objectID: ObjectID, in proposal: Proposal) -> Size {
        guard let create = proposal.operations.compactMap({ operation -> CreateObject? in
            if case .createObject(let create) = operation, create.id == objectID { return create }
            return nil
        }).first else { return Size(width: NodeLayout.minimumWidth, height: NodeLayout.thoughtHeight) }
        return NodeLayout.estimatedSize(
            for: ContentObject(id: objectID, kind: create.kind, text: create.text, provenance: .human("ghost"))
        )
    }

    /// Every rectangle a proposed object must not cover.
    private func occupiedRects(excluding proposed: [ObjectID]) -> [Rect] {
        visibleInstances
            .filter { !proposed.contains($0.objectID) }
            .compactMap { frame(of: $0.objectID) }
    }

    /// Pushes a candidate down, then sideways, until it is clear of everything
    /// already on the canvas. Deterministic, and it never moves existing work.
    private func separate(_ position: Position, size: Size, from others: [Rect]) -> Position {
        let gap = Space.m
        var candidate = position
        for _ in 0..<24 {
            let rect = Rect(origin: candidate, size: size)
            let blocker = others.first { rect.insetBy(dx: -gap, dy: -gap).intersects($0) }
            guard let blocker else { return candidate }
            candidate = Position(x: candidate.x, y: blocker.maxY + gap + size.height / 2)
        }
        // Still colliding after pushing down: step to the right of everything.
        let right = others.map(\.maxX).max() ?? candidate.x
        return Position(x: right + Space.xl + size.width / 2, y: candidate.y)
    }

    /// Keep: the proposed objects become normal document objects, in one
    /// transaction that undo restores as a whole.
    public func keepPreview() {
        guard let preview else { return }
        let kept = apply(
            [.applyProposal(ApplyProposal(
                proposal: preview.proposal,
                placements: preview.placements,
                provenance: .human("local-user")
            ))],
            label: L10n.undoKeepProposal
        )
        // The confirmation follows the command and not the other way round. This
        // used to say "kept" whatever happened, which during a presentation would
        // have replaced the refusal with a lie.
        guard kept else { return }
        self.preview = nil
        status = L10n.statusKept
    }

    /// Setting a proposal aside discards it. Nothing was added to the document,
    /// so there is nothing to remember: a *direction* is set aside from its own
    /// contextual action, which does record a durable reason.
    public func discardPreview() {
        preview = nil
        status = L10n.statusDiscarded
    }

    /// Asks for the reason before setting a direction aside, so the memory of
    /// the decision belongs to the user and not to the machine.
    public func requestSetAsideReason(for id: ObjectID) {
        composer = ComposerState(anchorID: id, intent: .setAside)
    }

    /// Set aside on a real direction: a durable decision, not a deletion.
    public func setAside(_ id: ObjectID, reason: String?) {
        let command = Command.recordDecision(RecordDecision(
            id: KollioID.decision(UUID().uuidString),
            kind: .setAside,
            targetObjectID: id,
            rationale: reason.map { LocalizedText($0) },
            provenance: .human("local-user")
        ))
        guard apply([command], label: L10n.undoSetAside) else {
            status = L10n.errorGeneric
            return
        }
        if selection.contains(id) { selection.remove(id) }
        // The camera is deliberately left alone. Collapsing a branch is a local
        // decision, and Cmd+0 stays the explicit way to reframe the view.
    }

    /// Reopen: restores the objects, the relationships and the positions.
    public func reopen(_ id: ObjectID) {
        let command = Command.recordDecision(RecordDecision(
            id: KollioID.decision(UUID().uuidString),
            kind: .reopened,
            targetObjectID: id,
            provenance: .human("local-user")
        ))
        guard apply([command], label: L10n.undoReopen) else {
            status = L10n.errorGeneric
            return
        }
        selection = [id]
        // Reopening restores what was already there. It does not rearrange it,
        // and it does not move the view either.
    }

    // MARK: Inline input

    public func startComposer(anchor: ObjectID, intent: Intent = .add) {
        composer = ComposerState(anchorID: anchor, intent: intent)
    }

    /// Opens the composer pre-filled with the object's own text, so an edit
    /// starts from what is actually there rather than from nothing.
    public func startEditing(anchor: ObjectID) {
        guard let object = object(anchor) else { return }
        composer = ComposerState(
            anchorID: anchor,
            text: object.text.text,
            intent: .edit,
            baseVersion: object.objectVersion
        )
    }

    public func submitComposer() async {
        guard let composer else { return }
        let text = composer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch composer.intent {
        case .add:
            guard !text.isEmpty else { return }
            // CTX-01: Add is not a call that spends the sentence. It writes the note,
            // linked to the target, in one local transaction. Nothing is asked of a
            // model here, so there is nothing that can fail here, and the note is
            // already findable before the person asks to see the consequences.
            if addNote(text, to: composer.anchorID) != nil { self.composer = nil }
        case .setAside:
            self.composer = nil
            setAside(composer.anchorID, reason: text.isEmpty ? nil : text)
        case .explore:
            // AI-03: "A local instruction may be added." It used to be discarded
            // here, which meant a person who typed a steer and pressed the key had
            // it silently ignored. The draft is only closed once the request has
            // actually been made, so a refused send leaves the words in place.
            let sent = await explore(composer.anchorID, intent: .explore, instruction: text)
            if sent { self.composer = nil }
        case .edit:
            // An edit is a user's own contribution, not a request to a model,
            // so it goes through the command system and never asks anything.
            // The composer is *not* cleared before the write: a refusal has to
            // leave the person their text, and clearing first would throw it away
            // on the way to finding out it failed.
            let applied = applyEdit(
                to: composer.anchorID,
                text: text,
                expectedVersion: composer.baseVersion
            )
            if applied { self.composer = nil }
        }
    }

    /// Replaces the text of one object, keeping its identity.
    ///
    /// The full authored text is preserved: no summary replaces what was typed,
    /// no other object moves, and the object stays the same object. It is one
    /// transaction, so it undoes as one action.
    @discardableResult
    public func applyEdit(to id: ObjectID, text: String, expectedVersion: Int? = nil) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let object = object(id) else { return false }
        guard object.text.text != trimmed else { return true }
        let command = Command.updateObjectText(UpdateObjectText(
            id: id,
            text: LocalizedText(trimmed),
            provenance: .human("local-user"),
            expectedVersion: expectedVersion
        ))
        guard apply([command], label: L10n.undoEdit) else {
            // The refusal is about the text, not about the application, so it is
            // reported as such. The draft is still in the composer.
            status = L10n.errorEditConflict
            return false
        }
        return true
    }

    /// Whether the object moved on while this draft was open, so the interface can
    /// say so *before* the person presses the key rather than after.
    public func hasEditConflict(_ composer: ComposerState) -> Bool {
        guard composer.intent == .edit, let base = composer.baseVersion else { return false }
        guard let object = object(composer.anchorID) else { return true }
        return object.objectVersion != base
    }

    // MARK: First experience

    /// The first experience: the person's own words become the document's
    /// context object.
    ///
    /// There is no longer a pair of canned hypotheses behind it. The authored
    /// text is preserved exactly as written, the object is created through the
    /// command system so it has a stable identity and an undo entry, and the
    /// canvas shows it immediately. Asking for intelligence is a separate step
    /// that can fail without touching any of this.
    @discardableResult
    public func start(with statement: String) -> ObjectID? {
        let text = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // A fresh document, and a save target of its own: a new document must
        // never overwrite the previous one.
        var builder = DocumentBuilder(document: KollioDocument())
        guard let context = builder.object(
            "context", kind: .context, text, en: text, at: Position(x: 0, y: 0)
        ) else { return nil }
        session = KollioSession(document: builder.document)
        adoptNewSaveTarget()
        selection = [context]
        frames = [:]
        camera = Camera(zoom: 1, translation: Position(x: 40, y: 120))
        // Persisted before anything else can fail, so the words are safe even
        // if the intelligence source is unreachable.
        save()
        return context
    }

    /// Explores the authored context. Separate from `start(with:)` on purpose:
    /// a failure here must not cost the user their sentence.
    public func exploreInitialContext(_ id: ObjectID) async {
        await explore(id, intent: .explore)
    }

    /// A new document gets its own file, so saving it can never overwrite the
    /// document that was open before.
    /// The same thing, for a test that needs two documents on disk.
    ///
    /// A launch gives a new document its own file so saving it cannot destroy the
    /// previous one, and proving that needs to do the same without going through
    /// the interface.
    func adoptNewSaveTargetForTest() { adoptNewSaveTarget() }

    private func adoptNewSaveTarget() {
        let name = "Kollio-\(Self.shortStamp())"
        documentURL = fileStore.url(named: name)
    }

    private static func shortStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // The short suffix keeps two documents created in the same second
        // distinct, which a bare timestamp would not.
        return "\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(4))"
    }

    public var isEmpty: Bool { document.content.isEmpty }

    /// A stored document could not be read. The user is told, and the file is
    /// left exactly as it is.
    public var hasUnreadableDocument: Bool { loadFailure != nil }

    /// Development aid for visual review: `KOLLIO_REVIEW=explore` opens the app
    /// with a proposal already on the canvas, so the ghost branch can be
    /// captured in a screenshot. Never used in a normal launch.
    public func prepareVisualStateForReview() async {
        let review = ProcessInfo.processInfo.environment["KOLLIO_REVIEW"]
        guard let review, !review.isEmpty else { return }
        let csv = KollioID.object("sarah-csv")
        switch review {
        case "explore", "kept":
            selection = [KollioID.object("sarah-crm")]
            await explore(KollioID.object("sarah-crm"))
            if review == "kept" { keepPreview() }
        case "setaside":
            setAside(csv, reason: reviewReason)
            selection = [csv]
        case "reopened":
            setAside(csv, reason: reviewReason)
            reopen(csv)
        // AI-12: the two states a budget produces, which no other review state can
        // reach because Sarah is far too small to hit the window.
        case "narrowed":
            loadReviewDocument(largeContext: true)
            selection = [Self.reviewTarget]
            await explore(Self.reviewTarget)
            // The panel is what names the scope, and opening it from a capture is
            // the only way it has ever been seen. It stays closed for a person.
            showsProposalAttribution = true
            frameOnReviewTarget()
        case "toobig":
            loadReviewDocument(largeContext: false)
            selection = [Self.reviewTarget]
            await explore(Self.reviewTarget)
            frameOnReviewTarget()
        // CAN-10: the tour, and the tour after two steps, so a capture can show
        // both "1 of n" and the fact that the view moved with it.
        case "presenting", "presentingmid":
            loadDemo()
            fitContent()
            beginPresentation()
            if review == "presentingmid" {
                advancePresentation()
                advancePresentation()
            }
        case "search", "searchreason":
            loadDemo()
            fitContent()
            // Two states, because the two halves of CAN-09 look nothing alike on a
            // screen: a result that is on the canvas, and a reason somebody wrote
            // for a direction that was set aside.
            if review == "searchreason" {
                setAside(KollioID.object("sarah-crm"), reason: reviewSearchReason)
            }
            selection = [KollioID.object("sarah-crm")]
            openSearch()
            // "budget" is the one word that reads the same in both languages, so
            // the state is reachable whichever the interface is in.
            updateSearch(review == "searchreason" ? "budget" : "export")
        default:
            break
        }
    }

    private static let reviewTarget = ObjectID("object:review-context")

    private func loadReviewDocument(largeContext: Bool) {
        session = KollioSession(document: Self.reviewDocument(largeContext: largeContext))
        frames = [:]
        preview = nil
        composer = nil
        loadFailure = nil
        adoptNewSaveTarget()
    }

    /// Framed on the target rather than on the content, and called after the
    /// request rather than before it.
    ///
    /// Two reasons, both learned from a capture that showed nothing. A document
    /// this size is zoomed out until nothing can be read, and the canvas frames the
    /// whole content when it appears, which happens while the request is still in
    /// flight. The target is what the answer is about, so it is what is framed.
    private func frameOnReviewTarget() {
        camera = Camera(
            zoom: 0.8,
            translation: Position(x: 140, y: viewport.height * 0.2)
        )
    }

    /// A document whose context does not fit the model's window.
    ///
    /// `largeContext` decides which of the two budget outcomes is reachable: three
    /// neighbours that together overflow a real 8192-token window, so an answer is
    /// produced from part of it, or one neighbour larger than that window on its own,
    /// so the request is refused. Both are states the app has to reach honestly, and
    /// neither can be produced by a document small enough to read at a glance.
    static func reviewDocument(largeContext: Bool) -> KollioDocument {
        var builder = DocumentBuilder()
        if largeContext {
            let target = builder.object(
                "review-context", kind: .context,
                "Should billing stay on the first screen of the signup?",
                en: "Should billing stay on the first screen of the signup?",
                at: .zero
            )!
            // Each neighbour is well under the window and together they are past it,
            // so what is left out is optional material and an answer is still
            // possible. They sit well to the right, not around the target: a
            // proposed branch is placed clear of what is already on the canvas, and
            // three nodes this long standing next to the target would push it off
            // the screen, which is where the answer has to be visible.
            for index in 0..<3 {
                let id = builder.object(
                    "review-n\(index)", kind: .hypothesis,
                    Self.reviewText(index), en: Self.reviewText(index),
                    at: Position(x: 3_000, y: Double(index) * 2_400)
                )!
                _ = builder.link("review-l\(index)", from: target, to: id, .alternativeTo)
            }
        } else {
            // The target itself is larger than the whole window. Nothing here is
            // optional, because the target is what was asked about, so this is
            // refused rather than answered around: a shorter answer about something
            // else is not an answer.
            _ = builder.object(
                "review-context", kind: .constraint,
                String(repeating: "Billing must not be a requirement before the trial. ", count: 400),
                en: String(repeating: "Billing must not be a requirement before the trial. ", count: 400),
                at: Position(x: 0, y: 0)
            )
        }
        return builder.document
    }

    private static func reviewText(_ index: Int) -> String {
        let seeds = [
            "The first screen measures three screens converted, and two hundred per cent of the abandonments happen there.",
            "The second screen loses half of whoever is left, and almost nobody sees it happen.",
            "The third screen is the only one people look at on their own in a usability test.",
        ]
        let seed = seeds[index % seeds.count]
        // Repeated so the payload is genuinely large, rather than a sentence that
        // happens to be long. The point is the budget, not the prose.
        return ([seed] + (0..<40).map { "\($0). \(seed)" }).joined(separator: " ")
    }

    /// A reason that carries the word the review state searches for, in the
    /// language being read. The generic review reason is about API access, and
    /// searching for "budget" in it would find nothing and prove nothing.
    private var reviewSearchReason: String {
        languageCode == "fr"
            ? "Pas de budget pour l'API avant mars"
            : "No budget for the API before March"
    }

    private var reviewReason: String {
        languageCode == "fr"
            ? "On garde cette direction pour plus tard, les accès API ne sont pas disponibles."
            : "Keeping this direction for later, the API access is not available."
    }

    // MARK: History and persistence

    public var canUndo: Bool { session.history.canUndo }
    public var canRedo: Bool { session.history.canRedo }

    /// Invalidates any answer still in flight.
    ///
    /// Called wherever the person has moved on: undo, close, and every new request.
    /// A response already on its way is now stale and will be dropped when it lands.
    public func invalidateInFlightAnswer() {
        lifecycle.invalidate()
    }

    public func undo() {
        if session.undo() {
            pruneSelection()
        }
    }

    public func redo() {
        if session.redo() {
            pruneSelection()
        }
    }

    /// Changes both the versioned document title and its local registry name.
    /// The previous file is removed only after the renamed document is safely
    /// written, so a failed save can never cost the user their document.
    @discardableResult
    public func renameDocument(to title: String) -> Bool {
        let previousSession = session
        let previousURL = documentURL
        let targetURL = fileStore.availableURL(named: title, excluding: previousURL)

        guard apply([.renameDocument(.init(
            title: title,
            provenance: .human("owner")
        ))], label: L10n.undoRenameDocument) else {
            return false
        }

        do {
            try fileStore.save(document, to: targetURL)
            documentURL = targetURL
            if previousURL.standardizedFileURL != targetURL.standardizedFileURL,
               FileManager.default.fileExists(atPath: previousURL.path) {
                try FileManager.default.removeItem(at: previousURL)
            }
            status = L10n.statusSaved
            return true
        } catch {
            session = previousSession
            try? FileManager.default.removeItem(at: targetURL)
            documentURL = previousURL
            status = L10n.errorSaveFailed
            return false
        }
    }

    /// Creates a fully independent copy and makes that copy the active document.
    /// The source file is never moved or rewritten.
    @discardableResult
    public func duplicateDocument(named title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            status = L10n.errorGeneric
            return false
        }

        do {
            let duplicate = try DocumentDuplicator.duplicate(document, title: trimmed)
            let targetURL = fileStore.availableURL(named: trimmed)
            try fileStore.save(duplicate, to: targetURL)
            session = KollioSession(document: duplicate)
            documentURL = targetURL
            selection = []
            preview = nil
            composer = nil
            status = L10n.statusSaved
            return true
        } catch {
            status = L10n.errorSaveFailed
            return false
        }
    }

    /// The scope the export commands act on: the selection when there is one,
    /// the whole document otherwise. Every export format takes the same scope, so
    /// two formats can never quietly disagree about what is being handed over.
    public func exportScope() -> DocumentExportScope {
        selection.isEmpty ? .document : .objects(selection)
    }

    /// Freezes the scope once. Markdown, PNG and the asset archive are all
    /// rendered from this, which is what makes the export match the preview.
    public func exportSnapshot() -> DocumentExportSnapshot {
        DocumentExporter.snapshot(of: document, scope: exportScope())
    }

    public func exportPortableDocument() -> KollioDocument {
        DocumentExporter.portableDocument(from: document, scope: exportScope())
    }

    /// The assets the exported scope depends on. Whether a file is still on the
    /// machine is checked here, because the plan is a claim about the disk and
    /// not only about the document.
    public func exportAssetPlan() -> [AssetArchiveEntry] {
        let candidates = document.sources.sources.values
            .map(\.locator)
            .filter { $0.isEmpty == false }
        let existing = Set(candidates.filter { FileManager.default.fileExists(atPath: $0) })
        return DocumentExporter.assetPlan(for: document, scope: exportScope(), existingPaths: existing)
    }

    /// Writes the asset archive and says what it managed to carry.
    @discardableResult
    public func archiveExportAssets(into parent: URL) -> Bool {
        let plan = exportAssetPlan()
        guard plan.isEmpty == false else {
            status = L10n.assetsArchiveEmpty
            return false
        }
        do {
            let result = try AssetArchiver.archive(
                plan: plan,
                into: parent,
                named: document.title + " " + L10n.assetsArchiveSuffix
            )
            status = L10n.assetsArchived(
                copied: result.copied.count,
                missing: result.skipped.count
            )
            return true
        } catch {
            status = L10n.errorSaveFailed
            return false
        }
    }

    @discardableResult
    public func save() -> Bool {
        // An empty document is not written. There is nothing in it to keep, and
        // writing it is what created the file that then shadowed every real
        // document on the machine. A save that reports success and leaves an empty
        // file behind is not a save, whatever the button says.
        guard document.content.isEmpty == false else {
            return true
        }
        do {
            try fileStore.save(document, to: documentURL)
            status = L10n.statusSaved
            return true
        } catch {
            status = L10n.errorSaveFailed
            return false
        }
    }

    /// Simulates the full cycle: save, close, reopen.
    public func reloadFromDisk() {
        guard let reloaded = try? fileStore.load(documentURL) else { return }
        // The new session reads the reloaded document, and establishes its own
        // replay base from it. The base is where *this* session started, so a
        // reload does not move it: a preview of the first action must still show
        // the document as it was before that action, not a finished document with
        // the whole history replayed on top.
        session = KollioSession(document: reloaded)
        frames = [:]
        selection = []
        preview = nil
    }

    /// A new, empty document with its own save target. Reusing the previous
    /// document's file would destroy it on the first save.
    public func newDocument() {
        session = KollioSession(document: KollioDocument())
        frames = [:]
        selection = []
        preview = nil
        composer = nil
        loadFailure = nil
        camera = .identity
        adoptNewSaveTarget()
    }

    /// The Sarah scenario, always through an explicit action. It is never what a
    /// launch falls back to.
    public func loadDemo() {
        session = KollioSession(document: SarahFixture.document())
        frames = [:]
        selection = []
        preview = nil
        composer = nil
        loadFailure = nil
        adoptNewSaveTarget()
        fitContent()
    }
}


/// The state a source chip shows, taken from what the import actually achieved.
///
/// There is no "imported" state that flatters the app: a file with no text layer
/// says so, and a source nobody has read yet says that too.
public enum SourceChipState: Hashable, Sendable {
    case notRead
    case importing
    case ready
    case partial(String)
    case noText
    case unsupported
    case missing
    /// Cited, but the source has moved or gone: the claim stands, the check does not.
    case unverifiable

    public init(_ extraction: SourceReference.Extraction) {
        switch extraction {
        case .notAttempted: self = .notRead
        case .pending: self = .importing
        case .ready: self = .ready
        case .partial(_, let reason): self = .partial(reason)
        case .noText: self = .noText
        case .unsupported: self = .unsupported
        case .missing: self = .missing
        }
    }

    /// Spoken rather than shown, because a coloured dot tells a screen reader
    /// nothing at all.
    public var accessibilityDescription: String {
        switch self {
        case .notRead: return L10n.sourceStateNotRead
        case .importing: return L10n.sourceStateImporting
        case .ready: return L10n.sourceStateReady
        case .partial: return L10n.sourceStatePartial
        case .noText: return L10n.sourceStateNoText
        case .unsupported: return L10n.sourceStateUnsupported
        case .missing: return L10n.sourceStateMissing
        case .unverifiable: return L10n.sourceStateUnverifiable
        }
    }

    /// A chip is calm when nothing needs a person's attention.
    public var needsAttention: Bool {
        switch self {
        case .ready, .notRead, .importing: return false
        case .partial, .noText, .unsupported, .missing, .unverifiable: return true
        }
    }
}

public struct SourceChip: Hashable, Sendable, Identifiable {
    public var id: SourceID
    public var title: String
    public var state: SourceChipState
    public var citations: Int

    public init(id: SourceID, title: String, state: SourceChipState, citations: Int) {
        self.id = id
        self.title = title
        self.state = state
        self.citations = citations
    }
}


/// A citation, with everything the interface needs to show it honestly.
public struct CitationDetail: Identifiable, Hashable, Sendable {
    public var citation: Citation
    public var sourceTitle: String
    /// The lines the locator points at, or nil when it points at a page or the
    /// text is unavailable.
    public var passage: String?
    public var state: SourceChipState
    /// False when the source has moved on since this was cited, which is the case
    /// where re-reading matters most.
    public var isCurrentRevision: Bool

    public var id: CitationID { citation.id }

    public init(
        citation: Citation,
        sourceTitle: String,
        passage: String?,
        state: SourceChipState,
        isCurrentRevision: Bool
    ) {
        self.citation = citation
        self.sourceTitle = sourceTitle
        self.passage = passage
        self.state = state
        self.isCurrentRevision = isCurrentRevision
    }
}


/// A claim as the interface reads it: role, how much it covers, and how it stands.
public struct ClaimSummary: Identifiable, Hashable, Sendable {
    public var id: ClaimID
    public var role: Claim.Role
    public var scopeCount: Int
    public var isAsserted: Bool
    public var hypothesis: HypothesisAssessment?
    public var constraint: ConstraintResolution?
    public var criterion: String?

    public init(
        id: ClaimID,
        role: Claim.Role,
        scopeCount: Int,
        isAsserted: Bool,
        hypothesis: HypothesisAssessment?,
        constraint: ConstraintResolution?,
        criterion: String?
    ) {
        self.id = id
        self.role = role
        self.scopeCount = scopeCount
        self.isAsserted = isAsserted
        self.hypothesis = hypothesis
        self.constraint = constraint
        self.criterion = criterion
    }
}


/// The metrics of a frame, in one place.
///
/// The padding is what makes a frame read as a container rather than as a box drawn
/// around its contents: the name needs somewhere to live, and a border flush with
/// the first node reads as a selection.
public enum FrameLayout {
    public static let padding: Double = 22
    public static let headerHeight: Double = 26
    public static let collapsedWidth: Double = 190
    public static let collapsedHeight: Double = 34
}


/// One direction of a comparison, as the card reads it.
///
/// `total` is nil whenever the comparison does not define one, and the card shows
/// nothing in that column rather than a zero: a zero would read as "this direction
/// scored nothing", which is a claim the document cannot make.
public struct ComparisonDirectionRow: Identifiable, Hashable, Sendable {
    public var id: ObjectID
    public var title: String
    public var kind: ContentObject.Kind
    public var cellCount: Int
    public var total: Double?
    public var isKept: Bool

    public init(
        id: ObjectID,
        title: String,
        kind: ContentObject.Kind,
        cellCount: Int,
        total: Double?,
        isKept: Bool
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.cellCount = cellCount
        self.total = total
        self.isKept = isKept
    }
}
