import SwiftUI

struct TierProgressCard: View {
    @EnvironmentObject var appState: AppState
    let showDetail: Bool

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    private var currentTierData: SkillTier? {
        GameData.skillTiers.first { $0.id == appState.currentTier }
    }

    private var tierProgress: (done: Int, total: Int) {
        guard let tier = currentTierData else { return (0, 0) }
        let done = tier.skills.filter { appState.completedLessons.contains($0.id) }.count
        return (done, tier.skills.count)
    }

    private var tierPercent: Int {
        let p = tierProgress
        guard p.total > 0 else { return 0 }
        return Int(Double(p.done) / Double(p.total) * 100)
    }

    var body: some View {
        InsightCardView(title: "Tier Progress", icon: "shield.fill") {
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
            HStack(spacing: 8) {
                Text(characterOutfits[appState.currentTier]?.badge ?? "🥚")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Tier \(appState.currentTier)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26"))
                    Text(currentTierData?.name ?? "")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(character.color)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#F0EDE6"))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(character.color)
                        .frame(width: geo.size.width * CGFloat(tierProgress.done) / max(CGFloat(tierProgress.total), 1))
                        .animation(.easeOut(duration: 0.6), value: tierProgress.done)
                }
            }
            .frame(height: 8)

            Text("\(tierPercent)% to next tier")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
        }
    }

    @ViewBuilder
    private var detailView: some View {
        let tier = currentTierData
        VStack(alignment: .leading, spacing: 6) {
            if let tier = tier {
                Text("Remaining in \(tier.name):")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))

                let remaining = tier.skills.filter { !appState.completedLessons.contains($0.id) }
                if remaining.isEmpty {
                    Text("All skills completed! Ready for next tier.")
                        .font(.system(size: 12))
                        .foregroundColor(character.color)
                        .italic()
                } else {
                    ForEach(remaining) { skill in
                        HStack(spacing: 6) {
                            Text(skill.icon)
                                .font(.system(size: 12))
                            Text(skill.name)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#2D2B26"))
                        }
                    }
                }
            }
        }
    }
}
