import SwiftUI
import AppKit

/// The live Tips tab — replaces TipsMockupView.
/// Reads real skill progress from TipsState, fetches daily AI guidance
/// via GuidanceEnricher, and renders per-pet content from TipsContent.
struct TipsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tipsState: TipsState
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var projectStore: ProjectStore
    @EnvironmentObject var learnProgress: LearnProgress
    @Environment(\.uiLanguage) private var uiLanguage

    /// Owned by this view — created once with a fresh API client.
    @StateObject private var guidanceEnricher = GuidanceEnricher(api: ReflectionAPIClient())

    // Learn section navigation
    @State private var selectedCaseStudy: CaseStudy? = nil
    @State private var selectedQA: MentorQA? = nil

    private var petName: String {
        PetCharacter.all[appState.activeChar]?.name ?? ReflectionPet.name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header
                GuidanceCardView(onRetry: {
                    Task {
                        let memory = PetMemoryStore.shared.allMemoryPrompt()
                        await guidanceEnricher.fetchIfNeeded(
                            tipsState: tipsState,
                            narrativeStore: narrativeStore,
                            appState: appState,
                            petMemory: memory
                        )
                    }
                }, onRefresh: {
                    Task {
                        let memory = PetMemoryStore.shared.allMemoryPrompt()
                        await guidanceEnricher.fetchIfNeeded(
                            tipsState: tipsState,
                            narrativeStore: narrativeStore,
                            appState: appState,
                            petMemory: memory,
                            force: true
                        )
                    }
                })
                learnFromExpertSection
                projectFoldersSection
                skillsSection
                petNote
                footer
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ReflectionTheme.background)
        .sheet(item: $selectedCaseStudy) { cs in
            CaseStudyDetailView(caseStudy: cs)
                .environmentObject(learnProgress)
        }
        .sheet(item: $selectedQA) { qa in
            MentorQADetailView(qa: qa)
                .environmentObject(learnProgress)
        }
        .task {
            // Pass aggregated pet memory for richer AI guidance context
            let memory = PetMemoryStore.shared.allMemoryPrompt()
            await guidanceEnricher.fetchIfNeeded(
                tipsState: tipsState,
                narrativeStore: narrativeStore,
                appState: appState,
                petMemory: memory
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            PetAvatar(mood: .calm, size: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text(petName)
                    .font(ReflectionTheme.serif(28, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)

                Text(uiLanguage == .vi ? "Mẹo vibe-coding của bạn" : "Your vibe-coding tips")
                    .font(ReflectionTheme.sans(13))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            Spacer()

            progressRing
        }
    }

    private var progressRing: some View {
        let mastered = tipsState.masteredCount(for: appState.activeChar)
        let total = tipsState.totalSkillsPerPet
        let fraction = total > 0 ? CGFloat(mastered) / CGFloat(total) : 0

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(ReflectionTheme.borderLight, lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(ReflectionTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                Text("\(mastered)")
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(uiLanguage == .vi ? "trên \(total)" : "of \(total)")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
                Text(uiLanguage == .vi ? "kỹ năng đã thành thạo" : "skills mastered")
                    .font(ReflectionTheme.sans(11, weight: .semibold))
                    .foregroundColor(ReflectionTheme.primaryText)
            }
        }
    }

    // ── Project folders (unified health + reading per project) ────────

    private var healthReports: [ProjectHealthReport] {
        ProjectHealthEngine.evaluateAll(projects: projectStore.projects)
    }

    // MARK: - Learn from Expert

    private let expert = ExpertContent.experts.first!
    private let caseStudies = ExpertContent.caseStudies
    private let mentorQAs = ExpertContent.mentorQAs

    private var learnFromExpertSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: uiLanguage == .vi ? "Học từ chuyên gia" : "Learn from experts")

            // Expert mini-hero
            PixelCard(fill: Color(hex: expert.avatarColor), borderWidth: 3) {
                HStack(spacing: 12) {
                    ZStack {
                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                            .fill(Color.white)
                        Text(expert.initials)
                            .font(CodepetTheme.pixel(16))
                            .foregroundColor(Color(hex: expert.avatarColor))
                    }
                    .frame(width: 40, height: 40)
                    .overlay(
                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                            .stroke(Color(hex: "#2D2B26"), lineWidth: 2)
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(expert.name)
                            .font(.pixelSystem(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(expert.role)
                            .font(.pixelSystem(size: 10))
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(14)
            }

            // Case study cards — horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(caseStudies) { cs in
                        CaseStudyCard(
                            caseStudy: cs,
                            progress: learnProgress.progress(for: cs),
                            completedCount: learnProgress.completedCount(for: cs)
                        ) {
                            selectedCaseStudy = cs
                        }
                        .frame(width: 240)
                    }
                }
            }

            // Ask expert — compact horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(mentorQAs) { qa in
                        Button(action: { selectedQA = qa }) {
                            HStack(spacing: 8) {
                                Image(systemName: qa.iconName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: qa.iconColor))
                                    .frame(width: 26, height: 26)
                                    .background(
                                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                            .fill(Color(hex: qa.iconColor).opacity(0.12))
                                    )

                                Text(qa.question)
                                    .font(.pixelSystem(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "#2D2B26"))
                                    .lineLimit(1)

                                if learnProgress.readQAIds.contains(qa.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#029902"))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "#2D2B26").opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .fill(Color.white)
                            )
                            .overlay(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .stroke(Color(hex: "#2D2B26"), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var projectFoldersSection: some View {
        ProjectFoldersView(
            projects: projectStore.projects,
            readingGroups: readingGroups,
            healthReports: healthReports,
            uiLanguage: uiLanguage,
            orderedProjectPaths: projectStore.reflectionProjectOrder,
            syncedProjectPath: projectStore.activeProjectPath,
            onFeedToClaude: { item, projectName in
                let title = item.title(uiLanguage)
                let prompt: String
                if let proj = projectName {
                    prompt = uiLanguage == .vi
                        ? "Hãy dạy mình những điểm chính từ \"\(title)\" của \(item.author), liên hệ với dự án \(proj) của mình"
                        : "Teach me the key ideas from \"\(title)\" by \(item.author), connected to my \(proj) project"
                } else {
                    prompt = uiLanguage == .vi
                        ? "Hãy dạy mình những điểm chính từ \"\(title)\" của \(item.author)"
                        : "Teach me the key ideas from \"\(title)\" by \(item.author)"
                }
                appState.pendingChatPrompt = prompt
                appState.selectedTab = .reflection
            },
            onOpenURL: { NSWorkspace.shared.open($0) }
        )
    }

    // MARK: - Skills grid

    private var petSkillTiles: [TipSkillTile]? {
        TipsContent.tipSkillsByPet[appState.activeChar]
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: uiLanguage == .vi ? "Kỹ năng vibe-coding" : "Vibe-coding skills")
                Spacer()
                let mastered = tipsState.masteredCount(for: appState.activeChar)
                Text(uiLanguage == .vi
                     ? "\(mastered) / \(tipsState.totalSkillsPerPet) đã thành thạo"
                     : "\(mastered) of \(tipsState.totalSkillsPerPet) mastered")
                    .font(ReflectionTheme.sans(10))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            if let tiles = petSkillTiles {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                        SkillTileView(
                            petId: appState.activeChar,
                            index: index,
                            tile: tile,
                            onStartChallenge: { challenge in
                                // Set challenge context + prompt — MainTabView opens the chat panel
                                appState.pendingChallengeContext = challenge
                                appState.pendingChatPrompt = challenge.description
                            }
                        )
                    }
                }
            } else {
                // Fallback: pet has no skill tiles defined
                Text(uiLanguage == .vi
                     ? "Kỹ năng cho pet này sẽ sớm được thêm."
                     : "Skills for this pet coming soon.")
                    .font(ReflectionTheme.sans(13))
                    .foregroundColor(ReflectionTheme.mutedText)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pixelBox(fill: ReflectionTheme.cardBackground)
            }
        }
    }

    // MARK: - Reading groups (used by ProjectFoldersView)

    private var readingGroups: [ReadingMatcher.ProjectReadingGroup] {
        ReadingMatcher.match(
            petId: appState.activeChar,
            projects: projectStore.projects
        )
    }

    // MARK: - Pet's note

    private var petNoteText: String {
        if let note = TipsContent.tipPetNoteByPet[appState.activeChar] {
            return note(uiLanguage)
        }
        return uiLanguage == .vi
            ? "Tôi để ý tuần này bạn bỏ qua bước kiểm tra hai lần. Tôi không phán xét — chỉ giữ một tấm gương."
            : "I noticed you skipped validation twice this week. I'm not judging — just holding a mirror."
    }

    private var petNote: some View {
        HStack(alignment: .top, spacing: 14) {
            PetAvatar(mood: .calm, size: 64)

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: uiLanguage == .vi ? "Lời nhắn từ \(petName)" : "A note from \(petName)")
                Text("\u{201C}\(petNoteText)\u{201D}")
                    .font(ReflectionTheme.serif(15))
                    .italic()
                    .foregroundColor(ReflectionTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .pixelBox(fill: ReflectionTheme.cardBackground)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Eyebrow(text: uiLanguage == .vi
                    ? "Mẹo CodePet · v1.0 · đồng hành cùng bạn, không áp đặt bạn."
                    : "CodePet tips · v1.0 · held for you, not over you.")
            Spacer()
        }
        .padding(.top, 12)
    }

}
