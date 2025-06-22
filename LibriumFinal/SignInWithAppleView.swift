//
//  SignInWithAppleView.swift
//  LibriumFinal
//
//  Created by James Garmon on 6/22/25.
//


import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Sign in with Apple View
struct SignInWithAppleView: View {
    @StateObject private var authManager = AppleAuthManager()
    @State private var showingMainApp = false
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo/Icon
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 100))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
                // App Name
                Text("FINALE AI")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Your Personal AI Assistant")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Sign in with Apple Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { request in
                        authManager.handleSignInWithAppleRequest(request)
                    },
                    onCompletion: { result in
                        authManager.handleSignInWithAppleCompletion(result)
                    }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: 280)
                .shadow(radius: 5)
                
                // Alternative sign in
                Button(action: {
                    authManager.continueAsGuest()
                }) {
                    Text("Continue as Guest")
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.vertical, 8)
                }
                
                Spacer()
                    .frame(height: 100)
            }
            .padding(.horizontal)
        }
        .onReceive(authManager.$isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                showingMainApp = true
            }
        }
        .onReceive(authManager.$authError) { error in
            if error != nil {
                showingError = true
            }
        }
        .fullScreenCover(isPresented: $showingMainApp) {
            // Your main app view
            MainAppView()
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") {
                authManager.authError = nil
            }
        } message: {
            Text(authManager.authError?.localizedDescription ?? "Unknown error occurred")
        }
    }
}

// MARK: - Apple Auth Manager
class AppleAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var fullName: PersonNameComponents?
    @Published var email: String?
    @Published var authError: Error?
    
    private let userDefaults = UserDefaults.standard
    private let keychainManager = KeychainManager()
    
    // Keys for storage
    private let userIDKey = "com.finale.userID"
    private let hasAuthenticatedKey = "com.finale.hasAuthenticated"
    
    init() {
        checkExistingAuthentication()
    }
    
    // MARK: - Sign in with Apple Handlers
    
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        
        // Generate nonce for security
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)
        
        // Store nonce for validation
        userDefaults.set(nonce, forKey: "signin_nonce")
    }
    
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }
            
            // Save user ID
            let userID = appleIDCredential.user
            self.userID = userID
            keychainManager.save(userID, forKey: userIDKey)
            
            // Save user info (only provided on first sign in)
            if let fullName = appleIDCredential.fullName {
                self.fullName = fullName
                saveUserName(fullName)
            }
            
            if let email = appleIDCredential.email {
                self.email = email
                saveEmail(email)
            }
            
            // Save authentication state
            userDefaults.set(true, forKey: hasAuthenticatedKey)
            
            // Create user in your system
            createOrUpdateUser(
                userID: userID,
                fullName: fullName,
                email: email
            )
            
            // Update authentication state
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
            
        case .failure(let error):
            DispatchQueue.main.async {
                self.authError = error
            }
        }
    }
    
    // MARK: - User Management
    
    private func createOrUpdateUser(userID: String, fullName: PersonNameComponents?, email: String?) {
        Task {
            do {
                // Get or create user data
                let firstName = fullName?.givenName ?? "User"
                let lastName = fullName?.familyName ?? ""
                let userEmail = email ?? "\(userID)@privaterelay.appleid.com"
                
                // Create user in your system
                let userData = UserData(
                    id: UUID(), // You might want to derive this from Apple ID
                    firstName: firstName,
                    lastName: lastName,
                    email: userEmail,
                    phoneNumber: nil,
                    preferences: UserPreferencesData(),
                    privacySettings: PrivacySettingsData(),
                    enabledHubs: Set([.life]),
                    createdAt: Date(),
                    lastActiveAt: Date()
                )
                
                // Save to your data manager
                _ = try await DataManager.shared.createUser(userData)
                
                // Setup Maria Brain for the user
                await MariaBrain.shared.setupUser(
                    firstName: firstName,
                    lastName: lastName,
                    email: userEmail
                )
                
            } catch {
                print("Error creating user: \(error)")
            }
        }
    }
    
    // MARK: - Persistence
    
    private func saveUserName(_ name: PersonNameComponents) {
        if let data = try? JSONEncoder().encode(name) {
            userDefaults.set(data, forKey: "user_fullname")
        }
    }
    
    private func saveEmail(_ email: String) {
        keychainManager.save(email, forKey: "user_email")
    }
    
    private func checkExistingAuthentication() {
        // Check if user has authenticated before
        guard userDefaults.bool(forKey: hasAuthenticatedKey) else { return }
        
        // Try to retrieve user ID from keychain
        if let savedUserID = keychainManager.load(forKey: userIDKey) {
            self.userID = savedUserID
            
            // Load saved user info
            if let nameData = userDefaults.data(forKey: "user_fullname"),
               let name = try? JSONDecoder().decode(PersonNameComponents.self, from: nameData) {
                self.fullName = name
            }
            
            if let email = keychainManager.load(forKey: "user_email") {
                self.email = email
            }
            
            // Verify with Apple that credentials are still valid
            verifyExistingCredentials()
        }
    }
    
    private func verifyExistingCredentials() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        
        guard let userID = self.userID else { return }
        
        appleIDProvider.getCredentialState(forUserID: userID) { [weak self] credentialState, error in
            switch credentialState {
            case .authorized:
                // Credentials are valid
                DispatchQueue.main.async {
                    self?.isAuthenticated = true
                }
                
            case .revoked, .notFound:
                // Credentials are invalid, clear saved data
                DispatchQueue.main.async {
                    self?.signOut()
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Guest Mode
    
    func continueAsGuest() {
        Task {
            await MariaBrain.shared.setupUser(
                firstName: "Guest",
                lastName: "User",
                email: "guest@finale.ai"
            )
            
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() {
        // Clear keychain
        keychainManager.delete(forKey: userIDKey)
        keychainManager.delete(forKey: "user_email")
        
        // Clear user defaults
        userDefaults.removeObject(forKey: hasAuthenticatedKey)
        userDefaults.removeObject(forKey: "user_fullname")
        
        // Clear properties
        userID = nil
        fullName = nil
        email = nil
        isAuthenticated = false
        
        // Clear user data if needed
        // You might want to keep some data for re-authentication
    }
    
    // MARK: - Security Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - Keychain Manager
class KeychainManager {
    enum KeychainError: Error {
        case noData
        case unexpectedData
        case unhandledError(status: OSStatus)
    }
    
    func save(_ value: String, forKey key: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != noErr {
            print("Error saving to keychain: \(status)")
        }
    }
    
    func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr {
            if let data = dataTypeRef as? Data {
                return String(data: data, encoding: .utf8)
            }
        }
        
        return nil
    }
    
    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Main App View (Placeholder)
struct MainAppView: View {
    @StateObject private var brain = MariaBrain.shared
    @EnvironmentObject var authManager: AppleAuthManager
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Welcome, \(brain.userName)!")
                    .font(.largeTitle)
                    .padding()
                
                // Your ConversationView would go here
                Spacer()
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                .padding()
            }
            .navigationTitle("FINALE AI")
        }
    }
}

// MARK: - App Entry Point
struct FINALEApp: App {
    @StateObject private var authManager = AppleAuthManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainAppView()
                    .environmentObject(authManager)
            } else {
                SignInWithAppleView()
                    .environmentObject(authManager)
            }
        }
    }
}

// MARK: - Preview
struct SignInWithAppleView_Previews: PreviewProvider {
    static var previews: some View {
        SignInWithAppleView()
    }
}
