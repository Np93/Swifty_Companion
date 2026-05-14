# Swifty Companion

Swifty Companion est une application iOS développée en **Swift** avec **SwiftUI**.

Le but du projet est de permettre à l’utilisateur de rechercher un profil étudiant de l’école 42 à partir de son login, puis d’afficher les informations principales récupérées depuis l’API officielle de l’Intra 42.

L’application gère l’authentification OAuth avec l’API 42, récupère un token d’accès, le stocke temporairement dans le **Keychain iOS**, puis l’utilise pour effectuer les requêtes vers l’API.

---

## Sommaire

- [Présentation du projet](#présentation-du-projet)
- [Fonctionnalités](#fonctionnalités)
- [Technologies utilisées](#technologies-utilisées)
- [Architecture du projet](#architecture-du-projet)
- [Gestion de l’authentification](#gestion-de-lauthentification)
- [Gestion des secrets](#gestion-des-secrets)
- [Avertissement important sur la sécurité](#avertissement-important-sur-la-sécurité)
- [Installation](#installation)
- [Configuration OAuth 42](#configuration-oauth-42)
- [Images du README](#images-du-readme)
- [Aperçu de l’application](#aperçu-de-lapplication)
- [Détails techniques](#détails-techniques)
- [Améliorations possibles](#améliorations-possibles)
- [Auteur](#auteur)

---

## Présentation du projet

**Swifty Companion** est un projet mobile iOS réalisé dans le cadre du cursus 42.

L’application permet de rechercher un utilisateur de l’Intra 42 grâce à son login. Une fois le profil trouvé, elle affiche plusieurs informations liées à cet utilisateur :

- login
- email
- wallet
- correction points
- cursus disponibles
- niveau dans le cursus sélectionné
- compétences
- projets
- notes
- statut des projets
- photo de profil

L’interface est construite avec **SwiftUI** et utilise une navigation simple entre une page de recherche et une page de profil.

---

## Fonctionnalités

### Recherche d’un utilisateur 42

Depuis l’écran principal, l’utilisateur peut saisir un login 42 dans un champ de recherche.

Si le login existe, l’application récupère les données depuis l’API :

`https://api.intra.42.fr/v2/users/{login}`

Si le login est invalide ou introuvable, un message d’erreur est affiché.

---

### Authentification OAuth 42

L’application utilise le flow OAuth de l’API 42.

Lors de la première requête, si aucun token valide n’est disponible, une session d’authentification web est ouverte avec `ASWebAuthenticationSession`.

L’utilisateur se connecte à son compte 42, puis l’application récupère un `authorization code`, qui est ensuite échangé contre un `access_token`.

---

### Stockage du token dans le Keychain

Le token d’accès, sa date d’expiration et le refresh token sont stockés dans le **Keychain iOS** grâce à un acteur dédié : `KeychainStore`.

Les valeurs stockées sont :

- `intra_access_token`
- `intra_token_expiry_date`
- `intra_refresh_token`

Cela permet de ne pas redemander une authentification à chaque requête tant que le token est encore valide.

---

### Refresh automatique du token

Le token est réutilisé tant qu’il est valide.

L’application vérifie sa date d’expiration et tente de le rafraîchir automatiquement 5 minutes avant son expiration.

Si un refresh token est disponible, l’application l’utilise pour demander un nouveau token d’accès.

Si le refresh échoue, le token est supprimé et une nouvelle authentification OAuth est lancée.

---

### Affichage du profil

La vue `ProfileView` affiche les informations de l’utilisateur dans une interface organisée en plusieurs sections :

- header avec photo de profil
- informations générales
- sélection du cursus
- niveau du cursus sélectionné
- compétences
- projets

L’utilisateur peut changer de cursus si plusieurs cursus sont disponibles.

---

### Affichage des compétences

Les compétences sont affichées avec :

- le nom de la compétence
- le niveau
- une barre de progression

Le niveau est calculé sur une base maximale de `21`, qui correspond au niveau maximum habituellement utilisé dans l’Intra 42.

---

### Affichage des projets

Les projets sont affichés sous forme de cartes.

Chaque carte affiche :

- le nom du projet
- le statut
- la note
- un badge visuel
- une barre de progression

Les projets sont classés selon leur note, du plus haut score au plus bas.

Les différents états possibles sont gérés dans une enum interne :

- `validated`
- `failed`
- `waitingCorrection`
- `inEvaluation`
- `groupClosed`
- `inProgress`
- `unknown`

Cela permet d’avoir une interface plus lisible et de mieux représenter l’état réel des projets.

---

## Technologies utilisées

- Swift
- SwiftUI
- Foundation
- Security
- AuthenticationServices
- UIKit
- URLSession
- Keychain iOS
- OAuth 2.0
- API 42

---

## Architecture du projet

Le projet est organisé autour de plusieurs fichiers ayant chacun une responsabilité claire.

```text
SwiftyCompanion/
│
├── SwiftyCompanionApp.swift
├── Info.plist
│
├── Base.lproj
│   └── LaunchScreen.storyboard
│
├── Services/
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── TokenManager.swift
│   │   ├── OAuthLoginManager.swift
│   │
│   └── Storage/
│       └── KeychainStore.swift
│
├── Models/
│   └── Models.swift
│
├── Helpers/
│   ├── Theme.swift
│   ├── Secrets.swift
│   └── String+Encoding.swift 
│
├── Features/
│   ├──Profile/
│   │   └── Views/
│   │       └── ProfileView.swift
│   └── Search/
│       └── Views/
│           └── SearchView.swift
│
└── Assets/
    ├── Colors
    └── Images
```
L’organisation peut varier selon la structure exacte du projet Xcode, mais cette séparation représente la logique utilisée dans le code.

---

## Détail des fichiers

### `SwiftyCompanionApp.swift`

Point d’entrée de l’application.

```text
@main
struct SwiftyCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            SearchView()
        }
    }
}
```
L’application démarre directement sur `SearchView`.

---

### `Info.plist`

Le fichier `Info.plist` contient notamment les clés nécessaires à la configuration OAuth.

```
<key>INTRA_CLIENT_ID</key>
<string>$(INTRA_CLIENT_ID)</string>

<key>INTRA_CLIENT_SECRET</key>
<string>$(INTRA_CLIENT_SECRET)</string>

<key>INTRA_REDIRECT_URI</key>
<string>$(INTRA_REDIRECT_URI)</string>
```

Les valeurs réelles sont injectées via la configuration Xcode, par exemple avec un fichier `Secrets.xcconfig`.

---

### `KeychainStore.swift`

Ce fichier contient un `actor` responsable de l’accès au Keychain iOS.

Il fournit trois actions principales :
- `set(_:for:)`
- `get(for:)`
- `delete(for:)`

Le Keychain est utilisé pour stocker localement les tokens OAuth.

---

### `TokenManager.swift`

Ce fichier gère toute la logique liée au token OAuth.

Il est responsable de :
- charger le token depuis le Keychain
- vérifier sa date d’expiration
- rafraîchir le token si possible
- lancer une nouvelle authentification si nécessaire
- sauvegarder le token
- invalider le token en cas d’erreur

La fonction principale est `getValidToken()`.

C’est cette fonction qui est utilisée par le client API avant chaque requête.

---

### `OAuthLoginManager.swift`

Ce fichier gère le login OAuth avec l’API 42.

Il utilise `ASWebAuthenticationSession` pour ouvrir une session d’authentification sécurisée.

La méthode principale est `startLogin()`.

Elle retourne le `code` OAuth qui sera ensuite échangé contre un token.

---

### `APIClient.swift`

Ce fichier contient le client réseau principal de l’application.

Il permet de récupérer les données d’un utilisateur 42 avec `fetchUser(login:)`.

Il ajoute automatiquement le token OAuth dans le header HTTP :

`Authorization: Bearer <token>`

Il gère aussi certains cas d’erreur :
- `401` : token invalide, tentative de retry après invalidation
- `404` : utilisateur introuvable
- autre code HTTP : erreur API
- erreur de décodage JSON

---

### `Models.swift`

Ce fichier contient les modèles utilisés pour décoder les réponses JSON de l’API 42.

Les principaux modèles sont :

- `TokenResponse`
- `IntraUser`
- `UserImage`
- `ImageVersions`
- `CursusUser`
- `CursusInfo`
- `Skill`
- `ProjectUser`
- `Project`

Ces structures sont conformes à `Decodable`, ce qui permet de convertir directement les réponses JSON en objets Swift.

---

### `Theme.swift`

Ce fichier centralise les couleurs utilisées dans l’application.

```text
enum Theme {
    static let primary = Color("ThemePrimary")
    static let secondary = Color("ThemeSecondary")
    static let background = Color("ThemeBackground")
    static let card = Color("ThemeCard")
    static let textSecondary = Color("ThemeTextSecondary")
    static let success = Color("ThemeSuccess")
    static let danger  = Color("ThemeDanger")
    static let warning = Color("ThemeWarning")
}
```

Les couleurs sont définies dans les assets Xcode.

Cela permet de garder une interface cohérente et de modifier facilement le thème global de l’application.

---

### `String+Encoding.swift`

Ce fichier ajoute deux extensions utiles sur `String` :

- `urlEncoded`
- `urlPathEncoded`

Elles permettent d’encoder correctement les valeurs utilisées dans les URLs ou dans les bodies de requêtes HTTP.

---

### `Secrets.swift`

Ce fichier lit les valeurs OAuth depuis le `Info.plist`.

Il expose les valeurs suivantes :

- `clientId`
- `clientSecret`
- `redirectUri`
- `callbackScheme`

Cela permet d’éviter d’écrire directement les secrets dans le code Swift.

---

### `SearchView.swift`

Vue principale de l’application.

Elle contient :

- le titre de l’application
- un champ de recherche
- un bouton de recherche
- un état de chargement
- l’affichage des erreurs
- la navigation vers `ProfileView`

La recherche est effectuée via `APIClient.shared.fetchUser(login:)`.

---

### `ProfileView.swift`

Vue de détail d’un utilisateur 42.

Elle affiche :

- la photo de profil
- le login
- l’email
- le wallet
- les correction points
- les cursus
- le niveau
- les compétences
- les projets

La vue contient aussi plusieurs fonctions privées pour garder le code plus lisible :

- `header`
- `cursusSelector`
- `infoRow(_:_: )`
- `projectState(for:)`
- `projectTheme(for:)`
- `projectBadge(_:tint:)`
- `projectCard(_:)`

---

## Gestion de l’authentification

L’authentification suit ce fonctionnement :

1. L’utilisateur recherche un login.
2. `APIClient` demande un token valide à `TokenManager`.
3. `TokenManager` vérifie si un token existe dans le Keychain.
4. Si le token est encore valide, il est réutilisé.
5. Si le token est expiré ou absent :
  - l’application tente d’utiliser le refresh token ;
  - si ce n’est pas possible, elle lance le flow OAuth.
6. L’utilisateur se connecte via l’Intra 42.
7. L’application reçoit un code OAuth.
8. Ce code est échangé contre un access token.
9. Le token est sauvegardé dans le Keychain.
10. La requête vers l’API 42 est effectuée.

---

## Gestion des secrets

Les secrets OAuth sont référencés dans `Info.plist` comme ceci :

```text
<key>INTRA_CLIENT_ID</key>
<string>$(INTRA_CLIENT_ID)</string>

<key>INTRA_CLIENT_SECRET</key>
<string>$(INTRA_CLIENT_SECRET)</string>

<key>INTRA_REDIRECT_URI</key>
<string>$(INTRA_REDIRECT_URI)</string>
```

Ces valeurs peuvent être définies dans un fichier local de configuration Xcode, par exemple `Secrets.xcconfig`.

Exemple :

```text
INTRA_CLIENT_ID = your_client_id
INTRA_CLIENT_SECRET = your_client_secret
INTRA_REDIRECT_URI = swifty-companion://callback
```

Il est important de ne pas versionner ce fichier si de vrais secrets sont utilisés.

Ajouter dans `.gitignore` :

```text
Secrets.xcconfig
```

---

## Avertissement important sur la sécurité

Dans ce projet, les secrets OAuth comme le `client_id` et le `client_secret` sont utilisés directement côté application iOS.

Même si le token est stocké dans le **Keychain**, il faut bien comprendre qu’une application mobile ne peut jamais protéger totalement un secret embarqué dans le binaire.

Le Keychain est adapté pour stocker des données sensibles côté utilisateur, comme :

- access token
- refresh token
- date d’expiration

Cependant, il ne rend pas un `client_secret` réellement secret si celui-ci est inclus dans l’application.

**Pourquoi cette approche a été utilisée ?**

Ce projet a été réalisé dans un contexte scolaire.

Le sujet demandait une application iOS capable d’utiliser l’API 42, mais ne demandait pas de développer un backend dédié.

Dans une application destinée à la production, il serait préférable d’utiliser un backend pour :

- stocker le `client_secret` côté serveur
- gérer l’échange OAuth côté backend
- éviter d’exposer les secrets dans l’application mobile
- contrôler plus finement les tokens
- améliorer la sécurité globale

Dans le cadre de ce projet école, et afin de respecter le temps disponible ainsi que le périmètre demandé, les secrets sont donc utilisés côté application.

Cette solution est acceptable pour un projet pédagogique, mais ne doit pas être considérée comme une architecture de production.

---

## Installation

### Prérequis

- macOS
- Xcode
- un compte développeur Apple ou un simulateur iOS
- une application OAuth créée sur l’Intra 42
- Swift compatible avec le projet
- iOS target compatible avec SwiftUI et `ASWebAuthenticationSession`

---

### Étapes
1. Cloner le projet :
```text
git clone <url-du-repository>
cd SwiftyCompanion
```

2. Ouvrir le projet dans Xcode :
```text
open SwiftyCompanion.xcodeproj
```
ou, si le projet utilise un workspace :
```text
open SwiftyCompanion.xcworkspace
```

3. Créer un fichier local `Secrets.xcconfig`.
4. Ajouter les valeurs OAuth :
```text
INTRA_CLIENT_ID = your_client_id
INTRA_CLIENT_SECRET = your_client_secret
INTRA_REDIRECT_URI = swifty-companion://callback
```
5. Vérifier que `Info.plist` lit bien ces valeurs.
6. Configurer le scheme d’URL dans Xcode si nécessaire.
7. Lancer l’application sur simulateur ou appareil physique.

---

## Configuration OAuth 42

Pour que l’authentification fonctionne, il faut créer une application sur l’Intra 42.

La configuration doit contenir une URI de redirection correspondant à celle utilisée dans le projet.

Exemple :
```text
swifty-companion://callback
```

Dans le code, le scheme est automatiquement extrait depuis la redirect URI avec `URLComponents`.

Ce scheme est ensuite utilisé par `ASWebAuthenticationSession` pour intercepter le retour OAuth.

---

## Aperçu de l’application

### Écran de recherche

<img src="docs/images/search-screen.png" width="300" alt="Search screen">

Cet écran permet de saisir un login 42 et de lancer la recherche.

---

### Écran de profil

<img src="docs/images/profile-header.png" width="300" alt="Profile screen">

Cet écran affiche les informations principales de l’utilisateur récupéré depuis l’API 42.

---

### Onglet de l'application

<img src="docs/images/app-icon.png" width="180" alt="App icon">

L’application possède une icône personnalisée, créée spécialement pour le projet.  
Cette icône permet d’identifier rapidement Swifty Companion sur l’écran d’accueil iOS et donne une apparence plus propre et plus professionnelle à l’application.

---

### Compétences

<img src="docs/images/skills-section.png" width="300" alt="Skills section">

Chaque compétence est affichée avec son niveau et une barre de progression.

---

### Projets

<img src="docs/images/projects-section.png" width="300" alt="Projects section">
<img src="docs/images/projects-section2.png" width="300" alt="Projects section">
<img src="docs/images/projects-section3.png" width="300" alt="Projects section">

Les projets sont affichés sous forme de cartes avec leur statut et leur note.

---

## Détails techniques

### Utilisation des actors

Le projet utilise des `actor` Swift pour sécuriser certaines opérations asynchrones.

Exemples :

- KeychainStore
- TokenManager

Cela permet de protéger l’accès à des ressources partagées comme le Keychain ou les tokens.

---

### Gestion des erreurs

Les erreurs API sont centralisées dans l’enum `APIError.

Les cas gérés sont :

- `misconfiguredSecrets`
- `network`
- `http(code:)`
- `notFound`
- `decoding`

Chaque erreur fournit un message lisible via `errorDescription`.

Cela permet d’afficher facilement les erreurs dans l’interface utilisateur.

---

### Décodage JSON

Les réponses de l’API 42 sont décodées avec `JSONDecoder`.

Les modèles Swift correspondent aux champs retournés par l’API.

Certains champs peuvent être absents ou nuls, ils sont donc déclarés comme optionnels :

- `email`
- `phone`
- `location`
- `wallet`
- `correction_point`

Lorsqu’une information n’est pas disponible, l’application affiche `N/A`.

---

### Gestion du champ `validated`?

L’API 42 retourne un champ nommé `validated`?.

Comme ce nom n’est pas directement utilisable comme propriété Swift classique, il est mappé avec `CodingKeys` dans `ProjectUser`.

```text
enum CodingKeys: String, CodingKey {
    case id
    case final_mark
    case status
    case validated = "validated?"
    case cursus_ids
    case project
}
```

---

### Interface SwiftUI

L’interface repose principalement sur :

- `NavigationStack`
- `navigationDestination`
- `ScrollView`
- `VStack`
- `HStack`
- `GroupBox`
- `ProgressView`
- `AsyncImage`
- `LinearGradient`

Cela permet d’avoir une application simple, moderne et adaptée aux différentes tailles d’écran.

---

### Thème visuel

Les couleurs sont centralisées dans `Theme.swift` et définies dans les assets Xcode.

Cela permet de garder une cohérence visuelle entre les écrans :

- `Theme.primary`
- `Theme.background`
- `Theme.card`
- `Theme.success`
- `Theme.danger`
- `Theme.warning`

---

## Exemple de workflow utilisateur
1. L’utilisateur ouvre l’application.
2. Il arrive sur l’écran de recherche.
3. Il entre un login 42.
4. Il appuie sur `Search`.
5. Si aucun token valide n’est disponible, une page OAuth 42 s’ouvre.
6. L’utilisateur se connecte.
7. L’application récupère un token.
8. Le profil est demandé à l’API 42.
9. L’utilisateur est redirigé vers la page de profil.
10. Il peut consulter les infos, les skills, les cursus et les projets.

---

## Points importants du projet

Ce projet met en pratique plusieurs notions importantes du développement iOS moderne :

- utilisation de SwiftUI
- navigation entre vues
- appels réseau asynchrones
- authentification OAuth
- stockage sécurisé avec Keychain
- gestion d’état avec `@State`
- décodage JSON avec `Decodable`
- architecture simple et séparée
- gestion des erreurs utilisateur
- interface responsive pour iPhone et iPad

---

## Améliorations possibles

Plusieurs améliorations pourraient être ajoutées par la suite :

- ajout d’un écran de settings
- bouton de déconnexion
- suppression manuelle du token
- affichage du téléphone et de la localisation
- meilleure gestion des erreurs OAuth
- ajout d’un cache des profils consultés
- mode sombre plus complet
- tests unitaires sur le TokenManager
- tests réseau avec mock API
- ajout d’un backend pour sécuriser totalement le flow OAuth
- amélioration de l’affichage des projets par cursus
- recherche récente ou historique des profils consultés

---

## Limitations

L’application dépend directement de l’API 42.

Elle peut donc être affectée par :

- une indisponibilité de l’API
- un changement de format de réponse
- un token expiré
- une mauvaise configuration OAuth
- un login inexistant
- des champs absents dans le profil utilisateur

Certaines données sont optionnelles dans l’API, donc l’application affiche `N/A` lorsqu’une information n’est pas disponible.

---

## Auteur

Projet réalisé par :

**[Nicolas Hirzel](https://github.com/Np93)**

Dans le cadre du cursus 42.

---

## [Licence](https://github.com/Np93/Swifty_Companion/blob/main/LICENSE)

Ce projet est réalisé dans un cadre scolaire.

Il n’est pas destiné à être utilisé tel quel en production, notamment à cause de la gestion des secrets OAuth directement côté application mobile.