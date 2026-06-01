import SwiftUI

// =============================================================================
// MARK: - LearnTabView
// =============================================================================

/// Main tab view for the Learn section. Displays the expert hero, a 2-column
/// grid of case study cards, and a list of mentor Q&A entries.
struct LearnTabView: View {
    @EnvironmentObject var learnProgress: LearnProgress

    // Navigation state
    @State private var selectedCaseStudy: CaseStudy? = nil
    @State private var selectedQA: MentorQA? = nil

    // Data
    private let expert = ExpertContent.experts.first!
    private let caseStudies = ExpertContent.caseStudies
    private let mentorQAs = ExpertContent.mentorQAs

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Color(hex: "#F7F5FC")
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // ─────────────────────────────────────────────────────────
                    // Expert Hero
                    // ─────────────────────────────────────────────────────────
                    expertHeroSection

                    // ─────────────────────────────────────────────────────────
                    // Case Studies
                    // ─────────────────────────────────────────────────────────
                    sectionEyebrow(icon: "hammer.fill", label: "BUILD-ALONG CASE STUDIES")

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(caseStudies) { cs in
                            CaseStudyCard(
                                caseStudy: cs,
                                progress: learnProgress.progress(for: cs),
                                completedCount: learnProgress.completedCount(for: cs)
                            ) {
                                selectedCaseStudy = cs
                            }
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // Mentor Q&A
                    // ─────────────────────────────────────────────────────────
                    sectionEyebrow(icon: "bubble.left.and.bubble.right.fill", label: "ASK ASTRO")

                    VStack(spacing: 14) {
                        ForEach(mentorQAs) { qa in
                            MentorQACard(qa: qa, isRead: learnProgress.readQAIds.contains(qa.id)) {
                                selectedQA = qa
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
        }
        .sheet(item: $selectedCaseStudy) { cs in
            CaseStudyDetailView(caseStudy: cs)
                .environmentObject(learnProgress)
        }
        .sheet(item: $selectedQA) { qa in
            MentorQADetailView(qa: qa)
                .environmentObject(learnProgress)
        }
    }

    // MARK: - Expert Hero Section

    private var expertHeroSection: some View {
        HStack(spacing: 16) {
            // Avatar — colored square with initials, pixel-art border
            ZStack {
                PixelStaircaseRectangle(blockSize: 3, steps: 2)
                    .fill(Color(hex: expert.avatarColor))
                    .frame(width: 64, height: 64)

                Text(expert.initials)
                    .font(CodepetTheme.pixel(22))
                    .foregroundColor(.white)
            }
            .overlay(
                PixelStaircaseRectangle(blockSize: 3, steps: 2)
                    .stroke(Color(hex: "#2D2B26"), lineWidth: 3)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(expert.name)
                    .font(CodepetTheme.display(20))
                    .foregroundColor(Color(hex: "#2D2B26"))

                Text(expert.role)
                    .font(CodepetTheme.body(12, weight: .medium))
                    .foregroundColor(CodepetTheme.mutedText)

                Text(expert.bio)
                    .font(CodepetTheme.body(13))
                    .foregroundColor(CodepetTheme.bodyText)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .pixelBox(
            fill: .white,
            borderColor: Color(hex: "#2D2B26"),
            shadowOffset: 3,
            blockSize: 3,
            steps: 2,
            borderWidth: 3
        )
    }

    // MARK: - Section Eyebrow

    private func sectionEyebrow(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(CodepetTheme.mutedText)

            Text(label)
                .font(CodepetTheme.body(10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(CodepetTheme.mutedText)
        }
        .padding(.top, 4)
    }
}
