import SwiftUI
import AppKit

/// The live Tips tab — replaces TipsMockupView.
/// Reads real skill progress from TipsState, fetches daily AI guidance
/// via GuidanceEnricher, and renders per-pet content from TipsContent.
/// A setup item computed from real system state.
private struct DynamicSetupItem {
    let title: L10n
    let status: L10n
    let state: TipSetupState
    let actionLabel: L10n?
    let action: SetupAction?

    enum SetupAction {
        case navigateToReflection
    }
}

struct TipsTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tipsState: TipsState
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var hookInstaller: HookInstaller
    @EnvironmentObject var projectStore: ProjectStore
    @Environment(\.uiLanguage) private var uiLanguage

    /// Owned by this view — created once with a fresh API client.
    @StateObject private var guidanceEnricher = GuidanceEnricher(api: ReflectionAPIClient())

    // Learn section navigation

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
                            petMemory: memory,
                            projectStore: projectStore
                        )
                    }
                })
                setupSection
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
        .task {
            // Pass aggregated pet memory for richer AI guidance context.
            // A new app build forces a fresh fetch (replaces the manual reload),
            // otherwise the normal once-per-day cache applies.
            let memory = PetMemoryStore.shared.allMemoryPrompt()
            let isNewBuild = currentBuildSignature != lastBuildSignature
            await guidanceEnricher.fetchIfNeeded(
                tipsState: tipsState,
                narrativeStore: narrativeStore,
                appState: appState,
                petMemory: memory,
                projectStore: projectStore,
                force: isNewBuild
            )
            // Only mark this build as seen once we actually have fresh guidance,
            // so a failed/empty fetch retries on the next visit.
            if isNewBuild, tipsState.currentGuidance?.isFresh == true {
                lastBuildSignature = currentBuildSignature
            }
        }
    }

    // MARK: - Build-change detection

    /// Persisted signature of the build that last refreshed guidance.
    @AppStorage("cp_tips_lastBuildSig") private var lastBuildSignature: String = ""

    /// A signature that changes on every new build. The app executable's
    /// modification date is rewritten on each compile/link, so it's a reliable
    /// "new build" marker without manually bumping the version number.
    private var currentBuildSignature: String {
        if let url = Bundle.main.executableURL,
           let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate {
            return String(Int(date.timeIntervalSince1970))
        }
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
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

    // MARK: - Setup section (dual-mode: app onboarding OR project health)

    /// Whether the generic app-level setup is fully complete.
    private var appSetupComplete: Bool {
        hookInstaller.status == .installed
            && !narrativeStore.narratives.isEmpty
            && !projectStore.projects.isEmpty
            && tipsState.currentGuidance?.isFresh == true
    }

    /// The setup section shows app-level onboarding until all 4 steps are green,
    /// then auto-hides. Project health is now shown in the folder tabs below.
    @ViewBuilder
    private var setupSection: some View {
        if !appSetupComplete {
            appSetupSection
        }
    }

    // ── App-level onboarding (auto-hides when complete) ──────────────

    private var appSetupItems: [DynamicSetupItem] {
        let hooksInstalled = hookInstaller.status == .installed
        let hasNarratives = !narrativeStore.narratives.isEmpty
        let hasProjects = !projectStore.projects.isEmpty
        let hasGuidance = tipsState.currentGuidance?.isFresh == true

        return [
            DynamicSetupItem(
                title: L10n(vi: "Hook phản chiếu", en: "Reflection hooks"),
                status: hooksInstalled
                    ? L10n(vi: "Đã kết nối — đang ghi nhận phiên code", en: "Connected — capturing coding sessions")
                    : L10n(vi: "Chưa cài — CodePet cần hook để theo dõi", en: "Not installed — CodePet needs hooks to track"),
                state: hooksInstalled ? .done : .missing,
                actionLabel: hooksInstalled ? nil : L10n(vi: "Cài đặt", en: "Set up"),
                action: hooksInstalled ? nil : .navigateToReflection
            ),
            DynamicSetupItem(
                title: L10n(vi: "Phiên code đầu tiên", en: "First coding session"),
                status: hasNarratives
                    ? L10n(vi: "Đã ghi nhận \(narrativeStore.narratives.count) lượt", en: "Captured \(narrativeStore.narratives.count) turns")
                    : L10n(vi: "Chưa có phiên nào — hãy code với Claude Code", en: "No sessions yet — code with Claude Code"),
                state: hasNarratives ? .done : .missing,
                actionLabel: hasNarratives ? nil : L10n(vi: "Mở Reflection", en: "Open Reflection"),
                action: hasNarratives ? nil : .navigateToReflection
            ),
            DynamicSetupItem(
                title: L10n(vi: "Phát hiện dự án", en: "Project detected"),
                status: hasProjects
                    ? L10n(vi: "\(projectStore.projects.count) dự án đã nhận diện", en: "\(projectStore.projects.count) project\(projectStore.projects.count == 1 ? "" : "s") detected")
                    : L10n(vi: "Chưa nhận diện — code thêm để phát hiện", en: "Not yet — code more to detect"),
                state: hasProjects ? .done : (hasNarratives ? .warning : .missing),
                actionLabel: nil,
                action: nil
            ),
            DynamicSetupItem(
                title: L10n(vi: "Gợi ý hàng ngày", en: "Daily guidance"),
                status: hasGuidance
                    ? L10n(vi: "Đang hoạt động — gợi ý mới mỗi ngày", en: "Active — fresh tip every day")
                    : L10n(vi: "Cần ít nhất 1 phiên để phân tích", en: "Needs at least 1 session to analyze"),
                state: hasGuidance ? .done : (hasNarratives ? .warning : .missing),
                actionLabel: nil,
                action: nil
            ),
        ]
    }

    private var appSetupSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(text: uiLanguage == .vi ? "Bắt đầu" : "Getting started")
                Spacer()
                let doneCount = appSetupItems.filter { $0.state == .done }.count
                Text(uiLanguage == .vi
                     ? "\(doneCount) / \(appSetupItems.count) hoàn thành"
                     : "\(doneCount) of \(appSetupItems.count) ready")
                    .font(ReflectionTheme.sans(10))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            VStack(spacing: 0) {
                ForEach(Array(appSetupItems.enumerated()), id: \.offset) { index, item in
                    dynamicSetupRow(item)
                    if index < appSetupItems.count - 1 {
                        Rectangle()
                            .fill(ReflectionTheme.borderLight)
                            .frame(height: 1)
                            .padding(.horizontal, 18)
                    }
                }
            }
            .pixelBox(fill: ReflectionTheme.cardBackground)
        }
    }

    private func dynamicSetupRow(_ item: DynamicSetupItem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: item.state.icon)
                .font(.pixelSystem(size: 16, weight: .medium))
                .foregroundColor(item.state.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title(uiLanguage))
                    .font(ReflectionTheme.sans(13, weight: .semibold))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text(item.status(uiLanguage))
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }

            Spacer()

            if let label = item.actionLabel, item.action != nil {
                Button(action: {
                    handleSetupAction(item.action!)
                }) {
                    HStack(spacing: 4) {
                        Text(label(uiLanguage))
                            .font(ReflectionTheme.sans(11, weight: .semibold))
                            .foregroundColor(ReflectionTheme.accent)
                        Image(systemName: "arrow.right")
                            .font(.pixelSystem(size: 9, weight: .semibold))
                            .foregroundColor(ReflectionTheme.accent)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func handleSetupAction(_ action: DynamicSetupItem.SetupAction) {
        switch action {
        case .navigateToReflection:
            appState.selectedTab = .reflection
        }
    }

    // ── Project folders (unified health + reading per project) ────────

    private var healthReports: [ProjectHealthReport] {
        ProjectHealthEngine.evaluateAll(projects: projectStore.projects)
    }

    private var projectFoldersSection: some View {
        ProjectFoldersView(
            projects: projectStore.projects,
            readingGroups: readingGroups,
            healthReports: healthReports,
            uiLanguage: uiLanguage,
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
                                // Open the large practice-workspace modal (MainTabView)
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appState.activeExercise = challenge
                                }
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
