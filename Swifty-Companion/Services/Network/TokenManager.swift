import Foundation

actor TokenManager {
    nonisolated static let shared = TokenManager()

    private let tokenKey = "intra_access_token"
    private let expiryKey = "intra_token_expiry_date"
    private let refreshKey = "intra_refresh_token"

    private init() {}

    func getValidToken() async throws -> String {
        if let token = await loadToken(),
           let expiry = await loadExpiryDate() {

            // refresh 5 minutes avant expiration
            let refreshThreshold = expiry.addingTimeInterval(-5 * 60)
            // LOG 1 : token trouvé + quand il expire
//            print("[TokenManager] cached token found. expiry=\(expiry) refreshAt=\(refreshThreshold) now=\(Date())")
//            print(token)
            if Date() < refreshThreshold {
                // LOG 2 : on réutilise le token, donc PAS un token par requête
//                print("[TokenManager] using cached token")
                return token
            }
//            else {
                // LOG 3 : on va refresh car proche expiration
//                print("[TokenManager] token near expiry -> refreshing")}
        } //else {
            // LOG 4 : aucun token stocké
//            print("[TokenManager] no cached token -> fetching new token")
//        }
        if let refreshed = try await refreshAccessTokenIfPossible() {
            return refreshed
        }
        return try await fetchAndStoreToken()
    }

    private func fetchAndStoreToken() async throws -> String {
        let clientId = Secrets.clientId
        let clientSecret = Secrets.clientSecret

        guard !clientId.isEmpty, !clientSecret.isEmpty else { throw APIError.misconfiguredSecrets }

        let redirectUri = Secrets.redirectUri
        let code = try await OAuthLoginManager.shared.startLogin()

        var request = URLRequest(url: URL(string: "https://api.intra.42.fr/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body =
            "grant_type=authorization_code" +
            "&client_id=\(clientId.urlEncoded)" +
            "&client_secret=\(clientSecret.urlEncoded)" +
            "&code=\(code.urlEncoded)" +
            "&redirect_uri=\(redirectUri.urlEncoded)"

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.network }
        guard (200...299).contains(http.statusCode) else { throw APIError.http(code: http.statusCode) }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiryDate = Date().addingTimeInterval(TimeInterval(decoded.expires_in))

        await saveToken(decoded.access_token)
        await saveExpiryDate(expiryDate)

        if let rt = decoded.refresh_token {
            await saveRefreshToken(rt)
        }

        return decoded.access_token
    }

    private func saveToken(_ token: String) async {
        _ = await KeychainStore.shared.set(Data(token.utf8), for: tokenKey)
    }

    private func saveExpiryDate(_ date: Date) async {
        let timeInterval = date.timeIntervalSince1970
        let data = withUnsafeBytes(of: timeInterval) { Data($0) }
        _ = await KeychainStore.shared.set(data, for: expiryKey)
    }

    private func loadToken() async -> String? {
        guard let data = await KeychainStore.shared.get(for: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func loadExpiryDate() async -> Date? {
        guard let data = await KeychainStore.shared.get(for: expiryKey),
              data.count == MemoryLayout<Double>.size else { return nil }
        let value = data.withUnsafeBytes { $0.load(as: Double.self) }
        return Date(timeIntervalSince1970: value)
    }
    
    func invalidateToken() async {
        await KeychainStore.shared.delete(for: tokenKey)
        await KeychainStore.shared.delete(for: expiryKey)
        await KeychainStore.shared.delete(for: refreshKey)
    }

    private func saveRefreshToken(_ token: String) async {
        _ = await KeychainStore.shared.set(Data(token.utf8), for: refreshKey)
    }

    private func loadRefreshToken() async -> String? {
        guard let data = await KeychainStore.shared.get(for: refreshKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteRefreshToken() async {
        await KeychainStore.shared.delete(for: refreshKey)
    }

    private func refreshAccessTokenIfPossible() async throws -> String? {
        guard let refreshToken = await loadRefreshToken() else { return nil }

        let clientId = Secrets.clientId
        let clientSecret = Secrets.clientSecret
        guard !clientId.isEmpty, !clientSecret.isEmpty else {
            throw APIError.misconfiguredSecrets
        }

        var request = URLRequest(url: URL(string: "https://api.intra.42.fr/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body =
            "grant_type=refresh_token" +
            "&client_id=\(clientId.urlEncoded)" +
            "&client_secret=\(clientSecret.urlEncoded)" +
            "&refresh_token=\(refreshToken.urlEncoded)"

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.network }

        // si refresh token invalid => on le supprime
        if http.statusCode == 400 || http.statusCode == 401 {
            await deleteRefreshToken()
            return nil
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.http(code: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiryDate = Date().addingTimeInterval(TimeInterval(decoded.expires_in))

        await saveToken(decoded.access_token)
        await saveExpiryDate(expiryDate)

        if let newRefresh = decoded.refresh_token {
            await saveRefreshToken(newRefresh)
        }

        return decoded.access_token
    }
}

enum APIError: LocalizedError {
    case misconfiguredSecrets
    case network
    case http(code: Int)
    case notFound
    case decoding

    var errorDescription: String? {
        switch self {
        case .misconfiguredSecrets:
            return "Missing INTRA_CLIENT_ID / INTRA_CLIENT_SECRET (Secrets.xcconfig)."
        case .network:
            return "Network error. Please check your connection."
        case .http(let code):
            return "HTTP error: \(code)"
        case .notFound:
            return "Login not found."
        case .decoding:
            return "Unexpected API response."
        }
    }
}
