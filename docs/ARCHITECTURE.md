# Mino : architecture

## Principes

| Principe | Traduction technique |
|---|---|
| **Vie privée par construction** | Aucun serveur, aucun compte, aucun SDK tiers. Toute l'analyse d'image se fait sur l'appareil (Apple Vision). La localisation est approximative, ponctuelle et jamais stockée. |
| **L'intelligence est testable** | Toute la logique métier vit dans `MinoKit`, un package Swift pur (Foundation seulement), testé hors de l'app et même sous Linux. |
| **Natif et sobre** | SwiftUI, SwiftData, Observation, Swift Charts, WeatherKit et Vision, sur iOS 17 minimum. Zéro dépendance externe. |
| **Aucun code mort** | Chaque type et chaque fonction est utilisé. Pas d'abstraction « au cas où » : un protocole n'apparaît que lorsqu'il a deux implémentations. |
| **Prêt pour la synchronisation** | Les modèles SwiftData respectent les contraintes de CloudKit (valeurs par défaut, relations optionnelles, pas d'unicité). Activer la synchro iCloud en v1.1 ne demandera donc pas de migration. |

## Vue d'ensemble

```
┌──────────────────────────── App Mino (SwiftUI) ────────────────────────────┐
│ Features/                                                                  │
│   Onboarding   Today (Le soir, c'est prêt · Mode enfant)   Wardrobe        │
│   Growth (La taille d'après · besoins)   Sort (Trier & transmettre)        │
│   Settings                                                                 │
│        │ lit et écrit                          │ demande                   │
│ Persistence/ (SwiftData)                 Services/                         │
│   Child · GrowthEntry · Garment          WeatherStore (WeatherKit)         │
│   PlannedOutfit · FamilySnapshot ──┐     LocationProvider (approximative)  │
│                                    │     GarmentAnalyzer (Vision)          │
│                                    │     EveningReminder (notification)    │
└────────────────────────────────────┼───────────────────────────────────────┘
                                     │ valeurs immuables (ChildProfile, WardrobeItem, DayForecast)
┌────────────────────────────────────▼────── MinoKit (Swift pur) ────────────┐
│ Growth      courbes OMS, projection taille et pointure avec incertitude    │
│ Sizing      tailles en cm (EN 13402), libellés FR, lecture d'étiquette     │
│ Wardrobe    catégories, couleurs, cycle de vie, « est-ce que ça lui va ? » │
│ Weather     ressenti de la journée d'un enfant, estimation de saison       │
│ Outfit      moteur de tenue, routine apprise, apprentissage des préférences│
│ Anticipation besoins saisonniers, cartons familiaux, conseil de seconde vie│
│ Briefing    ce qui mérite un geste : trier, récupérer, mesurer             │
│ Listing     annonce de revente factuelle                                   │
│ Recognition labels Vision → catégorie, pixels → couleur nommée             │
└────────────────────────────────────────────────────────────────────────────┘
```

La frontière est nette : l'app traduit ses objets SwiftData en **valeurs immuables** (`ChildProfile`, `WardrobeItem`, `DayForecast`) via `FamilySnapshot`, appelle `MinoKit`, puis applique le résultat. `MinoKit` ne connaît ni SwiftUI, ni SwiftData, ni Vision.

## L'intelligence, expliquée

### Projection de croissance (`ChildProfile`)
- Les références de stature (médiane et écart-type, de 0 à 16 ans, fille ou garçon) sont tirées des standards OMS 2006 et de la référence OMS 2007.
- L'enfant est maintenu dans **son propre couloir** (z-score constant depuis la dernière mesure). Un grand enfant reste grand.
- **L'incertitude** s'élargit avec l'horizon. Elle part de ±0,5 cm après une vraie mesure, et de ±2,5 cm quand la taille est déduite des vêtements portés (l'onboarding demande la taille de l'étiquette, pas la stature).
- La pointure suit la même logique : l'écart à une courbe typique est conservé.
- `dateReaching` renvoie une **fenêtre** (au plus tôt, attendu, au plus tard), affichée sous la forme « vers mi-février (entre janvier et mars) ».

### Est-ce que ça lui va ? (`Fit`)
- Un vêtement étiqueté *s* cm va aux statures comprises dans ]s − 8 ; s + 2]. Entre s − 14 et s − 8, il est « un peu grand » mais portable.
- Une chaussure *s* va à une pointure estimée dans ]s − 1,2 ; s + 0,3].
- Quand le parent répond « Ça va encore » pendant le tri, la mesure du moment est mémorisée et repousse la limite haute.

### Moteur de tenue (`OutfitEngine`)
1. **Ressenti** : 60 % la température ressentie du matin, 40 % le maximum de l'après-midi, réparti en six bandes (de très froid à chaud).
2. **Couches requises** selon le ressenti, la pluie et le contexte (École, Sport, Sortie, Fête, Maison).
3. **Score par pièce** : adéquation à la météo, adéquation au contexte, préférence apprise, rotation (une pièce portée la veille se repose), ajustement, et une petite variation stable par jour pour départager deux pièces équivalentes.
4. **Combinaison haut et bas** avec harmonie des couleurs (les neutres vont avec tout, deux couleurs vives différentes se heurtent). Une robe est comparée à la meilleure paire haut-bas.
5. **Explications** : une ou deux phrases, et les **manques** (« Rien à sa taille pour : manteau »).

### Le copilote invisible
- **Préférences** (`PreferenceLearning`) : quand le parent confirme une tenue, les pièces gardées gagnent +0,15, les pièces choisies à la place +0,3 et les pièces écartées −0,3. Le score est borné entre −2 et 2.
- **Routine** (`WeeklyRoutine`) : choisir « Sport » un mercredi fait de tous les mercredis des jours de sport. Rien n'est demandé au parent.

### Anticipation (`NeedsForecaster`)
- Une garde-robe type par saison, pensée pour une semaine d'école avec une lessive.
- L'évaluation se fait **à la date utile** : dans 6 semaines pour la saison en cours, et au début de la saison suivante si elle commence dans moins de 8 semaines.
- Avant de compter un manque, Mino cherche dans **les cartons** et dans **les vêtements devenus trop petits pour un aîné**, à condition qu'ils aillent au cadet à cette date.
- En dessous de 8 vêtements, Mino ne donne aucun conseil : ce serait du bruit.

### Seconde vie (`LifecycleAdvisor`)
L'ordre est fixe : d'abord le frère ou la sœur à qui le vêtement va maintenant, puis celui ou celle à qui il ira dans les 12 mois, puis les cartons si un enfant de la famille pourra le porter plus tard. Sinon, Mino propose la vente pour les pièces qui se revendent (manteaux, chaussures, tenues habillées) et le don pour le reste.

## Flux de données

- **Aujourd'hui** : `TodayView` construit un `FamilySnapshot`. Une tâche (`.task(id:)`), relancée dès que la météo, le jour ou la garde-robe change, rafraîchit la météo puis appelle `DayPlanner.ensurePlans`. Celui-ci crée ou recalcule un `PlannedOutfit` par enfant, pour aujourd'hui puis pour demain. Les jours sont planifiés dans l'ordre : la tenue prévue aujourd'hui compte comme portée pour demain (`WardrobeItem.worn(on:)`), demain ne la répète donc pas, même si rien n'a été validé. Une tenue que le parent n'a pas retouchée suit la dernière météo ; une tenue retouchée reste telle quelle, sauf si l'une de ses pièces n'est plus disponible. Les écritures n'ont lieu que si quelque chose change.
- **Carnet des tenues** : `OutfitJournalView` affiche, dans un calendrier, les tenues portées (et celles prévues pour aujourd'hui et demain). Tout reste dans l'app.
- **Échanger une pièce** : `DayPlanner.swap` parcourt les alternatives sans revenir en arrière (les pièces écartées dans la journée sont mémorisées).
- **Tenue portée** : `DayPlanner.confirm` met à jour la rotation (`lastWornAt`, `wearCount`) et les préférences. Il est appelé à la fin du Mode enfant, et automatiquement pour toute tenue d'un jour passé : le parent n'a jamais rien à confirmer.
- **Ajouter des vêtements (validation par exception)** : tout le lot s'affiche en grille, avec une taille commune au lot ; seuls les vêtements non reconnus sont signalés « À vérifier ». `GarmentAnalyzer` détoure le vêtement (`VNGenerateForegroundInstanceMaskRequest`), classe l'image (`VNClassifyImageRequest` puis `CategoryGuess.ranked`, dont les trois premières catégories sont proposées en tête), en déduit la couleur dominante (`GarmentColor.dominant`) et lit le texte visible (`VNRecognizeTextRequest` puis `SizeLabelParser`). Le parent valide un brouillon pré-rempli.

## Respect de l'utilisateur

| Sujet | Choix |
|---|---|
| Notifications | Une seule, le rituel du soir, proposée au bon moment (après la première tenue) et jamais à l'installation. Elle est programmée pour les 3 soirs suivants seulement : sans ouverture de l'app, Mino se tait. |
| Localisation | `kCLLocationAccuracyReduced`, demandée une fois, jamais stockée. Sans autorisation, Mino utilise une **estimation de saison** et l'indique. |
| Photos | `PhotosPicker` (aucune autorisation d'accès à la photothèque n'est nécessaire), stockage local en `externalStorage`. |
| Droit à l'effacement | « Effacer toutes les données » dans les Réglages. |
| Attribution | Le logo et les mentions légales d'Apple Weather sont affichés, comme WeatherKit l'exige. |

## Tests

- `MinoKit/Tests` contient 42 tests couvrant la croissance, les tailles et étiquettes, l'ajustement, le moteur de tenue, la routine, l'apprentissage, l'anticipation, le cycle de vie, le briefing, la reconnaissance et l'annonce.
- Commande : `cd MinoKit && swift test` (macOS ou Linux).

## Prochaines étapes techniques

1. **v1.1** : activer `ModelConfiguration(cloudKitDatabase: .private(...))` pour la synchronisation privée ; widget et Live Activity « Tenue de demain » ; App Intents.
2. **v2** : partage CloudKit (co-parent, famille élargie), contexte tiré du calendrier (EventKit).
3. Localisation : les libellés sont aujourd'hui en français dans `MinoKit`. Pour une version internationale, ils passeront dans un String Catalog.
