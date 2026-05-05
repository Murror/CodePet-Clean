import SwiftUI

/// Chat-style render for ONE Turn's Narrative.
/// - User bubble (right, pet avatar) shows the rephrased intent.
/// - AI bubble (left, claude avatar) shows what was accomplished (educational explanation).
/// - Both avatars use playful gamification animations:
///     pet  → bounce, glow ring, head tilt
///     ai   → fast spin, pulsing glow, orbiting sparkles
///   Bubbles spring-in on first appear.
struct NarrativeChatTurnView: View {
    @EnvironmentObject var appState: AppState
    let narrative: Narrative

    // Pet animation tracks (premium = restrained)
    @State private var petFloat = false
    @State private var petGlow: CGFloat = 0

    // AI animation tracks
    @State private var aiRotation: Double = 0
    @State private var aiPulse: CGFloat = 0
    @State private var sparkleAngle: Double = 0

    // Bubble entry animation
    @State private var didAppear = false

    private var pet: PetCharacter? {
        PetCharacter.all[appState.activeChar]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            userBubble
                .scaleEffect(didAppear ? 1.0 : 0.6)
                .opacity(didAppear ? 1.0 : 0.0)
            aiBubble
                .scaleEffect(didAppear ? 1.0 : 0.6)
                .opacity(didAppear ? 1.0 : 0.0)
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Spring-in entrance
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.05)) {
            didAppear = true
        }

        // Pet — slow, unified float (drives both Y-offset and scale)
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            petFloat = true
        }
        // Pet — single soft glow ring, slightly slower than float so they breathe gently apart
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            petGlow = 1.0
        }

        // AI spin — faster, more obvious
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            aiRotation = 360
        }
        // AI pulse glow
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            aiPulse = 1.0
        }
        // Sparkle orbit
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            sparkleAngle = 360
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
            petAvatar(size: 44)
        }
    }

    private func petAvatar(size: CGFloat) -> some View {
        ZStack {
            if let pet = pet {
                // Single soft glow ring — slow, gentle expansion + fade
                Circle()
                    .stroke(pet.color.opacity(0.35), lineWidth: 1.5)
                    .scaleEffect(1.0 + petGlow * 0.18)
                    .opacity(1.0 - petGlow * 0.7)
                    .frame(width: size, height: size)

                // Pet sprite — unified float (subtle scale + 2px y-bob)
                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(Circle().fill(pet.color.opacity(0.18)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(pet.color.opacity(0.55), lineWidth: 1.5))
                    .scaleEffect(petFloat ? 1.02 : 0.98)
                    .offset(y: petFloat ? -2 : 2)
                    .shadow(
                        color: pet.color.opacity(petFloat ? 0.45 : 0.3),
                        radius: petFloat ? 10 : 6,
                        x: 0,
                        y: petFloat ? 5 : 3
                    )
            } else {
                Circle()
                    .fill(ReflectionTheme.accent.opacity(0.2))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: AI-side (left) — claude avatar with sparkles

    private var aiBubble: some View {
        HStack(alignment: .bottom, spacing: 10) {
            aiAvatar(size: 44)
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
        let claudeOrange = Color(red: 0xE3/255.0, green: 0x70/255.0, blue: 0x55/255.0)
        let claudeCream = Color(red: 0xFD/255.0, green: 0xF6/255.0, blue: 0xF1/255.0)

        return ZStack {
            // Outer pulsing glow
            Circle()
                .fill(claudeOrange.opacity(0.25))
                .scaleEffect(1.0 + aiPulse * 0.5)
                .opacity(1.0 - aiPulse * 0.7)
                .frame(width: size, height: size)

            // Background circle
            Circle()
                .fill(claudeCream)
                .overlay(Circle().stroke(claudeOrange.opacity(0.5), lineWidth: 1.5))
                .frame(width: size, height: size)
                .shadow(color: claudeOrange.opacity(0.4), radius: 5, x: 0, y: 2)

            // Spinning starburst icon
            Image("claude-icon")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
                .rotationEffect(.degrees(aiRotation))

            // Orbiting sparkles
            ForEach(0..<4) { i in
                sparkle(at: i, around: size, color: claudeOrange)
            }
        }
        .frame(width: size, height: size)
    }

    /// Tiny dot that orbits the AI avatar.
    private func sparkle(at index: Int, around size: CGFloat, color: Color) -> some View {
        let baseAngle = Double(index) * 90.0
        let angle = baseAngle + sparkleAngle
        let radius = size * 0.65
        let x = cos(angle * .pi / 180) * radius
        let y = sin(angle * .pi / 180) * radius
        // Each sparkle's twinkle is offset by index so they pulse out of phase
        let twinklePhase = (sparkleAngle / 90.0).truncatingRemainder(dividingBy: 1.0)
        let phaseShift = Double(index) * 0.25
        let rawTwinkle = abs(sin((twinklePhase + phaseShift) * .pi))
        return Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .opacity(0.4 + rawTwinkle * 0.6)
            .scaleEffect(0.7 + rawTwinkle * 0.6)
            .offset(x: x, y: y)
    }
}
