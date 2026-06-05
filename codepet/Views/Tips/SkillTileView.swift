import SwiftUI

/// Skill tile — bold brand color, exercises to practice, AI-detected evidence.
struct SkillTileView: View {
    @EnvironmentObject var tipsState: TipsState
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var challengeProgress: ChallengeProgress
    @Environment(\.uiLanguage) private var uiLanguage

    let petId: String
    let index: Int
    let tile: TipSkillTile
    var onStartChallenge: ((SkillChallenge) -> Void)? = nil

    @State private var selectedChallenge: SkillChallenge? = nil

    private var progress: SkillProgress {
        tipsState.progress(for: petId, index: index)
    }

    private let dark = Color(hex: "#2D2B26")

    private var skillColor: Color {
        [Color(hex: "#9538CF"), Color(hex: "#1C40CF"), Color(hex: "#029902"),
         Color(hex: "#F58345"), Color(hex: "#0EA5A5"), Color(hex: "#E0457B")][index % 6]
    }

    private var skillColorLight: Color {
        [Color(hex: "#EEEDFE"), Color(hex: "#E6F1FB"), Color(hex: "#E1F5EE"),
         Color(hex: "#FAECE7"), Color(hex: "#E2F6F6"), Color(hex: "#FBE9F0")][index % 6]
    }

    private var skillId: String {
        ["component_composition", "loading_error_states", "form_validation_ux",
         "accessibility_basics", "responsive_layout", "performance"][index % 6]
    }

    /// Active (incomplete) challenges for this skill.
    private var activeChallenges: [SkillChallenge] {
        challengeProgress.activeChallenges(for: skillId)
    }

    /// Completed challenges for this skill.
    private var completedChallenges: [SkillChallenge] {
        challengeProgress.completedChallenges(for: skillId)
    }

    /// Most recent evidence from AI detection.
    private var latestEvidence: String? {
        narrativeStore.narratives.values
            .sorted { $0.generatedAt > $1.generatedAt }
            .flatMap { $0.detectedSkills.filter { $0.skillId == skillId && $0.confidence == "strong" } }
            .first?.evidence
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Colored banner ──
            ZStack {
                skillColor

                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 60, height: 60)
                    .offset(x: -40, y: -15)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                    .offset(x: 50, y: 10)

                HStack {
                    ZStack {
                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                            .fill(Color.white)
                        Image(systemName: tile.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(skillColor)
                    }
                    .frame(width: 40, height: 40)
                    .overlay(
                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                            .stroke(dark, lineWidth: 2)
                    )

                    Spacer()

                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle()
                                .fill(i < progress.practiceCount ? Color.white : Color.white.opacity(0.25))
                                .frame(width: 8, height: 8)
                        }
                    }

                    if progress.isMastered {
                        Text("Mastered")
                            .font(.pixelSystem(size: 10, weight: .bold))
                            .foregroundColor(skillColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .fill(Color.white)
                            )
                            .overlay(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .stroke(dark, lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 64)
            .clipped()

            // ── Body ──
            VStack(alignment: .leading, spacing: 10) {
                Text(tile.title(uiLanguage))
                    .font(.pixelSystem(size: 16, weight: .bold))
                    .foregroundColor(dark)

                // Evidence from AI detection
                if let evidence = latestEvidence {
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(skillColor)
                            .frame(width: 5, height: 5)
                            .padding(.top, 5)
                        Text(evidence)
                            .font(.pixelSystem(size: 11))
                            .foregroundColor(dark.opacity(0.6))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // ── Challenges ──
                if !activeChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(uiLanguage == .vi ? "BÀI TẬP" : "EXERCISES")
                            .font(.pixelSystem(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(dark.opacity(0.35))

                        ForEach(activeChallenges.prefix(2)) { challenge in
                            challengeRow(challenge)
                        }
                    }
                } else if !progress.isMastered && completedChallenges.isEmpty {
                    // No challenges generated yet
                    Text(uiLanguage == .vi ? "Codepet sẽ nhận ra khi bạn luyện tập" : "Codepet will notice when you practice this")
                        .font(.pixelSystem(size: 11))
                        .foregroundColor(dark.opacity(0.35))
                }

                // Completed challenges count
                if !completedChallenges.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#029902"))
                        Text(uiLanguage == .vi
                             ? "\(completedChallenges.count) bài tập hoàn thành"
                             : "\(completedChallenges.count) exercise\(completedChallenges.count == 1 ? "" : "s") completed")
                            .font(.pixelSystem(size: 10))
                            .foregroundColor(dark.opacity(0.45))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#FDFCFF"))
        }
        .frame(maxWidth: .infinity)
        .background(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .fill(dark)
                .offset(x: 3, y: 3)
        )
        .background(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .fill(Color.white)
        )
        .clipShape(PixelStaircaseRectangle(blockSize: 3, steps: 2))
        .overlay(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .stroke(dark, lineWidth: 3)
        )
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailView(
                challenge: challenge,
                skillColor: skillColor,
                isCompleted: challengeProgress.isCompleted(challenge.id),
                onStartCoding: {
                    onStartChallenge?(challenge)
                }
            )
        }
    }

    // MARK: - Challenge Row

    private func challengeRow(_ challenge: SkillChallenge) -> some View {
        Button(action: { selectedChallenge = challenge }) {
            HStack(spacing: 8) {
                difficultyIcon(challenge.difficulty)

                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.pixelSystem(size: 11, weight: .bold))
                        .foregroundColor(dark)
                        .lineLimit(1)

                    Text(challenge.description)
                        .font(.pixelSystem(size: 10))
                        .foregroundColor(dark.opacity(0.5))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(dark.opacity(0.25))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(skillColorLight.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(skillColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func difficultyIcon(_ difficulty: SkillChallenge.ChallengeDifficulty) -> some View {
        let (icon, color): (String, Color) = {
            switch difficulty {
            case .starter:  return ("star", Color(hex: "#029902"))
            case .practice: return ("star.leadinghalf.filled", Color(hex: "#D49700"))
            case .stretch:  return ("star.fill", Color(hex: "#E24B4A"))
            case .expert:   return ("crown.fill", Color(hex: "#7B3FE4"))
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.12))
            )
    }
}
