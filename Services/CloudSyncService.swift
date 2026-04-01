import SwiftUI
import Combine

class CloudSyncService: ObservableObject {
    private var syncTimer: Timer?
    private var pendingSync = false

    func saveToCloud(userId: String, appState: AppState) {
        // TODO: Implement Firestore save
        // let userData: [String: Any] = [
        //     "totalXP": appState.totalXP,
        //     "userLevel": appState.userLevel,
        //     "currentTier": appState.currentTier,
        //     "streak": appState.streak,
        //     "activeChar": appState.activeChar,
        //     "completedLessons": appState.completedLessons,
        //     "completedChallenges": appState.completedChallenges,
        //     "displayName": appState.displayName,
        //     "onboardingComplete": appState.onboardingComplete,
        //     "difficultyLevel": appState.difficultyLevel,
        //     "skillLevel": appState.skillLevel,
        //     "dailyGoalMinutes": appState.dailyGoalMinutes,
        //     "updatedAt": FieldValue.serverTimestamp()
        // ]
        // Firestore.firestore().collection("users").document(userId).setData(userData, merge: true)
        print("[CloudSync] Saving data for user: \(userId)")
    }

    func loadFromCloud(userId: String, appState: AppState) {
        // TODO: Implement Firestore load
        print("[CloudSync] Loading data for user: \(userId)")
    }

    /// Debounced save — waits 2 seconds after last change
    func scheduleSave(userId: String, appState: AppState) {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.saveToCloud(userId: userId, appState: appState)
        }
    }
}
