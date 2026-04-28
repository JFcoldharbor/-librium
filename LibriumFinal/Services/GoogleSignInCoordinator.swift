import FirebaseAuth
import Foundation
import GoogleSignIn
import UIKit

enum GoogleSignInError: Error, LocalizedError {
    case missingPresentingVC
    case missingIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingPresentingVC: return "Could not find a window to present sign-in."
        case .missingIDToken: return "Google did not return an ID token."
        case .cancelled: return "Sign-in cancelled."
        }
    }
}

@MainActor
final class GoogleSignInCoordinator {
    static let shared = GoogleSignInCoordinator()

    static var isConfigured: Bool {
        GIDSignIn.sharedInstance.configuration != nil
    }

    private init() {}

    func signIn() async throws -> AuthCredential {
        guard let presentingVC = topViewController() else {
            throw GoogleSignInError.missingPresentingVC
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        } catch let error as NSError where error.code == GIDSignInError.canceled.rawValue {
            throw GoogleSignInError.cancelled
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInError.missingIDToken
        }
        let accessToken = result.user.accessToken.tokenString

        return GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
