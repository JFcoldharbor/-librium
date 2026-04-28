import GoogleSignInSwift
import SwiftUI

struct SignInView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var mode: AuthMode = .signIn
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isWorking = false

    enum AuthMode {
        case signIn, signUp

        var primaryLabel: String {
            switch self {
            case .signIn: return "Sign In"
            case .signUp: return "Sign Up"
            }
        }

        var toggleLabel: String {
            switch self {
            case .signIn: return "Don't have an account? Sign up"
            case .signUp: return "Already have an account? Sign in"
            }
        }
    }

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 80)

                    Text("EQUILIBRIUM")
                        .font(.system(size: 36, weight: .bold))
                        .tracking(2)
                        .foregroundColor(EquilibriumColor.primaryText)

                    Text("Where work and life meet.")
                        .font(.system(size: 14))
                        .foregroundColor(EquilibriumColor.secondaryText)

                    Spacer().frame(height: 24)

                    emailField
                    passwordField

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    if let infoMessage {
                        Text(infoMessage)
                            .font(.system(size: 13))
                            .foregroundColor(EquilibriumColor.accent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    primaryButton

                    if mode == .signIn {
                        Button(action: sendPasswordReset) {
                            Text("Forgot password?")
                                .font(.system(size: 13))
                                .foregroundColor(EquilibriumColor.secondaryText)
                        }
                        .disabled(isWorking)
                    }

                    if GoogleSignInCoordinator.isConfigured {
                        divider

                        GoogleSignInButton(action: signInWithGoogle)
                            .frame(height: 50)
                            .frame(maxWidth: 280)
                            .disabled(isWorking)
                    }

                    Spacer().frame(height: 16)

                    Button(action: toggleMode) {
                        Text(mode.toggleLabel)
                            .font(.system(size: 14))
                            .foregroundColor(EquilibriumColor.primaryText)
                    }
                    .disabled(isWorking)

                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private var backgroundGradient: some View {
        RadialGradient(
            colors: [
                EquilibriumColor.accent.opacity(0.35),
                EquilibriumColor.accent.opacity(0.1),
                EquilibriumColor.background
            ],
            center: .center,
            startRadius: 80,
            endRadius: 600
        )
        .ignoresSafeArea()
    }

    private var emailField: some View {
        TextField("", text: $email, prompt: Text("Email").foregroundColor(EquilibriumColor.tertiaryText))
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 16)
            .frame(height: 50)
            .frame(maxWidth: 280)
            .background(EquilibriumColor.primaryText.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .foregroundColor(EquilibriumColor.primaryText)
    }

    private var passwordField: some View {
        SecureField("", text: $password, prompt: Text("Password").foregroundColor(EquilibriumColor.tertiaryText))
            .textContentType(mode == .signUp ? .newPassword : .password)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .frame(maxWidth: 280)
            .background(EquilibriumColor.primaryText.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .foregroundColor(EquilibriumColor.primaryText)
    }

    private var primaryButton: some View {
        Button(action: submitEmailForm) {
            HStack {
                if isWorking {
                    ProgressView().tint(.black)
                } else {
                    Text(mode.primaryLabel)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: 280)
            .frame(height: 50)
            .background(EquilibriumColor.primaryText, in: RoundedRectangle(cornerRadius: 10))
            .foregroundColor(.black)
        }
        .disabled(isWorking)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(EquilibriumColor.primaryText.opacity(0.15)).frame(height: 1)
            Text("or").font(.system(size: 12)).foregroundColor(EquilibriumColor.tertiaryText)
            Rectangle().fill(EquilibriumColor.primaryText.opacity(0.15)).frame(height: 1)
        }
        .frame(maxWidth: 280)
        .padding(.vertical, 8)
    }

    private func toggleMode() {
        mode = (mode == .signIn) ? .signUp : .signIn
        errorMessage = nil
        infoMessage = nil
    }

    private func submitEmailForm() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            errorMessage = "Enter a valid email."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        Task {
            isWorking = true
            errorMessage = nil
            infoMessage = nil
            defer { isWorking = false }

            do {
                switch mode {
                case .signIn:
                    _ = try await AuthService.shared.signIn(email: trimmedEmail, password: password)
                case .signUp:
                    _ = try await AuthService.shared.signUp(email: trimmedEmail, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendPasswordReset() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty, trimmedEmail.contains("@") else {
            errorMessage = "Enter your email above first."
            return
        }
        Task {
            isWorking = true
            errorMessage = nil
            infoMessage = nil
            defer { isWorking = false }

            do {
                try await AuthService.shared.sendPasswordReset(email: trimmedEmail)
                infoMessage = "Reset link sent to \(trimmedEmail)."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func signInWithGoogle() {
        Task {
            isWorking = true
            errorMessage = nil
            infoMessage = nil
            defer { isWorking = false }

            do {
                let credential = try await GoogleSignInCoordinator.shared.signIn()
                _ = try await AuthService.shared.signIn(with: credential)
            } catch GoogleSignInError.cancelled {
                // ignore — user cancelled
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
