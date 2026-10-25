# P02 — Product Requirements Document

## Objectif

Construire Kollio comme produit macOS fiable pour le raisonnement visuel persistant avec intelligence bornée.

La spec normative du repository reste la source d’acceptance criteria.

## Requirements produit

### R1 — Real entry
Un lancement neuf accepte le contexte réel de l’utilisateur. Sarah reste une démo explicite.

### R2 — Durable document
Le `.kollio` conserve objets, IDs, décisions, directions écartées, provenance utile et présentation indépendante du renderer.

### R3 — Canvas-first
Le cœur du travail ne dépend d’aucune sidebar, chat, toolbar ou inspector permanent.

### R4 — Validated mutations
Toute mutation significative est une commande validée et atomique.

### R5 — Intelligence as proposal
Une intelligence reçoit un snapshot borné et produit un candidat. Elle n’attribue ni autorité, ni propriété, ni statut vérifié.

### R6 — Human decision
Une proposition reste provisoire jusqu’à l’action humaine explicite.

### R7 — Rejected ≠ deleted
Une direction écartée conserve sa mémoire et peut être rouverte.

### R8 — Source truthfulness
Attaché, extrait, partiel, cité, revu et vérifié sont des états distincts.

### R9 — Offline usefulness
Kollio reste utilisable sans serveur, réseau ou modèle disponible.

### R10 — Provider clarity
`demo`, `On this Mac`, `PCC`, `server` ne sont jamais silencieusement interchangeables.

### R11 — Native interaction
Pointer, trackpad, clavier, drag/drop, menus natifs, dark/light et accessibilité sont de premier rang.

### R12 — Recoverability
Les erreurs de sauvegarde et versions non supportées sont visibles et sûres.

## Grandes zones fonctionnelles

- Document
- Canvas
- Thought objects
- Relationships
- Decisions
- Sources/evidence
- Intelligence
- Comparison/reader
- Apple system integration plus tard

## Non-functional

- fluidité interaction avant latence modèle ;
- tests déterministes sans réseau/modèle ;
- secrets hors documents/logs ;
- FR/EN ;
- VoiceOver / Reduce Motion / Reduce Transparency / Increase Contrast ;
- baseline macOS conservée par progressive enhancement.

## SOLO beta

Doit prouver :

- entrée réelle ;
- parcours humain pointer/trackpad ;
- local model ;
- persistance ;
- accessibilité ;
- performance ~100 objets / 200 relations ;
- distribution/signing ;
- maturité visuelle.
