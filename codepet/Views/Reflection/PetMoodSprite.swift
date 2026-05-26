import SwiftUI

/// Pet mood enum — maps to Claude's `mood` field in the narrative.
enum NarrativeMood: String, CaseIterable {
    case idle
    case excited
    case thinking
    case proud
    case concerned
    case cheering

    init(raw: String) {
        self = NarrativeMood(rawValue: raw) ?? .idle
    }

    /// System image shown as a small badge/indicator near the sprite.
    var badgeIcon: String {
        switch self {
        case .idle:      return "sparkle"
        case .excited:   return "star.fill"
        case .thinking:  return "bubble.left.fill"
        case .proud:     return "trophy.fill"
        case .concerned: return "exclamationmark.triangle.fill"
        case .cheering:  return "heart.fill"
        }
    }

    /// Accent color for the mood badge.
    var badgeColor: Color {
        switch self {
        case .idle:      return .gray
        case .excited:   return Color(hex: "#FFB800")
        case .thinking:  return Color(hex: "#5B9BD5")
        case .proud:     return Color(hex: "#4CAF50")
        case .concerned: return Color(hex: "#FF9800")
        case .cheering:  return Color(hex: "#E040FB")
        }
    }
}

/// Animated pet sprite that reacts to the narrative mood.
/// Displayed next to (or within) narrative cards.
struct PetMoodSprite: View {
    let characterId: String
    let mood: NarrativeMood
    let size: CGFloat

    // Animation state
    @State private var phase: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0
    @State private var particlesVisible = false
    @State private var badgeScale: CGFloat = 0

    private var pet: PetCharacter? {
        PetCharacter.all[characterId]
    }

    private var petColor: Color {
        pet?.color ?? .purple
    }

    var body: some View {
        ZStack {
            // Glow ring
            Circle()
                .fill(petColor.opacity(glowOpacity * 0.2))
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: 8)

            // Particle effects
            if particlesVisible {
                particleLayer
            }

            // Main sprite
            spriteImage
                .offset(y: bounceOffset)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotation))

            // Mood badge
            moodBadge
                .offset(x: size * 0.35, y: -size * 0.35)
                .scaleEffect(badgeScale)
        }
        .frame(width: size * 1.6, height: size * 1.6)
        .onAppear { startMoodAnimation() }
        .onChange(of: mood) { _, _ in startMoodAnimation() }
    }

    // MARK: - Sprite Image

    private var spriteImage: some View {
        Group {
            if let pet = pet {
                Image(pet.imageName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
    }

    // MARK: - Mood Badge

    private var moodBadge: some View {
        ZStack {
            Circle()
                .fill(mood.badgeColor)
                .frame(width: size * 0.35, height: size * 0.35)
                .shadow(color: mood.badgeColor.opacity(0.5), radius: 4)

            Image(systemName: mood.badgeIcon)
                .font(.system(size: size * 0.15, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Particles

    @ViewBuilder
    private var particleLayer: some View {
        switch mood {
        case .excited:
            excitedParticles
        case .proud:
            proudParticles
        case .cheering:
            cheeringParticles
        case .concerned:
            concernedParticles
        case .thinking:
            thinkingParticles
        case .idle:
            EmptyView()
        }
    }

    private var excitedParticles: some View {
        let radius: Double = Double(size * 0.7)
        let phaseD: Double = Double(phase)
        return ForEach(0..<5, id: \.self) { i in
            let angle: Double = Double(i) * .pi * 2.0 / 5.0 + phaseD * 2.0
            Text("✨")
                .font(.system(size: size * 0.2))
                .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                .opacity(1.0 - phaseD * 0.5)
                .scaleEffect(0.5 + phase * 0.5)
        }
    }

    private var proudParticles: some View {
        let colors: [Color] = [.yellow, .green, .purple, .orange, .pink, .blue]
        let dist: Double = Double(size * 0.5 + phase * size * 0.3)
        return ForEach(0..<6, id: \.self) { i in
            let angle: Double = Double(i) * .pi * 2.0 / 6.0
            Circle()
                .fill(colors[i % colors.count])
                .frame(width: 4, height: 4)
                .offset(x: cos(angle) * dist, y: sin(angle) * dist)
                .opacity(1.0 - Double(phase) * 0.7)
        }
    }

    private var cheeringParticles: some View {
        let offsets: [CGFloat] = [-15, 10, -8, 18]
        return ForEach(0..<4, id: \.self) { i in
            let yOff: CGFloat = -phase * size * 0.6 - CGFloat(i * 8)
            Text("💕")
                .font(.system(size: size * 0.18))
                .offset(x: offsets[i], y: yOff)
                .opacity(1.0 - Double(phase) * 0.6)
        }
    }

    private var concernedParticles: some View {
        let yOff: CGFloat = -size * 0.1 + phase * size * 0.3
        let opacity: Double = Double(phase) < 0.7 ? 1.0 : max(0, 1.0 - (Double(phase) - 0.7) * 3.0)
        return Text("💧")
            .font(.system(size: size * 0.22))
            .offset(x: size * 0.3, y: yOff)
            .opacity(opacity)
    }

    private var thinkingParticles: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                let threshold: CGFloat = CGFloat(i) * 0.3
                Circle()
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase > threshold ? 1.2 : 0.6)
            }
        }
        .offset(x: size * 0.4, y: -size * 0.2)
    }

    // MARK: - Animations

    private func startMoodAnimation() {
        // Reset
        phase = 0
        bounceOffset = 0
        rotation = 0
        scale = 1.0
        glowOpacity = 0
        particlesVisible = false
        badgeScale = 0

        // Badge entrance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
            badgeScale = 1.0
        }

        switch mood {
        case .idle:
            // Gentle float
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                bounceOffset = -4
                glowOpacity = 0.5
            }

        case .excited:
            // Happy bounce + sparkles
            particlesVisible = true
            withAnimation(.spring(response: 0.35, dampingFraction: 0.4).repeatCount(3, autoreverses: true)) {
                bounceOffset = -12
                scale = 1.1
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                phase = 1.0
                glowOpacity = 0.8
            }

        case .thinking:
            // Slow head tilt + thought dots
            particlesVisible = true
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                rotation = 8
                bounceOffset = -2
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                phase = 1.0
            }

        case .proud:
            // Chest puff + confetti
            particlesVisible = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                scale = 1.15
                glowOpacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                scale = 1.05
            }
            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                phase = 1.0
            }

        case .concerned:
            // Slight shrink + sweat
            particlesVisible = true
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 0.92
                bounceOffset = 2
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                phase = 1.0
            }

        case .cheering:
            // Jump + wave + hearts
            particlesVisible = true
            withAnimation(.spring(response: 0.3, dampingFraction: 0.35).repeatCount(4, autoreverses: true)) {
                bounceOffset = -16
                rotation = -5
            }
            withAnimation(.easeOut(duration: 2.5).repeatForever(autoreverses: false)) {
                phase = 1.0
                glowOpacity = 0.6
            }
        }
    }
}
