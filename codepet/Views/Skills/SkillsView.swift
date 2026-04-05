import SwiftUI

struct SkillsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedLesson: Lesson? = nil
    @Binding var showCompanion: Bool

    private var nextSkill: Skill? {
        for tier in GameData.skillTiers {
            if tier.id > appState.currentTier { break }
            for skill in tier.skills {
                if !appState.completedLessons.contains(skill.id) {
                    return skill
                }
            }
        }
        return nil
    }

    private var nextTier: SkillTier? {
        GameData.skillTiers.first { tier in
            tier.skills.contains { !appState.completedLessons.contains($0.id) }
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Main Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("◆ CODEPET")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundColor(PetCharacter.all[appState.activeChar]?.color ?? .gray)
                            Text("Your Skills")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                            Text("Learn the skills you need to build with AI – one lesson at a time.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                        }

                        // Level Progress Card
                        LevelProgressCard()

                        // Start Here
                        if let skill = nextSkill, let tier = nextTier {
                            StartHereCard(skill: skill, tier: tier, onStart: {
                                openLesson(for: skill)
                            })
                        }

                        // Learning Path
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR LEARNING PATH")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))

                            ForEach(GameData.skillTiers) { tier in
                                KingdomSectionView(tier: tier, onStartLesson: { skill in
                                    openLesson(for: skill)
                                })
                            }
                        }
                    }
                    .padding(24)
                }
                .background(Color(hex: "#FBF9F1"))

                // Companion Panel
                if showCompanion {
                    CompanionPanelView(onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCompanion = false
                        }
                    })
                    .frame(width: 280)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            // Lesson Overlay
            if let lesson = selectedLesson {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { selectedLesson = nil }

                LessonModalView(lesson: lesson, onComplete: { xp in
                    withAnimation(.easeOut(duration: 0.2)) {
                        appState.addXP(xp)
                        if !appState.completedLessons.contains(lesson.id) {
                            appState.completedLessons.append(lesson.id)
                        }
                        appState.checkTierProgression()
                        selectedLesson = nil
                    }
                }, onClose: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedLesson = nil
                    }
                })
                .frame(width: 560, height: 620)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedLesson != nil)
    }

    private func openLesson(for skill: Skill) {
        if let lesson = LessonLibrary.all[skill.id] {
            selectedLesson = lesson
            SoundManager.shared.playTap()
        }
    }
}

// MARK: - Level Progress Card

struct LevelProgressCard: View {
    @EnvironmentObject var appState: AppState

    private var xpForLevel: Int { appState.userLevel * 100 }
    private var xpPrev: Int { (appState.userLevel - 1) * 100 }
    private var xpInLevel: Int { appState.totalXP - xpPrev }
    private var xpNeeded: Int { xpForLevel - xpPrev }
    private var xpPct: Double { min(1.0, Double(xpInLevel) / Double(max(1, xpNeeded))) }

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(PetCharacter.all[appState.activeChar]?.color ?? .gray)
                .frame(width: 48, height: 48)
                .overlay(
                    Text("\(appState.userLevel)")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Level \(appState.userLevel) – \(levelTitle)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#2D2B26"))

                Text("\(xpInLevel) / \(xpNeeded) XP • Complete your \(ordinalLesson) lesson!")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#EBE8DF"))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(PetCharacter.all[appState.activeChar]?.color ?? .gray)
                            .frame(width: geo.size.width * xpPct)
                            .animation(.spring(response: 0.5), value: xpPct)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private var levelTitle: String {
        switch appState.userLevel {
        case 1: return "Just Getting Started"
        case 2: return "Finding Your Feet"
        case 3...5: return "Building Momentum"
        case 6...9: return "Getting Confident"
        case 10...14: return "Skilled Builder"
        case 15...19: return "Advanced Crafter"
        case 20...29: return "Expert Navigator"
        default: return "AI Master"
        }
    }

    private var ordinalLesson: String {
        let count = appState.completedLessons.count + 1
        switch count {
        case 1: return "first"
        case 2: return "second"
        case 3: return "third"
        default: return "\(count)th"
        }
    }
}

// MARK: - Start Here Card

struct StartHereCard: View {
    let skill: Skill
    let tier: SkillTier
    let onStart: () -> Void

    private var teacher: PetCharacter? {
        if let lesson = LessonLibrary.all[skill.id] {
            return PetCharacter.all[lesson.teacher]
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("START HERE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#D4960A"))

            HStack(spacing: 16) {
                if let t = teacher {
                    VStack(spacing: 4) {
                        CharacterImage(t.id, size: 56)
                            .charIdle(t.id)
                            .petBreathing()
                        Text(t.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(t.color)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("TIER \(tier.id)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tier.kingdomColor)
                            .cornerRadius(4)
                        Text(LessonLibrary.all[skill.id]?.duration ?? "3 min")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                    }

                    Text(skill.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color(hex: "#2D2B26"))

                    Text(skill.desc)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                        .lineLimit(2)

                    Button(action: onStart) {
                        Text("Start lesson →")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#2D2B26"))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#D4960A").opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

// MARK: - Kingdom Section

struct KingdomSectionView: View {
    let tier: SkillTier
    let onStartLesson: (Skill) -> Void
    @EnvironmentObject var appState: AppState

    private var completedCount: Int {
        tier.skills.filter { appState.completedLessons.contains($0.id) }.count
    }

    private var isLocked: Bool { tier.id > appState.currentTier }

    private var nextSkillIndex: Int? {
        tier.skills.firstIndex { !appState.completedLessons.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(tier.kingdomColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("\(tier.id)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    )
                Text(tier.kingdom)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isLocked ? Color(hex: "#2D2B26").opacity(0.35) : Color(hex: "#2D2B26"))
                Spacer()

                // Navigate to kingdom on World Map
                if !isLocked {
                    Button(action: {
                        SoundManager.shared.playTap()
                        appState.pendingKingdomId = tier.id
                        appState.selectedTab = .home
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 9))
                            Text("View Kingdom")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(tier.kingdomColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(tier.kingdomColor.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("\(completedCount) / \(tier.skills.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(completedCount == tier.skills.count ? Color(hex: "#D4960A") : .gray)
            }

            ForEach(Array(tier.skills.enumerated()), id: \.element.id) { index, skill in
                let isCompleted = appState.completedLessons.contains(skill.id)
                let isNext = !isLocked && index == nextSkillIndex
                let isSkillLocked = isLocked || (!isCompleted && index != nextSkillIndex && (nextSkillIndex == nil || index > nextSkillIndex!))

                SkillRowView(
                    skill: skill,
                    index: index + 1,
                    isCompleted: isCompleted,
                    isNext: isNext,
                    isLocked: isSkillLocked,
                    tierColor: tier.kingdomColor,
                    teacher: LessonLibrary.all[skill.id]?.teacher,
                    onStart: { onStartLesson(skill) }
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        )
        .opacity(isLocked ? 0.5 : 1)
        .saturation(isLocked ? 0.3 : 1)
    }
}

// MARK: - Skill Row

struct SkillRowView: View {
    let skill: Skill
    let index: Int
    let isCompleted: Bool
    let isNext: Bool
    let isLocked: Bool
    let tierColor: Color
    let teacher: String?
    let onStart: () -> Void

    private var teacherChar: PetCharacter? {
        if let t = teacher { return PetCharacter.all[t] }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isCompleted ? Color(hex: "#6BCB77") : (isNext ? tierColor : Color(hex: "#E8E6E0")))
                .frame(width: 30, height: 30)
                .overlay(
                    Group {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(index)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isNext ? .white : .gray)
                        }
                    }
                )

            if let t = teacherChar {
                CharacterImage(t.id, size: 28)
                    .charIdle(t.id)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isLocked ? Color(hex: "#2D2B26").opacity(0.35) : Color(hex: "#2D2B26"))
                if let t = teacherChar {
                    Text("with \(t.name)")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                }
                if isLocked && !isCompleted {
                    Text("Unlocks after \(previousSkillName)")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.3))
                }
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "#6BCB77"))
                    .font(.system(size: 16))
            } else if isNext {
                Button(action: onStart) {
                    Text("Start →")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(tierColor)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.2))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isNext ? tierColor.opacity(0.06) : Color.clear)
                .overlay(
                    isNext ? RoundedRectangle(cornerRadius: 12).stroke(tierColor.opacity(0.2), lineWidth: 1) : nil
                )
        )
    }

    private var previousSkillName: String {
        for tier in GameData.skillTiers {
            if let idx = tier.skills.firstIndex(where: { $0.id == skill.id }), idx > 0 {
                return tier.skills[idx - 1].name
            }
        }
        return "previous lesson"
    }
}

#Preview {
    SkillsView(showCompanion: .constant(true))
        .environmentObject(AppState())
}
