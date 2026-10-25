# Kollio Spatial Ink — C2.6: drag one authored occurrence

## Input and visible behavior

- In a real-document Spatial Ink window, dragging a card previews only that NodeInstance.
- In this view, the pointer reports screen-space translation. It is divided by camera zoom
  before using the existing world-coordinate model command. Camera pan does not affect the delta.
- The moved card follows the pointer, while connected edge endpoints stay attached in the preview.
  All bends are recalculated from authored document positions on release via C2.4.
- Pointer release performs one `KollioModel.moveInstances` transaction for one InstanceID.
  No intermediate drag coordinates are written; Undo/Redo treats the move as one action.
- The user saves explicitly to persist in their `.kollio` document.
- Cards without a real authored NodeInstance (demo fixture or generated fallback) cannot be moved.
- Existing background pan, tap selection, zoom and camera fit stay separate.

## Data safety

- No new mutation path or file format. All writes use the domain's moveNodeInstances command.
- The visual ID resolves to a real InstanceID, not the containing ContentObject ID.
- Other occurrences, semantic content and semanticRevision remain unchanged.
- Invalid, non-finite and sub-pixel world displacements are rejected.
- If a model command fails to move, the editor reports failure rather than success.

## Verification

- C2.6 automated tests cover two occurrences: only the second moves, undo, redo, save and reopen.
- Validation tests cover unknown instance IDs, tiny and non-finite deltas.
- Screen-to-world conversion tested at zoom 0.5, 1, and 2, plus invalid zoom.
- Targeted SpatialDocument tests: 26/26 passed.
- Full KollioApp suite: 371/371 tests passed in 41 suites.
- Diff formatting check passed.
- GitHub native-spatial CI and actual pointer/trackpad remain separately gated.

## Still owed

- Manual macOS pointer and trackpad test for gesture hit priority inside horizontal ScrollView.
- Keyboard and VoiceOver move affordance; touch cancellation and interrupted gestures.
- A production UI/i18n review, including contextual feedback and obstacle routes during drag.
- Dedicated moving-card accessibility and end-to-end screenshots.
