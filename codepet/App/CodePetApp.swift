import SwiftUI
import FirebaseCore

@main
struct CodePetApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()
    @StateObject private var gameState = GameState()
    @StateObject private var mcpBridge = MCPBridgeService.shared
    @StateObject private var reflectionComposition: ReflectionComposition
    @StateObject private var chatStore: SessionChatStore
    @StateObject private var chatController: SessionChatController
    private var notificationManager = NotificationManager()

    init() {
        FontRegistrar.registerBundledFonts()
        FirebaseApp.configure()
        print("[Firebase] Configured successfully")

        let composition = ReflectionComposition()
        let chatStore = SessionChatStore()
        let chatController = SessionChatController(api: composition.api, store: chatStore)
        _reflectionComposition = StateObject(wrappedValue: composition)
        _chatStore = StateObject(wrappedValue: chatStore)
        _chatController = StateObject(wrappedValue: chatController)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, CodepetTheme.usePixelFontGlobally
                             ? CodepetTheme.pixel(13)
                             : .body)
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(gameState)
                .environmentObject(mcpBridge)
                .environmentObject(reflectionComposition.eventStore)
                .environmentObject(reflectionComposition.narrativeStore)
                .environmentObject(reflectionComposition.summaryStore)
                .environmentObject(reflectionComposition.enricher)
                .environmentObject(reflectionComposition.endStore)
                .environmentObject(reflectionComposition.sessionEnricher)
                .environmentObject(chatStore)
                .environmentObject(chatController)
                .frame(minWidth: 400, minHeight: 700)
                .themed(isDark: appState.isDarkMode)
                .task { reflectionComposition.start() }
                .onAppear {
                    notificationManager.requestAuthorization()
                    notificationManager.scheduleDailyReminder(hour: 9, minute: 0)
                    SoundManager.shared.initialize()

                    // Wire GameState ↔ AppState and process return from idle
                    gameState.setAppState(appState)
                    gameState.processReturnFromIdle()

                    // Sync real coding XP from MCP server
                    mcpBridge.refresh()
                    appState.syncFromMCP(mcpBridge)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                    // Save game state when app goes to background
                    gameState.forceSave()
                    appState.lastVisit = Date()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    // Process return from idle when app comes back
                    gameState.processReturnFromIdle()
                    // Re-sync MCP data
                    mcpBridge.refresh()
                    appState.syncFromMCP(mcpBridge)
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

                Button("Reflection") { appState.selectedTab = .reflection }
                    .keyboardShortcut("5", modifiers: .command)

                Button("Tips") { appState.selectedTab = .tips }
                    .keyboardShortcut("6", modifiers: .command)

                Button("Profile") { appState.selectedTab = .profile }
                    .keyboardShortcut("7", modifiers: .command)
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
