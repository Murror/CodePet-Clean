import SwiftUI

/// Chat-style render for ONE Turn's Narrative.
/// - User bubble (right, pet avatar) shows the rephrased intent.
/// - AI bubble (left, sparkles avatar) shows what was accomplished (educational explanation).
/// - NO lesson card — lesson is now session-level, shown in SessionSummaryView.
struct NarrativeChatTurnView: View {
    @EnvironmentObject var appState: AppState
    let narrative: Narrative

    private var pet: PetCharacter? {
        PetCharacter.all[appState.activeChar]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            userBubble
            aiBubble
        }
    }

    // MARK: User-side (right) — pet avatar

    private var userBubble: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                if let pet = pet {
                    Text(pet.name)
                        .font(ReflectionTheme.sans(10, weight: .semibold))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Text(narrative.whatYouWanted)
                    .font(ReflectionTheme.serif(14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ReflectionTheme.accent)
                    )
            }
            petAvatar(size: 36)
        }
    }

    private func petAvatar(size: CGFloat) -> some View {
        Group {
            if let pet = pet {
                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(
                        Circle().fill(pet.color.opacity(0.18))
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(pet.color.opacity(0.6), lineWidth: 1.5))
            } else {
                Circle()
                    .fill(ReflectionTheme.accent.opacity(0.2))
                    .frame(width: size, height: size)
            }
        }
    }

    // MARK: AI-side (left) — sparkles avatar

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 10) {
            aiAvatar(size: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI")
                    .font(ReflectionTheme.sans(10, weight: .semibold))
                    .foregroundColor(ReflectionTheme.mutedText)
                Text(narrative.whatHappened)
                    .font(ReflectionTheme.serif(14))
                    .foregroundColor(ReflectionTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ReflectionTheme.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ReflectionTheme.borderLight, lineWidth: 1)
                    )
            }
            Spacer(minLength: 60)
        }
    }

    private func aiAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(ReflectionTheme.background)
                .overlay(Circle().stroke(ReflectionTheme.borderLight, lineWidth: 1))
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.5, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ReflectionTheme.accent, ReflectionTheme.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: size, height: size)
    }
}
