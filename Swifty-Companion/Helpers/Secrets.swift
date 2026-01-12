import Foundation

enum Secrets {
    nonisolated static var clientId: String {
        (Bundle.main.object(forInfoDictionaryKey: "INTRA_CLIENT_ID") as? String) ?? ""
    }

    nonisolated static var clientSecret: String {
        (Bundle.main.object(forInfoDictionaryKey: "INTRA_CLIENT_SECRET") as? String) ?? ""
    }

    nonisolated static var redirectUri: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "INTRA_REDIRECT_URI") as? String) ?? ""
        return raw.replacingOccurrences(of: "\\/", with: "/")
    }

    nonisolated static var callbackScheme: String {
        URLComponents(string: redirectUri)?.scheme ?? "swifty-companion"
    }
}