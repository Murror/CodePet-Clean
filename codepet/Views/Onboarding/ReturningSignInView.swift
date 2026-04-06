import SwiftUI

/// A simplified sign-in screen for returning users who have already completed onboarding.
/// Shows only the sign-in options (Google + Email) without age gate or onboarding steps.
struct ReturningSignInView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var resetSent = false
    @State private var isSignUp = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Logo
                Image("codepet-text-logo")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 280)

                Text("Welcome back!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))

                Text("Sign in to continue your journey.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }

            Spacer().frame(height: 32)

            // Sign-in form
            VStack(spacing: 14) {
                // Error message
                if let error = authManager.authError, !error.contains("reset email sent") {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Sign in with Google
                Button(action: {
                    authManager.signInWithGoogle()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 16))
                        Text("Sign in with Google")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    )
                    .foregroundColor(Color(hex: "#1F2937"))
                }
                .buttonStyle(.plain)

                // Divider
                HStack {
                    Rectangle().fill(Color(hex: "#E0DBEF")).frame(height: 1)
                    Text("or")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#AAAAAA"))
                    Rectangle().fill(Color(hex: "#E0DBEF")).frame(height: 1)
                }
                .padding(.vertical, 4)

                // Email field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#888888"))
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                        .textContentType(.emailAddress)
                }
                .padding(.horizontal, 8)

                // Password field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Password")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#888888"))
                    SecureField("Your password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 8)

                // Toggle sign-in / sign-up + forgot password
                HStack {
                    Button(isSignUp ? "Already have an account? Sign in" : "New here? Create an account") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSignUp.toggle()
                            resetSent = false
                            authManager.authError = nil
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#7B6BD8"))
                    .buttonStyle(.plain)

                    if !isSignUp {
                        Spacer()
                        Button("Forgot password?") {
                            guard !email.isEmpty else {
                                authManager.authError = "Enter your email above first."
                                return
                            }
                            authManager.sendPasswordReset(email: email)
                            resetSent = true
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#B0A898"))
                        .buttonStyle(.plain)
                    }
                }

                // Reset confirmation
                if resetSent {
                    Text("Password reset email sent! Check your inbox.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#20B090"))
                        .multilineTextAlignment(.center)
                }

                // Sign-in / sign-up button
                let emailReady = !email.isEmpty && password.count >= 6 && !isAuthenticating
                Button(action: {
                    isAuthenticating = true
                    authManager.authError = nil
                    if isSignUp {
                        authManager.signUpWithEmail(email: email, password: password, name: appState.displayName)
                    } else {
                        authManager.signInWithEmail(email: email, password: password)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isAuthenticating = false
                    }
                }) {
                    HStack(spacing: 10) {
                        if isAuthenticating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "envelope.fill")
                        }
                        Text(isAuthenticating ? "Signing in..." : (isSignUp ? "Create Account" : "Sign In"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(emailReady ? Color(hex: "#7B6BD8") : Color(hex: "#D0CDE0"))
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!emailReady)

                // Skip — continue as anonymous
                Button("Continue without signing in →") {
                    authManager.signInAnonymously(name: appState.displayName, pin: "")
                }
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#B0A898"))
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .frame(maxWidth: 340)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#F5F3FA"))
    }
}
