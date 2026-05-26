import SwiftUI

struct StreakCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        InsightCardView(title: "Streak", icon: "flame.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("🔥")
                    .font(.system(size: 28))
                Text("\(appState.streak)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#FF8C00"))
                Text(appState.streak == 1 ? "day" : "days")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }

            if appState.longestStreak > appState.streak {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#D4960A"))
                    Text("Best: \(appState.longestStreak) days")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                }
            } else if appState.streak > 0 {
                Text("You're at your best! 🏆")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let snapshots = appState.dailySnapshots.suffix(28)
        if snapshots.isEmpty {
            Text("Start learning to build your streak calendar.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let activeDates = Set(snapshots.map { calendar.startOfDay(for: $0.date) })

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(0..<28, id: \.self) { offset in
                        let day = calendar.date(byAdding: .day, value: -(27 - offset), to: today)!
                        let isActive = activeDates.contains(day)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isActive ? character.color : Color(hex: "#F0EDE6"))
                            .frame(height: 14)
                    }
                }

                HStack {
                    Text("4 weeks ago")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
