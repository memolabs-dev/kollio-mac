# Spatial Ink C2.7 — interruption-safe pointer movement and accessible nudge controls

## User-facing behavior

- Pointer dragging an authored NodeInstance previews motion without mutating the KollioDocument.
- SwiftUI @GestureState owns the preview. On cancellation, view removal or losing a gesture it resets automatically.
- Only a completed drag's onEnded calls the existing SpatialDocumentEditor.moveOccurrence command.
- Background dragging pans the camera. Dragging a card moves the card; mouse/trackpad interaction arbitration still needs on-device manual testing.
- At a selected real-document card, four directional controls nudge just that instance by 16 document-world units.
- Each authored card also exposes SwiftUI move commands for keyboard focus and named VoiceOver accessibility actions.
- All these paths share the same validated model command, undo/redo and explicit Save.
- Empty, demo and non-authored generated cards are not movable.

## Invariants

- No model writes during live gestures; cancelled gestures do not call the editor.
- Keyboard controls operate in document world coordinates and ignore camera zoom.
- Existing pan/zoom remain available; magnification is ignored during an active card drag.
- No ContentObject cloning, geometry format migration or relation mutation.
- Labels for the new directional controls exist in the FR/EN String Catalog.

## Automated verification

- Tests cover each direction's 16-unit delta and MoveCommandDirection mapping.
- Tests cover two arrow moves, command-level Undo/Redo and persistence after save/reopen.
- Tests verify the preview is a non-authoritative value; discarding it leaves the document untouched.
- SpatialDocument targeted: 29/29 tests passed.
- KollioApp full suite: 374/374 tests passed in 41 suites.
- Swift source parse, translation JSON parse, and git diff --check passed.
- Real OS gesture cancellation, full AX tree, pointer/trackpad conflicts and keyboard focus require manual acceptance.

## Follow-up acceptance on Mac

1. Open a real .kollio with two occurrences of one object, then drag the second one at multiple zoom levels.
2. Interrupt movement by dismissing the preview or changing focus: confirm that no move was persisted.
3. Drag the canvas background to pan; verify the selected card does not move.
4. Use each arrow button, keyboard arrow focus and VoiceOver custom action; undo and redo.
5. Save and reopen; verify only the targeted instance changed and relations rerouted.
6. Validate interaction in both FR/EN; check reduced-motion and screen-reader descriptions.
