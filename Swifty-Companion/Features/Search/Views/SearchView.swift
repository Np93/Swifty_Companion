import SwiftUI

struct SearchView: View {
    @State private var login: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var user: IntraUser?
    @State private var debugMessage: String?
    @State private var debugMessageTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Swifty Companion")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(Theme.primary)

                TextField("Enter a 42 login (e.g. jdoe)", text: $login)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.primary.opacity(0.25), lineWidth: 1)
                    )

                Button {
                    Task { await search() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Text("Search").bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .disabled(isLoading)
                .tint(Theme.primary)
                .buttonStyle(.borderedProminent)

                if let msg = errorMessage {
                    Text(msg)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // DEBUG : bouton de test, voir TokenDebugService.swift
                Button("Delete saved token (debug)") {
                    // Annule le timer précédent pour que les 5 secondes repartent de zéro
                    debugMessageTask?.cancel()
                    debugMessageTask = Task {
                        await TokenDebugService.deleteSavedToken()
                        debugMessage = "Token deleted."
                        try? await Task.sleep(for: .seconds(5))
                        if !Task.isCancelled { debugMessage = nil }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let debugMessage {
                    Text(debugMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationDestination(item: $user) { u in
                ProfileView(user: u)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Theme.primary.opacity(0.18),
                        Theme.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }

    private func search() async {
        errorMessage = nil
        let trimmed: String = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a login."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched: IntraUser = try await APIClient.shared.fetchUser(login: trimmed)
            user = fetched
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unknown error."
        }
    }
}
