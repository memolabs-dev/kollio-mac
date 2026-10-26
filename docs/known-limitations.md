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

- Real pointer interaction: dragging, double-clicking to explore, pressing the contextual buttons. The
  model behind each of these is covered by tests and the resulting states were captured as screenshots,
  but the click coordinates themselves were not driven by an automated UI test, because this
  environment does not grant UI scripting access. A human should still do a pass with a trackpad.
- The entry point as a user reaches it: the invitation, the multiline field and the primary action were
  seen in the launched app (`build/01-entry.png`). **Typing a sentence and pressing the action was not
  done by a human or a script**: keystroke injection needs accessibility access, which this
  environment refuses. The behaviour behind it is covered by tests against the real model, and the
  transport it triggers is covered separately, but the two have not been joined by an actual person
  typing.
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
  truncation is reported, but it is not a token count.
- **The specification is written down; most of it is not built.** 71 features and 213 acceptance
  criteria exist in [specs/SPECIFICATIONS.md](specs/SPECIFICATIONS.md). 15 are `automatedVerified`,
  1 is `humanVerified`, 55 are `specified`, which means written down and nothing more. Read
  [../openspec/specs/evidence.md](../openspec/specs/evidence.md) for the proved, the owed and the
  wrong.
- **No web renderer, no public SDK, no standard.** Intentional.
- **No accounts, no payments, no marketplace, no collaboration.** Intentional.

## Screenshot privacy gate (25 October 2026)

The old `run-app.sh --shot` saved the whole display and could include the wrong foreground app. The new script uses ScreenCaptureKit and **only** captures exactly one window whose owner has bundle ID `dev.kollio.app`. It fails closed on missing TCC/Screen Recording permission, zero/multiple windows and capture failure. A successful PNG still requires visual inspection to demonstrate correct product content. The independent clean-user journey and product video are still **unverified**. See issue #30.
