# P14 — Master Agent Brief

## Read order

1. `AGENTS.md`
2. `docs/CONTINUE.md`
3. relevant normative features in `docs/specs/SPECIFICATIONS.md`
4. relevant existing design/architecture docs
5. relevant P* file
6. `P13_VISUAL_LANGUAGE_V3.md` for visual work

## Product

Kollio est un document visuel vivant macOS.

Le canvas est l’application.  
Le `.kollio` est durable.  
L’intelligence propose.  
L’humain décide.  
Rejected ≠ deleted.

## Architecture boundaries

- KollioCore : no SwiftUI/AppKit/FoundationModels/Vapor
- no direct view mutations
- validated commands
- provider-specific types stay in adapters
- model never assigns IDs/authority/verification/ownership
- no credentials/model sessions in `.kollio`

## UI boundaries

Ne pas introduire sans décision explicite :

- permanent sidebar
- permanent chat
- permanent inspector
- generic toolbar
- glass on persistent content
- cardification of every thought
- silent provider fallback
- authored-text replacement

## Visual

Paper = world  
Ink = meaning  
Branch = change  
Glass = instruments

Motion explains consequence.

## Intelligence

Scoped immutable request → candidate → validation → preview → human decision.

Validate again at acceptance.

## Quality

Toujours distinguer :

- implemented
- deterministic verified
- real-model verified
- visually reviewed
- human verified
- operational verified

## Current strategic order

1. human interaction
2. Visual Language V3
3. accessibility
4. realistic graph performance
5. behavioral evaluation
6. Apple system integration

## Final test

> Did this make the reasoning world clearer, more durable, more trustworthy or easier to manipulate?

Sinon, probablement pas maintenant.
