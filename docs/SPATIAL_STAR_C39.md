# Kollio C2.19 — STAR: recover selection when an authored occurrence disappears

## Situation

CAN-02 requires clearing a selected object removed from the document without silently selecting another item and explaining the loss of an active editing context. The native Spatial Ink scene optimizes the first representation of an object by using the semantic object's ID as its visual ID. When that first occurrence is removed, the next surviving occurrence inherits the **same visual ID**. A selection stored only by visual ID can therefore silently jump to a different physical card despite its ID string remaining unchanged. A paused edit that reverse-maps its old visual ID after the deletion can lose its original semantic object ID.

## Task

- Keep the selected **authored instance** identity stable across scene projections, including duplicate and remove commands.
- Clear the selection on target disappearance or visual-ID reuse rather than retargeting a sibling. Prune stale history entries, show localized feedback, and never mutate the document as a consequence of focus reconciliation.
- Preserve an unfinished edit keyed by its original **semantic object ID and language**, even when its original visual representation no longer exists.
- Return focus to a predictable navigation command only when an active editor/inspector owned the focus. Avoid stealing unrelated text input on background model updates.

## Actions

- Track selectedInstanceID separately from selected visualID, including an initial selection passed to the native fixture.
- Compare full available scene visual IDs and the visual-to-instance mapping using the pure SpatialSelectionContinuity policy. Reconcile only when the authored scene changes, not on camera/pointer gestures.
- Keep editingObjectID stable from beginEdit through optimistic save, pause and discard. Do not reverse-map missing visual IDs during draft preservation or stale revision handling.
- Prune unavailable history entries and report when the selected representation is no longer available; preserve an unfinished draft in this window until its original semantic target can be restored.
- Add real Kollio model tests: remove the first of two occurrence IDs, observe that the remaining occurrence inherits its visual ID, assert the previous instance must be deselected and that the originally authored semantic draft remains intact.
- Add opt-in native NSHostingView scenario that changes a live macOS document after selecting a card and captures the projected UI, without touching user files.

## Results / evidence gates

- Focused and full Swift tests; true native window transition + screenshots FR/EN; full macOS Xcode Debug build; generated specs and Xcode source parity; GitHub CI after stacked PR.
- Physical keyboard/VoiceOver focus and actual live collaborative removal remain human/production acceptance gates. Tests use a local deterministic model, not a remote service.

## Next STAR

C2.20: investigate the actual accessibility hierarchy and restore safe focus when other modal/dismissal and remote update paths remove their controls; do not claim a passing VoiceOver session from a screenshot or an AppKit accessibilityChildren probe.


## Evidence from initial implementation

- **PASS:** 17/17 focused scene tests, including a real KollioModel transaction which removes the first of two authored occurrences and proves that the second inherits the exact visual ID while its stable InstanceID differs.
- **PASS:** 411/411 KollioApp Swift tests in 48 suites, before the final wording adjustment.
- **PASS:** four native acceptance scenarios in one suite under FR and EN opt-in mode, including a live NSHostingView document transition with a selected card, removal of one occurrence, unchanged authored semantic objects, and a resulting screenshot with selection-cleared feedback. Both screenshots were inspected on the Mac; images are outside Git at review/c39/evidence/c39-selection-fr.png and c39-selection-en.png.
- **PASS:** full Debug Xcode macOS application build using Swift 6 on the initial implementation.
- **Follow-up review:** the initially displayed copy suggested a retained draft even without an open edit. The copy was split into an ordinary disappearance message and a modified-draft-specific message. Final suite/native/Xcode verification after upstream C2.18 CI fixes is required before publication.
- **Manual gate:** physical Tab, Escape and VoiceOver/focus transfer on a real macOS window remain unverified. No remote collaboration service was used.
