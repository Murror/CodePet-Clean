import SwiftUI
import Charts

struct RecentPerformanceCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private func gradeEmoji(score: Int) -> String {
        if score >= 95 { return "S" }
        if score >= 85 { return "A" }
        if score >= 70 { return "B" }
        if score >= 55 { return "C" }
        if score >= 40 { return "D" }
        return "F"
    }

    private func gradeColor(score: Int) -> Color {
        if score >= 95 { return Color(hex: "#FFD700") }
        if score >= 85 { return Color(hex: "#6BCB77") }
        if score >= 70 { return Color(hex: "#4FC3F7") }
        if score >= 55 { return Color(hex: "#D4960A") }
        if score >= 40 { return Color(hex: "#FF8C00") }
        return Color(hex: "#E04040")
    }

    var body: some View {
        InsightCardView(title: "Recent Performance", icon: "chart.line.uptrend.xyaxis") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        let recent = appState.performanceHistory.suffix(3).reversed()
        if recent.isEmpty {
            Text("Complete challenges to see your scores here!")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(recent), id: \.skillId) { entry in
                    HStack(spacing: 8) {
                        Text(gradeEmoji(score: entry.score))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(gradeColor(score: entry.score))
                            .frame(width: 20)

                        Text(skillName(for: entry.skillId))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#2D2B26"))
                            .lineLimit(1)

                        Spacer()

                        Text("\(entry.score)%")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let history = Array(appState.performanceHistory.suffix(10))
        if history.isEmpty {
            Text("Complete challenges to see your performance trend.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            Chart(history, id: \.skillId) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(character.color)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Score", entry.score)
                )
                .foregroundStyle(character.color)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100])
            }
            .frame(height: 100)
        }
    }

    private func skillName(for id: String) -> String {
        for tier in GameData.skillTiers {
            if let skill = tier.skills.first(where: { $0.id == id }) {
                return skill.name
            }
        }
        return id
    }
}
