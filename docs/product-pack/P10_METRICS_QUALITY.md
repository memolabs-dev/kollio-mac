# P10 — Metrics & Quality

## North-star question

Le produit rend-il le raisonnement complexe plus persistant, compréhensible et réutilisable ?

## Activation

Utilisateur :

1. saisit son contexte ;
2. crée/explore une branche ;
3. prend une décision ;
4. save/reopen.

## Product metrics

- reasoning retention ;
- decision inspectability ;
- reopen usefulness ;
- source traceability ;
- discoverability des actions ;
- contextual-control collision rate.

## Model metrics

Structural :

- valid proposal rate ;
- operation bounds ;
- stale-response rejection ;
- fabricated-ref prevention ;
- cancel correctness.

Behavioral :

- relevance ;
- usefulness ;
- novelty sans redondance ;
- constraint adherence ;
- language quality ;
- appropriate noChange.

Latency :

- cold ;
- warm ;
- first visible progress ;
- cancel time.

## Performance

Cible SOLO : environ 100 objets / 200 relations.

Mesurer pan, zoom, select, drag, relationship rendering, positioning, save/load.

## Evidence levels

1. Specified
2. Implemented
3. Automated verified
4. Real-model verified
5. Human verified
6. Operational verified

Ne jamais appeler tout cela simplement « done ».
