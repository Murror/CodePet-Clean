import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDetail = false

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("◆ CODEPET")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(character.color)
                        Text("Insights")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color(hex: "#2D2B26"))
                        Text(showDetail ? "Detailed analytics for your learning journey." : "Your learning at a glance.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                    }

                    Spacer()

                    // Fun / Details toggle
                    HStack(spacing: 0) {
                        toggleButton(label: "Fun", isSelected: !showDetail) {
                            showDetail = false
                            SoundManager.shared.playTap()
                        }
                        toggleButton(label: "Details", isSelected: showDetail) {
                            showDetail = true
                            SoundManager.shared.playTap()
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#F0EDE6"))
                    )
                }

                // Cards grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    XPProgressCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    StreakCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    SkillsMasteredCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    WeeklyActivityCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    TierProgressCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    RecentPerformanceCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    FeedbackLoopCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    ResilienceCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                    ActiveTrapsCard(showDetail: showDetail)
                        .modifier(FadeUpModifier())
                }
            }
            .padding(20)
        }
        .background(Color(hex: "#FBF9F1"))
        .onAppear {
            appState.checkAndUpdateSnapshot()
        }
    }

    private func toggleButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isSelected ? .white : Color(hex: "#2D2B26").opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? character.color : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InsightsView()
        .environmentObject(AppState())
}
