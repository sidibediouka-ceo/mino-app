# Mino : vision produit, arbitrages et parcours

> **Chaque soir, demain est prêt. Chaque saison, rien ne manque. Chaque vêtement trouve une seconde vie.**

Ce document part d'une page blanche. Il pose le problème, remet en cause les idées reçues de la catégorie, résume le benchmark mondial, définit le MVP et décrit les mécanismes de différenciation. L'architecture technique est décrite dans [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 1. Le vrai problème

La charge mentale vestimentaire d'un parent ne tient pas au style. C'est de la **logistique sous incertitude** :

| Question récurrente | Fréquence | Coût aujourd'hui |
|---|---|---|
| « Qu'est-ce qu'il met demain avec ce temps ? » | quotidienne | 5 min le soir ou le matin, avec du stress |
| « Est-ce que ça lui va encore ? » | hebdomadaire | essayages, disputes, vêtements trop petits portés trop longtemps |
| « Qu'est-ce qui va lui manquer cet hiver ? » | saisonnière | achats en urgence ou en double |
| « Qu'est-ce que je fais de tout ça ? » | 2 à 3 fois par an | cartons oubliés, achats alors que la grande sœur avait déjà tout |

Un enfant change de taille **tous les 6 à 12 mois** avant 6 ans. Sa garde-robe est donc éphémère par nature. C'est ce qui distingue Mino d'une application de dressing pour adulte.

## 2. Hypothèses remises en cause

| Hypothèse de départ | Notre position | Conséquence produit |
|---|---|---|
| « Il faut numériser toute la garde-robe. » | **Faux.** La saisie fait abandonner la plupart des utilisateurs des apps de dressing, et la garde-robe d'un enfant se renouvelle tous les ans. | Mino est utile **dès 10 vêtements**. Saisie en lot (20 photos d'un coup) et analyse automatique. On ne numérise ni les chaussettes ni les sous-vêtements. |
| « Les parents veulent des tenues stylées. » | **Pas d'abord.** Ils veulent une tenue **adaptée à la météo, à la bonne taille et disponible**. | Moteur de tenue : météo × taille × rotation × contexte de la journée. Le style se limite à l'harmonie des couleurs et aux vêtements « habillés » pour les fêtes. |
| « On mesure la taille en âge (4 ans, 18 mois…). » | **Trompeur.** L'âge sur l'étiquette varie selon les marques. Le Japon, la Chine et la norme EN 13402 utilisent la **stature en cm**. | L'unité interne est le cm (100, 110, 120…), affichée avec l'équivalent en âge. C'est ce qui rend la projection fiable. |
| « Il faut engager par des notifications. » | **Nuisible.** Chaque notification inutile use la confiance. | **Une seule** notification, opt-in : le rituel du soir. Elle n'est jamais culpabilisante. |
| « La revente doit être intégrée (marketplace). » | **Conflit de valeurs** : une marketplace pousse à consommer. | Mino **rédige l'annonce** et le parent la publie où il veut. Avant toute idée d'achat, Mino regarde d'abord dans les cartons de la famille. |
| « L'IA doit tourner dans le cloud. » | **Inacceptable pour des photos d'enfants.** | Toute l'analyse se fait sur l'appareil (Apple Vision). Pas de compte, pas de serveur, pas de tracking. |
| « La gamification (séries, badges) augmente la rétention. » | **Anxiogène** : rater une série culpabilise. | La récompense, c'est le temps gagné et une bonne nouvelle (« rien à racheter cet hiver »). |

## 3. Benchmark mondial

| Produit | Pays | Ce qu'il fait bien | Sa limite pour notre cible | Ce que Mino en retient |
|---|---|---|---|---|
| **Acloset** | 🇰🇷 Corée | Détourage et tags automatiques, tenues selon la météo, statistiques de port, seconde main intégrée | Pensé pour les adultes et le style. Les utilisateurs signalent des associations incohérentes. Freemium au-delà de 100 pièces | Détourage automatique par défaut. Tenue météo comme rituel quotidien |
| **Whering** | 🇬🇧 R.-U. | Interface soignée, « Dress Me » | Tenues proposées au hasard. Marketplace financée par l'affiliation | Pas d'affiliation. Les tenues sont justifiées, jamais aléatoires |
| **Stylebook** | 🇺🇸 É.-U. | Planificateur fiable, coût par port | Saisie entièrement manuelle | La saisie est la dette principale : on l'élimine |
| **Indyx** | 🇺🇸 É.-U. | Revente intégrée, stylistes humains | Payant et centré sur le style | La sortie du vêtement fait partie du cycle de vie |
| **SizeSeason**, **Outgrow**, **Baby Togs** | 🇺🇸 et autres | Tailles bébé, courbes OMS, scan d'étiquette | Inventaires sans quotidien : on ne les ouvre qu'une fois par saison | Courbes OMS et scan d'étiquette, mais **arrimés à un usage quotidien** |
| **Mercari** (AI Listing Support) | 🇯🇵 Japon | Une photo suffit : catégorie, titre et description sont générés | Marketplace | Annonce prête en un geste, sans marketplace |
| **Xianyu 闲鱼** (Alibaba) | 🇨🇳 Chine | Plus de 20 M de mères y échangent des articles enfants (chiffres 2021) | Plateforme commerciale | La transmission est un comportement de masse : il faut la faciliter |
| **Karrot 당근** | 🇰🇷 Corée | Échange hyperlocal entre voisins | Généraliste | Piste de long terme : un cercle de familles proches |
| **Uniqlo / ZOZO** | 🇯🇵 Japon | Tailles enfant en cm (100, 110, 120…) | Pas d'outil de suivi | Le cm comme unité de vérité |
| **Rituels japonais** | 🇯🇵 Japon | 前の晩の準備 (préparer les affaires la veille au soir avec la météo) et 自分で着替え (l'enfant s'habille seul à partir d'un support visuel, pratique courante en crèche) | Pratiques, pas des produits | **Le soir, c'est prêt** et le **Mode enfant** |

**Ce que montre le benchmark.** Les apps de dressing (Acloset, Whering) maîtrisent le quotidien mais ignorent la croissance. Les apps de taille enfant (SizeSeason, Outgrow) maîtrisent la croissance mais n'ont pas de quotidien. **Aucune ne relie les deux.** C'est l'espace de Mino : le rituel quotidien (la tenue de demain) nourrit l'intelligence saisonnière (besoins, tri, transmission), et l'inverse.

## 4. Positionnement

**Mino est le copilote de la garde-robe familiale qui grandit avec les enfants.** Ce n'est ni un dressing ni une boutique.

Ses principes de conception :
1. **L'intelligence se ressent, elle ne s'affiche pas.** On ne parle jamais d'« IA ». On voit seulement une tenue juste et une phrase d'explication (« 8° ce matin et pluie : imperméable et bottes »).
2. **Toute recommandation mène à un geste** : *Habillé*, *Récupérer*, *Transmettre*, *Mesurer*, *Trier*.
3. **Moins d'actions, mais de meilleures.** Au plus trois suggestions par jour, triées par utilité.
4. **L'incertitude est dite honnêtement.** « Vers mi-février (entre janvier et mars) » plutôt qu'une date fausse.
5. **Les cartons de la famille passent avant l'achat.**

## 5. Les parcours prioritaires

Le produit repose sur une entrée et trois boucles. Chaque boucle a un budget d'effort.

### Entrée : premier usage en moins de 90 secondes
1. Un écran d'accueil, une promesse.
2. L'enfant : prénom, date de naissance, **taille habituelle** (« il porte du 4 ans ») et pointure. On ne demande pas sa stature : les parents connaissent la taille de l'étiquette, pas la mesure en cm.
3. **10 photos en lot** depuis la photothèque ou en rafale à l'appareil. Mino détoure, propose catégorie, couleur et taille (lecture de l'étiquette) ; le parent valide d'un geste.
4. La première tenue apparaît immédiatement, avec la météo du jour.

### Boucle 1 : « Le soir, c'est prêt » (quotidienne)
- **19 h 30**, une notification opt-in : « Demain 8° et pluie. Les tenues de Léo et Inès sont prêtes. »
- À partir de 16 h, l'écran *Aujourd'hui* bascule seul sur **demain**.
- Pour chaque enfant : une tenue complète et justifiée. Toucher une pièce la remplace par la meilleure alternative. Le contexte (École, Sport, Sortie, Fête, Maison) s'ajuste en un geste.
- **« Habillé »** en un geste : le vêtement est marqué comme porté, la rotation se met à jour et Mino apprend.
- **Mode enfant** au matin : les pièces en grand, dans l'ordre d'habillage, que l'enfant coche lui-même. Ce mode est inspiré des crèches japonaises. Il transforme une corvée en autonomie, et c'est un moment que les enfants réclament.
- **Budget : 1 geste par jour.**

### Boucle 2 : « La taille d'après » (saisonnière)
- Projection de croissance à partir des courbes OMS, recalée sur les mesures de l'enfant, **avec un intervalle d'incertitude** : « Passe en 110 vers mi-février (entre janv. et mars). »
- **Besoins anticipés** : pour la saison en cours et la suivante, Mino compare une garde-robe type (une semaine d'école, une lessive par semaine) à ce qui ira à l'enfant **à la date utile**, pas seulement aujourd'hui.
- **Avant d'acheter, regarder dans les cartons** : si un vêtement stocké ou devenu trop petit pour l'aîné ira bientôt au cadet, Mino propose de le **récupérer** en un geste.
- **Budget : moins de 2 minutes par saison.**

### Boucle 3 : « Trier et transmettre » (cycle de vie)
- Mino détecte les vêtements probablement trop petits et propose une **session de tri** à cartes qu'on balaie, d'une minute.
- Pour chaque pièce, il recommande une destination : **le cadet** (« Pour Inès, dans 5 mois environ »), **les cartons**, **le don** ou **la vente**. Pour la vente, l'annonce est rédigée et prête à partager vers Vinted, Leboncoin ou ailleurs.
- « Ça va encore » est une réponse légitime : Mino recale alors son estimation.
- **Budget : 1 minute pour 10 vêtements.**

## 6. MVP : ce qui est dedans et ce qui ne l'est pas

| Dans le MVP | Hors MVP (et pourquoi) |
|---|---|
| Plusieurs enfants, profils, mesures | Comptes et connexion : aucune valeur ajoutée, et un risque pour la vie privée |
| Ajout en lot, détourage, catégorie, couleur et lecture d'étiquette sur l'appareil | Reconnaissance de marque ou de matière : trop peu fiable, et peu utile pour décider |
| Inventaire par enfant et cartons familiaux | Sous-vêtements et chaussettes : trop de saisie pour trop peu de valeur |
| Tenue du jour ou du lendemain : météo, contexte, rotation, harmonie des couleurs | Calendrier de tenues sur plusieurs semaines : le lendemain suffit, l'au-delà est spéculatif |
| Projection de taille et de pointure avec incertitude | Courbes médicales détaillées : Mino n'est pas un outil de santé |
| Besoins anticipés et récupération depuis les cartons | Liens d'achat ou affiliation : contraire à la promesse |
| Tri, transmission, don, vente (annonce prête) et souvenirs | Marketplace intégrée : conflit de valeurs |
| Une notification quotidienne opt-in | Notifications promotionnelles ou de relance : jamais |
| Apprentissage discret (préférences, routine de la semaine) | Statistiques détaillées de style : du bruit pour un parent |
| | Synchronisation et partage co-parent : V2, prévue dans le modèle (CloudKit) |

## 7. Une rétention saine

La boucle suit le modèle *trigger → action → récompense → investissement*, sans manipulation :

| Étape | Mécanisme Mino |
|---|---|
| **Déclencheur interne** | La petite angoisse de 19 h (« et demain ? »). Le déclencheur externe, la notification du soir, ne sert qu'à l'amorcer. |
| **Action minimale** | Ouvrir, voir la tenue, toucher *Habillé*. |
| **Récompense variable** | La tenue juste avec sa phrase d'explication, et parfois une bonne nouvelle : « Rien à racheter cet hiver », « 3 pantalons d'Inès iront à Léo en mars », « 12 vêtements ont eu une seconde vie cette année ». |
| **Investissement** | Chaque *Habillé*, chaque mesure et chaque tri rendent Mino plus juste. Les préférences et les routines (« le mercredi, c'est sport ») sont apprises, jamais saisies. |

Avec le **Mode enfant**, c'est l'enfant qui demande à ouvrir l'app le matin.

## 8. Différenciation à long terme

1. **Le graphe familial** : frères, sœurs, cousins. Transmission entre foyers (grands-parents, cousins) via un partage CloudKit.
2. **Le copilote partagé** : co-parent, nounou, grands-parents. La tenue est prête quel que soit l'adulte présent.
3. **Le calendrier comme contexte** : l'activité « piscine le jeudi » ou une sortie scolaire ajuste la tenue, avec App Intents et Siri (« Qu'est-ce que Léo met demain ? »).
4. **Widget et Live Activity « Tenue de demain »** sur l'écran verrouillé.
5. **Apprentissage des marques** : « Cette marque taille petit, prenez la taille au-dessus. »
6. **Cercle local de transmission** à la Karrot : échanger entre familles voisines, sans argent et sans marketplace.
7. **Capsule de saison** : une liste de besoins partageable avec la famille (« Pour son anniversaire, il lui faudra des bottes en 29 »).

## 9. Feuille de route

| Version | Contenu |
|---|---|
| **1.0 (ce dépôt)** | Les trois boucles, l'ajout en lot sur l'appareil, la projection de croissance et le Mode enfant |
| 1.1 | Synchronisation iCloud privée, widgets « Tenue de demain », App Intents |
| 2.0 | Partage co-parent et famille élargie (CloudKit Sharing), contexte calendrier |
| 2.x | Apprentissage des marques, cercle local de transmission |
