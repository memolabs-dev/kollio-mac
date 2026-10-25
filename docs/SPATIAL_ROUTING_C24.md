# Spatial Ink — C2.4 : relations sur document réel

Le canvas macOS « Document actif » lit le document .kollio v7 sans écriture de géométrie générée.
SpatialDocumentScene évite maintenant les cartes intermédiaires pour les relations réelles :
segment droit quand il est libre, sinon coude ou couloir orthogonal déterministe.
Les cartes intermédiaires sont protégées par une enveloppe conservative de 230 × 140 points
et une marge de 12 points. Les identifiants et le sens métier des relations restent inchangés.

En cas d'échec de tous les couloirs candidats, le trajet de secours porte blocked=true
et n'est jamais déclaré dégagé. Ce routage borné n'est PAS une preuve de routabilité exhaustive.

Vérification : swift test --package-path packages/KollioApp --filter SpatialDocumentSceneTests
Scénarios : Sarah inchangée, réouverture sans réécriture, carte obstacle, trajet droit libre,
et trajet impossible identifié comme bloqué.

Reste ouvert : occurrences multiples de NodeInstance, parcours sur grille exhaustive,
dimensions finales de carte / titres longs, retour d'accessibilité, gestes physiques,
migration Web/Mac et performance dense sur des documents utilisateur.
Validation locale du 13 octobre 2026 : 8/8 tests SpatialDocumentSceneTests et 363/363 tests KollioApp (41 suites) au vert. La promotion de la branche reste distincte de ce contrôle technique.
