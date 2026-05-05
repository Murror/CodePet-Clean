import SwiftUI

/// Chat-style render for ONE Turn's Narrative.
/// - User bubble (right, pet avatar) shows the rephrased intent.
/// - AI bubble (left, sparkles avatar) shows what was accomplished (educational explanation).
/// - NO lesson card — lesson is now session-level, shown in SessionSummaryView.
struct NarrativeChatTurnView: View {
    @EnvironmentObject var appState: AppState
    let narrative: Narrative

    @State private var isBreathing = false
    @State private var aiRotation: Double = 0

    private var pet: PetCharacter? {
        PetCharacter.all[appState.activeChar]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            userBubble
            aiBubble
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                aiRotation = 360
            }
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
                    .scaleEffect(isBreathing ? 1.04 : 0.96)
                    .offset(y: isBreathing ? -1 : 1)
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
                .fill(Color(red: 0xFD/255.0, green: 0xF6/255.0, blue: 0xF1/255.0))
                .overlay(Circle().stroke(Color(red: 0xE3/255.0, green: 0x9A/255.0, blue: 0x7B/255.0).opacity(0.4), lineWidth: 1))
            Image("claude-icon")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(aiRotation))
        }
        .frame(width: size, height: size)
    }
}
