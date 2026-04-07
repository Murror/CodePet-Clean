import SwiftUI
import Charts

struct WeeklyActivityCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var activityStars: Int {
        let stats = appState.weeklyStats
        let total = stats.challengesDone + stats.skillsLearned
        if total >= 10 { return 5 }
        if total >= 7 { return 4 }
        if total >= 4 { return 3 }
        if total >= 2 { return 2 }
        if total >= 1 { return 1 }
        return 0
    }

    private var petReaction: String {
        switch activityStars {
        case 5: return "Amazing week! 🎉"
        case 4: return "Great job! 💪"
        case 3: return "Solid progress!"
        case 2: return "Getting started!"
        case 1: return "Keep it up!"
        default: return "Let's get going!"
        }
    }

    var body: some View {
        InsightCardView(title: "Weekly Activity", icon: "calendar") {
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
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < activityStars ? "star.fill" : "star")
                        .font(.system(size: 16))
                        .foregroundColor(i < activityStars ? Color(hex: "#D4960A") : Color(hex: "#E0DDD6"))
                }
            }

            Text(petReaction)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                .italic()

            HStack(spacing: 12) {
                Label("\(appState.weeklyStats.skillsLearned) lessons", systemImage: "book.fill")
                Label("\(appState.weeklyStats.challengesDone) challenges", systemImage: "flag.fill")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let last7 = (0..<7).map { offset -> (day: String, date: Date) in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return (day: formatter.string(from: date), date: date)
        }

        let chartData = last7.map { item -> (day: String, lessons: Int, challenges: Int) in
            let snapshot = appState.dailySnapshots.first { calendar.isDate($0.date, inSameDayAs: item.date) }
            let prevSnapshot = appState.dailySnapshots.first {
                calendar.isDate($0.date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: item.date)!)
            }
            let lessonsToday = (snapshot?.lessonsCompleted ?? 0) - (prevSnapshot?.lessonsCompleted ?? 0)
            let challengesToday = (snapshot?.challengesCompleted ?? 0) - (prevSnapshot?.challengesCompleted ?? 0)
            return (day: item.day, lessons: max(0, lessonsToday), challenges: max(0, challengesToday))
        }

        if appState.dailySnapshots.count < 2 {
            Text("A few more days of learning and your weekly chart will appear here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            Chart {
                ForEach(chartData, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.lessons)
                    )
                    .foregroundStyle(character.color)
                    .position(by: .value("Type", "Lessons"))

                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Count", item.challenges)
                    )
                    .foregroundStyle(Color(hex: "#D4960A"))
                    .position(by: .value("Type", "Challenges"))
                }
            }
            .chartForegroundStyleScale([
                "Lessons": character.color,
                "Challenges": Color(hex: "#D4960A")
            ])
            .frame(height: 100)
        }
    }
}
