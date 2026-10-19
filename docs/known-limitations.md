# Known limitations

An honest inventory. Nothing here is a surprise: this is the prototype, not the product.

## Verified on this machine

Recorded 2026-09-26, on an arm64 Mac, macOS 27.0 (26A428), Xcode 27.0 (27A266a),
SDK 27.0.

- **The on-device model is genuinely available here.** `SystemLanguageModel.default.availability`
  is `.available`, 24 supported languages, a context size of 8192 tokens. This was probed directly
  rather than inferred from the SDK being installed.
- **Real generation works, in French and English, on two distinct non-Sarah contexts.** Through the
  adapter, not a standalone script: a French context and an English context each produced a small
  proposal, and both passed the same `ProposalValidator` as any other proposal. **The latency figure
  was wrong in the first version of this file and has been corrected**: see *On-device generation is
  slow enough to need streaming* below for the measurement that reproduces (3.6 s cold in a fresh
  process, 2.2 to 2.7 s warm, 2.50 / 2.68 / 2.29 s for three calls in one process, measured serially
  with `--no-parallel`). Reproduce with
  `KOLLIO_REAL_MODEL=1 swift test --package-path packages/KollioApp --filter RealOnDeviceModelTests --no-parallel`.
- **A measurement suite for the real model exists, and its gate passes.**
  `./scripts/evaluate-apple-model.sh` runs 18 synthetic FR/EN cases serially
  through the real adapter, with Apple's `Evaluations` framework, and wrote
  `build/evaluations/` on this machine. 291 findings, structural gate pass, 5
  behavioural warnings, 44.0 s wall clock. Twenty-one deterministic tests cover
  the gate itself with no model involved. Reproduce with the script above; it
  exits 3 rather than claiming success when the model is unavailable.
- **Three things the evaluation deliberately does not do**, and this is the
  limit of the evidence, not a formality: it does not judge relevance, it does
  not judge whether the next step is useful, and it does not judge language
  quality. All three need a model judge, which is not implemented, so they are
  reported as unmeasured. The two claims that a model is *relevant* and a model
  is *good* are therefore not made anywhere.
- **The language check in the suite is a stop-word heuristic**, and it reads
  "none" on any short answer. Four of the five warnings in the run are that
  heuristic declining to guess. It is not a gate for that reason.
- **The adapter cannot honour a per-request instruction limit.** Its budget is
  `min(request.scope.maxOperations, maximumIdeas)`; the instruction a person typed
  is not a term in it. A case that asks for at most two directions returned two,
  but because the model complied, not because anything enforced it.
- **The adversarial case is answered as an ordinary one, in English.** Asked to
  cite a source that does not exist, the model produced a normal proposal rather
  than saying no such source exists. Nothing unsafe reached the document, and
  structurally a fabricated source is unreachable: the candidate type has no
  citation capability. The behaviour is still wrong.
- **The document keeps an audit ledger, and it is not an event log.** `history`
  records what a person did, in order, and never edits it: an undo is appended as a
  reversal that names the entry it cancels, because "that was undone" and "that
  never happened" are different statements and only the second erases the work. It
  answers one question the document cannot — what happened to this object — and
  that question is the reason it exists. Three limits are stated rather than
  hidden: **it is not authoritative**, so restoring a document from it is not
  implemented and no claim is made that it would work; **it cannot be replayed**,
  so it is not event sourcing and should not be called that; and **a redo records
  nothing**, so after undo-then-redo the ledger still says the action was taken
  back. It also grows without bound, which a real document would have to address.
  Two existing tests asserted that an undo restored a byte-identical document;
  they now assert the content is restored and the ledger has only grown, because
  those are two claims and only one of them was ever true.
- **A second confirm is recorded as a command that changes nothing.** Confirming a
  synthesis, or a comparison's criteria, twice leaves the artefact byte-identical
  but still moves the document's revision, so undoing the second press undoes
  nothing. It is shared with comparisons, and it is recorded here rather than
  fixed for syntheses alone, which would leave the two behaviours divergent for
  the sake of tidiness.
- **No person has seen a proposal's attribution panel either.** The destination,
  the prompt revision, the limitations and what was read are all implemented and
  all covered by 18 tests, and the label on a demo proposal survives into the
  stored record rather than living in a menu. None of that is a screenshot. The
  panel has never been looked at, and the two destinations that would need real
  consent — Private Cloud and a remote service — have no implementation, so what is
  labelled is what a proposal *could* declare rather than what the product can do.
- **No person has seen a synthesis.** The model, the commands, the refusals, the
  file format, the Markdown export, the deterministic composer and the card are all
  in, covered by 85 tests, and AI-06 is `automatedVerified` because its three
  acceptance criteria are proved by named tests. None of that is a screenshot. The
  compact block, the expansion, the outdated banner and the confirmation refusal
  have never been looked at by anyone, in either appearance or either language.
- **The composer is deterministic and has no model behind it.** It writes only
  what it can point at: active objects, rejections with their reasons, hypotheses
  no claim touches. It cannot conclude, and it cannot tell that nothing is
  uncertain, which is why it leaves that one section absent rather than declaring
  it empty. A model-backed composer belongs here later and inherits the same
  budget: an engine line that rests on nothing is refused at the command layer.
- **The running app holds no network socket.** Checked with `lsof` against the app's own pid. This is
  evidence about the on-device path specifically, not a claim that no Mac feature the user turns on
  will ever reach the network.

## Implemented and tested

- **A document can be renamed, duplicated and exported, and the export is one frozen
  scope rendered three ways.** Markdown, PNG and the asset archive all read the same
  `DocumentExportSnapshot`, so a person cannot preview one scope and receive another.
  The PNG is a drawing of those blocks, not a screenshot of the window, which is why
  it is checkable: a test asserts the raster is a real PNG and that every non-blank
  line it draws is a line the Markdown export would have written. The `.kollio` export
  is a portable document that reopens with no dangling internal reference, and it
  deliberately carries no history rather than a partial audit trail whose entries
  describe objects that were not exported. The asset archive copies the files the
  exported scope actually cites and writes a manifest that says, per source, whether
  it was copied, is a link with no bytes to copy, or has moved: a missing file is a
  warning, never a silent omission. Renaming changes the versioned title and the
  registry filename together, and the previous file is removed only after the renamed
  document is safely written. Duplicating produces a new `documentId` with internal
  references remapped, a new file, and an untouched original. Tested in the domain and
  at the model. **What is not proved:** the three export commands were never driven by
  a human through their system dialogs, and a frozen scope of a real long document has
  not been read as a picture yet.

- **The document can be read along a chosen path, and read only.** `ReadingPath`
  is a value rather than document state: points keep their order, resolve against
  the document as it is, and a point that no longer resolves is skipped and counted
  rather than replaced by whatever now occupies its place. A source and a decision
  are points, anchored where they can be read. Every write goes through one guarded
  path that refuses while a tour runs, so set aside, reopen, create, update, keep,
  a move and a raw decision are all refused and the document stays byte-identical;
  the contextual action set is empty for the duration, so nothing is offered to
  press either. The camera is restored exactly on exit, through Escape as well as
  through the button, and Escape closes it through the same level stack as every
  other card. `Cmd+Return` starts and leaves, the arrows move between points, and
  the walk stops at both ends. No model is called, on any step. Tested in the domain
  and at the interface, and seen in the running app.
- **Search over titles, bodies and reasons, with what was not searched named.**
  `DocumentSearch` is a pure function of the document. A result says whether it is
  on the canvas, set aside, or history, and that state is a property of the match
  and not only of the object, so a reason whose decision no longer stands is
  offered as history rather than as the reason that applies today. Matching ignores
  case and accents, a reason is searched in the language being read, an excerpt is
  the words around the match, a title match outranks a reason outranks a body, and
  the same query always gives the same list. Rights are applied before the search
  and source content is not read to look for words, both named in `notSearched`.
  Choosing a result reveals its branch in the view only: the document stays
  byte-identical, the revision does not move, the direction stays set aside, and
  reopening remains a separate action. Zero results keeps the query and offers to
  clear it, Escape closes the card without touching the selection, and no model is
  asked. Tested in the domain and at the interface, and seen in the running app in
  French and English.
- **The context budget is now the payload, not a count beside it.** The projection
  that was measured is what the prompt is built from, so an item the log calls a
  drop is not sent. A required item that does not fit refuses the request and asks
  for a narrower question instead of answering about less and staying quiet, on the
  streaming route as well as the plain one. A narrowed answer carries
  `ProposalContextScope`: what was read, what was left out, and a count declared as
  characters rather than tokens. "What was read" is filtered by that scope rather
  than read off the request, and the scope is on the status line as well as in the
  attribution panel. A complete answer records no scope, so the row is not always
  lit. Tested in the domain, in the adapter and at the interface, and reached on a
  real 8192-token window: the on-device run logged one optional item dropped, a
  proposal arrived, and both the status line and the read list were narrowed.
- **The on-device availability and failure messages are localized.** They were
  English literals reaching the status line, so a French person read an English
  refusal about their own question, under a comment that called them localized.
- The entry point: a launch with no stored document shows the initial input, a stored document is
  restored, and an unreadable one is reported without being overwritten. Sarah is only ever reached
  through the explicit demo menu action. Tested.
- The typed context: the authored sentence is preserved exactly, becomes a real context object with a
  stable identity, is shown on the canvas, and is persisted **before** any intelligence is requested.
  A dead backend cannot cost the user their words. Tested.
- Editing the context: one object changes, keeps its identity, bumps only the semantic revision, and
  undoes as one action. Nothing else in the document moves. Tested.
- The request-bound document snapshot: bounded, layout-free, reference-checked, and rejected when
  oversized, incomplete, of the wrong document version, or inconsistent. It rebuilds a real narrow
  document on the server rather than a fixture. Tested in the domain.
- The proposal route, exercised against a **separate local server process** with the demo provider:
  two different client documents answered separately, in English and in French; a stale revision is a
  409; a snapshot from another document, an unknown target and a missing snapshot are 400s; a bad
  token is a 401. Verified over real HTTP.
- The provider wire contract, with a mocked transport and no key: the documented `response_format`
  field with a named `json_schema`, a schema that matches the DTO actually decoded, a valid candidate
  assembled by the server, and missing fields, truncated output, unknown references, unknown kinds,
  refusal, quota errors and timeouts all rejected. Tested.
- The sentence typed in the inline composer reaches the intelligence source as the request's
  instruction, and a failed call leaves the draft in the composer instead of discarding it. Tested with
  a capturing fake source.
- The document is saved when the app quits normally, with no Cmd+S: the app delegate is connected to
  the model the window is showing, and both quit hooks report a failure rather than swallowing it.
  Tested through the real delegate, and confirmed end to end by quitting the launched app and finding
  the document on disk afterwards.
- A local decision, set aside or reopen, leaves the camera exactly where the user left it. `Cmd+0`
  remains the explicit reframe. Tested.
- A collapsed direction is selectable, so its contextual "Reopen" button is reachable by click, and
  reopening is also a named accessibility action rather than a double-click only.
- The on-device adapter behind the existing `SuggestionService` seam: a compact `@Generable`
  candidate, a trusted conversion that mints identifiers and refuses kinds the canvas cannot render,
  a branch bounded to a few ideas, and `noChange` / `needsInput` passed through as themselves. Tested
  with a stubbed probe, so every unavailable state is reachable and no test needs Apple Intelligence.
- Availability is read from the reasons the SDK actually reports, and each maps to a distinct
  explanation. An unavailable model is a refusal: the app never falls back to the demo engine, never
  calls a network, and never claims an answer it did not get. Tested.
- Service selection: with no preference a usable on-device model is preferred over the offline engine;
  an explicit `demo` is respected even when the model works; `server` without a token falls back and
  says so. Tested.
- The deterministic suite never touches a real model. It runs in under two seconds and passes
  identically on a Mac with and without a usable system model, because every test pins the engine
  explicitly.
- `.kollio` document: versioned JSON, exact round-trip, stable ids, portable geometry, no renderer type
  in the file. Tested.
- Commands, transactions, atomicity, undo and redo. Tested.
- Durable decisions: set aside, collapse without deletion, reopen with the exact positions, survival of
  save and reload. Tested.
- Proposals: validation of ids, invariants, operation budget, staleness, forbidden operations. Tested
  in the domain, again in the client, and again in the server.
- The offline engine reacts to the real document state rather than replaying a sequence. Tested.
- Canvas geometry: world/screen round-trip, pan, zoom around an anchor, drag at several zoom levels,
  framing, connector endpoints. Tested.
- Connector obstacle avoidance: a connector never crosses an object that sits between its ends. A
  clear connector keeps the exact curve it had before, a blocked one detours around the side needing
  the smaller excursion with a fixed clearance, and the relationship label follows the curve. Tested.
- The vertical slice: Sarah, Explore, ghost branch, Keep, Undo, Explore again, Set aside with a reason,
  Reopen, save, quit, reopen. Tested end to end through the real model and the real file.
- The server: routes, bearer auth, scoping, provider swap, timeouts, cancellation, rate limiting, and
  the safety cases (malformed output, refusal, disabled remote provider). Tested.
- The server-backed client flow, through the real routes and the real JSON. Tested.
- French and English interface, from a native String Catalog, with no key ever visible.

## Implemented, seen on screen, but not automated

- **Nobody has walked a tour with a keyboard**, and the source step's reader has
  not been seen on a screen. The whole path is covered by tests and the card was
  captured in English, which is not the same as a person pressing the arrows.
- **The search card's "not searched" line has never been seen.** It is implemented
  and covered by tests, and it cannot appear in the two states that were captured:
  Sarah holds no attached source, and a local search is unfiltered, so there is
  nothing to hold back. Reaching it needs a document with evidence, or a
  permission-limited search, and neither is reachable from the demo fixture.
- **The scope of an answer has never been seen on a screen, and the reason is now
  understood.** Reaching the state needs a document whose context crosses a real
  8192-token window, so `KOLLIO_REVIEW=narrowed` and `KOLLIO_REVIEW=toobig` build
  one, and two tests prove the arithmetic against that real window rather than
  trusting it. The app reaches the state: the running app logged the truncation,
  produced a proposal, and set the status line to "Answered from part of the
  context: 1 item(s) did not fit." What could not be captured is a legible picture
  of it, because a document that large is a single node thousands of points tall,
  the canvas frames the whole content when it appears, and the status line and the
  attribution panel are drawn inside the same stack as that node. The captures in
  `build/kollio-narrowed.png` and `build/kollio-toobig.png` show the document those
  states produce and **not** the notice, so they are evidence of nothing about it.
  The scope row joins the list of things a person still has to look at.
- **The real-model suite is not deterministic.** One run of
  `RealOnDeviceModelTests.realStreaming` on 2026-09-27 failed after 313 s with the
  framework's own refusal, "Streamed response may contain sensitive or unsafe
  content". The same test passes on the clean tree and on the changed tree, and the
  prompt it sends is byte-identical either way when nothing is dropped, so nothing
  attributes the failure to a change. It is a local model refusing one run out of
  several, and the honest reading is that this test can fail without a defect. The
  313 s is also unexplained and is not the 8 to 12 s the passing runs take.
- **The human pass is automated, and it is not the one the repository expected.**
  `./scripts/ui-pass.sh` runs `KollioUITests`, which types a French sentence into the
  entry point with a real keyboard, presses the action, reads the canvas back by
  name, quits with no `Cmd+S` anywhere, and checks the document comes back. Two
  tests, both green, run against the real application over the accessibility bridge.
  The target is generated by `scripts/sync-xcodeproj.py` like every other target,
  and the app names what a test looks for in `AXID`.

  Three things about it are worth stating because two of them contradict what this
  file used to say:

  - **Accessibility is granted on this machine.** `AXIsProcessTrusted()` is true for
    the process that runs the check, and the test runner needs no permission at all
    — XCUITest does not post to the HID tap, it talks to the application over the
    accessibility channel. The old claim that "keystroke injection needs
    accessibility access, which this environment refuses" was half wrong and is gone.
  - **The window opens on the second display, and every element in a snapshot is
    reported `Disabled` because of it.** Clicks and keystrokes still arrive, which
    is why the pass is green. A reader of a test log will otherwise think the
    elements are untouchable.
  - **It is not in `verify.sh`,** because it needs a window and `verify.sh` must
    pass on a machine with no display.

  The pass is not decoration: it found two product bugs on its first run that every
  other suite in this repository had passed, and they are written up below.
- **A document written by the app could not be read back, and had not been since
  12:08 on 2026-09-27.** `DocumentFileStore.mostRecentDocumentURL` returned the
  *default* file whenever it existed, whatever its age. An empty `Kollio.kollio`
  was written by a launch that had nothing in it, and from then on every launch
  preferred it over real documents written minutes later. Documents kept being
  written, to their own names, and were never opened again. The name is not a claim
  about which document is the work; the date is, and a same-second tie is broken on
  the sortable stamp in the name rather than on directory order.
- **Framing a small document magnified it to 300%.** `Camera.fitting` took the
  largest zoom the numbers allowed, up to the maximum, so a document holding one
  short object opened framed on that one object blown up to fill the screen. It
  looked like a rendering fault — the text was also soft-edged — and it was the
  same fault: the same capture at its own size is crisp, so the blur came from the
  scale factor and not from the screenshot. Framing now shrinks and centres and
  stops at the content's own size; `Cmd+1` remains the way to move closer. No test
  stated the rule before, because every test framed content larger than the window,
  where the question never arises.
- **A quit with nothing in the document wrote an empty file.** That is the file that
  did the shadowing, so the two were one bug seen from two sides. Nothing is written
  for an empty document now: there is nothing in it to keep.
- Both were found by the automated pass and by hand, and neither was found by 697
  tests. Every one of those tests used a temporary directory, so no test ever had a
  stale file to trip over, and one of them asserted "a stored document is restored"
  against a directory it controlled. `DocumentRestoreTests` now covers both halves
  against a directory that is really used and really left behind.
- Pointer interaction beyond the entry point — dragging, double-clicking to explore,
  pressing the contextual buttons — is still not driven by a UI test. The model behind
  each gesture is covered and the states were captured as screenshots, but a person
  with a trackpad has still never done the pass.
- A full run with a ghost branch proposed by the **real on-device model** has not been captured. The
  generation, the conversion and the validation are each verified; the assembled screenshot is not.
- `scripts/run-app.sh --shot` captures the **whole screen**, not Kollio, and focusing Kollio first is
  not enough: on this machine another application takes the foreground back within a second or two,
  and has been observed submitting its own input while a capture was being taken. A capture taken by
  this script is therefore evidence of nothing unless the file has been looked at. During CAN-05 two
  attempts produced Mail and then another app, and a third attempt to crop to Kollio's window
  coordinates captured the other app again, because the coordinates are where the window *is*, not what
  is drawn there. The CAN-05 menu was **not** seen on screen; its behaviour rests on the twenty tests.
  The script should capture the window by id (`screencapture -l`) and should fail loudly when the
  frontmost process is not Kollio, rather than printing a path either way.
- **Capturing Kollio's own window works, done by hand.** `screencapture -l <window id>` with the id
  read from `CGWindowListCopyWindowInfo` produces a picture of Kollio and nothing else, which the
  three earlier attempts in this file did not manage. Two captures were inspected for CTX-05 this way:
  the entry point in English (`build/kollio-window.png`) and in French
  (`build/kollio-window-fr.png`), both in the light appearance, both containing only the Kollio
  window. It is not in `run-app.sh` yet, because the id lookup needs a small helper and a capture path
  that can fail silently is the thing this file is complaining about.
- **CTX-05's review card has not been seen on a screen.** Reading and marking an impact is covered by
  `ImpactReviewInterfaceTests` and `ImpactAssessmentTests`, and the resting state of the app was
  captured, but reaching the card needs a selection and a click, and keystroke and click injection are
  refused by this environment: an `osascript` keystroke into the launched entry field produced no text.
  The card's layout, its two lists and the mark on the object are unverified by a person.
- An assessment records the **first** moved citation of a claim. A claim citing two sources that have
  both moved is offered one review, and the other source appears in no assessment until the first has
  been dealt with. The read set says which one was read, so the answer is not wrong, it is partial.

- **A frame is created from the first drawing of each selected object.** Putting a
  selection in a frame uses each object's first instance, not the drawing under the
  pointer, so with an object drawn twice the frame may take the one the person was
  not looking at. It never takes the wrong *object*, and a member can be taken out
  again in one action, but choosing the occurrence under the pointer is not wired.
- **Moving a frame has no keyboard path.** Folding, renaming and removing are named
  buttons in the frame's header, so they are reachable by keyboard; the drag is
  pointer only, as every direct manipulation on this canvas is today.
- A frame's rectangle is computed from the estimated node sizes until SwiftUI has
  measured them, so a frame drawn in the first moments after a launch is slightly
  the wrong size and then settles. It is a cosmetic inaccuracy and it corrects
  itself, unlike the cached size the first version stored, which could have
  disagreed with the members for good.
- **`"sources": {}` in a hand-written `.kollio` is refused.** The ledgers encode
  their collections as arrays, and a document that uses an empty object where the
  format writes an empty array is reported as unreadable and left on disk, which
  is the correct behaviour and is easy to trip over when writing a fixture by hand.
  Found while seeding a document to put a frame on screen.

- **AI-05's card has never been seen on a screen.** Everything it does is covered by
  `ComparisonInterfaceTests` and `ComparisonTests`, and a saved comparison loads
  into the running app without disturbing the canvas, but the card needs two
  selected objects and an action behind the secondary menu, and no click can be
  injected in this environment. Its layout, its grid and its two editors are
  unverified by a person.
- A criterion can be given **one number** as its weight. A criterion that should be
  compared as a range, or whose weight depends on the direction being weighed, is
  not expressible, and a total is therefore defined over single numbers only.

- **Building the app target in Xcode rewrites `Localizable.xcstrings` in the source
  tree.** Observed 2026-09-26: a Cmd+R build left the file with five
  `relationship.*` keys missing and five new keys that are bare format patterns
  (`%@ %@`, `%@ · %lld`), which is Xcode's automatic string extraction writing back
  into the repository. The committed catalog is the one that was verified, and the
  rewrite was reverted with `git checkout`. Until the project turns extraction
  output off, **a build can leave the working tree dirty in a way that has nothing
  to do with the change being made**, so `git status` after a Cmd+R is worth reading
  and `verify.sh` does not protect against it.

## Simulated or approximated

- **The offline "intelligence"** is a rule engine with authored demo content, not a language model. It
  is deterministic and state-reactive, which is what the prototype needs, and it is not evidence that
  a real model produces good proposals.
- **`GroqProvider` has never been called with a real key.** Its wire contract is now correct and
  tested against a mocked transport, which is evidence about the request and the decoding, and
  **nothing at all** about the quality, latency or reliability of a live model. Treat its output
  quality as unknown until a small live test is authorised.
- The server validates against the snapshot the client sent, scoped to the requested neighbourhood.
  It validates the operations in that slice and nothing else: it does not see the rest of the
  document, and it is not authoritative. A partial snapshot is reported as partial rather than
  validated as if it were whole.
- A service is chosen by environment variable, not by UI. A `server` mode with no token in the
  Keychain falls back to the offline engine, and the status line says which source is in use. There is
  no provider control panel, and a live-mode error is reported rather than silently downgraded.
- **On-device generation is slow enough to need streaming, and an earlier 9 to 15
  second figure does not reproduce.** Measured 2026-09-26 on the same Mac, serially:
  the first call in a fresh process is 3.6 s, later calls are 2.2 to 2.7 s, and a
  three-call series in one process runs 2.50 s, 2.68 s, 2.29 s. So the cost is
  mostly per call rather than a large one-off asset load.
  An earlier round reported 9 to 15 s and called it the dominant finding. That
  number is not reproducible and the cause is unconfirmed. The most likely
  explanation is contention: the real-model suite runs in parallel by default and
  two tests hit the same on-device model at once, which pushed the first
  measured call to 7.08 s. Real-model latency must therefore be measured with
  `--no-parallel`.
  What survives is the conclusion, not the number: 2.3 s is still far too slow to
  feel interactive. The wait is now filled, because the answer streams: 54 progress
  updates over 5.1 s on a real model, the rationale arriving a few words at a time.
- **Streaming shows progress, not a forming proposal.** Only the rationale text and a
  count of directions are shown. A half-decoded direction is never drawn on the
  canvas, because it has no identifier, no kind the canvas can trust, and no way to be
  validated. The ghost branch still appears all at once at the end. Streaming the
  actual objects is not built.
- **Streaming is proven on the on-device path only.** The remote provider does not
  conform to `StreamingSuggestionService`, so a server round trip still waits for the
  whole answer. The seam allows it; nobody has done it.
- The on-device candidate is a small, fixed shape: an outcome, one sentence, and a bounded list of
  ideas. It cannot propose decisions, question existing objects, or edit a relationship's meaning,
  because the adapter does not yet convert those. This is a limitation of the conversion, not of the
  model.
- **Apple Private Cloud Compute is not implemented and not evaluated.** Entitlement, distribution
  route, quota and runtime availability are all unverified on this machine. No request leaves the Mac
  today, and nothing in the code path would send anything.

## Not built


Everything in the non-goals, and also, honestly:

- **Keyboard traversal of the canvas.** Nodes are focusable and actions are reachable, but there is no
  arrow-key navigation between objects.
- **Reduced motion and increased contrast** are honoured in the motion and border tokens, and have not
  been walked through with a human eye under those settings.
- **No performance measurement.** 100 objects and 200 relationships is the stated target; nothing has
  been measured. Off-screen culling is available on the camera and unused.
- **Two-finger scrolling is wired and its routing is tested; the gesture is not verified by a
  person.** An earlier version placed the catcher in `.background` with `.allowsHitTesting(false)`,
  which cannot work: SwiftUI drops that subtree from hit testing, so AppKit never routes a scroll to
  it. It is now a topmost overlay that claims a hit only while a scroll event is being routed, and
  `ScrollDeliveryTests` proves three things: a scroll reaches the canvas, a click does not, and a
  text field outranks both. **Still owed:** a real trackpad scroll and its feel, which no test
  substitutes for.
- **A file can now be attached, but almost nothing about it can be done with it.**
  There is a chooser, a reader and a chip. There is no way to open a citation at its
  passage, no way to record a verification from the interface, no reader for a long
  PDF and no CSV preview, so a table is read correctly and then shown as raw text.
- **L3 has a chip but no way to fill it.** `SourceLedger` is part of the document, its
  commands are transactional, and a claim now shows a chip saying what state its sources
  are in. But there is still no way to choose a file, read it, or import its text, so in
  practice every chip says "not read yet" unless a document was written by something other
  than this app. Nothing opens a citation back at its passage, and nothing records a
  verification from the interface.
- **The schema had drifted and nothing noticed.** `contracts/schemas/kollio-document.schema.json`
  declared `additionalProperties: false` while no test ever compared it to what the codec
  writes, and its `required` list demanded a top-level `provenance` that has never existed.
  Both are fixed, and a test now compares the codec against the schema. It is not full JSON
  Schema validation and does not claim to be.
- **The context budget is counted in characters, not tokens.** The app cannot know the
  model's tokenizer, so the conversion is a documented estimate, clamped so the budget can
  never exceed the model's real window. It is honest about being an estimate, and a
  truncation is reported, but it is not a token count. The scope record carries the same
  unit honestly: `ProposalContextScope.countsTokens` is `false`, so a number in the
  attribution panel cannot be read as a token count by mistake. What is real is the
  measured size of the payload that was actually built.
- **The specification is written down; most of it is not built.** 72 features and 217 acceptance
  criteria exist in [specs/SPECIFICATIONS.md](specs/SPECIFICATIONS.md). 34 are `automatedVerified`,
  1 is `humanVerified`, 36 are `specified`, which means written down and nothing more. Read
  [../openspec/specs/evidence.md](../openspec/specs/evidence.md) for the proved, the owed and the
  wrong.
- **The local action bar spoke key names, not French.** `ContextualActionSet.Kind.localizationKey`
  returned `explore`, `clarify` and `setAside`; the String Catalog holds `canvas.explore`,
  `canvas.clarify`, `canvas.setAside`. `String(localized:)` does not report a missing key, it
  returns the key, so the primary local controls of a French window read `explore`, `clarify`,
  `setAside` and `Plus`. Four more keys were absent from the catalog entirely. All are fixed and
  `ContextualActionLabelTests` now walks every kind, because the failure is silent and the
  mistake is cheap to repeat. The label this exposed is worth keeping: `.add` was pointing at
  `clarify`, so the button said "Clarify" over an action that adds.
- **The local action bar had no accessibility identifier.** `AXID.contextualActions` existed and
  nothing used it, so the cluster was absent from the accessibility tree: a VoiceOver user could
  reach the three actions but nothing announced the group, and a UI test could not find the bar
  at all. It is named now, as a container.
- **Dark mode has never been looked at.** The contrast work is proved by measurement
  (`OnAccentContrastTests`: white on the dark accent is 2.15:1, the dark ink is 8.12:1), and the
  fix is on the code path that renders it, but no dark rendering has been captured on this
  machine. `-AppleInterfaceStyle Dark` is ignored by this app, and setting the global appearance
  did not reach a SwiftUI window launched under XCUITest. It is the largest unverified claim in
  the visual layer.
- **The local controls now decide their own material, and that decision is the point.**
  Under reduced transparency the instruments stop being glass and become a surface with a
  border. That was a gap, not a feature: the previous version asked the system material to
  stay findable, which is a hope rather than a decision, and a control that depends on what
  is behind it in order to be seen is not a control. `InstrumentMaterial.resolve` is a pure
  function and `InstrumentMaterialTests` decides the matrix, so the fallback cannot be
  quietly removed. The opaque surface is the only hand-drawn material in the application.
- **The typographic hierarchy was carried by size alone.** Six roles, one family, and four of
  them set at medium, which quietly redefined medium as "ordinary" and left the reading text at
  the same weight as the controls around it. The document's rule is three weights with one job
  each — regular reads, medium distinguishes, semibold is exceptional — and it was not being
  followed. The scale is now a table of role to size and weight, so a size cannot drift away
  from its weight, and the invitation and the thought went back to regular because both are read.
  The one exception, the mark that says the ground moved, is now the only semibold in the
  application, and `TypeScaleTests` fails if a second thing takes it.
- **Two document forms looked like the same card.** A reference and a rich result were both
  white rounded rectangles, separated by four points of radius and by the fact that one had a
  shadow. On a canvas with ten objects that is not a usable distinction, so what a thing *was*
  was carried by a small icon while its shape carried nothing — and the shadow made a document
  object look like a card lying on top of the work. Silhouettes are now a table,
  `NodeAppearanceTable`: a thought has no surface and keeps it, a source is a hairline and no
  elevation, a rich result is a hairline plus a rule down the leading edge, so it reads as a
  section of the document. The rule is one thin rectangle, not a second colour and not a new
  radius token. `NodeAppearanceTests` says no document object is lifted, which a screenshot
  cannot say.
- **The result's surface has been seen by no one.** Recording a result, proposing a learning
  and reading the outcome are all implemented and held by named tests (`ExperimentResultTests`,
  `ResultInterfaceTests`), but no person has recorded one yet, and the acceptance flow that
  follows — taking the decision the learning points at — runs through DEC-01's own composer,
  untested as a combined loop.
- **The history timeline previews, restores and purges, but the preview is not a diff.**
  `reviewHistory` shows what happened to an object, newest first, with the labels the person
  acted under, and closing it changes nothing. Each row now offers a read-only preview of the
  document at that action and a restore; the card offers a purge against a retention horizon.
  `HistoryRestoreTests` (6) covers the three acts, including the two that were wrong before
  the tests existed: a replay no longer applies a reversal (which carries the payload of what
  it undid, and would have resurrected it), and a restore no longer empties the journal (it
  would have deleted the very timeline the person was reading).
  What is still missing: the purge horizon is a fixed thirty days rather than a choice, and
  neither the timeline nor the preview sheet has been seen at all. The canvas around them has
  been observed running — the entry screen, the demo document, its relationships, the status
  line — and reads correctly, in the interface's language. Everything behind a contextual set
  has not: opening the timeline, reading a preview and confirming a purge were not reached,
  because reaching them needs UI driving and this session is under a standing instruction not
  to build capture tooling. A green suite and an unlooked-at card are different things, and only
  one of them is evidence.
  The differences themselves are built and tested: the preview shows what changed about this
  object, not the past document in full, because that was the question the timeline was asking.
  A replay starts from the document as this session opened it, held on the session rather than
  in the document: the journal records what happened since, so replaying from an empty
  document would rebuild only the edits and lose the content they were applied to. A file
  written last week and reopened today therefore replays from its own content — but only
  across one session, because that base is not written to the file.
- **DEC-04's experiments exist in the document and nowhere else.** The domain holds a
  validation experiment as a ledger: question, method, success criterion, the evidence it will
  be judged against, owner, due date, the simulation flag, and an append-only revision list so
  the criterion a person committed to stays readable after an edit. `ExperimentTests` (15)
  proves the ACs that are earnable now: criteria kept across edits, evidence links validated
  against the document (a link to a thing that does not exist is refused, a duplicated link
  too), undo, save and reload, and intelligence being refused the right to build one. What does
  not exist yet: any way to build one from the interface, any surface that shows one, and
  DEC-05's result, without which DEC-04 AC03 ("editing *after a result*") is not fully earned.
  The status file says `inProgress` for exactly that reason. The interface half exists:
  `buildExperiment` in the contextual menu, `ExperimentComposerView` with the required fields
  required, evidence prefilled from the selection, undo and refusal with a reason, and
  `reviewExperiment` opening `ExperimentCardView` — question, method, committed criterion,
  evidence by authored name, the simulation flag, and the revision count when there is more
  than one. Escape closes it one level at a time and reading writes nothing. What has never
  happened: a person building one, reading it, and trusting the reading — no human eye yet.
- **A zoomed-out canvas gave no sense of where you are.** Panning or zooming moved the world
  over a flat colour: nothing on the paper told a person where they were, so a return to a
  document meant re-finding it by eye. The ground is now a dot grid that scales with the world —
  a minor step of 24 points, and when the minor step would draw as screen grain the major
  stride (5 steps, drawn as emphasis) takes over. `CanvasGround.scale` is the decision, tested;
  `CanvasGroundLayer` is the drawing. Points, not lines — lines cut space into corridors. The
  grid never takes a hit, dies completely under reduce transparency, and is silent at zooms
  where even the stride would be grain. What a capture cannot prove: whether the dots read as
  ground or as dirt at any real zoom, which is for eyes.
- **A relationship's kind is only readable at one point, and only from words.** The nine kinds
  of relation rendered identically, so whether a thing *supports* or *contradicts* had to be
  read from a twelve-point label at every connector. A support now carries a single bar across
  the stroke, a contradiction two — the pair being the meaning, rather than a second shape to
  learn. Most kinds wear nothing, which is the point: `RelationshipAppearance.treatment` is the
  table, and adding a marker for a kind that is not an assertion is what turns this into UML.
  The marker is drawn on the stroke and the label keeps its own font, because meaning is never
  expressed by making meaning harder to read.
- **The elevation scale in the design system is not used by anything.** `Elevation` is declared
  and read nowhere, while twelve views hand-write their own shadow. The world layer now carries
  none at all, so the remaining shadows are all on transient surfaces — but they are still
  invented numbers, and collapsing them onto the system material needs a pass that can see the
  screen. Left alone on purpose rather than swept blind.
- **Nothing here has been seen by a person.** Every change in this pass was verified by a test or
  by a capture the machine took of itself. Whether the local bar is pleasant to reach with a slow
  pointer, whether the glass reads as an instrument rather than as a row of pills, and whether the
  type is right are all still owed to somebody's eyes.
- **The canvas is measured, and one measurement is not a frame.** A 100-object, 180-relationship
  document on a 10x10 grid went from 149 ms to 5.6 ms per render pass, and a click went from
  133 ms to 2.9 ms. The 149 ms was a router testing every obstacle against every curve, 49
  samples at a time; a corridor around each chord rejects the obstacles that cannot matter for
  four comparisons, and a curve is sampled once instead of once per obstacle.
  `CanvasScaleTests` holds the pass against a ceiling, and holds the shape by *counting samples
  instead of timing them*: a connector samples the obstacles in its corridor and only those, so
  growing the document fourfold does not grow what it samples. Measured 1.00x.
  An earlier version of that test asserted a ratio of two timed passes and failed about one run in
  three, because a busy machine preempts the shorter pass proportionally harder than the longer
  one. The machine had to come out of the measurement, not be tolerated in it — the counting test
  runs in 0.17 s against the timing one's 1.1 s, and passes on a loaded machine.
  What is not measured: SwiftUI's own draw time, which needs Instruments on the running app, and
  every number here is from a `swift test` process, not from a person dragging.
- **The deployment floor is macOS 26, decided rather than derived.** It was 14, written in four
  places at once, and one of them was `services/KollioServer`, which is not in the Xcode project
  but is in the package graph, so raising the app alone failed with an error naming the wrong
  package. The floor is now 26.0, written once in `sync-xcodeproj.py` and once in each of the
  three manifests, all of which are `swift-tools-version: 6.4` because `.v26` does not exist
  below it. This is what makes `.glass` and `.glassProminent` usable without a fallback, and it
  is a choice about who cannot install Kollio, not a technical necessity.
- **No web renderer, no public SDK, no standard.** Intentional.
- **No accounts, no payments, no marketplace, no collaboration.** Intentional.
