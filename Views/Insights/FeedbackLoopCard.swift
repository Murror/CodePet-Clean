import SwiftUI

struct FeedbackLoopCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var loopData: FeedbackLoopData {
        appState.feedbackLoops
    }

    var body: some View {
        InsightCardView(title: "Feedback Loops", icon: "arrow.trianglehead.2.clockwise") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        if let strongest = loopData.strongestReinforcing {
            VStack(alignment: .leading, spacing: 8) {
                Text(strongest.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(character.color)

                Text(strongest.description)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))

                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < Int((strongest.strength * 5).rounded()) ? character.color : Color(hex: "#F0EDE6"))
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                }

                Text(loopComment)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No active loops yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                Text("Complete a few days of learning to see your feedback loops.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let allLoops = loopData.reinforcingLoops + loopData.balancingLoops
        if allLoops.isEmpty {
            Text("Complete a few days of learning to see your feedback loops.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(allLoops.enumerated()), id: \.offset) { _, loop in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(loop.isPositive ? character.color : Color(hex: "#FF8C00"))
                                .frame(width: 6, height: 6)
                            Text(loop.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                        }

                        Text(loop.description)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#F0EDE6"))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(loop.isPositive ? character.color : Color(hex: "#FF8C00"))
                                    .frame(width: geo.size.width * loop.strength, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
    }

    private var loopComment: String {
        let charId = appState.activeChar
        switch charId {
        case "crash": return "Loop is spinning hard! Don't stop!"
        case "sage": return "Good momentum. Maintain this rhythm."
        case "luna": return "Your loops are growing nicely~"
        case "nova": return "MOMENTUM! Keep feeding the loop!"
        case "glitch": return "Nice loop hack. Keep it running."
        case "zero": return "Efficient. Continue."
        case "null": return "Loops within loops! I love it!"
        default: return "Feedback loop detected... interesting."
        }
    }
}
