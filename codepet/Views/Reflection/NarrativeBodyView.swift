import SwiftUI

struct NarrativeBodyView: View {
    let narrative: Narrative

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            section(eyebrow: "BẠN MUỐN", body: narrative.whatYouWanted)
            section(eyebrow: "ĐÃ LÀM", body: narrative.whatHappened)
            lessonCard
        }
    }

    private func section(eyebrow: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(ReflectionTheme.accent.opacity(0.6))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow)
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(ReflectionTheme.mutedText)
                Text(body)
                    .font(ReflectionTheme.serif(15))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var lessonCard: some View {
        if !narrative.lesson.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("BÀI HỌC")
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(ReflectionTheme.accent)
                Text(narrative.lesson)
                    .font(ReflectionTheme.serif(14, weight: .medium))
                    .italic()
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReflectionTheme.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ReflectionTheme.accent.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

// #Preview omitted — requires AppState @EnvironmentObject (PetAvatar dependency in ReflectionTheme)
