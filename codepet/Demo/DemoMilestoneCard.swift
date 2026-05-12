import SwiftUI

/// One milestone in the demo flow: emote + bubble text, with timestamp.
/// Visual style intentionally mirrors NarrativeChatTurnView so the demo
/// reads like a real reflection turn.
struct DemoMilestoneCard: View {
    let milestone: DemoScript.Milestone
    let timestamp: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emote bubble
            Text(milestone.emote)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(ReflectionTheme.accent.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(DemoScript.petName)
                        .font(ReflectionTheme.serif(13, weight: .semibold))
                        .foregroundColor(ReflectionTheme.primaryText)
                    Text(timeString(timestamp))
                        .font(ReflectionTheme.sans(11))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Text(milestone.bubble)
                    .font(ReflectionTheme.sans(14))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                            )
                    )
            }
            Spacer(minLength: 0)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    DemoMilestoneCard(
        milestone: DemoScript.milestones[1],
        timestamp: Date()
    )
    .padding()
    .frame(width: 600)
    .background(ReflectionTheme.background)
}
