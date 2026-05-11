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

    // Bubble entry animation
    @State private var didAppear = false

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
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.05)) {
            didAppear = true
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
        PixelCard {
            VStack(alignment: .leading, spacing: 10) {
                if let pet = pet {
                    Text(pet.name.uppercased())
                        .font(.pixelSystem(size: 10))
                        .tracking(1.0)
                        .foregroundColor(petColor.opacity(0.85))
                }

                Text(narrative.whatYouWanted)
                    .font(CodepetTheme.body(14))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Color(hex: "#2D2B26").opacity(0.25))
                    .frame(height: 2)
                    .padding(.vertical, 2)

                Text(narrative.whatHappened)
                    .font(CodepetTheme.body(14))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !narrative.lesson.isEmpty {
                    lessonRow(narrative.lesson)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func lessonRow(_ text: String) -> some View {
        PixelCard(
            fill: Color(hex: "#FCEBA8"),
            shadowOffset: 3,
            blockSize: 3,
            steps: 2,
            borderWidth: 3
        ) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.pixelSystem(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#B6850A"))
                    .padding(.top, 2)
                Text(text)
                    .font(CodepetTheme.body(13, weight: .medium))
                    .foregroundColor(Color(hex: "#2D2B26"))
                    .multilineTextAlignment(.leading)
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
