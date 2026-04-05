import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedChallenge: Challenge? = nil
    @State private var showConfetti = false

    private var availableChallenges: [Challenge] {
        GameData.challenges.filter { challenge in
            let skillId = findSkillId(for: challenge.skillName)
            return appState.completedLessons.contains(skillId) && !appState.completedChallenges.contains(challenge.id)
        }
    }

    private var completedChallengesList: [Challenge] {
        GameData.challenges.filter { appState.completedChallenges.contains($0.id) }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("◆ CODEPET")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(PetCharacter.all[appState.activeChar]?.color ?? .gray)
                        Text("Practice")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color(hex: "#2D2B26"))
                        Text("Complete challenges in real AI tools to prove your skills.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#2D2B26").opacity(0.6))
                    }

                    // Available Challenges
                    if !availableChallenges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("READY TO CHALLENGE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#7B6BD8"))

                            ForEach(availableChallenges) { challenge in
                                ChallengeCard(challenge: challenge, state: .available, onStart: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedChallenge = challenge
                                    }
                                })
                            }
                        }
                    }

                    // Completed Challenges
                    if !completedChallengesList.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COMPLETED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#8B7BE8"))

                            ForEach(completedChallengesList) { challenge in
                                ChallengeCard(challenge: challenge, state: .completed, onStart: {})
                            }
                        }
                    }

                    // Empty state
                    if availableChallenges.isEmpty && completedChallengesList.isEmpty {
                        VStack(spacing: 16) {
                            Text("🎯")
                                .font(.system(size: 40))
                            Text("Complete lessons to unlock challenges")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.5))
                            Text("Challenges appear after you finish a skill lesson. Head to Skills to start learning!")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "#F7F5FC"))
                                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
                        )
                    }

                    // Locked challenges preview
                    let lockedChallenges = GameData.challenges.filter { challenge in
                        let skillId = findSkillId(for: challenge.skillName)
                        return !appState.completedLessons.contains(skillId) && !appState.completedChallenges.contains(challenge.id)
                    }

                    if !lockedChallenges.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LOCKED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "#2D2B26").opacity(0.3))

                            ForEach(lockedChallenges) { challenge in
                                ChallengeCard(challenge: challenge, state: .locked, onStart: {})
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(hex: "#F7F5FC"))

            // Confetti
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }

            // Challenge Overlay (ZStack approach - not .sheet)
            if let challenge = selectedChallenge {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Don't close on backdrop tap during active challenge
                    }

                ChallengeOverlayView(
                    challenge: challenge,
                    difficultyLevel: appState.difficultyLevel,
                    onComplete: { xpEarned, attempt in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if !appState.completedChallenges.contains(challenge.id) {
                                appState.completedChallenges.append(challenge.id)
                                appState.weeklyStats.challengesDone += 1
                            }
                            appState.addXP(xpEarned)
                            // Track performance
                            appState.performanceHistory.append(
                                PerformanceEntry(score: 100, date: Date(), skillId: challenge.id)
                            )
                            selectedChallenge = nil
                            showConfetti = true
                            SoundManager.shared.playSuccess()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                showConfetti = false
                            }
                        }
                    },
                    onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedChallenge = nil
                        }
                    }
                )
                .frame(width: 520, height: 620)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedChallenge != nil)
    }

    private func findSkillId(for skillName: String) -> String {
        for tier in GameData.skillTiers {
            if let skill = tier.skills.first(where: { $0.name == skillName }) {
                return skill.id
            }
        }
        return skillName.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

// MARK: - Challenge Card

enum ChallengeState {
    case available, completed, locked
}

struct ChallengeCard: View {
    let challenge: Challenge
    let state: ChallengeState
    let onStart: () -> Void

    private var teacher: PetCharacter? {
        PetCharacter.all[challenge.teacher]
    }

    var body: some View {
        HStack(spacing: 14) {
            // Badge icon
            ZStack {
                Circle()
                    .fill(state == .locked ? Color(hex: "#DCD8EC") : (teacher?.color ?? .gray).opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(challenge.badge.icon)
                    .font(.system(size: 18))
                    .grayscale(state == .locked ? 1 : 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(challenge.skillName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(state == .locked ? Color(hex: "#2D2B26").opacity(0.35) : Color(hex: "#2D2B26"))

                    if state == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#8B7BE8"))
                    }
                }

                Text(challenge.brief)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(state == .locked ? 0.3 : 0.5))
                    .lineLimit(2)

                if let t = teacher {
                    Text("with \(t.name)")
                        .font(.system(size: 9))
                        .foregroundColor(t.color.opacity(state == .locked ? 0.3 : 0.7))
                }
            }

            Spacer()

            // Action
            if state == .available {
                VStack(spacing: 4) {
                    Button(action: onStart) {
                        Text("Start")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(teacher?.color ?? Color(hex: "#7B6BD8"))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Text("\(challenge.xpReward) XP")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#7B6BD8"))
                }
            } else if state == .completed {
                Text("✓ \(challenge.xpReward) XP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#8B7BE8"))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#2D2B26").opacity(0.2))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#F7F5FC"))
                .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
        )
        .opacity(state == .locked ? 0.6 : 1)
        .saturation(state == .locked ? 0.3 : 1)
    }
}

// MARK: - Full 6-Stage Challenge Overlay

struct ChallengeOverlayView: View {
    let challenge: Challenge
    let difficultyLevel: String
    let onComplete: (_ xpEarned: Int, _ attempt: Int) -> Void
    let onClose: () -> Void

    @State private var stage: Int = 0  // 0=Brief, 1=PickTool, 2=Guidelines, 3=Submit, 4=Review, 5=Result
    @State private var selectedTool: ChallengeTool? = nil
    @State private var submissionText: String = ""
    @State private var showSampleAnswer: Bool = false
    @State private var attempt: Int = 1
    @State private var results: ChallengeResults? = nil

    private let stageLabels = ["Challenge", "Pick Tool", "Guidelines", "Submit", "Review", "Result"]

    private var teacher: PetCharacter? {
        PetCharacter.all[challenge.teacher]
    }

    private var teacherColor: Color {
        teacher?.color ?? Color(hex: "#D89840")
    }

    private var xpMultiplier: Double {
        switch attempt {
        case 1: return 1.0
        case 2: return 0.75
        default: return 0.5
        }
    }

    private var earnedXP: Int {
        Int(Double(challenge.xpReward) * xpMultiplier)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            HStack(spacing: 4) {
                ForEach(0..<6, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < stage ? Color(hex: "#8B7BE8") : (i == stage ? teacherColor : Color(hex: "#E0DDD6")))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Header
            HStack {
                HStack(spacing: 4) {
                    Text("🎯")
                        .font(.system(size: 10))
                    Text(stageLabels[stage].uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(teacherColor)
                    if attempt > 1 {
                        Text("· Attempt \(attempt)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#A09B8E"))
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("+\(earnedXP) XP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#D89840"))

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#B0A898"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            // Teacher avatar
            VStack(spacing: 4) {
                Text(challenge.badge.icon)
                    .font(.system(size: 32))
                if let t = teacher {
                    Text(t.name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(teacherColor)
                }
            }
            .padding(.top, 8)

            // Stage content
            ScrollView {
                VStack(spacing: 0) {
                    switch stage {
                    case 0: briefStage
                    case 1: pickToolStage
                    case 2: guidelinesStage
                    case 3: submitStage
                    case 4: reviewStage
                    case 5: resultStage
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "#F7F5FC"))
    }

    // MARK: - Stage 0: Brief

    private var briefStage: some View {
        VStack(spacing: 14) {
            Text("\(challenge.skillName) Challenge")
                .font(.system(size: 18, weight: .bold))
                .multilineTextAlignment(.center)

            // Difficulty badge
            Text(difficultyBadge)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(difficultyColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(difficultyColor.opacity(0.1))
                )

            // Mission card
            VStack(alignment: .leading, spacing: 8) {
                Text("🎯 YOUR MISSION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(teacherColor)
                Text(challenge.brief)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#444444"))
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#F7F5FC"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#E0DBEF"), lineWidth: 1)
                    )
            )

            // Rewards
            HStack(spacing: 8) {
                Text("\(challenge.xpReward) XP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#B8860B"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#FFF8E8"))
                    )
                Text("\(challenge.badge.icon) \(challenge.badge.name)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "#2E7D32"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#EDEBF7"))
                    )
            }

            Button(action: { withAnimation { stage = 1 } }) {
                Text("Accept Challenge →")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#2D2B26"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    // MARK: - Stage 1: Pick Tool

    private var pickToolStage: some View {
        VStack(spacing: 14) {
            Text("Pick Your Tool")
                .font(.system(size: 18, weight: .bold))
            Text("Which AI tool will you use for this challenge?")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#888888"))

            ForEach(ChallengeTool.all) { tool in
                let isSelected = selectedTool?.id == tool.id
                HStack(spacing: 12) {
                    // Tool icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(tool.color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Text(tool.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(tool.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tool.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#2D2B26"))
                            if tool.recommended {
                                Text("RECOMMENDED")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#D97706"))
                                    .cornerRadius(4)
                            }
                        }
                        Text(tool.desc)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#888888"))
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(tool.color)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? tool.color.opacity(0.06) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? tool.color.opacity(0.4) : Color(hex: "#E0DBEF"), lineWidth: isSelected ? 2 : 1)
                        )
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTool = tool
                    }
                    SoundManager.shared.playTap()
                }
            }

            Button(action: { withAnimation { stage = 2 } }) {
                Text("Continue →")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(selectedTool != nil ? .white : Color(hex: "#B0A898"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTool != nil ? Color(hex: "#2D2B26") : Color(hex: "#E0DDD6"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(selectedTool == nil)
        }
        .padding(.top, 12)
    }

    // MARK: - Stage 2: Guidelines

    private var guidelinesStage: some View {
        VStack(spacing: 14) {
            Text("How to Approach This")
                .font(.system(size: 18, weight: .bold))
            Text("\(teacher?.name ?? "Teacher") prepared building blocks to guide you:")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#888888"))

            // Prompt building blocks
            ForEach(Array(challenge.promptBlocks.enumerated()), id: \.offset) { i, block in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(block.emoji)
                            .font(.system(size: 16))
                        Text("Step \(i + 1): \(block.title)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#2D2B26"))
                    }
                    Text(block.hint)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#555555"))
                        .padding(.leading, 28)
                        .lineSpacing(3)
                    Text(block.example)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#999999"))
                        .italic()
                        .padding(.leading, 28)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#F7F5FC"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#E0DBEF"), lineWidth: 1)
                        )
                )
            }

            // Encouragement
            HStack(spacing: 8) {
                Text("✍️")
                    .font(.system(size: 14))
                Text("Use these steps as a guide, but write everything in your own words. \(teacher?.name ?? "Teacher") reviews your real effort!")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#166534"))
                    .lineSpacing(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#F0FDF4"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#BBF7D0"), lineWidth: 1)
                    )
            )

            // Action buttons
            HStack(spacing: 8) {
                if let tool = selectedTool, let url = tool.url {
                    Link(destination: URL(string: url)!) {
                        Text("Open \(tool.name) ↗")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(tool.color)
                            .cornerRadius(12)
                    }
                }
                Button(action: { withAnimation { stage = 3 } }) {
                    Text("I'm Done → Submit")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#2D2B26"))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Stage 3: Submit

    private var submitStage: some View {
        VStack(spacing: 14) {
            Text("Submit Your Work")
                .font(.system(size: 18, weight: .bold))
            Text("Paste your work below. \(teacher?.name ?? "Teacher") will review it.")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#888888"))

            // Sample answer toggle
            if let sample = challenge.sampleAnswer {
                Button(action: { withAnimation { showSampleAnswer.toggle() } }) {
                    HStack(spacing: 8) {
                        Text("📝")
                            .font(.system(size: 14))
                        Text("Stuck? See a sample answer")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(showSampleAnswer ? teacherColor : Color(hex: "#888888"))

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#B0A898"))
                            .rotationEffect(.degrees(showSampleAnswer ? 180 : 0))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showSampleAnswer ? teacherColor.opacity(0.06) : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(showSampleAnswer ? teacherColor.opacity(0.3) : Color(hex: "#E0DBEF"), lineWidth: 1.5)
                            )
                    )
                }
                .buttonStyle(.plain)

                if showSampleAnswer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("SAMPLE ANSWER")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(teacherColor)
                            Text(sample.topic)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(hex: "#C07030"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#FFE8D0"))
                                .cornerRadius(20)
                        }
                        Text("This is an example for a DIFFERENT topic. Use it to understand the expected format and quality — don't copy it!")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#B0A898"))
                            .italic()

                        Text(sample.text)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#4A4640"))
                            .lineSpacing(4)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: "#F7F5FC"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(hex: "#E8E4DC"), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#F2F0F8"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#E0DBEF"), lineWidth: 1)
                            )
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Retry hints
            if attempt > 1, let res = results {
                let failedIds = res.failedIds
                if !failedIds.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("💡 HINTS FROM \(teacher?.name.uppercased() ?? "TEACHER")")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#E07040"))

                        ForEach(failedIds, id: \.self) { fId in
                            Text("• \(challenge.retryHints[fId] ?? "Check this checkpoint again.")")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#C04020"))
                                .lineSpacing(3)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#FFF3EE"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#FFD0B0"), lineWidth: 1)
                            )
                    )
                }
            }

            // Text area
            TextEditor(text: $submissionText)
                .font(.system(size: 12, design: .monospaced))
                .lineSpacing(4)
                .frame(minHeight: 140)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#F7F5FC"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#E0DDD6"), lineWidth: 1.5)
                        )
                )
                .scrollContentBackground(.hidden)

            HStack {
                Spacer()
                Text("\(submissionText.count) characters")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "#B0A898"))
            }

            Button(action: { evaluateSubmission() }) {
                Text("Submit for Review →")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(submissionText.count > 30 ? .white : Color(hex: "#B0A898"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(submissionText.count > 30 ? Color(hex: "#2D2B26") : Color(hex: "#E0DDD6"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(submissionText.count <= 30)
        }
        .padding(.top, 12)
    }

    // MARK: - Stage 4: Review

    private var reviewStage: some View {
        VStack(spacing: 14) {
            if let res = results {
                Text("\(teacher?.name ?? "Teacher")'s Review")
                    .font(.system(size: 18, weight: .bold))

                // Score emoji
                Text(res.score >= 80 ? "🎉" : (res.score >= 60 ? "🤔" : "😤"))
                    .font(.system(size: 28))

                // Score text
                Text("\(res.score)% — \(res.passedIds.count)/\(challenge.checkpoints.count) checkpoints")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(res.score >= 80 ? Color(hex: "#2E7D32") : (res.score >= 60 ? Color(hex: "#D89840") : Color(hex: "#C04020")))

                // Checkpoint list
                VStack(spacing: 0) {
                    ForEach(Array(challenge.checkpoints.enumerated()), id: \.element.id) { i, cp in
                        let passed = res.passedIds.contains(cp.id)
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(passed ? Color(hex: "#E8F5E9") : Color(hex: "#FFF3EE"))
                                    .frame(width: 22, height: 22)
                                Text(passed ? "✓" : "✗")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(passed ? Color(hex: "#2E7D32") : Color(hex: "#C04020"))
                            }
                            Text(cp.label)
                                .font(.system(size: 11))
                                .foregroundColor(passed ? Color(hex: "#2D2B26") : Color(hex: "#C04020"))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        if i < challenge.checkpoints.count - 1 {
                            Divider().opacity(0.3)
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "#F7F5FC"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#E0DBEF"), lineWidth: 1)
                        )
                )

                // Pass or fail
                if res.score >= 60 {
                    Text(challenge.passFeedback)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#444444"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Button(action: {
                        withAnimation { stage = 5 }
                        SoundManager.shared.playSuccess()
                    }) {
                        Text("Claim Reward! 🎉")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#2E7D32"))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Not quite — you need at least 60% to pass. \(teacher?.name ?? "Teacher") will show you what to fix.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#C04020"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    Button(action: {
                        withAnimation {
                            attempt += 1
                            stage = 3
                        }
                    }) {
                        Text("Retry with Hints →")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(teacherColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Stage 5: Result

    private var resultStage: some View {
        VStack(spacing: 14) {
            Text("Challenge Complete!")
                .font(.system(size: 20, weight: .bold))

            // Badge display
            ZStack {
                Circle()
                    .fill(teacherColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(teacherColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                Text(challenge.badge.icon)
                    .font(.system(size: 44))
            }

            Text("NEW BADGE EARNED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#D97706"))
                .tracking(1)

            Text(challenge.badge.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "#2D2B26"))

            // XP reward
            HStack(spacing: 6) {
                Text("⚡")
                    .font(.system(size: 18))
                Text("+\(earnedXP) XP")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#D89840"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#FFF8E8"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#FFE0A0"), lineWidth: 1.5)
                    )
            )

            if attempt > 1 {
                Text("Attempt \(attempt) · \(Int(xpMultiplier * 100))% XP multiplier")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#B0A898"))
            }

            Button(action: {
                onComplete(earnedXP, attempt)
            }) {
                Text("Done")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#2D2B26"))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var difficultyBadge: String {
        switch difficultyLevel {
        case "easy": return "🌱 Easy Mode"
        case "hard": return "🔥 Hard Mode"
        default: return "⚡ Standard"
        }
    }

    private var difficultyColor: Color {
        switch difficultyLevel {
        case "easy": return Color(hex: "#2E7D32")
        case "hard": return Color(hex: "#C04020")
        default: return Color(hex: "#D89840")
        }
    }

    private func evaluateSubmission() {
        let lowered = submissionText.lowercased()
        var passedIds: [String] = []
        var failedIds: [String] = []

        for cp in challenge.checkpoints {
            let matched = cp.keywords.contains { keyword in
                lowered.contains(keyword.lowercased())
            }
            if matched {
                passedIds.append(cp.id)
            } else {
                failedIds.append(cp.id)
            }
        }

        let score = challenge.checkpoints.isEmpty ? 100 :
            Int(Double(passedIds.count) / Double(challenge.checkpoints.count) * 100)

        results = ChallengeResults(passedIds: passedIds, failedIds: failedIds, score: score)

        withAnimation {
            stage = 4
        }
    }
}

struct ChallengeResults {
    let passedIds: [String]
    let failedIds: [String]
    let score: Int
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, color: Color, rotation: Double, size: CGFloat)] = []
    @State private var animating = false

    var body: some View {
        Canvas { context, size in
            for p in particles {
                var ctx = context
                ctx.translateBy(x: p.x, y: animating ? p.y + 400 : p.y)
                ctx.rotate(by: .degrees(animating ? p.rotation + 360 : p.rotation))
                ctx.fill(
                    Path(CGRect(x: -p.size/2, y: -p.size/2, width: p.size, height: p.size)),
                    with: .color(p.color)
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, Color(hex: "#8B7BE8"), Color(hex: "#D89840")]
            particles = (0..<50).map { i in
                (id: i,
                 x: CGFloat.random(in: 20...500),
                 y: CGFloat.random(in: -50...200),
                 color: colors[i % colors.count],
                 rotation: Double.random(in: 0...360),
                 size: CGFloat.random(in: 4...10))
            }
            withAnimation(.easeIn(duration: 2.5)) {
                animating = true
            }
        }
    }
}

#Preview {
    SessionsView()
        .environmentObject(AppState())
}
