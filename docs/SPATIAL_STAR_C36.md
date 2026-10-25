# Kollio C2.16 — STAR: two-finger canvas scrolling

## Situation
- CAN-01 requires a two-finger gesture to move the canvas rather than authored objects, with no domain mutation, no interference while typing and no stuck gestures after interruption.
- C2.15 implemented cancellable magnification, but precise trackpad scroll was still owned by the vertical document ScrollView, which could move UI chrome rather than the canvas.
- The stage already uses independent mouse background drag and per-occurrence drag; those must remain unchanged.

## Task
- Route precise two-finger scroll only when the macOS event originates within the visible SpatialV3Stage viewport of the correct window.
- Keep mouse, keyboard, text fields and other scroll views native; never intercept OS modifier-wheel gestures, discrete wheel events or scroll momentum.
- Pan presentation only by incremental screen deltas, without changing zoom, semantic document or object locations.

## Actions
- Added `SpatialTrackpadScrollInput`, a pure policy that requires precise finite nonzero deltas, local visibility, enabled gesture state, no system-reserved modifier, no momentum or terminal event.
- Added a window-scoped, lifecycle-managed `NSEvent` local scroll monitor in `SpatialTrackpadScrollCapture`. It carries only Sendable scalar/geometry data through a synchronous MainActor bridge.
- Observer never participates in hit-testing (`hitTest = nil`); only consumes an event after confirming window number, canvas bounds and visible viewport. It returns all other NSEvents untouched.
- Installed observer as a background of SpatialV3Stage, not on the outer document ScrollView. It is disabled while another drag, pan or pinch is active. It updates only `SpatialV3Camera` and `cameraEdited`.
- Tests exercise precise incremental pan, click/shortcut conflicts, interruption and invalid deltas, and an actual NSView in an NSWindow with wrong-window/outside-viewport routing checks.
- Regenerated Xcode project through `scripts/sync-xcodeproj.py`, never editing the generated project manually.

## Results — gates
- Swift focused and complete suites; real Debug Xcode macOS app compilation; generated specs and project parity; `git diff --check`.
- Existing native NSHostingView captures FR/EN to detect visual regressions; captures are **not** physical trackpad evidence.
- GitHub `native-spatial` CI green before merge; no auto-merge.

## Limitations
- Native event observation and pure routing tests cannot prove physical trackpad behavior, inertial preference or accessibility focus. A hands-on macOS trackpad/VoiceOver test is still owed.
- Scroll direction is AppKit's precise screen delta, respecting the OS natural-scroll setting. Mouse-wheel notch events remain handled by the surrounding native scroll view.
- No document and no draft is ever written by camera scrolling.

## Next STAR
- C2.17: real on-device trackpad gesture acceptance and focus-loss/scroll-view arbitration; fix only measured defects. Audit standalone app menu navigation, visual viewport and assistive-tech focus while staying separate from semantic changes.

## Verified C2.16 results

- **PASS:** 3/3 pure, repeatable trackpad policy tests.
- **PASS:** 2/2 serial native acceptance tests with a real `NSHostingView` and `NSWindow`, including a programmatic viewport scroll routed to the SwiftUI camera; the before/after rendered frame differs while the `.kollio` document remains identical.
- **PASS:** full KollioApp Swift testing suite **402/402** in **47 suites**.
- **PASS:** generated OpenSpec status/index views, Swift syntax and whitespace consistency.
- **Test harness correction:** two independent AppKit window tests crashed when run concurrently with signal 11 even though the new scroll scenario itself passed. Keep window acceptance sequential (`--no-parallel`) and do not create extra AppKit windows inside parallel unit suites. The GitHub workflow includes this native gate.
- **PASS:** full macOS Debug Xcode build, using the generated 37-source project and Swift 6.
- **PASS:** two isolated native NSHostingView screenshots at 900×700 in French and English, captured and visually inspected. Evidence outside Git: `review/c36/evidence/c36-fr.png` and `c36-en.png`.
- **Pending:** GitHub native-spatial CI (must build Xcode and run native acceptance serially before merge).
