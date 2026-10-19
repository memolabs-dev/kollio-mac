# Kollio Spatial Ink — C2.8 native interaction review

## Observed code-level defects and fixes

1. Selecting a card in place used to auto-center the camera. This moved the user's canvas
   without an explicit navigation request and could disrupt manipulation. Selection now
   leaves the camera untouched. The selected inspector has an explicit Center on card
   action; search/history navigation requests intentional centering.
2. Background panning previously tracked the last drag translation in a persistent
   @State that was only cleared on onEnded. Cancelled gestures could carry an old delta
   into the next pan. Background panning now previews with @GestureState and commits
   the total translation once at the end; cancellation clears the preview automatically.

3. A 1280x1100 native capture initially revealed the branded header was clipped above the window. A vertical content ScrollView now keeps the header visible, with the inspector reachable by scrolling, including in a 900x700 viewport.

## Isolated native evidence

- `SpatialNativeAcceptanceTests` builds a real NSHostingView containing a native
  macOS SpatialV3WindowView and a real v7 .kollio in an ephemeral model.
- That fixture has two authored NodeInstance records of one ContentObject.
- With `KOLLIO_SPATIAL_C28_CAPTURE=/absolute/path.png`, the test captures the
  NSHostingView itself, never the whole desktop or personal documents.
- It verifies the real model remained unchanged while rendering.
- It is opt-in, since desktop graphics are not guaranteed on headless CI runners.
- Native captures passed at 1280x1100 and compact 900x700. Both were visually inspected; the header is now visible.
- Captures are kept outside the source worktree under review/c28/evidence, not tracked in Git.

## Automated acceptance

- Camera centering preserves zoom, lands the card at the viewport center and
  does not mutate the source camera.
- A cancelled preview of background pan cannot contribute a stale delta
  to the next pan.
- Two opt-in native render captures passed (one test each).
- Full KollioApp suite: 377/377 tests passed in 42 suites.
- Targeted and full Swift app suites are separate from the opt-in native capture.

## Gates not established by tests

- Real physical mouse and trackpad gesture priority within the horizontal ScrollView.
- Keyboard focus/arrow routing and the macOS VoiceOver accessibility tree.
- Full OS-level interruption (focus loss, Escape, switching windows).
- Human inspection: 6 semantic objects produce 7 visual cards, including the duplicate occurrence; arrow buttons and the explicit center action are visible.
- Mixed localized and hardcoded French/English labels remain an existing UI consistency issue, requiring further work.
- Full light/dark acceptance is still owed.

No user document, main branch, or original dirty Kollio checkout is modified.
