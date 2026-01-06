import Foundation

enum Secrets {
    nonisolated static var clientId: String {
        (Bundle.main.object(forInfoDictionaryKey: "INTRA_CLIENT_ID") as? String) ?? ""
    }

    nonisolated static var clientSecret: String {
        (Bundle.main.object(forInfoDictionaryKey: "INTRA_CLIENT_SECRET") as? String) ?? ""
    }
}