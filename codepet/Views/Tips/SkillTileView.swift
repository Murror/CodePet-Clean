import SwiftUI

/// Redesigned skill tile — bold brand colors, AI-detected practice evidence,
/// and suggested next learning activities. Inspired by vibrant card-based UIs.
struct SkillTileView: View {
    @EnvironmentObject var tipsState: TipsState
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var learnProgress: LearnProgress
    @Environment(\.uiLanguage) private var uiLanguage

    let petId: String
    let index: Int
    let tile: TipSkillTile

    var onOpenChapter: ((CaseStudy, Chapter) -> Void)?

    private var progress: SkillProgress {
        tipsState.progress(for: petId, index: index)
    }

    private let dark = Color(hex: "#2D2B26")

    // ── Brand color per skill ──
    private var skillColor: Color {
        let colors = [
            Color(hex: "#9538CF"),  // Purple — component composition
            Color(hex: "#1C40CF"),  // Blue — loading & error states
            Color(hex: "#029902"),  // Green — form validation
            Color(hex: "#F58345"),  // Orange — accessibility
        ]
        return colors[index % colors.count]
    }

    private var skillColorLight: Color {
        let colors = [
            Color(hex: "#EEEDFE"),
            Color(hex: "#E6F1FB"),
            Color(hex: "#E1F5EE"),
            Color(hex: "#FAECE7"),
        ]
        return colors[index % colors.count]
    }

    private var skillId: String {
        let ids = ["component_composition", "loading_error_states", "form_validation_ux", "accessibility_basics"]
        guard index < ids.count else { return "" }
        return ids[index]
    }

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
            // ── Colored banner with icon ──
            ZStack {
                skillColor

                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 60, height: 60)
                    .offset(x: -40, y: -20)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 40, height: 40)
                    .offset(x: 50, y: 15)

                HStack {
                    // Icon in white pixel square
                    ZStack {
                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                            .fill(Color.white)
                        Image(systemName: tile.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(skillColor)
                    }
                    .frame(width: 36, height: 36)
                    .overlay(
                        PixelStaircaseRectangle(blockSize: 2, steps: 1)
                            .stroke(dark, lineWidth: 2)
                    )

                    Spacer()

                    // Progress dots (on banner)
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { dotIndex in
                            Circle()
                                .fill(dotIndex < progress.practiceCount
                                      ? Color.white
                                      : Color.white.opacity(0.25))
                                .frame(width: 7, height: 7)
                        }
                    }

                    // Score or mastered badge
                    if progress.isMastered {
                        Text(uiLanguage == .vi ? "Thành thạo" : "Mastered")
                            .font(.pixelSystem(size: 9, weight: .bold))
                            .foregroundColor(skillColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .fill(Color.white)
                            )
                            .overlay(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .stroke(dark, lineWidth: 1.5)
                            )
                    } else {
                        Text("\(progress.practiceCount)/5")
                            .font(.pixelSystem(size: 11, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 60)
            .clipped()

            // ── Body: title + evidence + next ──
            VStack(alignment: .leading, spacing: 0) {
                // Title
                Text(tile.title(uiLanguage))
                    .font(.pixelSystem(size: 14, weight: .bold))
                    .foregroundColor(dark)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                // Hint
                Text(tile.hint(uiLanguage))
                    .font(.pixelSystem(size: 10))
                    .foregroundColor(dark.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                // ── Evidence or empty state ──
                if recentEvidence.isEmpty {
                    emptyState
                } else {
                    evidenceSection
                }

                // ── Up next ──
                if !progress.isMastered && !relatedChapters.isEmpty {
                    upNextSection
                        .padding(.top, 8)
                }
            }
            .padding(14)
            .background(Color(hex: "#FDFCFF"))
        }
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
    }

    // MARK: - Evidence Section

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(
                text: progress.isMastered
                    ? (uiLanguage == .vi ? "Lịch sử" : "History")
                    : (uiLanguage == .vi ? "Gần đây" : "Recent")
            )

            ForEach(Array(recentEvidence.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(skillColor)
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.evidence)
                            .font(.pixelSystem(size: 10))
                            .foregroundColor(dark.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)

                        Text(relativeDate(item.date))
                            .font(.pixelSystem(size: 8))
                            .foregroundColor(dark.opacity(0.35))
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(skillColor.opacity(0.6))

            Text(emptyPrompt)
                .font(.pixelSystem(size: 10))
                .foregroundColor(dark.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(skillColorLight.opacity(0.5))
        )
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
                : "Add try-catch or a loading spinner and Codepet will notice."
        case "form_validation_ux":
            return uiLanguage == .vi
                ? "Thêm validation cho form và Codepet sẽ nhận ra."
                : "Add validation to any form and Codepet will notice."
        case "accessibility_basics":
            return uiLanguage == .vi
                ? "Thêm alt text hoặc keyboard nav và Codepet sẽ nhận ra."
                : "Add alt text or keyboard nav and Codepet will notice."
        default:
            return uiLanguage == .vi
                ? "Code thêm và Codepet sẽ phát hiện kỹ năng này."
                : "Keep coding and Codepet will detect this skill."
        }
    }

    // MARK: - Up Next

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel(text: uiLanguage == .vi ? "Bước tiếp" : "Up next")

            ForEach(relatedChapters.prefix(1), id: \.chapter.id) { cs, ch in
                Button(action: { onOpenChapter?(cs, ch) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                PixelStaircaseRectangle(blockSize: 2, steps: 1)
                                    .fill(skillColor)
                            )

                        Text(ch.title)
                            .font(.pixelSystem(size: 10, weight: .medium))
                            .foregroundColor(dark)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(dark.opacity(0.3))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(skillColorLight.opacity(0.5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(text: String) -> some View {
        Text(text.uppercased())
            .font(.pixelSystem(size: 8, weight: .bold))
            .tracking(0.8)
            .foregroundColor(dark.opacity(0.35))
            .padding(.bottom, 3)
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
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
