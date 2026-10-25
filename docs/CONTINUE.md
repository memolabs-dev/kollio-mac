# Continue Kollio

Paste this into the agent working in the `Kollio.xcworkspace` window.

---

You are continuing **Kollio**, a macOS prototype: a living visual document that humans and AI build,
question and evolve together. The canvas is the application. A `.kollio` document is the product
model. An intelligence source proposes a patch; it never regenerates the world.

The direction is [PRODUCT_BLUEPRINT.md](PRODUCT_BLUEPRINT.md). Read it once, not every task.

## Spatial Ink V3 — C2.18 STAR loop

C2.18 provides a contextual **Card actions / Actions de la carte** command reachable in compact 680×520 windows, both in the native card navigation region and at the viewport-leading canvas edge for an actually visible selection. Explicit navigation scrolls to the canvas; explicit action navigation scrolls to the selected-card inspector and focuses Edit (or Close for read-only fixtures); Escape/Close scrolls and returns to the native navigation menu. New SwiftUI FocusState and AccessibilityFocusState bindings never intentionally move focus for incidental selection updates. **22/22 focused and 408/408 full KollioApp tests (48 suites)** pass, with serial native FR/EN selected-card renders inspected and no model mutation. The AppKit accessibilityChildren probe yielded no usable AX identifiers in the accessory-window test harness, so real VoiceOver/Tab and physical Escape remain unverified gates; do not overclaim accessibility acceptance. Build target validation: actual Debug Xcode macOS app build passed with Swift 6. Source parity/FR+EN native String Catalog and generated spec views were checked. GitHub CI after publication remains the remote gate. See [C2.18 STAR](SPATIAL_STAR_C38.md). Next C2.19: actual accessibility tree and target-fallback behavior for removed objects / real focus transitions.

## Spatial Ink V3 — C2.17 STAR loop

C2.17 corrects CAN-01 pinch focal anchoring: Spatial Ink uses the actual start point of SwiftUI MagnifyGesture in the viewport for both the cancellable @GestureState preview and the final camera commit, not the center of the window. A pure SpatialPinchPreview converts the normalized finger origin once; invalid/nonfinite anchors cannot poison camera state, and C2.16 scroll routing remains disabled during an active pinch. Verified **3/3 targeted tests and 405/405 KollioApp tests in 48 suites**. A full Swift 6 Xcode Debug build and native 900×700 FR/EN rest-state captures passed; GitHub CI is the remaining remote gate. See [C2.17 STAR](SPATIAL_STAR_C37.md). Physical trackpad feel, focus-loss interruptions and VoiceOver remain unverified by a person. Next C2.18: keyboard/VoiceOver focus and small-window navigation acceptance.

## Spatial Ink V3 — C2.16 STAR loop

C2.16 implements two-finger precise scroll over the Spatial Ink viewport via a window-local, lifecycle-managed AppKit event observer that does not hit-test. It ignores other windows, outside-viewport input, momentum, system shortcut modifiers and competing pinch/card/background-drag gestures; camera moves in screen points with no document mutation. Verified **3/3 pure policy tests, 402/402 KollioApp tests in 47 suites**, and **2/2 real NSHostingView native acceptance tests** run sequentially, including scroll routing that changes the rendered image but not the canonical document. The CI now runs native window tests with `--no-parallel` to avoid AppKit parallel harness crashes. See [C2.16 STAR](SPATIAL_STAR_C36.md). Real macOS Debug Xcode build succeeded, and native FR/EN 900x700 captures were visually inspected (kept outside Git at review/c36/evidence/). GitHub CI must pass before merge; physical trackpad and VoiceOver still require hands-on acceptance. Next C2.17: physical/focus-loss gesture acceptance and remediation of measured issues.

## Spatial Ink V3 — C2.15 STAR loop

C2.15 addresses interrupted native trackpad pinch zoom. SwiftUI `@GestureState` now owns a temporary magnification preview; `SpatialPinchTransaction` applies the total gesture factor around the viewport anchor, and only a valid completed pinch commits a camera change. Cancelling or losing the gesture restores the baseline; a pinch never writes domain content. It also refuses invalid factors and suppresses zoom commits during a card drag or background pan. Five tests cover cancellation, restart, single commit, anchor, arbitration and limits; **5/5 focused and 398/398 full KollioApp tests in 46 suites passed**, with a successful real Xcode macOS Debug build. Native FR/EN resting canvas captures at 900×700 passed and were visually inspected, but do not prove an actual pinch. See [C2.15 STAR](SPATIAL_STAR_C35.md). A human two-finger trackpad test, VoiceOver and actual OS gesture interruption remain separate acceptance gates. CI and final tests must pass before merge.

## Spatial Ink V3 — C2.14 STAR loop

C2.14 validates an actual NSWindow/NSHostingView with a pending idea: cancel keeps the window and document, confirm closes, and reopening starts without an uncommitted draft. A close-completed marker prevents closed-but-retained windows from raising a second Cmd+Q warning; an existing AppKit delegate veto is checked before destructive confirmation. The Xcode project is regenerated from scripts/sync-xcodeproj.py to include Spatial V3, fixing previously broken Cmd+R; actor-isolation proxy warnings were also fixed. Evidence: 6/6 targeted native tests, 393/393 KollioApp tests (45 suites), and successful Xcode macOS Debug build. The GitHub workflow now checks generated Xcode project parity, builds the real macOS target and executes the opt-in native journey. See docs/SPATIAL_STAR_C34.md. Real human keyboard, VoiceOver and trackpad gestures remain unverified; there is no on-disk draft recovery.

## Spatial Ink V3 — C2.13 STAR loop

C2.13 adds a native macOS window-close and Cmd+Q safeguard for unconfirmed Spatial Ink input, preserving the original NSWindow delegate's veto and requiring explicit consent before discarding window-local drafts. It does **not** silently save draft text to the canonical document or to disk. Five targeted native guard tests passed; the full KollioApp suite passed **392/392 tests in 44 suites**; OpenSpec generated views, String Catalog JSON, Swift syntax and diff checks passed. See [C2.13 STAR report](SPATIAL_STAR_C33.md). Native physical close buttons, focus, VoiceOver and real keyboard/trackpad remain human acceptance gates; do not claim disk recovery or forced-quit recovery. Next C2.14: end-to-end window/quit interaction review and potential opt-in draft recovery policy.

## Spatial Ink V3 — C2.12 STAR loop

C2.12 adds visible and localized unconfirmed-input counts, honest canonical Save feedback, and a native destructive confirmation before discarding a single draft. It counts an active + paused snapshot once, and includes an unsubmitted New idea in the warning. Confirmed 20/20 focused and 387/387 full KollioApp tests in 43 suites; native pending-input screenshots FR/EN captured and visually inspected (window-only text input, document unchanged); GitHub CI separately gated. No draft text is silently committed, and the existing document save semantics stay unchanged. See [C2.12 STAR record](SPATIAL_STAR_C32.md). **Not yet implemented:** retention of drafts after native window close; on-disk draft recovery is not claimed. Next C2.13: real OS-window close guard or opt-in separate draft persistence, followed by hands-on keyboard/trackpad/VoiceOver validation.

## Spatial Ink V3 — C2.11 STAR loop

C2.11 builds on C2.10 with Escape hierarchy, paused/recovered editing per semantic object and authored language, explicit conflict comparison/rebase, and Cmd+Return commit through the existing validated command. Verified 385/385 KollioApp tests in 43 suites, with native FR/EN baseline scene captures. The captures do not prove the active editing panel or physical Escape/Cmd+Return delivery; keyboard/VoiceOver and trackpad remain manual gates. Draft memory is window-local, not persisted between launches. See [C2.11 STAR ledger](SPATIAL_STAR_C31.md). Next C2.12: unsaved-draft lifecycle and explicit save/close feedback, then real native editing acceptance.

## Spatial Ink V3 — C2.10 STAR loop

C2.10 continues C2.9 with a native FR/EN Browse cards menu, relation-first deterministic reading order, and explicit keyboard/VoiceOver focus after chosen navigation. Confirmed 381/381 KollioApp tests in 43 suites, and two real 900x700 NSHostingView captures FR/EN. Selection does not mutate the document. See [C2.10 STAR record](SPATIAL_STAR_C30.md). Real VoiceOver, keyboard focus delivery and trackpad use remain unverified by a person. Next: C2.11 — Escape hierarchy and recoverable editing drafts per CAN-02/CAN-04.

## Spatial Ink V3 — STAR loop (2026-10-13)

C2.8 is in [PR #12](https://github.com/guillaume-flambard/kollio-mac/pull/12), with the native CI green and isolated FR/EN-independent macOS screenshots. C2.9 is the next stacked branch (`feat/spatial-v3-c29-a11y-l10n`, based on C2.8): native document-localized controls, explicit compiled `.lproj` lookup, no implicit arrow-key movement, VoiceOver selected state, and Reduce Motion camera focus. Verified 378/378 KollioApp tests in 42 suites, plus two real NSHostingView captures (French and English), kept out of Git. See [STAR record](SPATIAL_STAR_C29.md). Real trackpad / keyboard focus and VoiceOver tests remain human-gated. Next: C2.10 focus and accessibility hierarchy, then remaining spec gaps; do not merge stacked branches without the necessary CI and review.

## Active milestone: G0, real entry point and on-device Apple intelligence

**Status: G0-A and G0-B both reached. The human gesture pass is still owed.**

Verified 2026-09-25 on arm64, macOS 27.0 (26A428), Xcode 27.0, SDK 27.0.
`SystemLanguageModel.default.availability` is `.available`, 24 languages, 8192-token context. This
was probed directly, not inferred from the SDK being installed.

| Criterion | State |
|---|---|
| Fresh input instead of automatic Sarah | Done, tested |
| Authored context persisted before any request | Done, tested |
| Inline instruction delivered | Done, tested |
| New-document isolation, unreadable document reported | Done, tested |
| Save on quit wired | Done, tested end to end |
| `AppleLocalSuggestionService` behind the seam | Done, tested with a stub |
| Two distinct non-Sarah contexts reach the adapter | Done, real model, FR and EN |
| Keep / Undo / save / reopen without a server | Done, tested |
| Real on-device generation produces a valid proposal | Done, real model |
| No network socket held by the running app | Done, `lsof` against the app pid |
| **Human trackpad and pointer pass** | **Owed** |
| **Ghost branch from the real model, captured on screen** | **Owed** |
| Warm latency, three calls in one process | Done, real model: 2.50 s, 2.68 s, 2.29 s |
| A streaming answer reports progress and stays non-blocking | Done, real model: 54 updates in 5.1 s |
| Sources attach, cite and verify as atomic commands | Done, tested, and refused to intelligence |
| A claim shows a chip for the state of its sources | Done, tested |
| Context budget measured, required items never dropped | Done, on the real request path |
| **Network-disabled run after system resources exist** | **Not done**: it needs the firewall changed, which is the owner's call |

The deterministic suite never touches a real model, and stays under two seconds. Reproduce the
real-model check:

```bash
KOLLIO_REAL_MODEL=1 swift test --package-path packages/KollioApp --filter RealOnDeviceModelTests
```

Measured latency for a small candidate, serially on this Mac: the first call in a fresh process
is **3.6 s**, later calls are **2.2 to 2.7 s**. A three-call series in one process runs
2.50 s, 2.68 s, 2.29 s, so the cost is mostly per call and not a large one-off asset load.

An earlier round reported 9 to 15 s and treated it as the dominant finding. **That number does not
reproduce and the cause is unconfirmed.** The likely explanation is contention: the real-model suite
runs in parallel by default, and two tests hitting the same on-device model pushed the first measured
call to 7.08 s. Measure it with `--no-parallel`:

```bash
KOLLIO_REAL_MODEL=1 swift test --package-path packages/KollioApp \
  --filter RealOnDeviceModelTests --no-parallel
```

What survives the correction is the conclusion rather than the figure: 2.3 s is still too slow to
feel interactive on its own. The wait is now filled, though, because the answer streams.

## The answer streams, and a progress is never a proposal

`AppleLocalSuggestionService` now conforms to `StreamingSuggestionService`, so the sentence the model
is writing appears as it is written. Measured on a real model: **54 progress updates over 5.1 s**, the
rationale growing a few words at a time. The proposal is still minted once, at the end, and goes
through the same converter and the same `ProposalValidator` as before.

The rule that makes this safe is that a progress carries no identifier, no operation and no way to
become a command. `ProposalProgress` has no initialiser that could mint one, so a half-received answer
cannot become something the user could keep. It is cleared the moment the request ends, whatever the
outcome, including a cancellation.

`StreamingSuggestionService` is an **additional** capability. The seam stays `SuggestionService`, and a
source that cannot stream simply does not conform, so the offline engine and the remote provider are
unaffected.

## Where the code is

```
kollio/
├── apps/macos/Kollio.xcodeproj   generated, app target only, for Cmd+R and the debugger
├── packages/KollioCore           domain, document format, commands, proposals, validation
├── packages/KollioApp            the app sources, and the tests
├── services/KollioServer         Vapor API
├── contracts/                    JSON schemas + the reference .kollio fixture
├── docs/                         architecture, format, action protocol, backend, limitations
│   └── specs/SPECIFICATIONS.md   the normative specification: 71 features, 213 criteria
├── openspec/                     the decomposition, in capabilities and lots
└── scripts/                      run-app.sh, verify.sh, sync-xcodeproj.py,
                                 generate-spec-index.py, generate-spec-status.py
```

`apps/macos/Kollio.xcodeproj` is **generated** by `scripts/sync-xcodeproj.py`. Never edit it by hand.
After adding or removing a file under `packages/KollioApp/Sources`, run:

```bash
./scripts/sync-xcodeproj.py
```

## Verify before believing anything

```bash
./scripts/verify.sh     # the spec views, 3 test suites (415 tests), the Xcode app target
./scripts/run-app.sh --shot   # builds, launches, screenshots into build/
```

`KOLLIO_REVIEW=explore|kept|setaside|reopened ./scripts/run-app.sh` opens the app in a given state so
one step of the vertical slice can be captured in a screenshot. Use it instead of guessing what a state
looks like.

Note: `run-app.sh --shot` prints a path whether or not the capture worked, and it captures the whole
screen rather than the Kollio window. Check the file exists and shows the app before trusting it.
Capturing **only** Kollio's window does work, by hand: read the window id from
`CGWindowListCopyWindowInfo` and pass it to `screencapture -l`. See the CTX-05 batch below for two
captures made that way and inspected.

## The specification is decomposed, and the views are generated

`docs/specs/SPECIFICATIONS.md` is the normative source: 71 features, 213 acceptance criteria.
`openspec/` decomposes it twice, and both decompositions are generated from that prose so they cannot
drift out of sync with it:

```bash
python3 scripts/generate-spec-index.py     # openspec/specs/feature-catalog.json + openspec/todo.md
python3 scripts/generate-spec-status.py    # openspec/implementation-status.json
```

`./scripts/verify.sh` runs both with `--check` first, so a stale view fails verification. The honest
state today, per capability: `canvas`, `intelligence` and `decisions` are `automatedVerified`;
`documents` is `implemented`; `context` and `studio` are `specified`; `collaboration`, `commerce` and
`ecosystem` are `blockedExternal` and need an explicit authorisation.

`openspec/specs/evidence.md` is the short honest answer to "what is actually proved", including the
things that are wrong and the things owed to a person.

## Which intelligence source is in use

Chosen by environment variable, never by UI. `KOLLIO_SERVICE=server` with a token in the Keychain
(`dev.kollio.app` / `api-token`) points the app at a local backend; without them it uses the offline
engine. The status line names the source when it is not the offline default.

```bash
# terminal 1: the local backend, offline provider
KOLLIO_API_TOKEN=$(openssl rand -hex 32) swift run --package-path services/KollioServer kollio-server

# terminal 2: the app, pointed at it
security add-generic-password -a "api-token" -s "dev.kollio.app" -w "$TOKEN"   # once
KOLLIO_SERVICE=server KOLLIO_SERVER_URL=http://127.0.0.1:8080 ./scripts/run-app.sh
```

The Groq key is the server's, in its environment, and never reaches the app or the repository. The
Kollio token and the Groq key are different things and live in different places.

## What is built and tested

- The entry point: no stored document shows the initial input, a stored one is restored, an unreadable
  one is reported and never overwritten, and Sarah is only ever reached through an explicit menu
  action. A new document gets its own file, so saving it cannot destroy the previous one.
- The typed context becomes a real object with a stable identity, shown on the canvas and persisted
  before any intelligence is asked for, and it can be edited in place without moving anything else.
- `.kollio`: versioned JSON, exact round trip, greppable object keys, no renderer type in the file.
  Schema in `contracts/schemas/`, reference file in `contracts/fixtures/sarah/sarah.kollio`.
- Commands, atomic transactions, undo and redo, redo tail dropped after a new action.
- Durable decisions: set aside collapses a branch without deleting it, reopen restores the exact
  objects, relationships and positions. A decision survives save, quit and reload.
- Proposals validated three times: provider output, server, client. Staleness, unknown ids, operation
  budget and forbidden operations are all rejected.
- A request-bound document snapshot: bounded, layout-free, reference-checked, refused when oversized
  or inconsistent. The server reasons about exactly that and is never authoritative.
- Canvas: pure `Camera` geometry, world and screen transforms, zoom around an anchor, drag at any
  zoom, screen-space connectors, selection, contextual actions, ghost branches, inline composer.
- Connectors detour around any object between their ends, keeping a fixed clearance, and the
  relationship label follows the curve. A clear connector keeps the exact curve it had before.
- The whole loop: Sarah → Explore → ghost branch → Keep → Cmd+Z → Explore again → Écarter with a reason
  → Rouvrir → save → quit → reopen, as one integration test on the real model and the real file.
- Server: routes, bearer auth, scoping, provider swap, timeout, cancellation, rate limit, malformed
  output, refusal, disabled remote provider. Plus the client flow through real routes and real JSON,
  and a run against a **separate local server process** carrying non-Sarah documents.
- The provider wire contract, against a mocked transport and no key: the documented `response_format`
  field, a schema matching the decoded DTO, and every malformed, truncated, refusing, unknown-reference
  and quota case rejected.
- FR and EN from a native String Catalog, no key ever visible. `L10n` resolves the bundle for both
  SwiftPM and Xcode.

## What is not done, and what that means

Read `docs/known-limitations.md` before promising anything. The short version:

- **No pointer-level UI automation.** The model behind each gesture is tested and the states were
  captured, but real clicks were not driven by a test. A human pass with a trackpad is still owed,
  and it is now the only thing standing between the prototype and a trustworthy verdict on feel.
- **The entry point has never been typed into by a person.** The screen is verified, and the model
  behind it is tested, but keystroke injection needs accessibility access this environment refuses.
  Two-finger scrolling is not wired anywhere in the app either: see `known-limitations.md`. Both are
  inspection or partial evidence, not reproduced bugs.
- **`GroqProvider` has never run with a real key.** Its wire contract is tested with a mock, which says
  nothing about a live model's output quality. Do not describe its quality.
- **No performance measurement** of the 100 object / 200 relationship target.
- The offline "intelligence" is a deterministic rule engine, not a model.

## Rules for continuing

1. **Do not start a feature before the current one is verified.** Build, run, look, then extend.
2. **The domain stays renderer independent.** `KollioCore` must not import SwiftUI, AppKit, Vapor or
   Fluent. If a change needs one of those, the change is in the wrong layer.
3. **Every mutation is a validated command**, applied in a transaction that fully succeeds or leaves
   the document untouched. Views never mutate the document directly.
4. **Never regenerate the world.** An intelligence source returns operations. The client decides
   placement, and it must not move what already exists.
5. **Rejected work keeps its memory.** Set aside is a durable decision, not a deletion and not undo.
6. **No permanent chrome.** No sidebar, no toolbar, no inspector, no chat panel. Interaction appears
   where the user is working. System commands live in native menus.
7. **Design tokens only.** Views never use a raw colour. Light and dark are both defined.
8. **Interface strings live in the String Catalog** with semantic keys. User content is never machine
   translated.
9. **Report honestly.** Separate what is implemented and tested, what is implemented but not visually
   verified, what is simulated, what is configured but not called live, and what is future work. Never
   claim production readiness.
10. **All code, identifiers, comments and logs in English.** The interface is FR and EN.

## Verified batches, in order

CAN-02, CAN-03, CAN-04, CAN-05, CTX-01, AI-03, CTX-05, CAN-07, AI-05, the
Apple 27 measurement batch, and the earlier DOC-01..04, CAN-01, AI-01, AI-02,
AI-04, CTX-02..04, CTX-06, CTX-07, DEC-01..03 and CAN-06. What each one found is
in [batch-log.md](batch-log.md); the current state and the exact next task are
below and in the table above.

## What the Apple 27 measurement batch established

The Apple 27 landscape is mapped capability by capability in
[apple-intelligence-27-roadmap.md](apple-intelligence-27-roadmap.md), with each
status read out of the installed SDK rather than out of a release note. Two
capabilities in the request do not exist under the names given: there is no
`ImageInput` type and no `SpotlightSearchTool` in this SDK, and `ViewAnnotation`
exists only in a binary stub with no Swift declaration. They are recorded as
`UNKNOWN`, not as planned work.

The one implemented item is measurement of the intelligence that already existed:

- `packages/KollioApp/Sources/KollioEvaluationKit` holds the structural gate as a
  pure function. No model, no framework, no flags. 21 tests, and they run in
  ordinary `verify.sh`.
- `scripts/evaluate-apple-model.sh` runs 18 synthetic FR/EN cases against the
  real on-device model, serially, using Apple's `Evaluations` framework. It
  reports availability first, and it exits 3 when the model is absent rather than
  printing a success it did not earn.
- The gate passed on all 18 cases. `noChange` came back in both languages for
  "there is nothing to reopen", which is the result that matters most: the model
  is not agreeable for the sake of it. Every proposing case returned exactly two
  directions and passed `ProposalValidator`. A cancelled generation produced no
  proposal.
- Three corrections came out of the run itself, and they are recorded in the
  roadmap: the shape of an answer is a judgement and not a gate, the language
  check is a stop-word heuristic and cannot be a gate, and a bound a case asked
  for is not a bound the code enforces.
- Two product gaps are now visible rather than hypothetical: the adapter cannot
  honour a per-request instruction limit, and the adversarial case is answered as
  an ordinary one in English. Neither is a safety failure, and neither is fixed.
- Relevance, usefulness of the next step and language quality are named as
  unmeasured. No model judge exists yet, and a score would be a fiction.

## The next things worth doing, in this order

1. The human pass, which is owed and which no test substitutes for. Three things
   only a person can settle: **type a sentence into the entry point and
   press the action**, **scroll with two fingers** (the code says it does nothing; confirm or
   refute), and **watch a real-model proposal arrive and be kept**. Then drag, double-click to
   explore, contextual buttons, `Cmd+0` / `Cmd+1` / `Cmd+Z` / `Cmd+S`, and quit without `Cmd+S`.
3. Latency, because it is the blocking finding: measure a warm call, a second identical call, and
   whether the first cost is asset loading or generation. A pending state that lasts ten seconds is
   the next thing the user will complain about.
4. Relationship selection: a label, a wider hit area than the visible stroke, and a contextual action.
5. Performance: generate 100 objects and 200 relationships, measure pan, zoom and drag, then use the
   camera's visible rectangle to cull. Connector routing samples its curve, so this is where the
   cost will show.
6. Keyboard traversal between objects, so the canvas is usable without a pointer.
7. **AI-12, manage a large context**, then CAN-09 and CAN-10. Those are the
   remaining L3 lots, and each one now has the layer it
   needs: a comparison is a reading, a synthesis is a derivative that must never
    replace its sources. **AI-06 is verified.** The model, the commands,
    the refusals, the file format, the export, the composer and the card are in:
    `SummaryArtifact` and a
    `SummaryLedger` on the document at schema version 6, and five commands, with
    44 tests across the domain and the commands. An edit keeps the first text and
    records who changed it. A section can be declared empty on purpose, but not be
    empty *and* declared so. Confirming is refused while any section is silently
    blank, which is where "the AI does not fabricate conclusions to fill a
    template" is checked. Every reference resolves, and a synthesis goes outdated
    when a decision on something it read moves. Intelligence is refused all five
    commands: a model that could hand over a deliverable would be handing over
    something nobody agreed to.

    The export and the composer are in now, both deterministic and neither
    needing a model. `SummaryExport` writes Markdown that names the revision it
    read in the header, says plainly when a decision has moved since, exports a
    section that recorded nothing as exactly that, and carries every correction in
    an appendix so an edited line is never presented as the model's own words. It
    also produces the compact block, which omits rather than shortens: three
    current-state lines in a compact block would read as a summary of the section.

    `SummaryComposer` fills a draft from the document. Every line it writes rests
    on something, so nothing it produces is caught by the assertion rule. It never
    offers a set-aside direction as a direction, it turns a rejection with no
    reason into an uncertainty, and it refuses a selection wider than 40 objects
    by proposing the narrower scope it would have preferred. Its one asymmetry is
    deliberate: it declares *nothing recorded* for the sections where absence is a
    fact, and leaves **uncertainties absent**, because a deterministic reader knows
    what the document says and has no way of knowing what it failed to say.

    85 tests cover the domain, the commands, the export, the composer and the
    interface. The card is on the canvas, opened from a contextual action called
    "compose a synthesis", and it offers reading it all, confirming, and
    exporting. All three acceptance criteria are proved by named tests, so AI-06
    is `automatedVerified` rather than `specified`.

    What is still owed is a person. The card has never been seen, in either
    appearance, in either language, and a compact block that reads correctly in a
    test can still be unreadable at a glance on a screen. That is the same debt
    CTX-05, CAN-07 and AI-05 carry, and it is the reason the next task is still a
    human pass rather than a feature.

    Two corrections this lot forced, both of which were mine. The composer listed
    a set-aside object under the current state, which is the one thing it must
    never do. And a synthesis reported itself outdated the moment it was written,
    because writing it moved the document it had just read: a badge that is always
    lit is a badge that means nothing, so a draft is never outdated and a claim is
    measured from the revision it was confirmed at.
8. Only then, and only with explicit permission: a small live Groq test, or a PCC eligibility check.
   Everything the transport needs is in place and mocked; what is missing is evidence about a live
   model, not plumbing.
