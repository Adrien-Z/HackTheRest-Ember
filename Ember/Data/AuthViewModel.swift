import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published private(set) var displayName = ""
    @Published private(set) var email = ""
    @Published var errorMessage: String?

    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task { [weak self] in
            for await (_, session) in SupabaseManager.client.auth.authStateChanges {
                guard let self else { break }
                isAuthenticated = session != nil
                displayName = Self.displayName(from: session)
                email = session?.user.email ?? ""
                isLoading = false
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func signUp(email: String, password: String, displayName: String) async {
        guard validate(email: email, password: password, displayName: displayName) else { return }

        await performAuthentication {
            try await SupabaseManager.client.auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: ["display_name": .string(displayName.trimmingCharacters(in: .whitespacesAndNewlines))]
            )
        }
    }

    func signIn(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }

        await performAuthentication {
            try await SupabaseManager.client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    func signOut() async {
        await performAuthentication {
            try await SupabaseManager.client.auth.signOut()
        }
    }

    private func performAuthentication(_ action: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil

        do {
            try await action()
        } catch {
            errorMessage = readableMessage(for: error)
        }

        isLoading = false
    }

    private func validate(email: String, password: String, displayName: String? = nil) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty || !trimmedEmail.contains("@") {
            errorMessage = "Enter a valid email address."
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        if let displayName, displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Enter your display name."
            return false
        }
        return true
    }

    private func readableMessage(for error: Error) -> String {
        let description = error.localizedDescription
        let lowercased = description.lowercased()

        if lowercased.contains("invalid login credentials") {
            return "Your email or password is incorrect."
        }
        if lowercased.contains("user already registered") {
            return "An account already exists for this email. Please sign in."
        }
        if lowercased.contains("email not confirmed") {
            return "Verify your email before signing in."
        }
        if lowercased.contains("network") || lowercased.contains("internet") {
            return "There appears to be a network problem. Please try again."
        }
        return description.isEmpty ? "Authentication failed. Please try again." : description
    }

    private static func displayName(from session: Session?) -> String {
        guard let user = session?.user else { return "" }
        if let name = user.userMetadata["display_name"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return user.email?.split(separator: "@").first.map(String.init) ?? "You"
    }
}
