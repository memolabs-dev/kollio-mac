# Kollio Visual Language v3
## Paper / Ink / Branch / Glass

**Status:** Design specification  
**Scope:** Kollio macOS  
**Primary target:** macOS 27 / Xcode 27, with graceful fallback to the current macOS 14 minimum  
**Audience:** Product design, SwiftUI implementation, visual QA, coding agents  
**Principle:** *The canvas is the application.*

---

# 0. Purpose

This document defines the visual and motion language of Kollio.

It is not a moodboard and not a collection of disconnected style tips. It is an operational specification for how Kollio should **look, move, react, focus attention, expose controls, represent uncertainty, and settle back into calm**.

The goal is to make Kollio immediately recognizable without turning it into a visually noisy whiteboard or a glass-heavy demo.

The core thesis is:

> **Paper is where things live.  
> Ink is what things mean.  
> Branch is how thought evolves.  
> Glass is how the human acts on it.**

Kollio should feel like a **living thinking document native to macOS**, not:

- a chatbot with a canvas attached;
- a Miro clone;
- a collection of cards;
- a dashboard;
- a workflow editor;
- a glowing “AI app”;
- an Apple design demo full of gratuitous Liquid Glass.

The visual system must preserve the product model already present in Kollio:

- the canvas is primary;
- no permanent sidebar is required for the core loop;
- no permanent chat panel;
- actions appear near the object being worked on;
- proposals become branches in the graph;
- the document remains the source of truth;
- intelligence proposes changes rather than regenerating the world.

---

# 1. The four-material model

Kollio has four visual materials. Every major UI element should clearly belong to one of them.

## 1.1 PAPER — the world

Paper is the persistent spatial environment.

Examples:

- canvas background;
- frames;
- persistent document regions;
- large reading areas;
- stable source previews.

Paper should feel:

- quiet;
- matte;
- durable;
- spatially continuous;
- non-interactive until content or controls indicate otherwise.

Paper must **never compete with the content**.

### Rule

Do not add decorative blur, gradients, shine, glow, texture noise, or glass to the main canvas merely to make it look “premium”.

Premium comes from restraint, spacing, typography, interaction continuity, and motion quality.

---

## 1.2 INK — meaning

Ink represents durable semantic content.

Examples:

- context;
- ideas;
- decisions;
- constraints;
- claims;
- source labels;
- text;
- essential relationship labels.

Ink is the primary carrier of truth.

Ink must remain readable in:

- light mode;
- dark mode;
- increased contrast;
- reduced transparency;
- narrow windows;
- zoomed-out states;
- long French strings;
- long English strings.

### Rule

Opacity must never be the primary mechanism for communicating semantic uncertainty when that opacity makes text difficult to read.

Use:

- line style;
- label;
- border style;
- semantic marker;
- relationship style;
- spatial grouping;

before lowering text contrast.

---

## 1.3 BRANCH — change through space

Branch is Kollio’s signature.

Branch is not just a connector drawn between rectangles.

It visually represents:

- causality;
- derivation;
- exploration;
- alternatives;
- decisions;
- constraints;
- rejected directions;
- proposed future structure.

The branch system should eventually be more visually distinctive than the card system.

### Rule

Whenever possible, a user action that creates or changes structure should visually explain itself through a **branch transformation**.

Examples:

- Explore → branch grows outward.
- Add → local composer becomes a new branch.
- Keep proposal → dashed provisional connection settles into a durable connection.
- Set aside → branch collapses without pretending the content never existed.
- Reopen → the same branch returns from its previous structure.

---

## 1.4 GLASS — instruments

Glass represents temporary controls used to manipulate the world.

Examples:

- contextual action controls;
- command palette;
- temporary decision controls;
- local navigation aids;
- transient source actions;
- temporary reader controls;
- compact selection instruments.

Glass is **not content**.

Glass must feel:

- temporary;
- responsive;
- tactile;
- foregrounded;
- native;
- spatially attached to the object or operation that caused it.

### Rule

> **Do not turn nodes into glass.**

The document remains matte.

Liquid Glass belongs to the control layer that hugs the document.

This follows current Apple guidance: use Liquid Glass sparingly, favor standard controls, and avoid applying glass throughout content areas where it provides little functional benefit.

---

# 2. Visual hierarchy

Kollio uses semantic depth rather than arbitrary shadow levels.

## Z0 — WORLD

Persistent document content:

- canvas;
- nodes;
- text;
- relations;
- frames;
- stable sources.

Characteristics:

- matte;
- no glass;
- minimal elevation;
- remains visually calm.

## Z1 — ACTIVE WORLD

Something in the document is currently relevant:

- hovered node;
- selected node;
- drag target;
- active branch;
- proposal;
- citation target;
- frame being manipulated.

Characteristics:

- slightly stronger separation;
- more visible anchors;
- semantic accent;
- no heavy floating-card appearance.

## Z2 — INSTRUMENTS

Controls used to act:

- contextual actions;
- composer controls;
- proposal decision actions;
- command palette;
- quick actions;
- local menus.

Characteristics:

- system-native control styling;
- Liquid Glass when available and appropriate;
- screen-space sizing;
- foreground behavior;
- tactile response.

## Z3 — TEMPORARY FOCUS SURFACES

Used only when the task genuinely requires more room:

- long source reader;
- share confirmation;
- conflict comparison;
- complex modal operation.

Characteristics:

- explicit entry and exit;
- preserves canvas selection and camera;
- does not become a permanent inspector.

Kollio should almost never display all four depth levels simultaneously.

---

# 3. The “95% document” rule

At rest:

- ~90–95% perceived interface should be content/canvas;
- controls should be nearly absent;
- visual chrome should not frame every object.

During interaction:

- controls emerge locally;
- the affected branch gains emphasis;
- irrelevant chrome remains hidden.

After the action:

- controls recede;
- structure settles;
- the canvas becomes quiet again.

A good Kollio screenshot at rest should look more like a thoughtful document than like software configuration UI.

---

# 4. Surfaces

## 4.1 Canvas

The canvas is a continuous visual field.

Current light direction:

- warm neutral / off-white;
- no visible texture required;
- no gradient vignette;
- no glass.

Current dark direction:

- dark neutral;
- not pure black;
- nodes and relations must remain distinguishable without glowing.

### Background behavior

The background can respond to focus only minimally.

Allowed:

- extremely subtle global dimming when a focused temporary reader is open;
- slight reduction in distant visual hierarchy during branch focus.

Not allowed:

- animated gradients;
- aurora backgrounds;
- AI-themed bloom;
- decorative noise;
- moving particles.

---

## 4.2 Nodes are not all cards

Do not force every semantic object into the same rounded rectangle.

The visual form should help communicate what kind of thing an object is.

### Context

Context is structurally important.

Suggested characteristics:

- stronger text scale;
- calm stable container when useful;
- generous breathing room;
- clear anchor role.

### Thought / idea

A normal idea should be allowed to appear primarily as **text in space**, with only the minimum container necessary for hit testing, selection, drag affordance, and long content.

This prevents “Miro syndrome”: hundreds of equally heavy cards.

### Decision

A decision should feel settled.

Possible cues:

- compact confirmation mark;
- stronger relationship finality;
- semantic label;
- durable ink treatment.

Do not make it bright green by default.

### Constraint

A constraint should be distinct without looking like an error.

Possible cues:

- compact semantic marker;
- slightly different relationship treatment;
- attention color used sparingly.

### Source / reference

A source should look like a source:

- document/file icon or type marker;
- title;
- extraction state;
- provenance status where useful.

A source is not automatically evidence.

### Proposal

A proposal is a candidate state of the world.

It should be:

- fully readable;
- visually provisional;
- linked to the branch that would be created;
- clearly attributable when requested.

Use:

- dashed relationship;
- proposal label;
- accent;
- subtle provisional surface.

Do not simply set the entire proposal to 50% opacity.

---

# 5. Shape language

Use few shape families.

## Persistent document shapes

Prefer restrained continuous rounded rectangles only where a surface is truly necessary.

Avoid putting a visible rounded rectangle around every text block.

## Control shapes

Prefer system control shapes.

On current Apple design systems, standard controls may become more rounded or capsule-like automatically.

Do not fight those changes with hard-coded heights and radii.

## Nested temporary surfaces

When a control or temporary panel sits near the corner of a larger container/window, use concentric geometry when supported.

Goal:

> nested surfaces should feel physically related, not like unrelated rounded rectangles.

---

# 6. Radius policy

Current Kollio radius tokens remain useful for document surfaces, but system controls should increasingly use native shape behavior.

Suggested semantic mapping:

- **control** — use native control shape first;
- **reference** — compact durable source object;
- **richBlock** — content-rich temporary or persistent surface;
- **composer** — local writing surface.

Do not add five more radius sizes.

Avoid:

```swift
.cornerRadius(14)
```

sprinkled throughout unrelated components.

The radius should come from semantic role or system geometry.

---

# 7. Color system

The existing warm paper + dark ink + cobalt accent direction remains valid.

## 7.1 Accent meaning

Cobalt means:

- selection;
- active attention;
- primary action;
- proposal;
- interactive emphasis.

Cobalt does **not** mean:

- correct;
- AI-generated truth;
- approved;
- trustworthy.

## 7.2 Attention

Amber-like attention tones mean:

- inspect;
- unresolved;
- review;
- constraint.

Not:

- danger by default.

## 7.3 Error

Red is reserved for:

- actual errors;
- destructive operations;
- failed states requiring attention.

A rejected direction is not an error.

## 7.4 Text on accent

Never assume white text works on every accent.

The current dark-mode accent is relatively light.

Introduce semantic foreground logic such as:

- `onAccent`;
- system-resolved foreground;
- native button contrast behavior.

Do not hard-code `.white` for every primary button.

---

# 8. Typography

Use system typography.

Kollio should feel editorial rather than “UI dense”.

Current hierarchy is a reasonable starting point:

- invitation: ~28;
- context: ~22;
- primary thought: ~18;
- body: ~15;
- action: ~13;
- metadata: ~12.

These are not rigid pixel contracts.

## Rules

- Regular is the reading default.
- Medium distinguishes hierarchy.
- Semibold is occasional.
- Avoid using bold as the main differentiation mechanism.
- Avoid uppercase labels everywhere.
- Metadata must remain readable.
- Never shrink text automatically just to fit a card.
- Prefer width adaptation, wrapping, truncation with a reveal mechanism, or expansion.

---

# 9. Layout and spacing

Use the existing spacing scale consistently.

The interface should feel spacious because irrelevant UI is absent, not because every element has enormous padding.

## Local action spacing

Contextual controls must be placed in screen space, not canvas world scale.

They should:

- remain usable while zoomed out;
- stay inside the viewport;
- avoid covering the selected title;
- dynamically choose above/below/side placement;
- adapt to real measured size;
- work with long FR and EN labels.

Do not assume a fixed width like `300` for collision logic.

Measure the actual view.

---

# 10. Rest → Hover → Select → Act → Compose → Propose → Decide → Settle

This is the canonical Kollio interaction state machine.

Every visual behavior should fit into this sequence.

---

## 10.1 REST

The application is calm.

Visible:

- content;
- relationships;
- minimal global document status if required.

Hidden:

- local action bars;
- unnecessary handles;
- tooltips;
- persistent editing chrome.

### Motion

None.

Rest is not an animation.

---

## 10.2 HOVER

Hover means:

> “This can be interacted with.”

It does not mean:

> “This object is active.”

### Allowed hover response

- subtle edge or text separation increase;
- appearance of a tiny anchor/handle;
- pointer feedback;
- slight relationship emphasis if relevant.

### Avoid

- card lifting 8 points;
- giant shadow;
- bright fill;
- scale-up;
- glow;
- multiple icons appearing around the node.

### Timing

Hover entrance should feel almost immediate:

- target: 70–110 ms;
- no overshoot;
- ease-out.

Hover exit:

- 90–140 ms;
- calm ease.

If Reduce Motion is enabled, hover should still communicate state but without animated movement.

---

## 10.3 SELECT

Selection says:

> “Actions now apply here.”

Selection must be clearly distinct from hover.

Possible cues:

- accent outline or selection contour;
- branch attachment points;
- nearby local controls;
- active relationship emphasis.

The node should remain visually recognizable as the same persistent object.

Do not convert it into an entirely different card style.

### Motion

Selection can use:

- opacity reveal of controls;
- 2–4 point positional settling;
- subtle native glass interactive response.

Target:

- 120–180 ms.

No dramatic zoom.

---

## 10.4 ACT

Actions appear where they are relevant.

Three primary actions maximum in the immediate local surface.

Secondary actions live in an explicit “More” menu.

### Preferred model

The controls are instruments attached to the selected semantic object.

They may be:

- horizontal when space allows;
- compact vertical when needed;
- partially orbital if that makes the resulting direction spatially understandable.

### Orbital controls

Use only where spatial direction has semantic meaning.

Example:

- right-side action creates a rightward exploratory branch;
- lower action sets a direction aside;
- local plus creates adjacent content.

Do not use an arbitrary radial menu purely for novelty.

---

## 10.5 COMPOSE

The action should visually transform into the writing surface when possible.

Ideal continuity:

```text
[ + Add ]
    ↓
local composer
    ↓
new object
    ↓
settled branch
```

Avoid:

```text
button
↓
unrelated modal
↓
form
↓
confirmation
↓
new card appears elsewhere
```

### Composer surface

The text field itself should remain stable and readable.

Do not put dense document content behind highly transparent text entry.

Glass may be used for:

- surrounding command controls;
- submit/cancel;
- temporary instrument shell;

but the typing region must preserve legibility.

---

## 10.6 PROPOSE

When intelligence proposes a change, Kollio should show the *future structure* before it becomes true.

The animation should communicate:

> “A branch could grow here.”

Suggested sequence:

1. anchor becomes active;
2. provisional connector begins;
3. candidate destination appears;
4. proposal content fades into full readable state;
5. decision controls appear.

Do not use a generic centered spinner as the primary visual representation.

If computation takes time, status should stay local to the operation.

---

## 10.7 DECIDE

A proposal decision should visually separate:

- **what is proposed**;
- **why**;
- **what the user can do now**.

Controls:

- Keep;
- Set aside;
- Why / provenance when needed;
- reveal if proposal is off-screen.

Decision controls may use Glass.

Proposal content remains Paper/Ink.

---

## 10.8 SETTLE

This is the most important transition in Kollio.

When a proposal is kept:

- provisional styling resolves;
- dashed relation becomes durable;
- temporary proposal label disappears;
- control glass recedes;
- new content remains in the document.

The interface must communicate:

> “This is now part of the world.”

When set aside:

- do not fake deletion;
- preserve reasoning;
- collapse or quiet the branch;
- retain an affordance to inspect/reopen.

---

# 11. Liquid Glass rules

## 11.1 Use native controls first

When a standard SwiftUI/AppKit control can express the intent, use it.

Prefer native glass button styles over applying a raw glass material behind a custom fake button.

Do not create:

```text
custom filled button
+ custom blur
+ custom border
+ glassEffect
```

unless there is a strong semantic reason.

## 11.2 Glass belongs around content, not throughout content

Good candidates:

- contextual controls;
- command palette;
- compact temporary navigation;
- interactive clusters;
- proposal decision actions;
- floating local tools.

Poor candidates:

- every idea;
- context nodes;
- every source;
- canvas frames;
- relationship labels;
- paragraph backgrounds.

## 11.3 Regular vs clear

Default to a legible regular glass treatment.

Clear glass should be used only when the background context makes it beneficial and text remains readable.

Do not choose `clear` simply because it looks more futuristic.

## 11.4 One glass system per local group

If multiple glass elements belong together:

- group them with the system’s appropriate container APIs where available;
- avoid stacking glass on glass;
- avoid separate unrelated blur sampling layers.

## 11.5 Interactive glass

On macOS 27, use the system’s interactive glass behavior for appropriate controls when available.

The physical response should communicate that an instrument was pressed.

Do not add extra custom:

- shimmer;
- bloom;
- wobble;
- large scale bounce;

on top of the system response.

A little physicality is enough.

---

# 12. Local controls

The current contextual action surface is a priority redesign target.

## Desired behavior

When one object is selected:

1. compute the true rendered size of the control group;
2. find a non-overlapping screen-space placement;
3. prefer below;
4. otherwise above;
5. otherwise side placement;
6. otherwise compact layout;
7. keep a safe viewport inset;
8. preserve keyboard navigation.

## Visual form

Do not necessarily wrap all actions in a giant glass slab.

Prefer:

- native glass buttons grouped as one instrument cluster;
- an outer shared glass shape only if it genuinely improves hierarchy;
- one prominent action at most.

## Action hierarchy

Primary action:

- visually strongest;
- one only;
- may use prominent glass.

Secondary primary actions:

- normal glass/system buttons.

More:

- native menu.

Destructive:

- separated;
- never visually confused with the main action.

---

# 13. Control → Consequence principle

A Kollio interaction should preserve visual continuity between input and result.

Examples:

## Add

```text
+ Add
→ composer grows from control
→ text is submitted
→ composer shell resolves into node
→ branch settles
```

## Explore

```text
Explore
→ local control responds
→ provisional branch grows
→ proposal appears at destination
→ decision controls emerge
```

## Keep

```text
Keep
→ control responds
→ proposal style settles
→ glass disappears
→ durable structure remains
```

## Set aside

```text
Set aside
→ reason if required
→ branch compresses/collapses
→ durable set-aside state remains
```

The motion should explain the state transition.

---

# 14. Branch visual language

Relationships deserve their own design system.

Do not attempt to encode dozens of semantics with dozens of line styles.

Use a small vocabulary.

## Durable relationship

- solid;
- stable;
- moderate contrast;
- readable at common zoom.

## Proposal relationship

- dashed;
- accent;
- clearly provisional.

## Focused relationship

- stronger emphasis;
- no neon glow.

## Set-aside relationship

- quiet;
- inspectable;
- should not look like an error.

## Constraint / dependency

Use a semantic marker or controlled line treatment where needed.

Avoid turning Kollio into BPMN/UML.

---

# 15. Branch growth animation

Branch creation should be a signature Kollio motion.

## Goal

Communicate:

> one thought is becoming another.

## Sequence

1. origin anchor subtly activates;
2. connector reveals from origin toward destination;
3. destination node enters with a small offset;
4. text becomes readable quickly;
5. branch stops moving;
6. controls appear only after the structure is understandable.

## Timing target

For normal branch growth:

- total: 240–340 ms;
- connector begins immediately;
- destination begins ~40–80 ms after branch motion starts;
- no long stagger.

Current `Motion.branch ≈ 0.28 s` is consistent with this direction.

## Easing

Prefer a smooth ease-out or critically damped spring.

Avoid cartoon overshoot.

## Reduced motion

Skip growth travel.

Use:

- immediate relationship appearance;
- short opacity transition;
- no simulated drawing movement.

---

# 16. Proposal animation

The proposal is not magic.

Avoid:

- sparkles everywhere;
- typewriter AI text;
- rainbow gradients;
- floating particles.

A small sparkle icon may be used as a semantic marker, not as decoration.

## Candidate sequence

```text
origin
  ↓
provisional connector
  ↓
candidate node
  ↓
proposal label
  ↓
decision instruments
```

The proposal’s text must become fully readable as early as possible.

---

# 17. Keep transition

Keeping a proposal should be satisfying precisely because it is restrained.

Possible transition:

- dashed connector smoothly becomes solid;
- accent tint reduces to durable document styling;
- “Proposal” label fades;
- control cluster disappears;
- object remains exactly where it was.

No celebratory animation.

The satisfaction comes from **stability**.

Target:

- 160–240 ms.

---

# 18. Set-aside transition

Set aside means:

> “not now / not this direction,” not “destroy”.

Suggested behavior:

1. optional reason is captured;
2. active branch loses emphasis;
3. geometry collapses or condenses;
4. a small durable set-aside marker remains;
5. the original spatial history can be restored.

Avoid red.

Avoid trash animation.

Target:

- 180–280 ms.

---

# 19. Reopen transition

Reopen must feel like restoration, not generation.

The exact previous objects and relations return.

Suggested motion:

- collapsed marker remains the origin;
- previous branch expands from stored structure;
- nodes return to their known positions;
- no random layout.

Target:

- 220–320 ms.

Reduced motion:

- immediate structure restore + short opacity.

---

# 20. Hover and pointer language

macOS pointer interaction is a first-class affordance.

## Canvas

- pan cursor behavior should feel expected;
- dragging canvas and dragging content must be distinguishable.

## Node

Hover may reveal:

- subtle anchor;
- slight selection candidate contour.

## Drag

While dragging:

- dragged content gains Z1 emphasis;
- valid targets become clearer;
- invalid targets stay quiet;
- cursor and target state tell the same story.

Do not build flashy custom cursors.

Use system semantics whenever possible.

---

# 21. Drag and drop

Drag and drop can become a signature Mac interaction.

Examples:

- PDF onto branch;
- CSV onto idea;
- image onto relevant object;
- text selection into canvas;
- URL as reference.

## Drag-over state

Before drop, the UI must tell the user what will happen.

Examples:

- “Add as source to this branch”
- “Create independent reference”
- “Use here”

Do not silently send dropped content to an intelligence provider.

## Visual behavior

Valid target:

- controlled highlight;
- attachment point or destination hint;
- no massive color fill.

On drop:

- reference appears in the world;
- extraction state is visible;
- relationship settles.

---

# 22. Source previews and Peek

Kollio should embrace Mac inspection behavior.

A lightweight “peek” interaction can allow a person to inspect a source without leaving the canvas context.

Possible trigger:

- Space when a source is selected;
- explicit preview action.

## Peek surface

May use a temporary focused reader.

Requirements:

- source title;
- relevant extract;
- provenance/state;
- easy dismissal;
- preserve camera and selection.

Opening preview does not mutate the document.

---

# 23. Command palette

`⌘K` is recommended as a power-user layer.

It must remain contextual.

## Nothing selected

Possible commands:

- Find;
- Open;
- Import;
- Create;
- Fit content;
- Document actions.

## One object selected

Possible commands:

- Explore;
- Add;
- Edit;
- Add source;
- Compare;
- Set aside;
- Other valid actions.

## Multiple objects selected

Possible commands:

- Group;
- Compare;
- Frame;
- bulk operations that truly make sense.

## Visual design

Command palette is an instrument surface:

- Glass where appropriate;
- native text field;
- keyboard-first;
- concise;
- no permanent panel.

---

# 24. Focus depth

Kollio can use selective visual hierarchy to help someone reason about one branch without hiding the rest of the world.

When a branch is actively explored:

- active object: 100%;
- directly connected context: high;
- distant content: reduced visual priority.

But this must not reduce essential text below legible contrast.

Prefer:

- connector emphasis;
- slight surface quieting;
- reduced decorative detail;

before aggressively lowering text opacity.

## Escape ladder

`Esc` should move outward one semantic level at a time.

Example:

```text
editing
→ selected object
→ focused branch
→ normal document
```

This behavior should be visually mirrored: each Escape removes one layer of UI/focus.

---

# 25. First experience

Do not build a dashboard simply because the application needs an empty state.

The first experience should be almost entirely Paper.

Possible structure:

```text
What are we working on?

[ multiline context field ]

Open a document…
```

When context is submitted:

- the input should visually become the first durable object;
- then exploration may begin.

This is preferable to:

```text
welcome screen
→ wizard
→ project settings
→ provider selection
→ empty canvas
```

---

# 26. Window design

Use the native macOS window.

Do not build a fake custom title bar unless there is a concrete product requirement.

The current unified compact toolbar direction is compatible with a low-chrome canvas.

## Near window corners

Use native concentric corner behavior where supported for temporary surfaces that sit near the window edge.

This is especially relevant to:

- palette;
- floating controls;
- readers;
- share surfaces;
- transient overlays.

---

# 27. Menus

Menus should remain native and legible.

Rules:

- text-first;
- icons only when they add recognition;
- no emoji menu decoration;
- destructive items separated;
- ellipsis only when additional input is genuinely required;
- actions named by effect.

Prefer:

- “Remove from board”
- “Set aside”
- “Add source”

over vague labels like:

- “Manage”
- “Process”
- “AI action”

---

# 28. Icons

Use SF Symbols when an icon is appropriate.

Do not make icons the only representation of uncommon actions.

Use icon-only controls primarily when:

- convention is extremely strong;
- space is constrained;
- accessibility label/help is excellent.

Kollio’s local actions should often keep text labels because the semantic operations are more important than compactness.

---

# 29. Shadows

Shadows are not the default method for hierarchy.

Persistent nodes:

- little or no shadow.

Selection:

- rely on contour/accent before shadow.

Glass controls:

- let the system material do most of the work.

Temporary focus surfaces:

- system-appropriate separation.

Avoid large web-style `0 20 60` floating shadows.

---

# 30. Borders

Borders have three roles:

1. decorative separation;
2. semantic state;
3. focus/selection.

Do not use the same low-contrast line for all three.

Accessibility requirement:

- decorative border may disappear under some conditions;
- selection/focus must remain independently identifiable.

macOS 27 also exposes border-related environment behavior; custom controls should respect system preferences where applicable.

---

# 31. Dark mode

Dark mode is not a simple inversion.

Test every semantic state independently.

Important:

- light accent colors may require dark text;
- glass appearance changes with environment;
- shadows require restraint;
- selected nodes must not become neon;
- proposal readability must remain high.

Always review:

- Rest;
- Hover;
- Selected;
- Composer;
- Proposal;
- Keep;
- Set aside;
- Error;
- Disabled.

---

# 32. Accessibility

Accessibility is part of the visual language, not an audit phase.

## Reduce Transparency

Glass surfaces must remain functional and visually understandable when transparency is reduced.

Never make meaning depend on seeing content refracted behind a control.

## Increase Contrast

Increase:

- semantic outlines;
- control distinction;
- connector legibility.

Do not merely increase saturation everywhere.

## Reduce Motion

Remove spatial movement that is not essential.

Replace:

- branch travel → appearance;
- panel slide → fade;
- camera animated transition → immediate or very short transition.

Preserve state communication.

## VoiceOver

Every visually meaningful proposal must have an accessible semantic representation.

If a ghost node is hidden from accessibility, the proposal’s content and decision state must be exposed elsewhere.

## Keyboard

All primary flows must be usable without pointer precision.

Especially:

- select;
- actions;
- composer;
- keep/set aside;
- menus;
- command palette;
- dismiss;
- source preview.

---

# 33. Motion philosophy

Motion exists to answer one of four questions:

1. **Where did this come from?**
2. **Where did this go?**
3. **What changed state?**
4. **What is currently interactive?**

If an animation answers none of these, remove it.

---

# 34. Motion tokens

The existing Kollio motion scale is a strong basis.

Recommended semantic mapping:

| Token | Target | Use |
|---|---:|---|
| feedback | 90–120 ms | button/hover feedback |
| reveal | 120–160 ms | small UI appearance |
| dismiss | 140–180 ms | transient UI exit |
| expand | 190–240 ms | composer/reader expansion |
| branch | 250–320 ms | graph structural change |
| camera | 220–320 ms | fit/reveal/focus movement |
| stagger | 30–50 ms | only tightly related sequences |

Avoid animations longer than ~400 ms for routine interactions.

Long animations make the application feel performative rather than direct.

---

# 35. Easing policy

Use three motion characters maximum.

## Direct

For tiny feedback:

- short ease-out;
- near-instant response.

## Settling

For control morphing / composer:

- smooth critically damped spring;
- minimal overshoot.

## Structural

For branch/camera:

- smooth ease-in-out or low-bounce spring;
- spatial continuity is more important than spectacle.

Do not create unique easing curves per component.

---

# 36. Spring policy

A spring may be used when an element:

- physically responds to interaction;
- transforms into another control;
- settles after a drag.

Avoid obvious bounce for:

- content insertion;
- long text;
- proposals;
- reading surfaces.

The content should not look rubbery.

---

# 37. Morphing

Morphing is valuable when it preserves identity.

Good:

- Add button → local composer;
- compact action group → expanded local action group;
- glass control → menu/popover;
- proposal decision cluster → settled state removal.

Bad:

- unrelated node shape morphs into modal;
- every card morphs on hover;
- large canvas regions liquefy for decoration.

On systems supporting Glass morph APIs, use `GlassEffectContainer` / IDs / transitions only where the elements are genuinely one instrument transforming.

---

# 38. Camera motion

Camera animation is allowed when it helps orientation.

Examples:

- Fit content;
- Reveal off-screen proposal;
- Navigate to search result;
- restore anchor after temporary reader.

Camera must not move just because a node is selected.

## Rules

- preserve user orientation;
- shortest reasonable travel;
- no dramatic zoom out then zoom in;
- keep active anchor visible;
- avoid simultaneous heavy camera and node animations.

Target:

- 220–320 ms;
- Reduce Motion → immediate or minimal.

---

# 39. Drag motion

During a drag:

- movement should track the pointer directly;
- do not spring behind pointer;
- snap only when snap semantics are real.

After drag:

- minimal settling;
- avoid bounce.

If auto-layout is introduced later, layout movement must be predictable and reversible.

---

# 40. Loading and intelligence activity

Avoid a global “AI is thinking” surface when work applies to one branch.

Prefer local activity.

Possible treatment:

- origin connector indicates pending growth;
- small progress/status near anchor;
- controls remain understandable.

Never imply success before a valid proposal exists.

Do not animate fake branch content while the model has produced nothing.

---

# 41. Status and errors

Errors must be readable even if they are visually inconvenient.

Do not auto-hide an important save failure merely to preserve a clean canvas.

Use:

- local error near operation where possible;
- document-level status for save/share state;
- red only for real failures/destructive states.

Motion:

- no shaking;
- no flashing;
- short reveal.

---

# 42. Empty vs sparse states

Sparse is good.

Do not fill empty space with:

- educational cards;
- template carousels;
- inspirational copy;
- AI suggestions;
- onboarding mascots.

Offer one clear next action.

---

# 43. Responsive window behavior

Test at minimum:

- current default window;
- current minimum window;
- narrow but usable width;
- large desktop window;
- full-screen.

When space decreases:

1. preserve document;
2. reposition local instruments;
3. compact controls;
4. move secondary actions into menus;
5. only then consider alternative temporary layout.

Never shrink action targets below comfortable macOS interaction size merely to fit.

---

# 44. Long strings

Test French first-class, not as an afterthought.

Examples:

- “Ajouter une source”
- “Comparer les directions”
- “Retirer du document”
- long set-aside reason
- long source name

Controls must reflow or compact intentionally.

Do not clip semantic verbs.

---

# 45. Localization

Do not use fixed geometric assumptions based on English labels.

Measure.

If a control group cannot fit:

- reorder only if semantic hierarchy remains;
- use compact stacking;
- move secondary actions to More;
- reposition.

---

# 46. Selection geometry

Selection should attach to the object’s actual visible geometry.

For text-like nodes without heavy card containers:

- selection can use a subtle padded shape;
- hit target may be larger than visible shape.

Visual bounds and interaction bounds do not need to be identical.

---

# 47. Relationship hit testing

Thin connector lines can be visually thin but require larger invisible hit targets.

Do not make lines visually thick just to make them clickable.

Use an expanded interaction region.

---

# 48. Frames

Frames organize; they should not become panels.

At rest:

- quiet boundary;
- label if needed.

Selected:

- stronger structure;
- drag/rename affordance.

Do not fill every frame with tinted backgrounds that turn the canvas into nested cards.

---

# 49. Comparison

Comparison is a focused temporary mode, not a permanent inspector.

Visual priorities:

- comparable content first;
- differences second;
- controls third.

When closed:

- return to exact canvas context;
- preserve camera and selection.

---

# 50. Long-form reader

Use for content that cannot reasonably be understood inside a node.

The reader should:

- show what is being read;
- show source/provenance;
- preserve an obvious return path;
- not mutate state merely by opening.

The reader may occupy substantial space because the task has temporarily changed from spatial reasoning to reading.

---

# 51. Initial content transition

A signature first-run transition:

1. person writes context;
2. submits;
3. writing surface contracts/resolves into first context object;
4. camera remains stable;
5. first branch action becomes available.

Avoid throwing away the user’s text and recreating a visually unrelated object somewhere else.

---

# 52. Visual density budget

For any state, count:

- visible buttons;
- badges;
- icons;
- borders;
- panels;
- labels;
- status text.

Ask:

> Which of these exists because the current task requires it?

Remove everything else.

A UI can be visually small but conceptually overloaded.

---

# 53. AI visual language

AI must not receive a separate “magic visual universe”.

Avoid:

- purple gradients;
- rainbow borders;
- animated stars;
- glowing brains;
- pulsing AI halos;
- “thinking” particle fields.

Use the existing proposal semantics:

- branch candidate;
- attribution;
- rationale;
- source references;
- proposal status.

The product differentiator is **observable reasoning structure**, not AI decoration.

---

# 54. Visual truthfulness

Visual confidence must match semantic confidence.

Do not use:

- strong confirmation green for generated suggestions;
- verified badges for imported sources;
- polished completion animation for partial extraction;
- final solid relation before the user keeps a proposal.

The UI must visually distinguish:

- exists;
- proposed;
- reviewed;
- decided;
- unavailable;
- partial.

---

# 55. Persistence and visual continuity

After save/quit/reopen:

- positions remain;
- selected state may restore where sensible;
- camera restoration should be considered;
- collapsed/set-aside branches remain semantically identical;
- nothing should “reanimate as new” simply because the app relaunched.

Kollio is a document, not a feed.

---

# 56. Anti-patterns

Do not implement:

## Glass everywhere

If everything is glass, nothing is foreground.

## Cardification

Not every idea needs a white rounded rectangle.

## Glow hierarchy

Do not communicate importance by increasingly strong glow.

## AI sparkle spam

One semantic indicator is enough.

## Giant shadows

Avoid web-dashboard elevation tropes.

## Permanent controls

Do not add a left toolbar, right inspector, and bottom AI bar to solve local interaction problems.

## Invisible complexity

Do not hide ten unrelated commands behind one mysterious icon merely to keep screenshots minimal.

## Motion for delight only

Motion must explain.

## Opacity as status

Do not make important text illegible to show uncertainty.

## Random layout movement

Never move existing thought structure unpredictably after model output.

---

# 57. SwiftUI implementation guidance

The following is architectural guidance, not a literal requirement to copy code.

## Native buttons

Prefer semantic SwiftUI `Button` with native styles.

On compatible systems:

- `.glass`;
- `.glassProminent`;
- appropriate native border shapes.

On older systems:

- system-standard fallback;
- existing semantic theme colors.

Keep availability handling centralized.

Do not sprinkle availability checks throughout dozens of views.

---

## Glass helper layer

If needed, create a small design-system abstraction such as:

```swift
enum KollioControlEmphasis {
    case normal
    case prominent
    case destructive
}

struct KollioInstrumentButtonStyle { ... }
```

Purpose:

- semantic consistency;
- availability fallback;
- accessibility adaptation.

Do not build a second UI framework.

---

## Shared glass groups

Where several glass controls visually act as one instrument cluster, use the platform’s grouping/container mechanisms on supported systems.

This improves:

- material consistency;
- morph behavior;
- rendering;
- spatial cohesion.

---

## Measured contextual placement

Contextual surfaces should publish their actual size through layout/preferences and compute placement from:

- viewport;
- target frame;
- safe insets;
- control size;
- exclusion zones.

Pseudo-policy:

```text
try below
if collision → above
if collision → trailing
if collision → leading
if still impossible → compact/stack
clamp inside viewport
```

Do not rely on hard-coded `width = 300`.

---

## Screen-space instruments

Keep contextual instruments out of world zoom.

They should be anchored to world objects but rendered in screen space.

This preserves:

- click target;
- typography;
- legibility;
- glass rendering quality.

---

## Semantic motion

Keep timing in the design system.

Do not introduce ad-hoc:

```swift
.animation(.spring(duration: 0.47, bounce: 0.32))
```

per component.

Prefer named semantic animations:

```swift
KollioMotion.feedback
KollioMotion.reveal
KollioMotion.branch
KollioMotion.camera
```

---

# 58. Compatibility policy

Current Kollio baseline is macOS 14.

Do not silently raise it solely to get Liquid Glass.

Use progressive enhancement.

## macOS 14–25

- stable opaque/system materials;
- current semantic surfaces;
- native buttons;
- same hierarchy;
- same motion semantics.

## macOS 26

- adopt supported Liquid Glass APIs;
- native glass styles where available;
- grouped glass effects when useful.

## macOS 27

- receive system Liquid Glass refinements;
- use appropriate interactive glass behavior;
- consider concentricity APIs;
- respect user-adjustable Liquid Glass appearance and accessibility behavior;
- adopt system refinements without manually recreating them.

The design must remain conceptually identical across versions.

Only the rendering quality changes.

---

# 59. Accessibility fallback matrix

| Setting | Expected visual change |
|---|---|
| Reduce Transparency | Glass becomes more opaque/stable; hierarchy remains |
| Increase Contrast | Important outlines/connectors strengthen |
| Reduce Motion | Spatial travel removed; state still communicated |
| Show Borders / system border preference | Custom controls remain distinguishable |
| Dark Mode | Foregrounds resolve semantically, no hard-coded white |
| Larger text | Nodes expand/reflow; content is not clipped |

---

# 60. Visual QA matrix

Every major state must be captured and reviewed in:

## Theme

- Light
- Dark

## Language

- English
- French

## Window

- minimum supported size
- default size
- large

## Accessibility

- default
- increased contrast
- reduced transparency
- reduced motion

## State

- empty / first experience
- normal document
- hover
- selection
- contextual actions
- composer
- proposal
- proposal off-screen
- attribution open
- keep
- set aside
- reopened
- source attached
- source extraction partial
- error
- comparison
- long reader

---

# 61. Motion QA checklist

For every animation ask:

- Does it explain origin/destination/state?
- Can it be interrupted?
- Does interaction remain responsive during it?
- Does it preserve pointer position expectations?
- Does it create layout shift?
- Is content readable before the animation finishes?
- Does Reduce Motion have a coherent alternative?
- Are two unrelated major animations running simultaneously?
- Does camera motion fight node motion?
- Does the animation make the app feel slower?

If the answer to the last question is yes, shorten or remove it.

---

# 62. Visual review checklist

Before approving a component:

## Hierarchy

- Can the primary content be identified instantly?
- Are controls visually secondary to content?
- Is only one action truly prominent?

## Material

- Is Glass being used as an instrument?
- Could this surface simply be Paper?
- Is glass stacked on glass?

## Semantic truth

- Does the visual state match actual document state?
- Is proposal visually distinct from decision?
- Is an imported source accidentally styled as “verified”?

## Contrast

- Are labels readable?
- Is focus visible without relying on a decorative border?
- Does dark-mode accent foreground pass visual review?

## Motion

- Does movement explain change?
- Is settle state calm?

## Mac behavior

- keyboard reachable?
- pointer affordance?
- drag/drop understandable?
- menus native?
- native window conventions preserved?

---

# 63. Implementation priorities

## Phase V3.1 — Foundation

1. Fix foreground contrast on primary actions.
2. Introduce semantic `onAccent` / native foreground behavior.
3. Centralize visual compatibility for glass.
4. Measure contextual action size instead of assuming dimensions.
5. Capture baseline screenshots.

## Phase V3.2 — Liquid Instruments

1. Replace custom fake button backgrounds with native control styles where appropriate.
2. Introduce Glass only on local instruments.
3. Keep Paper/Ink nodes matte.
4. Refine local action placement.
5. Test reduced transparency and dark mode.

## Phase V3.3 — Motion grammar

1. Formalize semantic animation helpers.
2. Add control → composer continuity.
3. Refine branch growth.
4. Refine proposal → keep settle.
5. Refine set-aside/reopen restoration.
6. Add Reduce Motion variants.

## Phase V3.4 — Spatial interaction

1. Experiment with directional/orbital actions only where spatial semantics are real.
2. Improve branch anchors.
3. Improve drag targets.
4. Add source drag-and-drop polish.
5. Improve pointer states.

## Phase V3.5 — Power Mac

1. Add contextual `⌘K`.
2. Add lightweight Peek/source reading.
3. Improve keyboard navigation.
4. Restore context cleanly after temporary reading/focus modes.
5. Explore concentric temporary surfaces near window edges.

## Phase V3.6 — Simplify nodes

1. Review which node types truly require cards.
2. Reduce generic rectangles.
3. strengthen semantic visual forms.
4. Give Branch more visual identity.
5. Validate crowded real-world documents.

---

# 64. Definition of Done for Visual Language v3

V3 is successful when:

1. Kollio still feels like the same product, not a redesign for redesign’s sake.
2. A screenshot at rest is calmer than before.
3. A screenshot during interaction is more understandable than before.
4. Glass is visible primarily on instruments, not the document.
5. Ideas can exist without looking like identical cards.
6. Branch transformations explain intelligent operations.
7. Proposals remain fully readable.
8. Keeping a proposal visibly settles it into reality.
9. Set-aside feels reversible, not destructive.
10. Local controls never fall outside the window.
11. French labels do not break the layout.
12. Dark mode no longer relies on white text over light accents.
13. Reduce Transparency and Increase Contrast remain excellent.
14. Reduce Motion preserves all semantic feedback.
15. The core loop is fully usable by keyboard.
16. The application still works down to its declared baseline through graceful fallback.
17. No permanent sidebar or chat was added merely to hold actions.
18. The visual system can be explained in four words:

> **Paper. Ink. Branch. Glass.**

---

# 65. Canonical visual mantra

When making a design decision, use this order:

### 1. Can content itself explain the state?

Use Ink / Branch.

### 2. Does the person need to act now?

Reveal Glass locally.

### 3. Does the action change the document?

Animate the consequence through Branch.

### 4. Is the action complete?

Settle back into Paper.

That loop is Kollio.

---

# 66. Apple platform references

This design direction should be checked against the latest official Apple documentation during implementation because platform behavior can evolve.

Primary references:

- Apple — **Adopting Liquid Glass**  
  https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass

- Apple — **Applying Liquid Glass to custom views**  
  https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views

- Apple — **GlassEffectContainer**  
  https://developer.apple.com/documentation/swiftui/glasseffectcontainer

- WWDC26 — **Modernize your AppKit app**  
  https://developer.apple.com/videos/play/wwdc2026/289/

- WWDC26 — **SwiftUI Group Lab**  
  https://developer.apple.com/videos/play/wwdc2026/8120/

- Apple Human Interface Guidelines — **Materials**  
  https://developer.apple.com/design/human-interface-guidelines/materials

Implementation should prefer current SDK documentation over assumptions in this document whenever APIs or availability differ.

---

# 67. Agent execution brief

When an implementation agent works on this visual system, it must:

1. Read the project’s `AGENTS.md`.
2. Read the existing `docs/design/` documents.
3. Inspect the current component before changing it.
4. Preserve domain/document semantics.
5. Avoid broad redesigns unrelated to the visual task.
6. Reuse semantic tokens instead of raw local values.
7. Preserve the macOS 14 baseline unless explicitly instructed otherwise.
8. Use availability-safe native APIs.
9. Capture comparable before/after states.
10. Test the full repository after structural source changes.
11. Clearly distinguish:
   - implemented;
   - visually reviewed;
   - automatically tested;
   - not yet validated on live macOS 27 rendering.

The agent must not claim that an effect matches Apple guidance merely because it uses a blur or transparency API.

The desired result is not “more glass”.

The desired result is:

> **A quieter document, better instruments, more legible state changes, and a spatial interaction language that feels uniquely Kollio.**
