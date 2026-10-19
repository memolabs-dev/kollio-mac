# Kollio Spatial Ink — C2.5: multiple visual occurrences

## Contract

A ContentObject in a .kollio v7 document remains one semantic object.
Multiple NodeInstance values may place it at different canvas locations.
The native projection retains each occurrence ID, authored position and visibility.
Hidden instances and members of folded frames do not render. An object with
no authored instance receives a deterministic, view-only grid position.
An object with only hidden occurrences is not recreated by the fallback.

SpatialDocumentScene renders one card for each visible occurrence.
The first visible card keeps the semantic object ID for compatibility;
additional cards receive stable namespaced presentation IDs.
The objectIDByVisualID lookup maps every card back to its original object.
Native authoring commands always receive that semantic ID, never an instance ID.
The relationship target menu deduplicates by semantic ID.

## Relationships

Each semantic relation produces at most one displayed link.
The view selects the shortest visible occurrence pair, with deterministic
tie-breaking, then routes it with C2.4 obstacle avoidance. This is a
presentation heuristic, not a modification of the relationship or document.

## Automated verification

- Two authored occurrences appear at independent original positions.
- Semantic object count and document remain unchanged.
- One relationship chooses the nearest displayed occurrence pair.
- Hidden instances stay hidden; hidden-only objects get no synthetic view.
- Folding a frame hides its member occurrence without hiding the shared object.
- Editing from the second occurrence updates both renderings, including after save/reopen.
- Targeted SpatialDocument suite: 23/23 tests passed.
- Full KollioApp suite: 368/368 tests across 41 suites passed.

## Open work

- Instance dragging in V3 is not yet connected to the existing model commands.
- Frames have no dedicated V3 visual treatment beyond their fold visibility.
- A relation attaches to one chosen occurrence pair, not to every visual copy.
- Manual pointer/trackpad and accessibility review, long labels, and Web parity.
- No destructive migration or edits to the original dirty Mac checkout.
