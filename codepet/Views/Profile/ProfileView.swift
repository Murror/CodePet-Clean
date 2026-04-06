import SwiftUI
import FirebaseAuth

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
                    .foregroundColor(Color(hex: "#7B6BD8"))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(colors: [Color(hex: "#FFF8F0"), Color(hex: "#FFFAF4")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "#7B6BD8"), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Settings
                SettingsSection()
            }
            .padding(20)
        }
        .background(Color(hex: "#F7F5FC"))
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
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#F7F5FC")))
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
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "#EDEBF7")))
                    } else {
                        Text(user.email ?? appState.displayName)
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Button("Sign out") {
                        authManager.signOut()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E0DDD6")))
                } else {
                    Text("Connect your account to save progress.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    // Sign in with Google
                    Button(action: { authManager.signInWithGoogle() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 14))
                            Text("Sign in with Google")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E0E0E0"), lineWidth: 1))
                        )
                        .foregroundColor(Color(hex: "#1F2937"))
                    }
                    .buttonStyle(.plain)

                    // Error
                    if let error = authManager.authError {
                        Text(error)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#E04040"))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#F7F5FC")).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
        }
    }
}

struct SettingsSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @State private var showGoalPicker = false
    @State private var showAbout = false
    @State private var showExportAlert = false
    @State private var showNotifAlert = false
    @State private var showResetConfirm = false

    private let goalOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold, design: .default))

            VStack(spacing: 0) {
                // Daily session goal
                Button {
                    showGoalPicker = true
                } label: {
                    HStack {
                        Text("Daily session goal")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(appState.dailyGoalMinutes > 0 ? "\(appState.dailyGoalMinutes) min" : "Not set")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showGoalPicker) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Goal")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.bottom, 4)
                        ForEach(goalOptions, id: \.self) { mins in
                            Button {
                                appState.dailyGoalMinutes = mins
                                showGoalPicker = false
                            } label: {
                                HStack {
                                    Text("\(mins) min")
                                        .font(.system(size: 13))
                                    Spacer()
                                    if appState.dailyGoalMinutes == mins {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "#7B6BD8"))
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .frame(width: 160)
                }

                Divider().padding(.leading, 16)

                // Sound toggle
                HStack {
                    Text("Sound effects")
                        .font(.system(size: 13))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.soundEnabled },
                        set: { _ in appState.toggleSound() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().padding(.leading, 16)

                // Notification preferences
                Button {
                    showNotifAlert = true
                } label: {
                    HStack {
                        Text("Notification preferences")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .alert("Notifications", isPresented: $showNotifAlert) {
                    Button("Open System Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Manage CodePet notifications in System Settings.")
                }

                Divider().padding(.leading, 16)

                // Export my data
                Button {
                    showExportAlert = true
                } label: {
                    HStack {
                        Text("Export my data")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .alert("Export Data", isPresented: $showExportAlert) {
                    Button("OK") {}
                } message: {
                    Text("Level \(appState.userLevel) · \(appState.totalXP) XP · \(appState.completedLessons.count) skills · \(appState.streak) day streak")
                }

                Divider().padding(.leading, 16)

                // Reset progress
                Button {
                    showResetConfirm = true
                } label: {
                    HStack {
                        Text("Reset my progress")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#E04040"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .alert("Reset Progress?", isPresented: $showResetConfirm) {
                    Button("Reset", role: .destructive) {
                        appState.resetProgress()
                        // Also wipe Firestore so it doesn't reload old data on next sign-in
                        if let uid = authManager.currentUser?.uid {
                            CloudSyncService().saveToCloud(userId: uid, appState: appState)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all your XP, completed lessons, and streak. This cannot be undone.")
                }

                Divider().padding(.leading, 16)

                // About
                Button {
                    showAbout = true
                } label: {
                    HStack {
                        Text("About CodePet")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .alert("CodePet", isPresented: $showAbout) {
                    Button("OK") {}
                } message: {
                    Text("v1.0 · 8 characters · 16 skills · made with vibes")
                }
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#F7F5FC")).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
