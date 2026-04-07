import SwiftUI
import Charts

struct SkillsMasteredCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var totalSkills: Int {
        GameData.skillTiers.reduce(0) { $0 + $1.skills.count }
    }

    private var completedCount: Int {
        appState.completedLessons.count
    }

    private var progress: Double {
        totalSkills > 0 ? Double(completedCount) / Double(totalSkills) : 0
    }

    var body: some View {
        InsightCardView(title: "Skills Mastered", icon: "checkmark.seal.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "#F0EDE6"), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(character.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: progress)

                Text("\(completedCount)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(character.color)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(completedCount) of \(totalSkills)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26"))
                Text("skills completed")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                Text("Tier \(appState.currentTier) — \(characterOutfits[appState.currentTier]?.name ?? "Starter")")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(character.color)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let tierData = GameData.skillTiers.map { tier -> (name: String, completed: Int, total: Int, color: Color) in
            let done = tier.skills.filter { appState.completedLessons.contains($0.id) }.count
            return (name: tier.name, completed: done, total: tier.skills.count, color: tier.color)
        }

        Chart(tierData, id: \.name) { tier in
            BarMark(
                x: .value("Completed", tier.completed),
                y: .value("Tier", tier.name)
            )
            .foregroundStyle(tier.color)

            BarMark(
                x: .value("Remaining", tier.total - tier.completed),
                y: .value("Tier", tier.name)
            )
            .foregroundStyle(Color(hex: "#F0EDE6"))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4))
        }
        .frame(height: 100)
    }
}
