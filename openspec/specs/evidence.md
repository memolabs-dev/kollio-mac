# Evidence

What has actually been shown, and how. This file exists so that no claim in the
project outruns its proof.

## CAN-02, the visual pass of 27 September 2026

Four things were wrong with the local action controls and all four were found by
looking rather than by reading.

**White on the accent.** `ActionButton` used `Color.white` for a default action, and
the two accents are not the same colour. White on the light theme's cobalt measures
5.82:1 and is fine; white on the dark theme's periwinkle measures **2.15:1** and is
not. The foreground is now a measured semantic, `Theme.onAccent`, and
`OnAccentContrastTests` recomputes the ratio from the palette in both themes so a
regression cannot hide in a light-mode screenshot. The palette itself was changed to
hold its values as hex, because a `Color` cannot be measured without a window behind
it.

**A plate pretending to be a material.** The local bar was a hand-drawn white rounded
rectangle with a large shadow, containing buttons that each drew their own fill. That
is a surface on top of surfaces. The plate is gone: the cluster is
`GlassEffectContainer`, the prominent control is `.glassProminent` and the rest are
`.glass`, and the tint is applied to the prominent control only. Applying the tint to
all of them produced three identical blue pills, which is the opposite of the one
strong action the design asks for.

**A placement that could not notice it was wrong.** The bar was positioned with a
hard-coded width of 300 and a height of 52, then clamped, inside the view that chose
those numbers, so the view agreed with itself by construction and no test could
disagree. The size is now measured and published through a preference, and
`ContextualPlacement.resolve` decides: below, then above, then trailing, then leading,
then clamp. It is pure arithmetic, so it is tested exactly — including the case the
clamp got wrong, where a cluster wider than the window used to be shoved against one
edge because clamping an inverted range returns its lower bound. It is now centred,
so both ends overflow equally. `ContextualPlacementTests` covers a French-width
cluster, a viewport smaller than the cluster, and an object at the left edge.

**Labels that were key names.** `ContextualActionSet.Kind.localizationKey` returned
`explore`, `clarify` and `setAside` where the catalog holds `canvas.explore`,
`canvas.clarify`, `canvas.setAside`. `String(localized:)` returns the key when it
cannot find it, so the primary local controls of a French window read
`explore clarify setAside`. The bar also had no accessibility identifier, so the
cluster was missing from the accessibility tree entirely. Both are fixed and both are
now guarded: `ContextualActionLabelTests` walks every kind and fails on a key the
catalog does not have, and asserts that the failure mode it guards is still the
failure mode.

**Reduced transparency, decided rather than delegated.** The instruments were using the
system glass unconditionally, on the assumption the system would keep them findable when
transparency is reduced. `InstrumentMaterial.resolve(reduceTransparency:)` now returns an
opaque surface for that setting, `OpaqueInstrumentButtonStyle` draws it with the border
carrying the outline, and `InstrumentMaterialTests` decides the matrix. The opaque rectangle
is the only material in the application that this repository draws itself, and the test says
so, so it stays an exception rather than becoming a habit.

**Typography, decided as roles rather than as sizes.** The scale was six `Font.system` calls,
one family, and four of them at medium. The document allows three weights and gives each a
job: regular reads, medium distinguishes, semibold is exceptional. Medium on four roles
redefined it as "ordinary", so the text a person reads carried the same weight as the buttons
around it and the interface had a size hierarchy and no weight hierarchy. The scale is now a
table — `TypeRole` to `TypeSpec`, with the weight as a rank so it can be compared — and the
named fonts are read out of it, so a size and its weight cannot drift apart. The invitation and
the thought went back to regular, because both are read and one of them is a sentence the person
is meant to finish. `context` and `action` keep medium, because a context is structurally
louder than what it contains and a control's label is not prose. `TypeScaleTests` states all
of it as rules: regular is the reading default, medium belongs to exactly two roles, semibold
belongs to exactly one, and the scale never exceeds three weights.

**The silhouette of a document object, as a table.** `NodeAppearanceTable` maps each of the
three forms to a boundary and a radius: a thought has no surface and keeps none, a source is a
hairline, a rich result is a hairline plus a rule down the leading edge. Two independent
differences between the two surfaces, so a change to one does not make them identical again.
The shadow came off the source: the world is matte, and elevation is not how an object says
what it is. `NodeAppearanceTests` asserts that no document form is lifted — a claim no
screenshot can make — that a thought keeps no surface, that every radius is a named token
rather than a measured number, and that the vocabulary is still three.

**A result is recorded, and the observation stays what was seen (DEC-05).** `ExperimentResultVersion`
appends to the experiment: an observation, measurements each carrying a unit (a measurement
without a unit is a coincidence with a decimal point, and the command refuses one), what the
run could not do, an optional source validated to exist, and an outcome that is either a
stance on the criterion or an inconclusive result with its reason. Nothing in the type derives
the outcome from the numbers; there is no validity field at all, so none can be invented. A
learning is a `LearnedFinding`: authored, proposed about a scope, referencing the result
version it came from — and `accepted` only ever means it names a decision that already exists,
checked to be about something the learning covers. Recording, proposing and accepting are
refused to proposals outright: the result is what a person saw, and a model that could record
it could manufacture the whole outcome. Twenty-one tests, and the interface reaches it:
`ResultComposerView` keeps observation and interpretation apart by layout, a half-written
measurement is refused rather than half-recorded, the French decimal point is understood, and
the card shows the newest result with the count of the ones before it.

**The streaming hang is named and bounded (A27-06).** The first full real-model run of the
evaluation suite (18 cases, serial, 214 seconds) caught a case that streamed 1407 updates over
169 seconds and never ended: not a slow model, a loop. The service now holds two bounds — a
120-second wall-clock budget and a 30-second stall window — checked between snapshots, and a
stream that trips either one is reported as a generation that never produced an answer, never
flattened into a retry. The second run confirmed both the bound and the intermittency: a
*different* case (j01-fr) looped the same way (1810 updates, cut at exactly the budget), 17 of
18 cases passed every gate, and the suite failed honestly on the one that did not. The bound
is measured against the real distribution: normal cases complete in 0.4 to 5.5 seconds, so a
120-second budget is generous by more than an order of magnitude and cuts only hangs. What
stays owed from A27-06: the unavailable-model exit path has still never been seen (this Mac
reports the model as available), and the three behavioural dimensions still have no judge.

**DEC-06, half proved and the other half said so.** The timeline exists and reads the journal:
`reviewHistory` (offered only when something happened to the object) opens
`HistoryTimelineView`, newest first, each row with the label the person acted under and a
"taken back later" line where a reversal was folded in. `HistoryTimelineTests` (6) hold AC01
— the origin of a decision is answerable because the labels are the ones the person acted
under — and AC02 — the document is byte-identical after opening and closing, so returning to
the present mutates nothing. AC03 is not earned: restore-as-a-new-transaction is not built,
nor the read-only preview with differences, nor the explicit retention purge, and the card
honours that by not offering a restore button it cannot support.

**An experiment is built before it runs (DEC-04, in progress).** `ExperimentLedger` holds the
block: a question and a success criterion that the command layer refuses to leave blank, a
method, the evidence objects the result will be judged against — every link validated against
the document's content at command time, duplicates refused — an optional owner and due date
that carry no status (an overdue date is not a failure), the simulation flag, and revisions
that only ever append. `EditExperiment` never rewrites: the newest revision becomes current
and the old ones stay readable, which is what AC01 and AC03 rest on. Intelligence is refused
the right to build or edit an experiment, because a model that wrote the criterion a thing
would be judged against would be grading its own homework. Fifteen tests, from "the criterion
committed before any result stays readable after edits" to "the same evidence linked twice is
refused, not counted twice". The interface reaches it: `buildExperiment` is a secondary
contextual action on any object, `ExperimentComposerView` carries the two required fields as
required (the submit button does not grey out; the refusal names what is missing, which a
greyed button never does), evidence is prefilled from the selection minus the anchor, the
simulation flag travels from a checkbox to the document, and opening one commitment draft
closes the other. Nine interface tests. The built experiment is readable: `reviewExperiment`
(offered only when one exists, for the reason the impact review is) opens
`ExperimentCardView`, which shows the current revision's committed fields and the revision
count beneath them, evidence by its authored text rather than its id, and never shows an
outcome — there is none. Six surface tests prove the reading is a reading: the document is
byte-identical after opening and closing, Escape dismisses exactly one level, the newest
experiment is the one shown. Not earned yet: AC03's full wording needs a result to exist, and
that is DEC-05.

**The ground answers the zoom.** `CanvasGround.scale` decides from a camera zoom alone:
inside the screen band (9 to 72 points) the minor step of 24 world points draws; below the
band, the major stride of five steps draws as emphasis; when even the stride would be grain,
the ground is silent. The rules it holds are points not lines, one emphasis stride and never a
third scale, one dot diameter at every zoom, and silence only outside the camera's reach — at
the camera's floor the stride is 24 points on screen, so a fully zoomed-out document keeps a
ground, which is where a person is most lost. The dot color is `borderDecorative`, decorative
by role. Eight tests hold the arithmetic, including the one that caught the first draft lying
to itself: at the floor, silence and presence were both claimed, and the band won.

**The branch says what kind of reasoning it carries.** `RelationshipAppearance.treatment` is
the vocabulary: `supports` draws one bar across the stroke, `contradicts` two, every other kind
draws nothing. Two rather than a different shape, because *a pair* is the meaning — one
negates the other. `dependsOn` and `constrains` were considered and refused: they look like a
pair but neither cancels the other, and a marker vocabulary that grows to cover them is a
diagram notation nobody reads. The marker stays square to the stroke wherever the route bends,
found from the route's samples rather than assumed horizontal. Nine kinds, two marked — the
vocabulary stays small, and asserting the ratio is the test.

**What this pass did not establish.** No dark rendering was captured: this app ignores
`-AppleInterfaceStyle`, and the global appearance did not reach a window launched
under XCUITest. The contrast numbers are proved arithmetically, not seen. Nothing was
judged by a person. The system-level states — increased contrast, reduced
transparency, reduced motion — resolve in `Theme` and were read, not exercised.

## Rules

1. A checked task means the stated command was run and its result read. Not that
   code was written.
2. A test that depends on the machine is not a test. Every deterministic test pins
   its engine.
3. `specified` is the honest default for anything written down.
4. Real-model evidence lives in a separate, explicitly marked suite.

## What is proved

| What | How | Where |
|---|---|---|
| Launch, restore, unreadable reported | `InitialContextTests` | L1 |
| Context persisted before any inference | `InitialContextTests` | L1 |
| A new document cannot overwrite the previous file | `InitialContextTests` | L1 |
| Save on quit wired and reported | `InteractionReliabilityTests` | L1 |
| Inline text is an instruction, a failure keeps the draft | `InteractionReliabilityTests` | L1 |
| A local decision does not move the camera | `InteractionReliabilityTests` | L1 |
| Set aside, then reopen with a named action | `InteractionReliabilityTests` | L1 |
| Two-finger scroll reaches the canvas and only the canvas | `ScrollDeliveryTests` | L1 |
| A scroll pans in screen space at any zoom | `CameraTests` | L1 |
| Every availability reason is its own refusal | `AppleAdapterTests` | L2 |
| Ids minted, kinds refused, branch bounded | `AppleAdapterTests` | L2 |
| Deterministic suite is offline and fast | `AppleAdapterTests` | L2 |
| A real model produced a valid proposal, FR and EN | `RealOnDeviceModelTests` | L2 |
| The running app holds no network socket | `netstat` against the app's pid | L2 |
| Steady-state latency, three calls in one process | `RealOnDeviceModelTests`, `--no-parallel` | L2 |
| A real answer streams, and progress is not a proposal | `RealOnDeviceModelTests.realStreaming` | L2 |
| A half-written answer yields progress only, never commands | `AppleAdapterTests` | L2 |
| Streamed and non-streamed answers convert identically | `AppleAdapterTests` | L2 |
| One keep undoes as one action | `VerticalSliceTests` | L2 |
| A source is a reference; a link fetches nothing | `SourceLedgerTests` | L3 |
| A typed sentence becomes an object on the canvas | `KollioUITests`, `./scripts/ui-pass.sh` | L3 |
| The document comes back after a quit with no save | `KollioUITests`, on the real window | L3 |
| A launch opens the newest document, not the default file | `DocumentRestoreTests` | L3 |
| An empty document is never written | `DocumentRestoreTests` | L3 |
| AC01 a complete keyboard path | `PresentationInterfaceTests.theWholePathIsReachable` | L3 |
| AC02 exit returns to the previous camera | `PresentationInterfaceTests.exitRestoresTheCamera` | L3 |
| AC03 no model call to present | `PresentationInterfaceTests.presentingAsksNoModel` | L3 |
| A reader cannot change the document | `PresentationInterfaceTests.aReaderCannotChangeTheDocument` | L3 |
| A skipped point is named, never remapped | `ReadingPathTests.aDeletedPointIsSkipped` | L3 |
| The tour in the running app, editing commands gone | `KOLLIO_REVIEW=presentingmid`, `build/kollio-presentation.png` | L3 |
| AC01 a rejection reason is findable | `DocumentSearchTests.aRejectionReasonIsFindable` | L3 |
| AC02 returning alters no status | `DocumentSearchTests.searchingAltersNoStatus`, `SearchInterfaceTests.choosingAResultAltersNoStatus` | L3 |
| AC03 a private result is absent from the search | `DocumentSearchTests.aPrivateResultIsAbsent` | L3 |
| A set-aside result is revealed without being reversed | `SearchInterfaceTests.revealingIsNotReopening` | L3 |
| A textual search asks no model | `SearchInterfaceTests.searchAsksNoModel` | L3 |
| Zero results keeps the query | `SearchInterfaceTests.zeroResultsKeepsTheQuery` | L3 |
| The search card in the running app, in both languages | `KOLLIO_REVIEW=searchreason`, `build/kollio-search-reason.png` | L3 |
| A citation keeps its revision, and is refused towards nothing | `SourceLedgerTests` | L3 |
| Verification needs an observation and an author | `SourceLedgerTests` | L3 |
| A new revision flags without moving a citation | `SourceLedgerTests` | L3 |
| A failed extraction keeps the previous version | `SourceLedgerTests` | L3 |
| A removed source does not delete the claim | `SourceLedgerTests` | L3 |
| The context budget is measured, required items are never dropped | `ContextProjectionTests`, `AppleAdapterTests` | L3 |
| The payload list is the payload that was measured | `ContextProjectionTests.theListIsThePayload` | L3 |
| A required item that does not fit refuses before both routes' shared preparation | `AppleAdapterTests.requiredOverflowIsRefused` | L3 |
| A narrowed answer records and states its scope | `AppleAdapterTests.narrowedScopeSurvivesConversion`, `ProposalAttributionTests.narrowedScopeIsReadable` | L3 |
| A narrowed answer was reached on a real 8192-token window | the app's own log, `KOLLIO_REVIEW=narrowed` | L3 |
| A local-only projection cannot be sent | `ContextProjectionTests` | L3 |
| Attaching a source is transactional and atomic | `SourceCommandTests` | L3 |
| Intelligence may not attach or verify evidence | `SourceCommandTests` | L3 |
| A chip shows the state of a claim's sources | `SourceChipTests` | L3 |
| The codec and the published schema agree | `SourceCommandTests` | L3 |
| AC01 a CSV with quotes and newlines parses correctly | `SourceReaderTests` | L3 |
| AC02 a PDF with no text layer says so | `SourceReaderTests` | L3 |
| AC03 a pasted link is never fetched | `SourceReaderTests` | L3 |
| A chosen file is read and attached in one transaction | `SourceChipTests` | L3 |
| A file with no text is attached and labelled, not announced as read | `SourceChipTests` | L3 |
| A citation opens at the lines its locator points at | `SourceChipTests` | L3 |
| A page locator shows no passage rather than a wrong one | `SourceChipTests` | L3 |
| A verification is recorded only with an observation | `SourceChipTests` | L3 |
| A chosen passage becomes the quote and the locator, verbatim | `SourceChipTests` | L3 |
| A CSV is previewed as columns, from the revision on record | `SourceChipTests` | L3 |
| AC01 a constraint only blocks within its scope | `ClaimLedgerTests` | L3 |
| AC02 not applicable is not satisfied | `ClaimLedgerTests` | L3 |
| AC03 supported is not absolute truth | `ClaimLedgerTests` | L3 |
| Intelligence may not record how a claim stands | `ClaimLedgerTests` | L3 |
| A claim's scope comes from the selection, and an empty one states nothing | `ClaimInterfaceTests` | L3 |
| A stance needs an observation and the offered stances match the role | `ClaimInterfaceTests` | L3 |

## What is owed to a person

These cannot be automated here, and no line of code substitutes for them.

- Typing a sentence and seeing a proposal arrive. Owed: keystroke injection needs
  accessibility access that this environment refuses.
- A real two-finger scroll on a trackpad, and the feel of it. The wiring is
  proved; the gesture is not.
- Keeping, setting aside and reopening a real proposal by hand.

## Known discrepancies, left visible

- `scripts/run-app.sh --shot` prints a path whether or not the capture worked, and
  captures the whole screen rather than the Kollio window. A screenshot of an
  unrelated private window was produced once in this project and deleted.
- The save path keys on "most recent file in the directory", which is a race when
  two documents are written in the same second. A short uniquifier was added; the
  directory is still acting as an index, which is fragile and should become an
  explicit property of the document.
- The latency reported in an earlier round, 9 to 15 s, does not reproduce. Measured serially it is
  3.6 s for the first call in a fresh process and 2.2 to 2.7 s afterwards. The identified confounder
  is that the real-model suite runs its tests in parallel by default, so two of them hit the same
  on-device model at once. Any latency figure taken without `--no-parallel` is measuring contention,
  not the model. The conclusion is unchanged and the number is smaller than reported.
- A previous version of the deterministic suite inherited the launch default
  engine, took 35 seconds and started failing on a Mac with a usable model. Fixed
  by pinning the engine in every test; recorded because it is the failure mode
  this project is most likely to repeat.
- A constraint that was `satisfied` still reported itself as a block, because
  `blocks` only excluded `notApplicable`. A met constraint is not standing in the
  way, and now it says so.
- Two of my own assertions were theatre: one checked
  `String(describing: HypothesisAssessment.self)` for the word "supported", which
  says nothing about the cases. It now checks the evidence a supported assessment
  actually carries.
- The schema test earned its place a second time: it caught the new `claims` key
  and the version bump to 3 before anything else noticed.
- A citation test picked "the last citation", which was order-dependent by accident:
  the list is sorted by citation id and a new citation's id is a UUID, so the test
  passed, then failed, then passed again. It now finds the citation by its line
  range, and passes three runs out of three. A test that cannot fail is worthless and
  a test that fails at random is worse, because it trains you to re-run.
- A test for an impossible selection used an inverted range, `3..<1`. That is a
  trap in Swift rather than a value that can be passed and refused, so the test took
  the whole test process down with it. The case cannot exist, and the test now says
  so rather than pretending to cover it.
- `importRevision` originally **refused** an extraction that produced no text, which
  was right for CTX-07 and wrong for CTX-02: refusing it meant the chip could never
  show "no text", because the fact was never stored. Both hold now that the attempt
  is always recorded and only *currentness* is decided separately. A usable earlier
  revision stays the one being read; a first attempt that yields nothing becomes
  current, because then it is the best information there is.
- The CSV parser had a bug that would have corrupted every citation made from a
  table. Three separate faults, each found by a test rather than by reading: a
  trailing newline made it return an empty table and discard every row it had
  already parsed; a CRLF pair is a *single* Swift `Character`, so a Windows file
  walked past both `case "\r"` and `case "\n"` and became one single column; and
  an unterminated quote returned half a table that looked complete. All three are
  fixed and each has a test named after the failure.
- The first attempt to build a PDF fixture used a `PDFPage` with a text
  *annotation*. That does not work and never did: annotations are not page
  content, so `page.string` finds nothing. Building through a `CGPDFContext` is
  what actually produces a text layer.
- `SourceReader.read` touched the file before checking whether it was a link, so
  an https URL failed with a file error instead of the rule that refused it. The
  check now comes first.
- The published `.kollio` schema had drifted twice without anything noticing: it
  declared `additionalProperties: false` while the codec had never been compared
  against it, and its `required` list demanded a top-level `provenance` that has
  never existed in the format. A test now compares the two, which is not full JSON
  Schema validation and does not claim to be.
- `Citation` did not record which claim it supported, so nothing could answer "what
  is this object based on". The chip could not have been written without it, and my
  first attempt at `sourceChips` contained a filter that was always true because of
  it. The pairing now lives on the citation, where it survives.
- `KollioModel` exposed no way to run a command from outside, because every existing
  mutation had its own hand-written method. `perform(_:label:)` is now the single
  path, which is also what a source action in the interface will use.
- **`perform(_:label:)` was not that single path.** Its own comment claimed it was,
  and five call sites went straight to `session.apply` instead, so a guarantee
  placed there would have covered four fifths of the ways the document can change.
  CAN-10 needed a guarantee that no write happens while a reading tour is running,
  and that guarantee is now in a private `apply` that all six call sites use.
- `keepPreview` said "kept" whatever the command did, because the confirmation
  followed the apply instead of reading its result. During a tour it would have
  replaced the refusal with a claim that the branch had been kept.
- The first version of the tour kept the contextual action bar on screen. The
  command layer refused every one of its actions, and the refusal was correct, so
  every test passed; the capture is what showed a reading mode still offering
  explore, clarify and set aside. The set is empty for the duration now, and the
  bar is not drawn.
- `ReadingPath.Point.object(id).id` returned `"object:object:x"`, because it
  prefixed a kind onto an identifier that already carries one. The double prefix
  names nothing that exists, so a skipped point would have been reported under an
  identifier no document holds.
- `ObjectID` is `ExpressibleByStringLiteral` and takes the literal verbatim, so
  `"sarah-csv"` is not `object:sarah-csv`. A test written with bare literals
  addressed objects that do not exist and resolved to nothing, silently. It cost a
  debugging round in `ReadingPathTests`, and there is now a test that says so.
- The context budget had a 2000-character floor that could exceed a small model's
  whole window, so it would have claimed more room than existed and truncation would
  have gone undetected. It is now clamped to the window, and a test covers 64, 300,
  1000 and 8192 tokens.
- The first version of the search offered one row per object, so a reason that
  belonged to a branch appeared once for every member of it. Every test passed: the
  domain test asserted that the whole branch was findable through the reason, which
  is true, and read as a feature. The capture is what showed two identical rows
  with identical labels and no way to tell them apart. It is one row per decision
  now, filed under the root of the decided direction.
- The first version of the search card sat in the middle of the view, which is where
  the object it reveals is, so the card covered its own result. Also found by
  looking, and the comment claiming otherwise had been written before the picture
  existed.
- `CommandGroup(after: .find)` does not compile: there is no `find` placement in
  this SDK. The Edit menu's `textEditing` is where macOS puts Cmd+F.
- **The app wrote documents it could never read back, and 697 tests had passed.**
  `mostRecentDocumentURL` preferred the default file over everything, whatever its
  age, so one empty `Kollio.kollio` — written by a launch that had nothing in it, at
  12:08 on 2026-09-27 — shadowed every document written after it. Every launch since
  opened nothing and every quit wrote the empty file again. The automated pass
  found it in one run, and a hand check found it independently five minutes later.
  No test could have found it: each one used a directory it controlled, and the test
  that asserted "a stored document is restored" asserted it against exactly that.
  The newest document by date is the one a launch opens, with a same-second tie
  broken on the sortable stamp in the name rather than on directory order, and an
  empty document is not written at all.
- **`Camera.fitting` magnified small documents to 300%.** It took the largest zoom
  the arithmetic allowed, so a document holding one short object opened framed on
  that object at three times its size, filling the window. It read as a rendering
  fault because the text was soft-edged too; the same capture at the content's own
  size is crisp, so the softness came from the scale factor. No test stated that
  framing should not magnify, because every framing test used content larger than
  the window, where the question never comes up. `Cmd+1` is the command for moving
  closer, and pressing `Cmd+0` is not a request for it.
- The canvas was one accessibility element that absorbed its children's identifiers,
  so `kollio.canvas` answered to two elements and a test asking for the canvas would
  have got whichever came first. Making the canvas a `contain` container fixed it,
  and the object on it is now named `kollio.node.<id>`.
- The first UI test failed on a straight apostrophe against a typographic one. The
  keyboard produced the second and the test file contained the first, so the
  comparison was about the keyboard and calling it the application. It folds
  typographic punctuation now, and only for that.
- The budget was measured, counted and logged, and then ignored: the prompt was
  built from the whole request, so everything the log called a drop was sent
  anyway. Two numbers answered one question and only one was true, and the one on
  screen was the false one. The prompt is now built from the projection, which is
  what `ContextProjection`'s own comment always claimed.
- A required item that did not fit was neither dropped nor refused: it was sent, and
  the model answered about less than it was asked while a log line said the answer
  would be narrower. `AppleModelError.contextTooLarge` existed and was never thrown.
  It is now thrown, on the streaming route as well as the plain one.
- `AppleModelAvailability.explanation` and the two model error messages were English
  literals reaching the status line, so a French person read an English refusal
  about their own question. The comment above them called them localized, which is
  the kind of claim a test should have caught. They are catalog strings now.
- `importRevision` originally left already-verified citations alone when a source
  gained a revision, so a check on a superseded file kept looking current. A
  verified citation is now flagged like any other: the observation is not erased,
  but it is no longer presented as current.
- The first draft of the streaming test proved the projection against malformed
  JSON, which the framework cannot produce: `GeneratedContent(json:)` refuses to
  parse it. The test now covers the case that can actually happen, valid JSON in an
  unexpected shape, rather than a fictional one.
- The first draft of the latency test printed a verdict that separated asset
  loading from generation and fired on a margin of one hundredth of a second. It now
  prints the series and names no cause.
- `ScrollCatcher` was first placed in `.background` with
  `.allowsHitTesting(false)`. That combination cannot work: SwiftUI excludes the
  subtree from hit testing, so AppKit never routes a scroll to it. The view is now
  a topmost overlay that claims a hit only while a scroll event is being routed,
  proved by `ScrollDeliveryTests`.
- The evaluation harness does not aggregate its own metrics.
  `Evaluation.aggregateMetrics(using:)` is a protocol requirement with no default,
  and it is implemented as an empty function. The reason is that the numbers this
  run is judged on come from the verdict recorder, and computing means the report
  does not read would create a second set of figures to keep in step with the
  first. Apple's own `.xcevalresult` is written beside the summary for the cases
  where that aggregate is wanted.
- The first real evaluation run failed 23 findings, and 21 of them were bugs in
  the harness, not in the model. It counted every operation as an idea, so a
  three-direction proposal with a relationship read as four directions; and it
  treated references to objects the proposal itself had just created as
  fabrications. A measurement that reports its own tooling bugs as product
  defects is worse than no measurement, because it is believed.
- Three gate entries were demoted to observations after watching them run, not
  before. `statusWithinExpectation` flipped between `noChange` and `proposed` on
  the same adversarial case across two runs while fabricating nothing either
  time; the language check reads "none" on any short answer; and a bound stated
  in a case's instruction is not enforced anywhere in the code. Each of them
  looked like a reasonable gate in a design and none of them survived contact
  with a real model. The gate now asserts only what the code guarantees, and a
  test fails if the mirrored bounds drift from `AppleCandidateConverter` and
  `ProposalValidator`.
- `Evaluations.framework` cannot be linked into a shipped Kollio product as it
  stands. Its install name is `@rpath/Developer/Platforms/...`, no rpath on a
  SwiftPM product resolves it, and it is a Developer framework rather than a
  system one. The evaluation therefore lives in the test target and needs
  `DYLD_FRAMEWORK_PATH` at run time. That is a measurement tool, not app code,
  and nothing in the product links it.
- The first claim that Apple's evaluation report excludes content was false.
  `includeTranscripts: false` does not redact: the framework serialises the
  sample's expected value, so the authored text of all 18 cases was written into
  the `.xcevalresult`. The fix was structural rather than cosmetic. The
  expectation no longer encodes any authored text at all, the context and the
  instruction reach the runner through a non-`Codable` index, and a test fails if
  an encoded outcome contains an authored string. Verified by grepping the
  produced report after the fix: no fragment, and the report is 112 Ko of counts.
