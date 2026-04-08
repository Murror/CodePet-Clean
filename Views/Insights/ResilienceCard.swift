import SwiftUI

struct ResilienceCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        InsightCardView(title: "Resilience", icon: "shield.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        if appState.dailySnapshots.count < 7 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Building...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                Text("Complete 7 days of learning to see your resilience score.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(appState.resilienceScore)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(character.color)
                        .contentTransition(.numericText())
                    Text("/ 100")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                }

                Text(appState.resilienceLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(character.color))

                Text(resilienceComment)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if appState.dailySnapshots.count < 7 {
            Text("Complete 7 days of learning to see resilience details.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                resilienceBar(
                    label: "Consistency",
                    value: appState.consistencyScore,
                    detail: "\(appState.consistencyScore * 30 / 100)/30 days"
                )
                resilienceBar(
                    label: "Recovery",
                    value: appState.recoverySpeedScore,
                    detail: scoreLabel(appState.recoverySpeedScore)
                )
                resilienceBar(
                    label: "Review Health",
                    value: appState.reviewHealthScore,
                    detail: "\(appState.completedLessons.count - appState.lessonsReadyForReview.count)/\(appState.completedLessons.count) on track"
                )
            }
        }
    }

    private func resilienceBar(label: String, value: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.7))
                Spacer()
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "#F0EDE6"))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(for: value))
                        .frame(width: geo.size.width * Double(value) / 100.0, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func barColor(for value: Int) -> Color {
        switch value {
        case 70...100: return Color(hex: "#20B090")
        case 40..<70: return Color(hex: "#FF8C00")
        default: return Color(hex: "#E04040")
        }
    }

    private func scoreLabel(_ value: Int) -> String {
        switch value {
        case 80...100: return "Excellent"
        case 60..<80: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs work"
        }
    }

    private var resilienceComment: String {
        let score = appState.resilienceScore
        let charId = appState.activeChar
        if score >= 80 {
            switch charId {
            case "crash": return "Tank mode! Nothing can break you!"
            case "sage": return "Strong foundation. Continue."
            case "luna": return "Your resilience is beautiful~"
            case "nova": return "UNSTOPPABLE! Keep this energy!"
            case "glitch": return "System hardened. Impressive."
            case "zero": return "Optimal resilience. Efficient."
            case "null": return "Even chaos can't shake you!"
            default: return "Resilience core: stable."
            }
        } else if score >= 40 {
            switch charId {
            case "crash": return "Getting there! Toughen up!"
            case "sage": return "Building steadily. Patience."
            case "luna": return "Growing stronger each day, I believe in you!"
            case "nova": return "Not bad, but we can do better!"
            case "glitch": return "Half-patched. Keep going."
            case "zero": return "Suboptimal. Improve consistency."
            case "null": return "Wobbly but standing! That counts!"
            default: return "Building resilience... keep going."
            }
        } else {
            switch charId {
            case "crash": return "Fragile! We need to fix this NOW!"
            case "sage": return "Consistency is the path. Begin again."
            case "luna": return "It's okay to start small. I'm here with you."
            case "nova": return "We need to focus on consistency!"
            case "glitch": return "System vulnerable. Patch needed."
            case "zero": return "Critical. Focus on daily practice."
            case "null": return "Uh oh... but every journey starts somewhere!"
            default: return "Resilience low... let's build it up."
            }
        }
    }
}
