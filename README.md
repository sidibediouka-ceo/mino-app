# Mino

**Le copilote de la garde-robe des enfants.** Chaque soir, demain est prêt. Chaque saison, rien ne manque. Chaque vêtement trouve une seconde vie.

Application iOS native (SwiftUI · SwiftData · Vision · WeatherKit). Tout reste sur l'appareil : pas de compte, pas de serveur, pas de suivi.

- [Vision produit, benchmark, arbitrages et parcours](docs/VISION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Politique de confidentialité](index.html)

## Structure

```
MinoKit/          Toute l'intelligence de Mino (Swift pur) : framework dans le projet Xcode, package Swift pour les tests
Mino/             Application iOS (SwiftUI)
  App/            Point d'entrée, navigation
  DesignSystem/   Couleurs, composants, formulations françaises
  Persistence/    Modèles SwiftData
  Services/       Météo, localisation, analyse photo, notification du soir
  Features/       Aujourd'hui · Dressing · Grandir · Tri · Réglages · Accueil
project.yml       Définition du projet Xcode (XcodeGen)
```

## Démarrer

Prérequis : Xcode 15.4 ou plus récent, iOS 17 minimum, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen            # génère Mino.xcodeproj, Info.plist et les entitlements
open Mino.xcodeproj
```

**Équipe de signature, une seule fois :** créez `Config/Local.xcconfig` avec votre identifiant d'équipe Apple (10 caractères, visible sur developer.apple.com › Membership) :

```sh
echo 'DEVELOPMENT_TEAM = ABCDE12345' > Config/Local.xcconfig
```

Ce fichier n'est pas versionné et `xcodegen` le relie au projet : l'équipe n'est plus perdue à chaque régénération.

Pour la météo, activez la capability **WeatherKit** pour l'identifiant `com.diouka.mino` dans le portail Apple Developer, puis choisissez votre équipe dans Xcode. Sans WeatherKit, Mino fonctionne avec une estimation de saison.

## Scénarios de démonstration

En Debug (lancé depuis Xcode), la fin de l'onglet Grandir propose des scénarios qui remplissent l'app de données réalistes pour les captures App Store : dressing d'une enfant de 9 ans, passage de taille imminent, petit frère et cartons, tenue préparée, carnet avec photo, vente, photos pour l'ajout par lot. Le code et les images sont dans `Mino/DemoContent/` (photos nommées `DemoGarment-<nom>.png` et `DemoOutfitPhoto.jpg`) et sont exclus des builds Release.

## Tests

```sh
cd MinoKit && swift test
```
