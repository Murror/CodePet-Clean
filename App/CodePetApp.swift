import SwiftUI
import FirebaseCore

@main
struct CodePetApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()
    private var notificationManager = NotificationManager()

    init() {
        FirebaseApp.configure()
        print("[Firebase] Configured successfully")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .frame(minWidth: 400, minHeight: 700)
                .themed(isDark: appState.isDarkMode)
                .onAppear {
                    notificationManager.requestAuthorization()
                    notificationManager.scheduleDailyReminder(hour: 9, minute: 0)
                    // Initialize chiptune audio engine
                    SoundManager.shared.initialize()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Navigation") {
                Button("Home") { appState.selectedTab = .home }
                    .keyboardShortcut("1", modifiers: .command)

                Button("Skills") { appState.selectedTab = .skills }
                    .keyboardShortcut("2", modifiers: .command)

                Button("Sessions") { appState.selectedTab = .sessions }
                    .keyboardShortcut("3", modifiers: .command)

                Button("Insights") { appState.selectedTab = .insights }
                    .keyboardShortcut("4", modifiers: .command)

                Button("Profile") { appState.selectedTab = .profile }
                    .keyboardShortcut("5", modifiers: .command)
            }

            CommandMenu("Theme") {
                Button(appState.isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode") {
                    appState.toggleDarkMode()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button(appState.soundEnabled ? "Mute Sounds" : "Enable Sounds") {
                    appState.toggleSound()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("CodePet", systemImage: "pawprint.fill") {
            MenuBarView()
                .environmentObject(appState)
        }
    }
}
