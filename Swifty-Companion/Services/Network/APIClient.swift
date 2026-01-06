import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    func fetchUser(login: String) async throws -> IntraUser {
        try await fetchUserInternal(login: login, didRetry: false)
    }

    private func fetchUserInternal(login: String, didRetry: Bool) async throws -> IntraUser {
        let token = try await TokenManager.shared.getValidToken()

        let url = URL(string: "https://api.intra.42.fr/v2/users/\(login.urlPathEncoded)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.network }

        if http.statusCode == 401, didRetry == false {
//            print("[APIClient] 401 Unauthorized -> refresh token and retry once")
            await TokenManager.shared.invalidateToken()
            return try await fetchUserInternal(login: login, didRetry: true)
        }

        if http.statusCode == 404 {
            throw APIError.notFound
        }

        guard (200...299).contains(http.statusCode) else {
            throw APIError.http(code: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(IntraUser.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
