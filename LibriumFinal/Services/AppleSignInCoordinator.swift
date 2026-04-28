import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation

enum AppleSignInError: Error, LocalizedError {
    case invalidCredential
    case missingNonce
    case missingIdentityToken
    case nonceGenerationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Apple did not return a valid credential."
        case .missingNonce: return "Sign-in nonce was not generated."
        case .missingIdentityToken: return "Apple did not return an identity token."
        case .nonceGenerationFailed(let status): return "Could not generate secure nonce (\(status))."
        }
    }
}

@MainActor
final class AppleSignInCoordinator: ObservableObject {
    private var currentNonce: String?

    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try Self.randomNonceString()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)
        } catch {
            currentNonce = nil
        }
    }

    func makeFirebaseCredential(from result: Result<ASAuthorization, Error>) throws -> (credential: AuthCredential, fullName: PersonNameComponents?, email: String?) {
        let authorization = try result.get()

        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.invalidCredential
        }
        guard let nonce = currentNonce else {
            throw AppleSignInError.missingNonce
        }
        guard let idTokenData = appleCredential.identityToken,
              let idTokenString = String(data: idTokenData, encoding: .utf8) else {
            throw AppleSignInError.missingIdentityToken
        }

        currentNonce = nil

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        return (credential, appleCredential.fullName, appleCredential.email)
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else {
                throw AppleSignInError.nonceGenerationFailed(status)
            }

            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
