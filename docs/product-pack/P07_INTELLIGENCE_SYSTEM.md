# P07 — Intelligence System

## Règle

L’intelligence est un **proposal engine**.

## Modes

### Demo
Déterministe, tests et démonstration.

### Apple — On this Mac
Foundation Models local.

### Apple PCC — futur conditionnel
Seulement avec entitlement, destination explicite, consentement et avantage mesuré.

### Server
Provider distant optionnel, jamais fallback silencieux.

## Request

Envoyer le plus petit contexte borné nécessaire.

## Output

Le modèle remplit du sens candidat.

Le code de confiance garde :

- IDs ;
- request binding ;
- ownership ;
- verification ;
- authority ;
- execution metadata.

## Validator

Empêche :

- refs inexistantes ;
- overflow d’opérations ;
- états invalides ;
- réponses stale ;
- mutation non autorisée.

## noChange

Résultat valide et parfois préférable.

## Streaming

Montre du progrès sans appliquer de mutations intermédiaires instables.

## Prompts

Les prompts sont des adapters, pas des règles métier.

## Evaluations

Mesurer séparément :

- validité ;
- bounds ;
- fabricated refs ;
- rejected-memory ;
- relevance ;
- usefulness ;
- language quality ;
- latency ;
- first progress ;
- cancellation.

## Dynamic profiles

Explore / Challenge / Compare / Verify / Synthesize seulement après mesure.

## Retrieval

Pas de vector DB avant cas réel mesuré.

## Core AI

Plus tard, tâche étroite, dataset, confiance calibrée, gain mesuré sur une règle déterministe.
