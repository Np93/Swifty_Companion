import Foundation

/// Outil de test uniquement : ne fait pas partie de la logique normale d'authentification.
/// Permet d'effacer le token enregistré pour pouvoir refaire une connexion depuis zéro.
@MainActor
enum TokenDebugService {

    /// Armé par `deleteSavedToken()`, lu une seule fois par `consumeFreshLoginRequest()`.
    private static var forceFreshLogin = false

    /// Supprime du Keychain le token d'accès, sa date d'expiration et le refresh token,
    /// puis demande que la prochaine connexion OAuth utilise une session web éphémère.
    /// On réutilise `TokenManager.invalidateToken()` (aucun nouveau stockage, aucune clé recopiée).
    /// Le refresh token doit aussi être supprimé, sinon la prochaine requête
    /// obtiendrait un nouveau token sans repasser par la connexion.
    /// Sans effet (et sans erreur) si aucun token n'est enregistré.
    static func deleteSavedToken() async {
        await TokenManager.shared.invalidateToken()
        forceFreshLogin = true
    }

    /// Appelée par `OAuthLoginManager` au moment de créer la session web.
    /// Renvoie `true` une seule fois après une suppression debug (session éphémère :
    /// les cookies de Safari ne sont pas réutilisés), puis `false` (comportement normal).
    static func consumeFreshLoginRequest() -> Bool {
        defer { forceFreshLogin = false }
        return forceFreshLogin
    }
}
