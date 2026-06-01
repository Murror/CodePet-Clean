import SwiftUI

// =============================================================================
// MARK: - CaseStudyCard
// =============================================================================

/// A pixel-art card for a single case study. Colored banner at top with an SF
/// Symbol icon, white body below with title, tags, progress bar. Uses
/// PixelStaircaseRectangle for the chunky border.
struct CaseStudyCard: View {
    let caseStudy: CaseStudy
    let progress: Double
    let completedCount: Int
    var onTap: () -> Void

    private var totalChapters: Int { caseStudy.chapters.count }
    private var isComingSoon: Bool { totalChapters == 0 }
    private var isInProgress: Bool { completedCount > 0 && completedCount < totalChapters }
    private var isComplete: Bool { totalChapters > 0 && completedCount == totalChapters }

    private var tagLine: String {
        let chapterLabel = "\(totalChapters) chapter\(totalChapters == 1 ? "" : "s")"
        let tagStr = caseStudy.tags.joined(separator: ", ")
        return "\(chapterLabel) \u{00B7} \(tagStr)"
    }

    private let borderColor = Color(hex: "#2D2B26")

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // ─────────────────────────────────────────────────────────────
                // Banner (colored area with icon)
                // ─────────────────────────────────────────────────────────────
                ZStack {
                    Color(hex: caseStudy.color)

                    Image(systemName: caseStudy.icon)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(height: 90)

                // ─────────────────────────────────────────────────────────────
                // Body (white area with text)
                // ─────────────────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(caseStudy.title)
                        .font(CodepetTheme.display(14))
                        .foregroundColor(Color(hex: "#2D2B26"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Tags
                    if !isComingSoon {
                        Text(tagLine)
                            .font(CodepetTheme.body(10, weight: .medium))
                            .foregroundColor(CodepetTheme.mutedText)
                            .lineLimit(1)
                    }

                    if isComingSoon {
                        // Coming soon badge
                        comingSoonBadge
                    } else {
                        // Progress bar
                        progressSection
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FDFCFF"))
            }
        }
        .buttonStyle(.plain)
        .background(
            ZStack {
                // Shadow layer
                PixelStaircaseRectangle(blockSize: 3, steps: 2)
                    .fill(borderColor)
                    .offset(x: 3, y: 3)
                // White base
                PixelStaircaseRectangle(blockSize: 3, steps: 2)
                    .fill(Color.white)
            }
        )
        .clipShape(PixelStaircaseRectangle(blockSize: 3, steps: 2))
        .overlay(
            PixelStaircaseRectangle(blockSize: 3, steps: 2)
                .stroke(borderColor, lineWidth: 3)
        )
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    PixelStaircaseRectangle(blockSize: 2, steps: 1)
                        .fill(Color(hex: "#2D2B26").opacity(0.1))
                        .frame(height: 8)

                    PixelStaircaseRectangle(blockSize: 2, steps: 1)
                        .fill(isComplete ? Color(hex: "#029902") : Color(hex: "#7C3AED"))
                        .frame(width: max(geo.size.width * progress, 0), height: 8)
                }
            }
            .frame(height: 8)

            // Progress label + badge
            HStack(spacing: 6) {
                Text("\(completedCount)/\(totalChapters) chapters")
                    .font(CodepetTheme.body(10, weight: .medium))
                    .foregroundColor(CodepetTheme.mutedText)

                Spacer()

                if isInProgress {
                    Text("In progress")
                        .font(CodepetTheme.body(9, weight: .semibold))
                        .foregroundColor(Color(hex: "#7C3AED"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#7C3AED").opacity(0.12))
                        )
                } else if isComplete {
                    Text("Complete")
                        .font(CodepetTheme.body(9, weight: .semibold))
                        .foregroundColor(Color(hex: "#029902"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#029902").opacity(0.12))
                        )
                }
            }
        }
    }

    // MARK: - Coming Soon Badge

    private var comingSoonBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
            Text("Coming soon")
                .font(CodepetTheme.body(11, weight: .semibold))
        }
        .foregroundColor(CodepetTheme.mutedText)
        .padding(.top, 4)
    }
}
