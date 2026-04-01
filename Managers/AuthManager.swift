import SwiftUI
import Combine

class AuthManager: ObservableObject {
    @Published var currentUser: FirebaseUser? = nil
    @Published var isLoading: Bool = true
    @Published var authError: String? = nil
    @Published var authMethod: String? = nil // "google", "email", "pin"

    init() {
        // TODO: Set up Firebase Auth listener
        // firebaseAuth.addStateDidChangeListener { [weak self] _, user in
        //     self?.currentUser = user
        //     self?.isLoading = false
        // }

        // Temporary: simulate auth loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
        }
    }

    func signInWithGoogle() {
        authError = nil
        // TODO: Implement Google Sign-In
        // GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { ... }
    }

    func signInWithEmail(email: String, password: String) {
        authError = nil
        // TODO: Implement Email/Password sign-in
    }

    func signUpWithEmail(email: String, password: String, name: String) {
        authError = nil
        // TODO: Implement Email/Password sign-up
    }

    func signInAnonymously(name: String, pin: String) {
        authError = nil
        // TODO: Implement Anonymous sign-in for young users
    }

    func signOut() {
        // TODO: Firebase sign out
        currentUser = nil
        authMethod = nil
    }

    func sendPasswordReset(email: String) {
        authError = nil
        // TODO: Implement password reset
    }
}

struct FirebaseUser {
    let uid: String
    let email: String?
    let displayName: String?
    let isAnonymous: Bool
}
