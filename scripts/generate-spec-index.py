#!/usr/bin/env python3
"""Generate the feature catalog and the todo list from SPECIFICATIONS.md.

These two files are *views* over the specification, never a second source of
truth. If they disagree with the prose, the prose wins and this script is re-run.

The script parses the `**ID — Title.** *SET. Prerequisites.*` convention used in
the Documents, Canvas, Context, Intelligence, Decisions, Collaboration, Studio,
Commerce and Ecosystem sections, and then cross-references:

- the acceptance criteria `ACnn` that appear under each feature;
- the lot table, which maps capabilities to lots.

Usage:
    python3 scripts/generate-spec-index.py            # write both files
    python3 scripts/generate-spec-index.py --check    # fail if stale
"""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "specs" / "SPECIFICATIONS.md"
CATALOG = ROOT / "openspec" / "specs" / "feature-catalog.json"
TODO = ROOT / "openspec" / "todo.md"

# A feature heading: **DOC-02 — Enter a context and begin.** *SOLO. DOC-01.*
FEATURE = re.compile(
    # The prefix allows a digit because the Apple 27 capabilities are named
    # A27-06 and friends, and `[A-Z]+` silently refused every one of them: the
    # feature was written, the generator agreed with the count of 71, and nothing
    # said so. A parser that cannot see a feature is a parser that will one day
    # hide a feature.
    r"^\*\*(?P<id>[A-Z0-9]+-\d{2}) — (?P<title>.+?)\.\*\*\s*"
    # The delivery-set group is non-greedy on purpose. With a greedy `[^*]+` it
    # swallowed the prerequisites as well, so all 71 features were generated with
    # an empty dependency list, and anything scheduling from those views would
    # treat every feature as ready. The prerequisites are the whole point of the
    # generated order, so they are worth one character.
    r"\*(?P<sets>[^*]+?)\.\s*(?P<prereq>[^*]*)\*\s*$"
)
ACCEPTANCE = re.compile(r"AC(?P<n>\d{2})\b")
SECTION = re.compile(r"^## (?P<name>[A-Z].*)$")
LOT_ROW = re.compile(r"^\|\s*(L\d)\s*\|(.*)\|\s*(.*?)\s*\|(.*?)\s*\|$")

CAPABILITY_OF_PREFIX = {
    "DOC": "documents",
    "CAN": "canvas",
    "CTX": "context",
    "AI": "intelligence",
    "DEC": "decisions",
    "TEAM": "collaboration",
    "STU": "studio",
    "COM": "commerce",
    "EXT": "ecosystem",
    # Apple 27 system-integration and measurement work belongs to the same
    # capability as the rest of the intelligence: it is about the model Kollio
    # already calls, not about a new surface.
    "A27": "intelligence",
}

# Which lot a capability first belongs to. Mirrors the lot table in the spec.
LOT_OF_PREFIX = {
    "DOC": "L1", "CAN": "L1", "CTX": "L1",
    "AI": "L2", "DEC": "L2",
    "TEAM": "L5",
    "STU": "L7",
    "COM": "L9",
    "EXT": "L9",
}
# Features that join a later lot, per the lot table.
LOT_OVERRIDES = {
    "DOC-05": "L4", "DOC-06": "L4", "DOC-07": "L4", "DOC-08": "L4",
    "CTX-02": "L3", "CTX-03": "L3", "CTX-04": "L3", "CTX-05": "L3",
    "CTX-06": "L3", "CTX-07": "L3",
    "CAN-06": "L3", "CAN-07": "L3", "CAN-08": "L2", "CAN-09": "L3",
    "A27-06": "L3",
    "CAN-10": "L3",
    "AI-05": "L3", "AI-06": "L3", "AI-10": "L8", "AI-11": "L3", "AI-12": "L3",
    "DEC-04": "L4", "DEC-05": "L4", "DEC-06": "L4",
}

# Status of each feature, read from the repository rather than assumed.
# `specified` is the honest default: nobody has proved anything by writing it down.
STATUS_NOTES = {
    "DOC-01": ("automatedVerified",
               "Covered by InitialContextTests: fresh launch, restore, unreadable reported."),
    "DOC-02": ("automatedVerified",
               "Covered by InitialContextTests: context created, preserved, persisted first."),
    "DOC-03": ("automatedVerified",
               "Covered by InitialContextTests: a new document gets its own save target."),
    "DOC-04": ("automatedVerified",
               "Covered by InteractionReliabilityTests through the real delegate."),
    "CAN-01": ("automatedVerified",
               "Two-finger scroll wired via ScrollCatcher; pan is screen space at any zoom. "
               "Gesture feel still unverified by a human."),
    "CAN-02": ("automatedVerified",
               "SelectionAndActionsTests: Escape dismisses one level then the selection, through "
               "one function, with the selection pruned in one place; a context offers exactly "
               "three primary actions and the rest sit behind a native menu. Still owed to a "
               "person: the pointer affordance, and a capture cropped to the selection."),
    "CAN-03": ("automatedVerified",
               "MovingInstancesTests: a group drag is one transaction and one undo, AC01 asserted "
               "with the zoom division and with the three results differing so it cannot pass on "
               "a constant, and a move leaves content and semanticRevision untouched. Two "
               "occurrences of one object move independently, which needed instances(of:) and an "
               "InstanceID in the drag state. Still owed to a person: whether the drag feels "
               "direct on a trackpad."),
    "CAN-04": ("automatedVerified",
               "EditingContentTests: the exact characters typed are stored, an edit is one "
               "transaction, the document's undo cannot reach an open draft, and changing the "
               "interface language leaves authored text byte-identical. A conflict is refused as "
               "staleObjectText and keeps both the draft and the current text. DocumentFormatTests "
               "proves a file written before objectVersion existed still opens. Still owed: the "
               "two versions side by side, and Cmd+Z inside the field, which is an interaction "
               "between two undo systems this repository does not own."),
    "CAN-05": ("automatedVerified",
               "CreatingAndRemovingTests: an idea is written down before its kind is known, and "
               "locally, proved with a service that throws if consulted. Duplicate and delete each "
               "exist twice, once for an occurrence and once for an object, and the two are never "
               "the same gesture. AC01 duplicating does not double royalties, because a copy carries "
               "a reference to a contribution rather than a second one. AC02 undo restores links and "
               "positions exactly, and undoing a variant removes the link as well as the object. "
               "Intelligence is refused both removals. Owed: no command registers a contribution, "
               "so AC01 is proved against a seeded ledger; nothing moves an object out of .unclear; "
               "and the menu has not been seen by a person on a screen."),
    "CTX-01": ("automatedVerified",
               "AddingAtAPlaceTests: the sentence is written as an authored note linked by "
               "associatedWith in one transaction, and it is never asked of a model on the way in, "
               "proved with a service that throws if consulted. AC01 findable after a relaunch, "
               "link included; AC02 the target is byte-identical, version included; AC03 a thrown "
               "error, a refusal and a slow answer all leave the contribution with its author. A "
               "double submission is deduplicated per target. A kind proposed by intelligence asks "
               "first when it changes the reasoning. Owed: nothing on screen asks that question "
               "yet, and a note is not read as a consequence of anything."),
    "AI-03": ("automatedVerified",
               "ExploringABranchTests: the exact instruction is transmitted, which it was not, since "
               "the Explore intent used to discard it and clear the composer. The read set carries "
               "the target, its neighbours and every rejected direction with its reason, and the "
               "signature is stable because it sorts before hashing. The engine honours only the "
               "rejections it was given. AC03 a new proposal is offered rather than erasing the "
               "previous, and noChange takes nothing away. A rejected branch is not reopened, a "
               "repetitive loop converges instead of duplicating, and exploring leaves the parent "
               "byte-identical. Owed: the offer to keep or hide is not on screen, and second-degree "
               "reach is a documented guess rather than a rule of applicability."),
    "AI-01": ("automatedVerified",
              "AppleAdapterTests: every availability state is a refusal, never a fallback."),
    "AI-02": ("humanVerified",
              "Real on-device generation on two non-Sarah contexts, FR and EN, through the "
              "adapter. Steady state is about 2.3 s, first call in a fresh process about 3.6 s: "
              "still too slow to feel interactive, and nothing is streamed."),
    "AI-07": ("automatedVerified",
              "AppleAdapterTests: minted ids, dropped kinds, bounded branch, noChange."),
    "AI-08": ("automatedVerified",
              "VerticalSliceTests: one Keep undoes as one action."),
    "CAN-06": ("automatedVerified",
               "AC01 the line is clickable at several zooms: the catch area is wider than the "
               "stroke and grows as the view shrinks, and hit testing uses the same routed path "
               "the layer draws, at 0.35x through 3x. AC02 the text explains the direction: a "
               "sentence derived from the relationship and the two objects, in EN and FR, and "
               "refused rather than half-printed when an end is missing. AC03 objects do not "
               "become true because they are linked. Reversing is a named command, refused for "
               "intelligence, and a duplicate reveals the link that already says it. Still "
               "missing: a per-kind label on the connector itself, and the edit cannot be undone "
               "across a save."),
    "AI-09": ("automatedVerified",
               "AC01 a late answer after a switch, an undo or a close is dropped rather than "
               "published; AC02 the draft is kept; AC03 a refusal starts no loop. "
               "RequestLifecycleTests, LateAnswerTests, and a new request now supersedes one in "
               "flight instead of being refused. Still missing: the Cancel and Ask again actions "
               "in the interface, and remote cancel, which cannot be claimed before a provider "
               "answers ownership."),
    "AI-04": ("automatedVerified",
               "AC01 an answer is in the document and survives a reload; AC02 'I don't know' is a "
               "real state and is never an empty answer; AC03 a question resolves beside its object "
               "with no panel anywhere. ClarificationTests, ClarificationInterfaceTests. "
               "Intelligence may ask but may not answer. Still missing: a question the document has "
               "moved past, proposed for reassessment, and resuming the request with the answer."),
    "CAN-08": ("automatedVerified",
               "AC01 keeping does not shift the ghosts; AC02 earlier objects stay still; AC03 undo "
               "restores the view exactly. ProposalPlacementTests, against the real model. A "
               "branch placed off screen offers a way to see it, and nothing ever moves the view on "
               "its own. Still missing: the local organisation gesture, and a density measure for "
               "when to widen the search rather than place."),
    "CAN-09": ("automatedVerified",
               "AC01 a current or historical rejection reason is found and labelled honestly; "
               "AC02 visiting and leaving a folded result changes only camera, selection and the "
               "temporary reveal; AC03 an object outside the permitted set is absent and reported "
               "as not searched. DocumentSearchTests and SearchNavigationTests. Search is local, "
               "keeps a zero-result query, reports unloaded source content and opens from Cmd-F."),
    "CAN-10": ("automatedVerified",
               "AC01 ReadingPathTests and PresentationModeTests prove deterministic forward and "
               "back navigation, source and decision points, and that a deleted point is named as "
               "skipped rather than remapped; AC02 exit restores the exact previous camera; AC03 "
               "presentation asks no model and the single command path refuses every write. "
               "Cmd-Return starts or exits, arrow keys navigate, Escape exits, source reading stays "
               "available, and presentation labels are localized."),
    "DEC-04": ("automatedVerified",
               "AC01 the criterion committed before a run remains readable in the first revision; "
               "AC02 every expected-evidence link must resolve to an object in the document; AC03 "
               "editing after a recorded result appends a visible revision without rewriting the "
               "result or original criterion. ExperimentTests and ExperimentInterfaceTests. The "
               "block remains attached to reasoning, simulations are labelled, and intelligence is "
               "forbidden from building one."),
    "DEC-05": ("automatedVerified",
               "AC01 observation and outcome are separate fields and no conclusion is derived; "
               "AC02 an inconclusive result requires a visible reason and half-written measurements "
               "are refused; AC03 intelligence cannot record a result, propose a learning or accept "
               "one. ExperimentResultTests and ResultInterfaceTests. Results append, carry measured "
               "units, limits and a selected source, and undo removes exactly one recording. A "
               "learning references the result and scope, remains proposed, and requires a distinct "
               "decision within that scope before acceptance."),
    "CTX-02": ("automatedVerified",
               "AC01 a CSV with quotes, commas and newlines parses correctly; AC02 a PDF with no "
               "text layer is marked as having no text; AC03 a pasted link is never fetched. "
               "SourceReaderTests. A file is chosen, read and attached in one transaction, a CSV "
               "is previewed as columns from the revision on record, and a chosen file opens in "
               "the system reader: SourceChipTests, SourcePreviewPanel. Still missing: a page "
               "locator that can be pointed at a passage, and OCR as an explicit action."),
    "CTX-03": ("automatedVerified",
               "A citation keeps its revision, is refused towards anything absent, and cannot be "
               "verified without an observation and an author. Intelligence is refused these "
               "commands outright. SourceLedgerTests, SourceCommandTests. The interface opens a "
               "citation at the lines its locator names, from the revision it was read against, "
               "records a check only with an observation, and lets a passage be chosen so the "
               "quote is the selection verbatim: SourceChipTests. Still missing: opening the file "
               "itself in a reader, and a page locator that can be pointed at a passage."),
    "CTX-04": ("automatedVerified",
               "AC01 a constraint only blocks within its scope; AC02 not applicable is not "
               "satisfied; AC03 supported is not absolute truth. ClaimLedgerTests, and a scope "
               "with nothing in it is refused rather than read as everything. Intelligence may "
               "suggest a claim but may not record how it stands. The interface states a claim with "
               "its scope taken from the current selection, and records a stance only with an "
               "observation. Still missing: asking for precision when two scopes overlap."),
    "CTX-05": ("automatedVerified",
               "ImpactAssessmentTests: the read set, the proposed changes and the unaffected "
               "references are all recorded, and the read set is stable between runs. Propagation "
               "follows the direction of reliance and a link is walked towards what relies on it, "
               "never away from it, so a shared tool a branch merely uses is reported as "
               "unaffected rather than as a casualty. AC01 an available CSV touches only the object "
               "that cited it plus what explicitly depends on it, and never the CRM identifiers; "
               "AC02 the shared tool and the alternative branch keep their links, their lifecycle "
               "and their usability; AC03 one command, one transaction, one undo, and content, "
               "relationships and revision all come back. A cycle terminates through a visited set, "
               "a walk that hits its bound declares itself truncated, and the same document gives "
               "the same assessment twice. A reason cannot invert a decision: ImpactReason has no "
               "refuted case, a bare .impacted decision is refused, and taking a stance supersedes "
               "the mark rather than deleting it. Intelligence is refused applyImpact. "
               "ImpactReviewInterfaceTests: the action is offered only when the document has "
               "something to say and sits behind the secondary menu, the card names both lists, "
               "reading asks no model, the marks survive a save and a reload, Escape closes the "
               "card before the selection, and the mark is drawn on the object. Owed: the card has "
               "never been seen on a screen, and an assessment records only the first moved "
               "citation of a claim when two sources have both moved."),
    "AI-11": ("automatedVerified",
               "GeneratorAttributionTests (9) and ProposalAttributionTests (9). AC01 the "
               "four destinations are distinct and only two are reachable in this "
               "build: Private Cloud is a real Apple API and is reported unavailable "
               "rather than listed, because a menu offering a destination the product "
               "cannot reach is a lie with a button on it, and a demo answer is "
               "labelled as a demonstration in the stored record rather than only in "
               "a menu. AC02 no chain of thought and no key: the attribution type has "
               "no field that could carry a prompt, a thought or a credential, and a "
               "test reads the rendered text and asserts it contains none of sk-, a "
               "bearer prefix, api_key, apiKey or token=. The rationale a person sees "
               "is the one sentence the model addressed to them, not a derivation. "
               "AC03 references are checked: what was read is resolved against the "
               "document rather than asserted, a reference that no longer resolves is "
               "kept and marked instead of dropped, and a reference carries a "
               "truncated label rather than the content it points at. A proposal "
               "from before the prompt revision was recorded still reads and says the "
               "version is unknown rather than hiding the gap. The attribution is "
               "carried beside the existing generator rather than replacing it, so a "
               "stored proposal cannot be contradicted by a separately declared "
               "destination. Owed: nobody has read the panel, and the two destinations "
               "that would need real consent have no implementation to test against."),
    "AI-12": ("automatedVerified",
               "ContextProjectionTests prove AC01 and AC02: the measured payload is the payload "
               "sent, optional material is omitted without changing its authored text, required "
               "targets are prioritised and an overflow is reported rather than dropped. "
               "AppleAdapterTests prove the runtime window bounds the budget, a required overflow "
               "is refused before either generation route, and a narrowed scope survives candidate "
               "conversion. ProposalAttributionTests prove AC03: the answer states the number of "
               "objects read and omitted from the recorded scope. The scope panel still needs a "
               "person to inspect it in both languages and appearances."),
    "AI-06": ("automatedVerified",
               "74 core tests and 11 interface tests. The domain, the commands, the "
               "export, the composer and the card. AC01 the initial text stays "
               "intact: SummaryCommandTests edits a line twice and asserts the "
               "first generated text survives both times rather than the previous "
               "keystroke, and that the editor is recorded; SummaryInterfaceTests "
               "checks a corrected line is marked where it is read. AC02 "
               "uncertainties are visible: a section can be declared empty on "
               "purpose but not be empty and declared so, writing a line cancels the "
               "declaration, confirming is refused while any section is silently "
               "blank, and the card distinguishes 'nothing uncertain was recorded' "
               "from 'not written yet'. AC03 the export names the revision used, in "
               "the header and in the filename, and says in the header when a "
               "decision has moved since. Beyond the criteria: the composer writes "
               "only lines that carry a reference, never offers a set-aside "
               "direction as a direction, turns a rejection with no reason into an "
               "uncertainty, and refuses a selection wider than 40 objects by "
               "proposing the narrower scope it would have preferred. Every one of "
               "the five commands is refused to intelligence, because a model that "
               "could hand over a deliverable would hand over something nobody "
               "agreed to. Two things this feature will not do: a synthetic "
               "synthesis is not a reading of a real document, and the card has "
               "never been seen by a person, in either appearance or either "
               "language. The three corrected mid-batch: the composer listed a "
               "set-aside object as current state; a synthesis reported itself "
               "outdated the moment it was written, because writing it moved the "
               "document it had just read, and a badge that is always lit is a "
               "badge that means nothing; and the language check is a stop-word "
               "heuristic that is not a gate."),
    "A27-06": ("inProgress",
               "KollioEvaluationKitTests (23 tests, no model involved) prove AC01: the "
               "structural gate is a pure function of an expectation and an observation, "
               "so the model cannot change the verdict by changing its taste, and each "
               "refusal is exercised with numbers chosen to fail - an unknown reference, "
               "a rejected direction reached for again, applyProposal or removeObject "
               "minted, a document whose revision moved, a bound the code does not "
               "enforce. AC03 is proved by 'An encoded outcome carries no authored text' "
               "and by a grep of the produced report: no fragment of authored or "
               "generated text, which took encoding the expectation without its own text "
               "because includeTranscripts: false redacts nothing. AC04 is proved by the "
               "three judged.dimensions reporting ignore. AC02 is enforced in the script "
               "and in the suite's require, and 'The script's availability marker is a "
               "string the suite emits' keeps the two from drifting, but the end-to-end "
               "exit 3 has not been observed on a Mac whose model is unavailable. Three "
               "measurements were demoted out of the gate after running, not before: the "
               "shape of an answer flipped between runs on the same case, the language "
               "check is a stop-word heuristic that reads none on a short answer, and a "
               "bound stated in a case's instruction is enforced nowhere. Status is "
               "inProgress rather than automatedVerified for that one unobserved path, "
               "and not because the code is missing. Owed: a run on a Mac with no model, "
               "and a model judge for the three dimensions that stay unjudged."),
    "CAN-07": ("automatedVerified",
               "FrameTests: AC01 folding changes no business status at all, asserted field by "
               "field and with semanticRevision unmoved, and a fold is not a way to reopen a "
               "branch somebody really set aside; AC02 moving a frame applies one delta to every "
               "member so the offsets are compared as differences and not as absolute positions, "
               "which a constant could pass; AC03 a second drawing of a member's object stays "
               "exactly where it was while the framed one moved. Membership is explicit, "
               "reversible, and an empty frame is a state rather than an error. A frame cannot "
               "hold a drawing that does not exist, and one drawing cannot be in two frames, "
               "which is refused rather than resolved by a rule. Two overlapping frames share no "
               "member and one frame's move does not reach the other. Renaming changes the frame's "
               "name and nothing inside it. Removing a frame leaves its members and their "
               "positions byte-identical. Every frame command is presentation-only, so none of them "
               "moves semanticRevision, and a file written before frames existed still opens. "
               "FrameInterfaceTests: the action appears only with a selection and behind the "
               "secondary menu, the frame is named by the person with a refused empty name keeping "
               "the field, folding hides the drawings in the view and a shared object drawn "
               "elsewhere stays visible, a drag draws live and writes one transaction, Escape "
               "closes the field before the selection, and a frame survives a save with its name "
               "and its folded state. Owed: a frame is created from the first drawing of each "
               "selected object rather than the drawing under the pointer, moving a frame has no "
               "keyboard path, and the frame's rectangle is computed from estimated node sizes "
               "until SwiftUI has measured them."),
    "AI-05": ("automatedVerified",
               "ComparisonTests: AC01 a cell cannot hold a number unless its criterion carries a "
               "measure, refused in the store with criterionHasNoMeasure while words are accepted "
               "on the same criterion, and a measure with no weight still gives no total because a "
               "weight nobody typed is an absent one, not a weight of one; a total is the sum of "
               "signed, weighted values and is undefined the moment one criterion is unmeasured, "
               "unweighted or unrecorded; a draft accepts no cell at all, and setting criteria and "
               "confirming them are two separate commands after the first version merged them and a "
               "typed criterion silently confirmed the comparison. AC02 every cell keeps its "
               "references, the revision each source was read against and the fingerprint of each "
               "referenced object, a reference towards something absent is refused, and the need to "
               "review is derived from those references rather than flagged, so an edited object or "
               "a superseded source is found. AC03 keeping one direction is a list, not a pointer, "
               "and leaves every sibling cell and the document itself byte-identical. Correcting a "
               "cell replaces it and says who wrote it. Intelligence is refused all six comparison "
               "commands. A cell's value is written as a discriminated kind, not the synthesised "
               "associated-value form, and the JSON schema states the measure, the minimum of two "
               "directions and the value shape. ComparisonInterfaceTests: the action needs two "
               "directions, the draft proposes criteria from the claims already in the document, a "
               "confirmed comparison records cells, a total appears only once every term is defined, "
               "a missing cell reads as not recorded rather than zero, keeping leaves the others, "
               "Escape closes the card without changing anything, and a save and reload keeps the "
               "kept direction and the total. Owed: the card has never been seen on a screen, and a "
               "criterion cannot yet be given a measure and a weight from the card itself, only by "
               "the command."),
    "CTX-06": ("automatedVerified",
               "The projection is built and measured on the real request path: omissions are "
               "counted, a required item is never dropped, and the budget cannot exceed the "
               "model's window. ContextProjectionTests, AppleAdapterTests. The interface that "
               "shows the list to a person is not built."),
    "CTX-07": ("automatedVerified",
               "A new revision flags what it supersedes without moving a citation, a failed "
               "extraction keeps the previous version active, and a removed source never deletes "
               "the claim. SourceLedgerTests, SourceCommandTests. No comparison of dependent "
               "extracts and no reassessment proposal are built."),
    "DEC-01": ("automatedVerified", "CommandTests: a decision survives save and reload."),
    "DEC-02": ("automatedVerified",
               "InteractionReliabilityTests: the camera is identical before and after."),
    "DEC-03": ("automatedVerified",
               "InteractionReliabilityTests and VerticalSliceTests: one Keep, one undo."),
    "DOC-05": ("automatedVerified",
               "InitialContextTests prove the rename and the duplicate: a rename changes the "
               "versioned title and the registry name together, an empty or failed rename leaves "
               "the document and its file intact, and a duplicate is a new documentId with "
               "remapped internal references, a new file and an untouched original. "
               "DocumentDuplicatorTests prove the same copy at the domain level. "
               "DocumentExportTests prove the export: the scope is frozen at preview time, a "
               "scoped .kollio file reopens with no dangling internal reference, Markdown and PNG "
               "are two renderings of the same blocks so the picture cannot show what the preview "
               "did not, and no request id, actor or provenance crosses into a private export. "
               "ExportArtifactsTests prove AC03 and the asset archive: a cited file is copied with "
               "a manifest, a link is recorded as a link, and a file that moved is reported as "
               "missing instead of silently omitted. The export panels are the system dialogs, so "
               "there is no custom panel of ours to test, and the export commands still need a "
               "human pass on a real document."),
    "DEC-06": ("automatedVerified",
               "HistoryTimelineTests and HistoryDifferenceTests prove AC01 and AC02: the origin of "
               "an action is readable, previewing is read-only, and text plus relationship changes "
               "carry both their earlier and current readings. HistoryRestoreTests prove AC03: a "
               "restore is a validated command, one Undo/Redo action, remains replayable by later "
               "previews, preserves the journal, and an explicit retention purge reports its count. "
               "The timeline and restore controls still need a human visual and pointer pass."),
}


def parse() -> list[dict]:
    text = SPEC.read_text(encoding="utf-8")
    features: list[dict] = []
    section = ""
    current: dict | None = None
    in_lots = False

    for line in text.splitlines():
        if line.startswith("## "):
            section = line[3:].strip()
            in_lots = section.startswith("Lots")
            if in_lots:
                current = None
            continue

        if in_lots:
            match = LOT_ROW.match(line)
            if match:
                lot = match.group(1)
                features_seen = match.group(3)
                for fid in re.findall(r"[A-Z]{2,4}-\d{2}", features_seen):
                    for feature in features:
                        if feature["id"] == fid:
                            feature.setdefault("lots", []).append(lot)
            continue

        heading = FEATURE.match(line)
        if heading:
            fid = heading.group("id")
            prefix = fid.split("-")[0]
            current = {
                "id": fid,
                "title": heading.group("title"),
                "capability": CAPABILITY_OF_PREFIX.get(prefix, "other"),
                "deliverySets": [s.strip() for s in heading.group("sets").split(",")],
                "prerequisites": [
                    p.strip() for p in re.findall(r"[A-Z]{2,4}-\d{2}", heading.group("prereq"))
                ],
                "acceptanceCriteria": [],
                "section": section,
            }
            features.append(current)
            continue

        # The acceptance criteria of a feature wrap across several lines, so they
        # are accumulated in order rather than read from the line holding AC01.
        if current is not None:
            for m in ACCEPTANCE.finditer(line):
                ac_id = f"{current['id']}-{m.group(0)}"
                if ac_id not in current["acceptanceCriteria"]:
                    current["acceptanceCriteria"].append(ac_id)

    return features


def main() -> int:
    features = parse()
    for feature in features:
        lot = LOT_OVERRIDES.get(feature["id"]) or LOT_OF_PREFIX.get(
            feature["id"].split("-")[0], "L0"
        )
        feature["lot"] = lot
        status, note = STATUS_NOTES.get(feature["id"], ("specified", ""))
        feature["status"] = status
        if note:
            feature["evidence"] = note

    catalog = {
        "$comment": (
            "Generated by scripts/generate-spec-index.py from "
            "docs/specs/SPECIFICATIONS.md. A view, never a second source of truth."
        ),
        "specification": "docs/specs/SPECIFICATIONS.md",
        "counts": {
            "features": len(features),
            "acceptanceCriteria": sum(len(f["acceptanceCriteria"]) for f in features),
            "byStatus": {
                status: sum(1 for f in features if f["status"] == status)
                for status in sorted({f["status"] for f in features})
            },
            "byLot": {
                lot: sum(1 for f in features if f["lot"] == lot)
                for lot in sorted({f["lot"] for f in features})
            },
        },
        "features": sorted(features, key=lambda f: f["id"]),
    }

    rendered_catalog = json.dumps(catalog, indent=2, ensure_ascii=False) + "\n"

    # The todo list: one line per feature, ordered by lot then id.
    lines = [
        "# Kollio todo",
        "",
        "Generated by `scripts/generate-spec-index.py` from "
        "[../docs/specs/SPECIFICATIONS.md](../docs/specs/SPECIFICATIONS.md).",
        "A view, not a source of truth. Status meanings:",
        "",
        "| Status | Means |",
        "|---|---|",
        "| `specified` | Written down. Nothing implemented. |",
        "| `inProgress` | Some code exists, no complete evidence. |",
        "| `implemented` | Code exists and builds. No test evidence. |",
        "| `automatedVerified` | A test proves the stated behaviour. |",
        "| `humanVerified` | A person did it. |",
        "| `blockedExternal` | Blocked on a capability or authorisation. |",
        "| `notInCurrentRelease` | Deliberately out of this product. |",
        "",
        "Counts: "
        + ", ".join(f"{n} {s}" for s, n in sorted(catalog["counts"]["byStatus"].items()))
        + f". {catalog['counts']['features']} features, "
        + f"{catalog['counts']['acceptanceCriteria']} acceptance criteria.",
        "",
    ]
    for lot in sorted(catalog["counts"]["byLot"]):
        in_lot = [f for f in catalog["features"] if f["lot"] == lot]
        lines.append(f"## {lot} — {len(in_lot)} features")
        lines.append("")
        for feature in in_lot:
            marker = {"automatedVerified": "x", "humanVerified": "x"}.get(feature["status"], " ")
            ac = f"{len(feature['acceptanceCriteria'])} AC" if feature["acceptanceCriteria"] else "—"
            lines.append(
                f"- [{marker}] **{feature['id']}** {feature['title']} "
                f"· `{feature['status']}` · {ac}"
            )
            if feature.get("evidence"):
                lines.append(f"      {feature['evidence']}")
        lines.append("")

    rendered_todo = "\n".join(lines)

    if "--check" in sys.argv:
        problems = []
        if not CATALOG.exists() or CATALOG.read_text(encoding="utf-8") != rendered_catalog:
            problems.append("openspec/specs/feature-catalog.json is stale")
        if not TODO.exists() or TODO.read_text(encoding="utf-8") != rendered_todo:
            problems.append("openspec/todo.md is stale")
        if problems:
            for problem in problems:
                print(f"error: {problem}", file=sys.stderr)
            return 1
        print("spec index is up to date")
        return 0

    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(rendered_catalog, encoding="utf-8")
    TODO.write_text(rendered_todo, encoding="utf-8")
    print(
        f"wrote {CATALOG.relative_to(ROOT)} and {TODO.relative_to(ROOT)}: "
        f"{len(features)} features, "
        f"{catalog['counts']['acceptanceCriteria']} acceptance criteria"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
