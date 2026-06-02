import SwiftUI

/// Redesigned skill tile — shows AI-detected practice evidence and
/// suggested next learning activities. No manual "Mark practiced" button.
struct SkillTileView: View {
    @EnvironmentObject var tipsState: TipsState
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var learnProgress: LearnProgress
    @Environment(\.uiLanguage) private var uiLanguage

    let petId: String
    let index: Int
    let tile: TipSkillTile

    /// Called when user taps a case study chapter link.
    var onOpenChapter: ((CaseStudy, Chapter) -> Void)?

    private var progress: SkillProgress {
        tipsState.progress(for: petId, index: index)
    }

    private let dark = Color(hex: "#2D2B26")

    /// The AI skill ID that maps to this tile index.
    private var skillId: String {
        let ids = ["component_composition", "loading_error_states", "form_validation_ux", "accessibility_basics"]
        guard index < ids.count else { return "" }
        return ids[index]
    }

    /// Recent narratives that detected this skill, sorted most recent first.
    private var recentEvidence: [(evidence: String, date: Date)] {
        narrativeStore.narratives.values
            .sorted { $0.generatedAt > $1.generatedAt }
            .flatMap { narrative in
                narrative.detectedSkills
                    .filter { $0.skillId == skillId && $0.confidence == "strong" }
                    .map { (evidence: $0.evidence, date: narrative.generatedAt) }
            }
            .prefix(3)
            .map { $0 }
    }

    /// Case study chapters that teach this skill.
    private var relatedChapters: [(caseStudy: CaseStudy, chapter: Chapter)] {
        let mapping: [String: [String]] = [
            "component_composition": ["cs_codepet_mvp_ch2"],
            "loading_error_states": ["cs_codepet_mvp_ch5"],
            "form_validation_ux": ["cs_codepet_mvp_ch4"],
            "accessibility_basics": ["cs_codepet_mvp_ch3"]
        ]
        guard let chapterIds = mapping[skillId] else { return [] }
        var results: [(CaseStudy, Chapter)] = []
        for cs in ExpertContent.caseStudies {
            for ch in cs.chapters where chapterIds.contains(ch.id) {
                if !learnProgress.completedChapterIds.contains(ch.id) {
                    results.append((cs, ch))
                }
            }
        }
        return results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header: icon + title + score ──
            HStack(spacing: 8) {
                Image(systemName: tile.icon)
                    .font(.pixelSystem(size: 16, weight: .medium))
                    .foregroundColor(progress.isMastered ? ReflectionTheme.brandGreen : ReflectionTheme.accent)

                Text(tile.title(uiLanguage))
                    .font(.pixelSystem(size: 14, weight: .bold))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                if progress.isMastered {
                    Text(uiLanguage == .vi ? "Thành thạo" : "Mastered")
                        .font(.pixelSystem(size: 10, weight: .bold))
                        .foregroundColor(ReflectionTheme.brandGreen)
                } else {
                    Text("\(progress.practiceCount)/5")
                        .font(.pixelSystem(size: 11))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
            }
            .padding(.bottom, 6)

            // Hint
            Text(tile.hint(uiLanguage))
                .font(.pixelSystem(size: 11))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            // Progress dots
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { dotIndex in
                    Circle()
                        .fill(dotIndex < progress.practiceCount
                              ? (progress.isMastered ? ReflectionTheme.brandGreen : ReflectionTheme.accent)
                              : ReflectionTheme.borderLight)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 12)

            // ── Divider ──
            Rectangle()
                .fill(dark.opacity(0.08))
                .frame(height: 1)
                .padding(.bottom, 10)

            // ── Evidence or empty state ──
            if recentEvidence.isEmpty {
                emptyState
            } else {
                evidenceSection
            }

            // ── Up next (if not mastered) ──
            if !progress.isMastered && !relatedChapters.isEmpty {
                upNextSection
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .pixelBox(fill: ReflectionTheme.cardBackground)
    }

    // MARK: - Evidence Section

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(
                text: progress.isMastered
                    ? (uiLanguage == .vi ? "Lịch sử luyện tập" : "Practice history")
                    : (uiLanguage == .vi ? "Luyện tập gần đây" : "Recent practice")
            )

            ForEach(Array(recentEvidence.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(progress.isMastered ? ReflectionTheme.brandGreen : ReflectionTheme.accent)
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.evidence)
                            .font(.pixelSystem(size: 11))
                            .foregroundColor(ReflectionTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(relativeDate(item.date))
                            .font(.pixelSystem(size: 9))
                            .foregroundColor(ReflectionTheme.mutedText)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel(text: uiLanguage == .vi ? "Chưa phát hiện luyện tập" : "No practice detected yet")

            Text(emptyPrompt)
                .font(.pixelSystem(size: 10))
                .foregroundColor(ReflectionTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyPrompt: String {
        switch skillId {
        case "component_composition":
            return uiLanguage == .vi
                ? "Tách code thành file nhỏ hơn và Codepet sẽ nhận ra."
                : "Split your code into smaller files and Codepet will notice."
        case "loading_error_states":
            return uiLanguage == .vi
                ? "Thêm try-catch hoặc loading spinner và Codepet sẽ nhận ra."
                : "Add a try-catch or loading spinner and Codepet will notice."
        case "form_validation_ux":
            return uiLanguage == .vi
                ? "Thêm validation cho form và Codepet sẽ nhận ra."
                : "Add validation to any form and Codepet will notice."
        case "accessibility_basics":
            return uiLanguage == .vi
                ? "Thêm alt text hoặc keyboard nav và Codepet sẽ nhận ra."
                : "Add alt text or keyboard navigation and Codepet will notice."
        default:
            return uiLanguage == .vi
                ? "Code thêm và Codepet sẽ phát hiện kỹ năng này."
                : "Keep coding and Codepet will detect this skill."
        }
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel(text: uiLanguage == .vi ? "Bước tiếp theo" : "Up next")

            ForEach(relatedChapters.prefix(1), id: \.chapter.id) { cs, ch in
                Button(action: { onOpenChapter?(cs, ch) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(ReflectionTheme.accent)

                        Text(ch.title)
                            .font(.pixelSystem(size: 11))
                            .foregroundColor(ReflectionTheme.primaryText)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(ReflectionTheme.mutedText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ReflectionTheme.accent.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(text: String) -> some View {
        Text(text.uppercased())
            .font(.pixelSystem(size: 9, weight: .bold))
            .tracking(0.8)
            .foregroundColor(ReflectionTheme.mutedText)
            .padding(.bottom, 4)
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return uiLanguage == .vi ? "Hôm nay, \(fmt.string(from: date))" : "Today, \(fmt.string(from: date))"
        }
        if cal.isDateInYesterday(date) {
            return uiLanguage == .vi ? "Hôm qua" : "Yesterday"
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}
