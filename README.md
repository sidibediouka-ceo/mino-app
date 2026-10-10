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

Pour la météo, activez la capability **WeatherKit** pour l'identifiant `app.mino.ios` dans le portail Apple Developer, puis choisissez votre équipe dans Xcode. Sans WeatherKit, Mino fonctionne avec une estimation de saison.

## Tests

```sh
cd MinoKit && swift test
```
