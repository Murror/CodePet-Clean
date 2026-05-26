import SwiftUI

struct ActiveTrapsCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var traps: [SystemTrap] {
        appState.activeTraps
    }

    var body: some View {
        InsightCardView(title: "System Health", icon: "exclamationmark.triangle.fill") {
            if showDetail {
                detailView
            } else {
                funView
            }
        }
    }

    @ViewBuilder
    private var funView: some View {
        if traps.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#20B090"))
                    Text("All Clear!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(hex: "#20B090"))
                }

                Text(allClearComment)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("⚠️")
                        .font(.system(size: 20))
                    Text("\(traps.count) trap\(traps.count == 1 ? "" : "s") detected")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#FF8C00"))
                }

                if let worst = traps.max(by: { $0.severity < $1.severity }) {
                    Text(worst.type.name)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                }

                Text(appState.trapMessage(for: traps.first!.type).replacingOccurrences(of: "⚠️ ", with: ""))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .italic()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if traps.isEmpty {
            Text("No system traps detected. Your learning patterns are healthy.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(traps.enumerated()), id: \.offset) { _, trap in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(severityColor(trap.severity))
                                .frame(width: 8, height: 8)
                            Image(systemName: trap.type.icon)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                            Text(trap.type.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                        }

                        Text(trap.type.description)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 9))
                                .foregroundColor(character.color)
                            Text(trap.type.suggestedAction)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(character.color)
                        }
                    }
                }
            }
        }
    }

    private func severityColor(_ severity: Double) -> Color {
        switch severity {
        case 0.7...1.0: return Color(hex: "#E04040")
        case 0.4..<0.7: return Color(hex: "#FF8C00")
        default: return Color(hex: "#20B090")
        }
    }

    private var allClearComment: String {
        switch appState.activeChar {
        case "crash": return "No traps! System is rock solid!"
        case "sage": return "Harmony in your learning patterns."
        case "luna": return "Everything looks healthy~ keep going!"
        case "nova": return "Clean system! Full speed ahead!"
        case "glitch": return "No bugs in the matrix today."
        case "zero": return "System clean. Optimal."
        case "null": return "No traps? That's... suspicious. Just kidding!"
        default: return "System health: nominal."
        }
    }
}
