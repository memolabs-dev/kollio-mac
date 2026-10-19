# P08 — Privacy, Security & Trust

## Question de confiance

L’utilisateur doit pouvoir répondre :

> Qu’est-ce qui a quitté mon Mac, pourquoi, et qu’est-ce que ce système externe pouvait réellement changer ?

## Local-first

Le produit reste utile offline.

## Destination explicite

- Demo
- On this Mac
- Private Cloud Compute
- Server

Aucun fallback implicite.

## Data movement

Aucun contenu document/source ne quitte la machine sans chemin produit explicite.

## Secrets

Jamais dans :

- `.kollio`
- logs
- fixtures
- screenshots
- source control

## Logs

OK : IDs de corrélation, counts, durations, provider status.  
Par défaut non : texte utilisateur, sources, transcripts, credentials.

## Prompt injection posture

Le contenu importé est de la donnée non fiable, jamais une instruction exécutable.

## Source trust states

attached / pending / ready / partial / unsupported / missing / cited / reviewed.

Imported ≠ verified.

## Model trust

Output = candidat non fiable → validation → preview → décision humaine.

## Indexing

Indexer le minimum dérivé nécessaire. Éviter full source text, hidden branches, transcripts.

## Recovery

La sécurité inclut la durabilité des documents.

Ne pas revendiquer chiffrement/compliance/enterprise readiness sans implémentation et preuve.
