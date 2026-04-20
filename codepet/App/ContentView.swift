import SwiftUI
import FirebaseAuth
import os

private let logger = Logger(subsystem: "app.murror.codepet", category: "ContentView")

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoadingCloudData = false
    @State private var showSplash = true
    @State private var isOnboarding = false

    private let cloudSync = CloudSyncService()

    var body: some View {
        Group {
            if showSplash {
                // Splash always shows first
                SplashView(onContinue: {
                    withAnimation {
                        showSplash = false
                    }
                })
            } else if !isOnboarding && (authManager.isLoading || isLoadingCloudData) {
                // Still checking auth state or loading cloud data (not during onboarding)
                SplashView()
            } else if appState.onboardingComplete && authManager.currentUser == nil {
                // Returning user who already onboarded but signed out — show simple sign-in
                ReturningSignInView()
            } else if !appState.onboardingComplete {
                // Brand new user — full onboarding flow
                OnboardingFlow()
                    .onAppear { isOnboarding = true }
                    .onDisappear { isOnboarding = false }
            } else {
                // Authenticated + onboarded — main app
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSplash)
        .animation(.easeInOut(duration: 0.3), value: appState.onboardingComplete)
        .animation(.easeInOut(duration: 0.3), value: authManager.currentUser == nil)
        .onReceive(authManager.$currentUser) { user in
            guard let user = user, !user.isAnonymous else {
                // Signed out — intentionally keep the stored UID so when a different account
                // signs in next, the UID comparison still fires correctly.
                return
            }

            // Don't try to load cloud data while onboarding is in progress —
            // it would tear down OnboardingFlow and reset the user to step 1
            guard !isOnboarding else {
                logger.info("User signed in during onboarding — skipping cloud load")
                PersistenceManager.shared.currentUserId = user.uid
                return
            }

            let storedUID = PersistenceManager.shared.currentUserId

            // Case 1: A confirmed different account signed in
            let isDifferentUser = storedUID != nil && storedUID != user.uid
            // Case 2: No UID on record but there's onboarded data — unknown prior user (old install or cleared UID)
            let isUnknownPriorUser = storedUID == nil && appState.onboardingComplete

            if isDifferentUser || isUnknownPriorUser {
                logger.info("User switch detected (\(storedUID ?? "none", privacy: .private) → \(user.uid, privacy: .private)) — clearing local data")
                appState.resetProgress()
            }

            // Sync display name from Firebase Auth → AppState → UserDefaults
            if appState.displayName.isEmpty {
                if let authName = authManager.latestDisplayName, !authName.isEmpty {
                    appState.displayName = authName
                } else if let fbName = user.displayName, !fbName.isEmpty {
                    appState.displayName = fbName
                }
            }

            // Record this account as the owner of local data
            PersistenceManager.shared.currentUserId = user.uid

            // Load from cloud whenever we can't confirm this is the same user with fresh data
            let needsCloudLoad = !appState.onboardingComplete || isDifferentUser || isUnknownPriorUser
            if needsCloudLoad {
                isLoadingCloudData = true
                cloudSync.loadFromCloud(userId: user.uid, appState: appState) { hasData in
                    isLoadingCloudData = false
                    if hasData {
                        logger.info("Restored cloud data for \(user.uid, privacy: .private)")
                    } else {
                        logger.info("No cloud data for \(user.uid, privacy: .private) — showing onboarding")
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(AuthManager())
}
