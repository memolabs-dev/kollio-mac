# Kollio C2.10 — STAR : parcours lisible sans pointeur

## Situation
- C2.9 a fiabilisé la langue et évité qu'une flèche de navigation déplace accidentellement une occurrence.
- Le canvas restait essentiellement spatial : accéder à une carte sans pointeur nécessitait de la rechercher, et l'ordre des dessins ne donnait pas systématiquement le sens des relations.
- Contrats CAN-02 AC01/AC03, CAN-01, CAN-03 et design du focus : ordre du graphe puis position, actions accessibles sans survol.

## Task
- Fournir un parcours natif, découvrable au clavier et aux technologies d'assistance, sans changer le modèle ou la caméra avant choix explicite.
- Assurer un ordre déterministe, exhaustif, même avec cycles, objets sans relations ou plusieurs occurrences.
- Ajouter preuves automatiques et une capture NSHostingView réelle.

## Actions
- Ajouter SpatialV3ReadingOrder, parcours en largeur relationnel, racines triées par position et repli garanti pour les cycles/objets isolés.
- Ajouter un Menu natif Parcourir les cartes, chaque entrée ayant le type lisible et le titre d'origine, qui utilise le chemin navigate(to:) existant.
- Localiser les trois nouvelles chaînes FR/EN, ajouter des identifiants d'accessibilité, sans mutation documentaire.
- Ajouter trois tests de dépendances, permutation des entrées/cycles, et invariance du document réel.

## Results — vérifications
- **PASS** : 3/3 tests ciblés ; 381/381 tests KollioApp dans 43 suites ; vérification des vues générées des specs et syntaxe Swift.
- **PASS** : deux captures natives NSHostingView 900 × 700 (FR / EN), exécutées et inspectées. Le menu « Parcourir 7 cartes » / « Browse 7 cards » apparaît pour 6 objets sémantiques et 7 représentations.
- Captures hors Git : review/c30/evidence/c30-fr.png et c30-en.png ; aucun document utilisateur modifié.
- Le menu est une alternative clavier/pointeur ; sa présence ne prouve pas automatiquement le comportement réel de VoiceOver ou du Tab macOS. Navigation, focus et sélection restent une validation humaine ouverte.

## Suite
- C2.11 : Escape / retour au niveau précédent et récupération des brouillons, puis validation humaine de focus, trackpad et VoiceOver. Respecter la spécification CAN-02 et CAN-04.