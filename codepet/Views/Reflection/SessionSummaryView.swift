import SwiftUI

/// Session-level summary + lesson card shown at the bottom of a session body.
struct SessionSummaryView: View {
    let summary: SessionSummary?
    var onTriggerSummary: () -> Void = {}

    var body: some View {
        if let summary = summary {
            readyCard(summary: summary)
        } else {
            loadingCard
        }
    }

    // MARK: - Ready state

    private func readyCard(summary: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dividerLine

            VStack(alignment: .leading, spacing: 20) {
                // Summary section
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(ReflectionTheme.accent)
                        Text("TÓM TẮT PHIÊN")
                            .font(ReflectionTheme.sans(11, weight: .semibold))
                            .tracking(1.2)
                            .foregroundColor(ReflectionTheme.accent)
                    }
                    Text(summary.summary)
                        .font(ReflectionTheme.serif(14))
                        .foregroundColor(ReflectionTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                // Lesson section
                if !summary.lesson.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(ReflectionTheme.accent)
                            Text("BÀI HỌC PHIÊN")
                                .font(ReflectionTheme.sans(11, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(ReflectionTheme.accent)
                        }
                        Text(summary.lesson)
                            .font(ReflectionTheme.serif(14, weight: .medium))
                            .italic()
                            .foregroundColor(ReflectionTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReflectionTheme.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReflectionTheme.accent.opacity(0.2), lineWidth: 1)
            )

            dividerLine
        }
    }

    // MARK: - Loading state

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            dividerLine

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ReflectionTheme.mutedText)
                    Text("TÓM TẮT PHIÊN")
                        .font(ReflectionTheme.sans(11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                skeletonLine(width: 0.9)
                skeletonLine(width: 0.75)
                skeletonLine(width: 0.55)
                Text("Đang tóm tắt phiên…")
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)

                Button(action: onTriggerSummary) {
                    Text("Tóm tắt phiên ngay")
                        .font(ReflectionTheme.sans(11, weight: .medium))
                        .foregroundColor(ReflectionTheme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReflectionTheme.borderLight.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
            )

            dividerLine
        }
    }

    // MARK: - Helpers

    private var dividerLine: some View {
        Rectangle()
            .fill(ReflectionTheme.borderLight)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .padding(.vertical, 16)
    }

    private func skeletonLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(ReflectionTheme.borderLight.opacity(0.6))
            .frame(maxWidth: .infinity)
            .frame(height: 14)
            .scaleEffect(x: width, y: 1, anchor: .leading)
    }
}
