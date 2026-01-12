import Foundation
import AuthenticationServices
import UIKit

@MainActor
final class OAuthLoginManager: NSObject {
    static let shared = OAuthLoginManager()

    private var session: ASWebAuthenticationSession?

    func startLogin() async throws -> String {
        guard !Secrets.redirectUri.isEmpty else { throw APIError.misconfiguredSecrets }
        let clientId = Secrets.clientId
        guard !clientId.isEmpty else { throw APIError.misconfiguredSecrets }

        let state = UUID().uuidString
        let redirectUri = Secrets.redirectUri

        var comps = URLComponents(string: "https://api.intra.42.fr/oauth/authorize")!
        comps.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "public"),
            .init(name: "state", value: state)
        ]

        let authURL = comps.url!

        return try await withCheckedThrowingContinuation { cont in
            session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: Secrets.callbackScheme
            ) { callbackURL, error in
                if let error = error { cont.resume(throwing: error); return }
                guard let callbackURL else { cont.resume(throwing: APIError.network); return }

                guard
                    let cb = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                    let code = cb.queryItems?.first(where: { $0.name == "code" })?.value,
                    let returnedState = cb.queryItems?.first(where: { $0.name == "state" })?.value,
                    returnedState == state
                else {
                    cont.resume(throwing: APIError.decoding)
                    return
                }
                cont.resume(returning: code)
            }

            session?.presentationContextProvider = self
            session?.prefersEphemeralWebBrowserSession = false
            session?.start()
        }
    }
}

extension OAuthLoginManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            return UIWindow(windowScene: windowScene)
        }

        fatalError("No UIWindowScene available to present ASWebAuthenticationSession.")
    }
}
