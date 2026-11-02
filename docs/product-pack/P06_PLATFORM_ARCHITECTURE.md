# P06 — Platform & Architecture

## Layers

```text
KollioCore
  document / commands / validation / decisions / proposals / serialization

KollioApp
  SwiftUI/AppKit / canvas / Apple adapter / sources / system integration

KollioServer
  optional remote proposal path

contracts
  document / action / proposal schemas
```

## Invariant

`KollioCore` ne dépend jamais de SwiftUI, AppKit, FoundationModels ou Vapor.

## Document

`.kollio` est versionné, portable, stable-ID, explicite, renderer-independent, credential-free.

Séparer :

1. état sémantique ;
2. présentation ;
3. état éditeur transitoire.

## Mutation

Toute mutation passe par commande validée atomique.

Les vues demandent des changements ; elles ne patchent pas les collections.

## Proposal pipeline

`document → scoped request → SuggestionService → candidate → trusted conversion → validator → preview → human acceptance → command transaction`

Valider avant preview **et** avant acceptance.

## Provider seam

`SuggestionService` porte les modes demo / Apple / PCC futur / server.

Changer de provider ne change pas le modèle de document.

## Server

Optionnel en SOLO. Utile plus tard pour remote inference, tenancy, policy ou collaboration.

## Apple integration

App Entities = vues dérivées d’IDs Kollio.  
App Intents = appels vers commandes Kollio.  
Spotlight = index dérivé/reconstructible.

## Performance

Priorité :

1. direct manipulation ;
2. interaction latency ;
3. command execution ;
4. first visible model progress ;
5. total inference latency.

Ne pas distribuer prématurément un problème non mesuré.
