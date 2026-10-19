# Kollio C2.18 — STAR: reachable card actions and focus in compact windows

## Situation

CAN-02 requires actions reachable without hover and Escape closing one level before selection; the design requires a perceivable focus and a logical target when dismissing an inspector. The native reading menu from C2.10 can jump to an object whose inspector appears below the 580pt canvas and offscreen in a compact macOS window. Opening a selected card from the menu does not reliably give keyboard access to its actions or return the focus when closing it.

## Task

- Keep a discoverable, labeled native action for the selected card visible in a 680×520 macOS window, without requiring a drag, hover, or searching for the off-screen inspector.
- Explicitly scroll to inspector actions and place keyboard + accessibility focus on the actionable Edit command (or Close for read-only fixture).
- Scroll back and focus the native card navigation menu after explicit Escape or Close, without hijacking focus for incidental selection or text updates.
- Preserve model, selection semantics, draft recovery, reading order, gesture arbitration and no permanent sidebar.

## Actions

- Add a contextual Card actions / Actions de la carte command in the navigation region (own row at narrow widths) and a viewport-leading overlay only when a visible card is selected.
- Use ScrollViewReader with stable canvas, navigation and inspector anchors. Only explicit navigation, action navigation and return requests move the outer document scroll. Avoid unexpected repositioning on background updates.
- Use independent SwiftUI FocusState and AccessibilityFocusState for Edit, Close and navigator. The pause-editor gesture returns to its originating Edit action; a deliberate inspector close or Escape returns to navigation.
- Separate readonly (Close) and editable (Edit) focus destinations with a deterministic pure rule. Localize the label and hint in the native String Catalog.
- Add tests for route and FR/EN strings and a real 680×520 NSHostingView capture with selected card and unchanged document.

## Results / evidence gates

- Focused tests; full KollioApp tests; native capture FR/EN, visually inspected; Xcode Debug build and source-list parity; GitHub native CI.
- Keyboard Tab, physical Escape and VoiceOver focus must still be tested by a human. Automated accessibility focus bindings and screenshots alone are not a successful VoiceOver session.

## Next STAR

C2.19: assess effective Tab order, accessibility tree and focus management across real actions and missing/deleted targets, fixing only observed failures; continue to respect reduced motion.


## Verified evidence (Mac)

- **PASS:** 22/22 focused SpatialDocumentEditor tests, including C2.18 focus-destination/escape route and native FR/EN label checks.
- **PASS:** **408/408** KollioApp Swift tests in **48 suites**.
- **PASS:** three native acceptance scenarios in one suite, run **sequentially**, in both French and English. The C2.18 scenario renders a genuine 680×520 macOS NSHostingView with a selected object, without changing the original Kollio document.
- **PASS:** both compact FR and EN captures show **Actions de la carte / Card actions** at the navigation region and at the visible left edge of the canvas. Captures are retained outside Git under review/c38/evidence/c38-compact-fr.png and c38-compact-en.png.
- **Limit of native inspection:** querying NSHostingView accessibilityChildren through AppKit produced **no exposed spatial-v3 identifiers** in this offscreen/accessory-window harness. This is **not evidence that VoiceOver is correct** (or broken) in the actual app. Focus transfer, actual Tab order, VoiceOver and physical Escape must be manually accepted and audited through a real accessibility session.
- **PASS:** actual macOS Debug Xcode build succeeded using the generated 37-source Xcode project, with the Swift 6 toolchain. OpenSpec index/status checks, Swift parse, native String Catalog JSON and git diff checks passed.
- **Pending:** GitHub native-spatial CI after branch publication. The offscreen AX tree probe was inconclusive; real VoiceOver/Tab acceptance still requires a human.

## CI fix — AppKit accessibility probe removed

The GitHub xcode-27 runner compiled the macOS app and completed the existing C2.16 native window test, then the new C2.18 native window test exited with signal 11. The nonessential recursive accessibilityChildren walk was initially suspected; later inspection confirmed its guard prevented it from executing in that CI run, so the cause was more likely test-process window teardown. This probe had returned no usable identifiers locally, so it was removed from the native acceptance test while retaining the FR/EN compact-window bitmap capture and canonical document invariant. Until the rerun is green, native-spatial CI is NOT verified. A dedicated, safe AXUIElement/VoiceOver test belongs to C2.20; the offscreen harness must never be reported as human accessibility acceptance.

## CI root cause refined: isolate native windows per Swift Testing process

The failing GitHub job ran C2.16 successfully and then terminated with signal 11 as the C2.18 test started. C2.18's capture environment variable was *unset* in that CI invocation, so its test body (including the optional accessibilityChildren probe) was skipped. Thus the probe **cannot be credited as the demonstrated cause** of that crash. The macOS headless runner had a process-teardown/next-test boundary instability. The native CI now runs the C2.16 scroll and C2.18 compact selection fixture as **separate Swift Testing processes**, each with its explicit opt-in environment and --no-parallel. This both avoids shared NSWindow teardown across tests and actually validates the compact UI rather than silently skipping it. The AX probe stays removed because it offered no useful proof and should not be used to claim VoiceOver acceptance.
