import SwiftUI

// MARK: - World Map Section (for HomeView)

struct WorldMapSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("World Map")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))

                Spacer()

                Text("Tier \(appState.currentTier)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                    )
            }

            // Home Base
            HomeBaseCard()

            // 2x2 Kingdom Grid
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(GameData.skillTiers) { tier in
                    KingdomMapCard(tier: tier)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Home Base Card

struct HomeBaseCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#D6EEF8"), Color(hex: "#E8F4FC"), Color(hex: "#F0F8FF")],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 130)

            // Ground
            VStack {
                Spacer()
                Ellipse()
                    .fill(LinearGradient(colors: [Color(hex: "#B8D8E8"), Color(hex: "#D0E8F4")], startPoint: .top, endPoint: .bottom))
                    .frame(width: 220, height: 30)
                    .offset(y: 6)
            }
            .frame(height: 130)

            // Castle
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    CastleTower(width: 22, height: 40, color: Color(hex: "#88B8D8"))
                    CastleTower(width: 28, height: 55, color: Color(hex: "#7AACC8"))
                    CastleTower(width: 22, height: 40, color: Color(hex: "#88B8D8"))
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "#A0C8E0"))
                    .frame(width: 90, height: 30)
                    .overlay(
                        HStack(spacing: 16) {
                            Circle().fill(Color(hex: "#FFE8A0")).frame(width: 7, height: 7)
                            Circle().fill(Color(hex: "#FFE8A0")).frame(width: 7, height: 7)
                        }
                        .offset(y: -4)
                    )
            }
            .offset(y: -8)

            // HOME label
            VStack {
                Spacer()
                Text("HOME")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#7AACC8"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(3)
                    .offset(y: -12)
            }
            .frame(height: 130)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity)
    }
}

struct CastleTower: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color(hex: "#88C8E8"))
                .frame(width: width + 6, height: 12)
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "#FFE8A0"))
                        .frame(width: 6, height: 8)
                        .offset(y: -height * 0.15)
                )
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Kingdom Map Card

struct KingdomMapCard: View {
    let tier: SkillTier
    @EnvironmentObject var appState: AppState

    private var isLocked: Bool { tier.id > appState.currentTier }
    private var isMastered: Bool {
        tier.skills.allSatisfy { appState.completedLessons.contains($0.id) }
    }
    private var isActive: Bool { !isLocked && !isMastered && tier.id == appState.currentTier }
    private var completedCount: Int {
        tier.skills.filter { appState.completedLessons.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                KingdomScene(tierId: tier.id)
                    .frame(height: 100)

                if isLocked {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 100)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(tier.kingdom)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isLocked ? Color(hex: "#2D2B26").opacity(0.3) : tier.kingdomColor)

            Text("\(tier.name) · Tier \(tier.id)")
                .font(.system(size: 9))
                .foregroundColor(Color(hex: "#999999"))

            Text("\(completedCount)/\(tier.skills.count)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isMastered ? Color(hex: "#D4960A") : Color(hex: "#999999"))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#FAFAF7"))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isActive ? tier.kingdomColor.opacity(0.4) :
                                isMastered ? Color(hex: "#D4960A").opacity(0.4) : Color.clear,
                            lineWidth: isActive || isMastered ? 2 : 0
                        )
                )
        )
        .saturation(isLocked ? 0.3 : 1.0)
        .opacity(isLocked ? 0.6 : 1.0)
    }
}

// MARK: - Kingdom Scene Illustrations

struct KingdomScene: View {
    let tierId: Int

    var body: some View {
        switch tierId {
        case 1: MoltenForgeScene()
        case 2: FrozenSpireScene()
        case 3: EternalGardenScene()
        case 4: StormSummitScene()
        default: EmptyView()
        }
    }
}

struct MoltenForgeScene: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3D2020"), Color(hex: "#5A3028"), Color(hex: "#2D1818")], startPoint: .top, endPoint: .bottom)

            VStack {
                Spacer()
                Ellipse().fill(Color(hex: "#4A2828")).frame(height: 40).offset(y: 12)
            }

            VStack {
                Spacer()
                ZStack(alignment: .top) {
                    Triangle()
                        .fill(LinearGradient(colors: [Color(hex: "#C04830"), Color(hex: "#8A3020")], startPoint: .top, endPoint: .bottom))
                        .frame(width: 120, height: 80)
                    Ellipse().fill(Color(hex: "#FFD040").opacity(0.8)).frame(width: 24, height: 10).offset(y: -2).blur(radius: 3)
                    Ellipse().fill(Color(hex: "#E87850")).frame(width: 28, height: 8)
                }
                .offset(y: 15)
            }

            ForEach(0..<4, id: \.self) { _ in
                Circle()
                    .fill(Color(hex: "#FFD040").opacity(0.5))
                    .frame(width: 3, height: 3)
                    .offset(x: CGFloat.random(in: -50...50), y: CGFloat.random(in: -30...20))
            }
        }
    }
}

struct FrozenSpireScene: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#C0D8E8"), Color(hex: "#D8E8F0"), Color(hex: "#E0ECF4")], startPoint: .top, endPoint: .bottom)

            VStack {
                Spacer()
                Ellipse().fill(Color(hex: "#D8E8F0")).frame(height: 40).offset(y: 12)
            }

            VStack {
                Spacer()
                HStack(spacing: 6) {
                    Triangle().fill(Color(hex: "#6090A8")).frame(width: 18, height: 35)
                    Triangle().fill(LinearGradient(colors: [Color(hex: "#88B8D8"), Color(hex: "#A8D0E8")], startPoint: .top, endPoint: .bottom)).frame(width: 25, height: 55)
                    Triangle().fill(LinearGradient(colors: [Color(hex: "#5090C0"), Color(hex: "#88C0E0")], startPoint: .top, endPoint: .bottom)).frame(width: 32, height: 75)
                    Triangle().fill(LinearGradient(colors: [Color(hex: "#88B8D8"), Color(hex: "#A8D0E8")], startPoint: .top, endPoint: .bottom)).frame(width: 22, height: 50)
                    Triangle().fill(Color(hex: "#6090A8")).frame(width: 16, height: 32)
                }
                .offset(y: 8)
            }

            ForEach(0..<6, id: \.self) { _ in
                Circle().fill(Color.white.opacity(0.7)).frame(width: 3, height: 3)
                    .offset(x: CGFloat.random(in: -60...60), y: CGFloat.random(in: -40...30))
            }
        }
    }
}

struct EternalGardenScene: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#E8D0E8"), Color(hex: "#F0D8E8"), Color(hex: "#F8E8F0")], startPoint: .top, endPoint: .bottom)

            VStack {
                Spacer()
                Ellipse().fill(Color(hex: "#D8C8D8")).frame(height: 40).offset(y: 12)
            }

            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Ellipse().fill(Color(hex: "#E8A0C0")).frame(width: 35, height: 28)
                    VStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#C0A0B8"), lineWidth: 2).frame(width: 36, height: 30)
                        HStack(spacing: 26) {
                            RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#C0A0B8")).frame(width: 4, height: 20)
                            RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#C0A0B8")).frame(width: 4, height: 20)
                        }
                    }
                    Ellipse().fill(Color(hex: "#D090B0")).frame(width: 35, height: 28)
                }
                .offset(y: 2)
            }

            ForEach(0..<6, id: \.self) { _ in
                Circle().fill(Color(hex: "#FFB0C8").opacity(0.5)).frame(width: 4, height: 4)
                    .offset(x: CGFloat.random(in: -50...50), y: CGFloat.random(in: -30...20))
            }
        }
    }
}

struct StormSummitScene: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#708848"), Color(hex: "#90A860"), Color(hex: "#A8C070")], startPoint: .top, endPoint: .bottom)

            VStack {
                Spacer()
                Ellipse().fill(Color(hex: "#708050")).frame(height: 40).offset(y: 12)
            }

            VStack {
                Spacer()
                HStack(spacing: 3) {
                    VStack(spacing: 0) {
                        Triangle().fill(Color(hex: "#607040")).frame(width: 16, height: 10)
                        RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#506030")).frame(width: 12, height: 30)
                    }
                    VStack(spacing: 0) {
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#506030")).frame(width: 5, height: 6)
                            }
                        }
                        RoundedRectangle(cornerRadius: 2).fill(Color(hex: "#607040")).frame(width: 40, height: 36)
                    }
                    VStack(spacing: 0) {
                        Triangle().fill(Color(hex: "#607040")).frame(width: 16, height: 10)
                        RoundedRectangle(cornerRadius: 1).fill(Color(hex: "#506030")).frame(width: 12, height: 30)
                    }
                }
                .offset(y: 3)
            }

            ForEach(0..<3, id: \.self) { _ in
                Capsule().fill(Color.white.opacity(0.15)).frame(width: CGFloat.random(in: 16...30), height: 3)
                    .offset(x: CGFloat.random(in: -40...40), y: CGFloat.random(in: -35...(-5)))
            }
        }
    }
}

// MARK: - Achievements Section

struct AchievementsSection: View {
    @EnvironmentObject var appState: AppState

    private var achievements: [(icon: String, name: String, unlocked: Bool)] {
        [
            ("🏗️", "First Steps", appState.completedLessons.count >= 1),
            ("🌋", "Earth Walker", GameData.skillTiers[0].skills.allSatisfy { appState.completedLessons.contains($0.id) }),
            ("🔥", "On Fire", appState.streak >= 3),
            ("💧", "Water Sage", GameData.skillTiers.count > 1 && GameData.skillTiers[1].skills.allSatisfy { appState.completedLessons.contains($0.id) }),
            ("💎", "Flawless", appState.completedLessons.count >= 5),
            ("🦋", "Social Butterfly", false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACHIEVEMENTS")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                ForEach(0..<achievements.count, id: \.self) { i in
                    let a = achievements[i]
                    HStack(spacing: 6) {
                        Text(a.icon)
                            .font(.system(size: 16))
                            .grayscale(a.unlocked ? 0 : 1)
                            .opacity(a.unlocked ? 1 : 0.4)
                        Text(a.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(a.unlocked ? Color(hex: "#2D2B26") : Color(hex: "#A09B8E"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(a.unlocked ? Color(hex: "#F0FAF4") : Color(hex: "#F8F7F3"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(a.unlocked ? Color(hex: "#6BCB77").opacity(0.3) : Color(hex: "#E8E6E0"), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        )
        .padding(.horizontal, 20)
    }
}
