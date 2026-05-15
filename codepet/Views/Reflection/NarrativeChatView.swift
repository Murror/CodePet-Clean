import SwiftUI

/// Single-voice render for ONE Turn's Narrative.
/// The pet is the sole narrator — there is no AI/assistant counterpart.
/// One pet avatar on the left, one bubble on the right that contains the
/// pet's narration of what the user wanted, what happened, and (optionally)
/// the lesson it surfaces for them.
struct NarrativeChatTurnView: View {
    @EnvironmentObject var appState: AppState
    let narrative: Narrative
    /// When true, render the pet avatar to the left of the bubble. When
    /// false, the bubble takes full width with only a thin pet-color thread
    /// on its left edge — used for older turns so the avatar doesn't repeat.
    var showAvatar: Bool = true

    // Pet animation tracks (premium = restrained)
    @State private var petFloat = false
    @State private var petGlow: CGFloat = 0
    /// One-shot wiggle when the bubble first appears (0 → 1 → 0). Combines
    /// with petFloat as a multiplicative scaleEffect.
    @State private var petWiggle: CGFloat = 0

    // Bubble entry animation
    @State private var didAppear = false
    // Staggered section reveals (header → whatYouWanted → whatHappened → lesson).
    // Each block fades in + slides up slightly.
    @State private var headerVisible = false
    @State private var whatYouWantedVisible = false
    @State private var whatHappenedVisible = false
    @State private var lessonVisible = false

    private var pet: PetCharacter? {
        PetCharacter.all[appState.activeChar]
    }

    private var petColor: Color {
        pet?.color ?? ReflectionTheme.accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: showAvatar ? 12 : 0) {
            if showAvatar {
                petAvatar(size: 36)
            }
            petBubble
                .scaleEffect(didAppear ? 1.0 : 0.6, anchor: .topLeading)
                .opacity(didAppear ? 1.0 : 0.0)
        }
        .onAppear { startAnimations() }
    }

    private func startAnimations() {
        // Bubble container scales in (slower spring for premium feel).
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.05)) {
            didAppear = true
        }
        // Pet wiggle: up to 1, then spring back to 0 — a one-shot "Byte is
        // speaking" emote synced with bubble entry.
        withAnimation(.easeOut(duration: 0.25).delay(0.15)) {
            petWiggle = 1
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.45).delay(0.4)) {
            petWiggle = 0
        }
        // Stagger the content sections — slower, more breathing room. Each
        // section uses a longer fade + slide to feel deliberate, not rushed.
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            headerVisible = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.9)) {
            whatYouWantedVisible = true
        }
        withAnimation(.easeOut(duration: 0.6).delay(1.6)) {
            whatHappenedVisible = true
        }
        // Lesson lands last with a bouncy spring + subtle rotation correction.
        withAnimation(.spring(response: 0.65, dampingFraction: 0.6).delay(2.8)) {
            lessonVisible = true
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            petFloat = true
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            petGlow = 1.0
        }
    }

    // MARK: - Pet bubble (single voice)

    private var petBubble: some View {
        PixelCard(
            fill: Color(hex: "#FFF1DB"),
            borderColor: Color(hex: "#2D2B26").opacity(0.35),
            shadowOffset: 3,
            borderWidth: 2
        ) {
            bubbleContent
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView
            whatYouWantedView
            dividerView
            whatHappenedView
            lessonView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headerView: some View {
        if let pet = pet {
            Text(pet.name.uppercased())
                .font(.pixelSystem(size: 10))
                .tracking(1.0)
                .foregroundColor(petColor.opacity(0.85))
                .opacity(headerVisible ? 1 : 0)
                .offset(x: headerVisible ? 0 : -8, y: headerVisible ? 0 : 4)
        }
    }

    private var whatYouWantedView: some View {
        Text(markdown: narrative.whatYouWanted)
            .font(CodepetTheme.body(18))
            .foregroundColor(Color(hex: "#2D2B26"))
            .multilineTextAlignment(.leading)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(whatYouWantedVisible ? 1 : 0)
            .offset(x: whatYouWantedVisible ? 0 : -12, y: whatYouWantedVisible ? 0 : 8)
    }

    private var dividerView: some View {
        Rectangle()
            .fill(Color(hex: "#2D2B26").opacity(0.25))
            .frame(height: 2)
            .padding(.vertical, 2)
            .opacity(whatHappenedVisible ? 1 : 0)
            .scaleEffect(x: whatHappenedVisible ? 1.0 : 0.3, y: 1.0, anchor: .leading)
    }

    private var whatHappenedView: some View {
        MarkdownTypewriterText(
            markdown: narrative.whatHappened,
            charactersPerSecond: 150,
            font: CodepetTheme.body(18),
            isActive: whatHappenedVisible
        )
        .opacity(whatHappenedVisible ? 1 : 0)
        .offset(x: whatHappenedVisible ? 0 : -12, y: whatHappenedVisible ? 0 : 8)
    }

    @ViewBuilder
    private var lessonView: some View {
        if !narrative.lesson.isEmpty {
            lessonRow(narrative.lesson)
                .padding(.top, 4)
                .opacity(lessonVisible ? 1 : 0)
                .scaleEffect(lessonVisible ? 1.0 : 0.7, anchor: .topLeading)
                .rotationEffect(.degrees(lessonVisible ? 0 : -4), anchor: .topLeading)
                .offset(y: lessonVisible ? 0 : 12)
        }
    }

    private func lessonRow(_ text: String) -> some View {
        PixelCard(
            fill: Color(hex: "#FCEBA8"),
            borderColor: Color(hex: "#2D2B26").opacity(0.3),
            shadowOffset: 2,
            blockSize: 3,
            steps: 2,
            borderWidth: 2
        ) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.pixelSystem(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#B6850A"))
                    .padding(.top, 2)
                Text(markdown: text)
                    .font(CodepetTheme.body(16, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Pet avatar

    private func petAvatar(size: CGFloat) -> some View {
        ZStack {
            if let pet = pet {
                Circle()
                    .stroke(pet.color.opacity(0.35), lineWidth: 1.5)
                    .scaleEffect(1.0 + petGlow * 0.18)
                    .opacity(1.0 - petGlow * 0.7)
                    .frame(width: size, height: size)

                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .background(Circle().fill(pet.color.opacity(0.18)))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(pet.color.opacity(0.55), lineWidth: 1.5))
                    .scaleEffect(petFloat ? 1.02 : 0.98)
                    .scaleEffect(1.0 + petWiggle * 0.18)
                    .rotationEffect(.degrees(Double(petWiggle) * -4))
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
}
