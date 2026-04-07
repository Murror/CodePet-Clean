import SwiftUI
import Charts

struct XPProgressCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var xpComment: String {
        let todayXP = todayXPGain
        if todayXP == 0 { return "\(character.name) says: Let's learn something today!" }
        if todayXP >= 100 { return "\(character.name) says: You're on fire! 🔥" }
        return "\(character.name) says: Nice progress!"
    }

    private var todayXPGain: Int {
        guard let today = appState.dailySnapshots.last,
              Calendar.current.isDateInToday(today.date) else { return 0 }
        let yesterday = appState.dailySnapshots.dropLast().last
        return today.totalXP - (yesterday?.totalXP ?? 0)
    }

    var body: some View {
        InsightCardView(title: "XP Progress", icon: "star.fill") {
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
                Text("\(appState.totalXP)")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(character.color)
                    .contentTransition(.numericText())
                Text("XP")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }

            HStack(spacing: 6) {
                Text("Level \(appState.userLevel)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(character.color))
            }

            Text(xpComment)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                .italic()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.dailySnapshots.count < 2 {
            Text("Complete a few days of learning to see your XP trend.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            Chart(appState.dailySnapshots.suffix(30)) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.date, unit: .day),
                    y: .value("XP", snapshot.totalXP)
                )
                .foregroundStyle(character.color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", snapshot.date, unit: .day),
                    y: .value("XP", snapshot.totalXP)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [character.color.opacity(0.2), character.color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 120)
        }
    }
}
