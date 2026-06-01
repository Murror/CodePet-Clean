import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct CodePetApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthManager()
    @StateObject private var gameState = GameState()
    @StateObject private var mcpBridge = MCPBridgeService.shared
    @StateObject private var reflectionComposition: ReflectionComposition
    @StateObject private var chatStore: SessionChatStore
    @StateObject private var chatController: SessionChatController
    @StateObject private var hookInstaller = HookInstaller()
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var demoController = DemoScriptController()
    @StateObject private var demoHotkeyMonitor = DemoHotkeyMonitor()
    @StateObject private var healthNudge = HealthNudgeController()
    @StateObject private var tipsState = TipsState()
    @StateObject private var learnProgress = LearnProgress()
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
                .environment(\.font, CodepetTheme.body(13))
                .environment(\.uiLanguage, appState.uiLanguage)
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
                .environmentObject(hookInstaller)
                .environmentObject(projectStore)
                .environmentObject(demoController)
                .environmentObject(healthNudge)
                .environmentObject(tipsState)
                .environmentObject(learnProgress)
                .frame(minWidth: 400, minHeight: 700)
                .themed(isDark: appState.isDarkMode)
                .task {
                    projectStore.load()
                    TipsPersistence.shared.load(into: tipsState)
                    TipsPersistence.shared.startAutoSave(tipsState)
                    reflectionComposition.sessionEnricher.projectStore = projectStore
                    reflectionComposition.updateLanguage(appState.uiLanguage)
                    reflectionComposition.start()
                }
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

                    demoHotkeyMonitor.bind(controller: demoController)
                    demoHotkeyMonitor.onTipsDemo = { [weak demoController, weak tipsState, weak appState] in
                        guard let dc = demoController, let ts = tipsState, let app = appState else { return }
                        dc.populateTipsDemo(tipsState: ts, petId: app.activeChar)
                        app.selectedTab = .tips
                    }
                    // Sync display language into the demo controller so the
                    // synthesized Session/Turn/Narrative render in the right
                    // language.
                    demoController.language = appState.uiLanguage
                    if appState.demoModeEnabled {
                        demoHotkeyMonitor.start()
                        // Auto-start the demo session at launch so the
                        // Reflection sidebar already has the demo session
                        // selectable on first paint.
                        demoController.startSession()
                    }
                }
                .onChange(of: appState.uiLanguage) { _, lang in
                    demoController.language = lang
                    reflectionComposition.updateLanguage(lang)
                }
                .onChange(of: appState.demoModeEnabled) { _, enabled in
                    if enabled {
                        demoHotkeyMonitor.start()
                        // Auto-start the session so the production sidebar
                        // surfaces the demo session immediately — there's no
                        // manual "Start session" button in the prod layout.
                        demoController.startSession()
                    } else {
                        demoHotkeyMonitor.stop()
                        demoController.reset()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                    // Save game state when app goes to background
                    gameState.forceSave()
                    appState.lastVisit = Date()
                    TipsPersistence.shared.save(tipsState)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    // Process return from idle when app comes back
                    gameState.processReturnFromIdle()
                    // Re-sync MCP data
                    mcpBridge.refresh()
                    appState.syncFromMCP(mcpBridge)
                }
                // Google Sign-In OAuth callback. Without this handler the
                // browser redirects to com.googleusercontent.apps.<id>:// and
                // macOS routes the URL to us, but GoogleSignIn never finishes
                // — the user picks an account and the flow appears to hang.
                .onOpenURL { url in
                    print("[Auth] Received OAuth callback URL: \(url.scheme ?? "nil")://...")
                    let handled = GIDSignIn.sharedInstance.handle(url)
                    print("[Auth] GoogleSignIn.handle(url): \(handled)")
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
