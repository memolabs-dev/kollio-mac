# Kollio C2.17 — STAR: pinch zoom anchored to the two-finger gesture

## Situation
- CAN-01 says zoom must preserve the world point under its gesture anchor; AC01 explicitly rejects a jump when pinching.
- C2.15's interruptible pinch correctly discarded incomplete gestures, but zoom always used the center of the viewport, even when the user's fingers were elsewhere.
- C2.16 added precise two-finger scroll confined to the stage; its arbitration remains unchanged.

## Task
- Use the real SwiftUI `MagnifyGesture.Value.startAnchor` for both the ephemeral preview and completed pinch.
- Keep the same stable visual world location under the start of the pinch; do not move an authored node or increment document revisions.
- Maintain the existing cancellation, drag/pan arbitration, zoom limits and strict invalid-input handling.

## Actions
- Introduced `SpatialPinchPreview` carrying total magnification and absolute viewport-local start anchor. The normalized SwiftUI `UnitPoint` is converted into screen points exactly once via a shared initializer.
- `SpatialPinchTransaction.camera` accepts an optional explicit focal point and preserves the old center default for existing callers. Rejects invalid viewport dimensions and nonfinite/out-of-viewport anchors.
- Both `.updating` and `.onEnded` create the same preview value. `@GestureState` resets to nil on cancellation, so there is no stale anchor or magnification across gestures.
- The C2.16 trackpad scroll adapter is disabled for the duration of a nonnil pinch preview.
- Added targeted tests of off-center world-coordinate invariance, stable preview-versus-commit, cancellation/new-anchor isolation, and invalid focal points.

## Results — proof gates
- Focused and full KollioApp Swift tests, actual Xcode Debug Swift 6 app build and native NSHostingView acceptance.
- OpenSpec generated views and Xcode generated-source parity. No tracked screenshot or user document mutation.
- CI `native-spatial` green before merging. Physical two-finger pinch test remains unverified without a human operator.

## Next STAR
- C2.18: keyboard/VoiceOver focus of canvas items and a real small-window navigation journey, then repair only the observed problems. Preserve all semantic/document separation invariants.

## Verified local evidence

- **PASS:** 3/3 targeted C2.17 tests of off-centre screen/world anchor, preview and commit equivalence, invalid focal points.
- **PASS:** 405/405 KollioApp Swift tests in 48 suites.
- **PASS:** source syntax, generated OpenSpec views and Xcode project source parity.
- **PASS:** Xcode Debug build for the actual macOS application under Swift 6 (37-source generated project, no project diff).
- **PASS:** two native NSHostingView FR/EN captures (900×700) executed and visually inspected, with six semantic objects and seven visual representations; stored only on the Mac at `review/c37/evidence/c37-fr.png` and `c37-en.png`.
- **Pending:** GitHub CI after branch publication. The screenshots show the resting canvas, **not** an actual pinch performed by a person.
