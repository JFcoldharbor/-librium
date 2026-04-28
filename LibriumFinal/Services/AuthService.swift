import Combine
import FirebaseAuth
import FirebaseCore
import Foundation

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailInUse
    case weakPassword
    case invalidEmail
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Email or password is incorrect."
        case .emailInUse: return "An account already exists with that email."
        case .weakPassword: return "Password must be at least 6 characters."
        case .invalidEmail: return "That email address looks invalid."
        case .networkError: return "Network error. Check your connection."
        case .unknown(let message): return message
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: FirebaseAuth.User?
    @Published private(set) var isAuthenticating: Bool = false
    @Published private(set) var lastError: Error?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        guard FirebaseApp.app() != nil else { return }
        currentUser = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signUp(email: String, password: String) async throws -> FirebaseAuth.User {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return result.user
        } catch {
            let mapped = mapAuthError(error)
            lastError = mapped
            throw mapped
        }
    }

    func signIn(email: String, password: String) async throws -> FirebaseAuth.User {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return result.user
        } catch {
            let mapped = mapAuthError(error)
            lastError = mapped
            throw mapped
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signIn(with credential: AuthCredential) async throws -> FirebaseAuth.User {
        isAuthenticating = true
        lastError = nil
        defer { isAuthenticating = false }

        do {
            let result = try await Auth.auth().signIn(with: credential)
            return result.user
        } catch {
            let mapped = mapAuthError(error)
            lastError = mapped
            throw mapped
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    private func mapAuthError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }
        switch code {
        case .userNotFound, .wrongPassword, .invalidCredential, .userDisabled:
            return AuthError.invalidCredentials
        case .emailAlreadyInUse:
            return AuthError.emailInUse
        case .weakPassword:
            return AuthError.weakPassword
        case .invalidEmail:
            return AuthError.invalidEmail
        case .networkError:
            return AuthError.networkError
        default:
            return error
        }
    }
}
