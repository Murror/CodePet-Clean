import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 4) {
                    Text(appState.displayName.isEmpty ? "Your Profile" : "Hi, \(appState.displayName)!")
                        .font(.system(size: 24, weight: .bold, design: .default))

                    Text("Vibe coder since today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    if let char = PetCharacter.all[appState.activeChar] {
                        Text("Companion: \(char.name) — \(char.badge)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(value: "0", label: "SESSIONS")
                    StatCard(value: "0", label: "PROMPTS")
                    StatCard(value: "\(appState.completedLessons.count)/16", label: "SKILLS")
                    StatCard(value: "\(appState.streak)🔥", label: "STREAK")
                }

                // Account Section
                AccountSection()

                // Weekly Recap Button
                Button {
                    appState.showWeeklyRecap = true
                } label: {
                    HStack {
                        Text("📊")
                        Text("View Weekly Recap")
                            .font(.system(size: 13, weight: .bold, design: .default))
                    }
                    .foregroundColor(Color(hex: "#D4960A"))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(colors: [Color(hex: "#FFF8F0"), Color(hex: "#FFFAF4")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "#D4960A"), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Settings
                SettingsSection()
            }
            .padding(20)
        }
        .background(Color(hex: "#FBF9F1"))
    }
}

struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
    }
}

struct AccountSection: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(.system(size: 14, weight: .semibold, design: .default))

            VStack(spacing: 12) {
                if let user = authManager.currentUser {
                    if authManager.authMethod == "pin" {
                        // Young user
                        HStack(spacing: 8) {
                            Text("🌱")
                            VStack(alignment: .leading) {
                                Text("Young Explorer")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#2E7D32"))
                                Text("Progress saved automatically")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#F0FAF4")))
                    } else {
                        Text(user.email ?? appState.displayName)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Button("Sign out") {
                        authManager.signOut()
                        appState.onboardingComplete = false
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E0DDD6")))
                } else {
                    Text("Connect your account to save progress.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Button("Sign In / Create Account") {
                        // TODO: Show sign-in sheet
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PetCharacter.all[appState.activeChar]?.color ?? .blue)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
        }
    }
}

struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold, design: .default))

            VStack(spacing: 0) {
                ForEach(["Daily session goal", "Notification preferences", "Connected tools", "Export my data", "About CodePet"], id: \.self) { setting in
                    HStack {
                        Text(setting)
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    if setting != "About CodePet" {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
