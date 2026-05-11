import SwiftUI

// MARK: - Design tokens

enum ReflectionTheme {

    // Accent
    static let accent = Color(red: 0x7F / 255.0, green: 0x77 / 255.0, blue: 0xDD / 255.0)

    // Mood
    static let moodCalm = Color(red: 0x5D / 255.0, green: 0xCA / 255.0, blue: 0xA5 / 255.0)
    static let moodEngaged = Color(red: 0x85 / 255.0, green: 0xB7 / 255.0, blue: 0xEB / 255.0)
    static let moodAlert = Color(red: 0xEF / 255.0, green: 0x9F / 255.0, blue: 0x27 / 255.0)

    static func color(for mood: PetMood) -> Color {
        switch mood {
        case .calm: return moodCalm
        case .engaged: return moodEngaged
        case .alert: return moodAlert
        }
    }

    // Source tints
    static let cursorTintBg = Color(red: 0x7F / 255.0, green: 0x77 / 255.0, blue: 0xDD / 255.0).opacity(0.10)
    static let cursorTintFg = Color(red: 0x5B / 255.0, green: 0x54 / 255.0, blue: 0xB8 / 255.0)
    static let claudeTintBg = Color(red: 0x5D / 255.0, green: 0xCA / 255.0, blue: 0xA5 / 255.0).opacity(0.12)
    static let claudeTintFg = Color(red: 0x2F / 255.0, green: 0x7F / 255.0, blue: 0x65 / 255.0)
    static let codexTintBg  = Color(red: 0xEF / 255.0, green: 0x9F / 255.0, blue: 0x27 / 255.0).opacity(0.12)
    static let codexTintFg  = Color(red: 0xB6 / 255.0, green: 0x6E / 255.0, blue: 0x0D / 255.0)
    static let manualTintBg = Color(red: 0x2D / 255.0, green: 0x2B / 255.0, blue: 0x26 / 255.0).opacity(0.06)
    static let manualTintFg = Color(red: 0x66 / 255.0, green: 0x66 / 255.0, blue: 0x66 / 255.0)

    static func sourceTintBg(for source: EventSource) -> Color {
        switch source {
        case .cursorChat: return cursorTintBg
        case .claudeCode: return claudeTintBg
        case .codex:      return codexTintBg
        case .manualLog:  return manualTintBg
        }
    }

    static func sourceTintFg(for source: EventSource) -> Color {
        switch source {
        case .cursorChat: return cursorTintFg
        case .claudeCode: return claudeTintFg
        case .codex:      return codexTintFg
        case .manualLog:  return manualTintFg
        }
    }

    // Text
    static let primaryText = Color(red: 0x2D / 255.0, green: 0x2B / 255.0, blue: 0x26 / 255.0)
    static let secondaryText = Color(red: 0x4F / 255.0, green: 0x4B / 255.0, blue: 0x45 / 255.0)
    static let mutedText = Color(red: 0x94 / 255.0, green: 0x8E / 255.0, blue: 0x82 / 255.0)

    // Surfaces
    static let background = Color(red: 0xFA / 255.0, green: 0xFA / 255.0, blue: 0xF6 / 255.0)
    static let cardBackground = Color.white
    static let borderLight = Color(red: 0xEB / 255.0, green: 0xE8 / 255.0, blue: 0xDF / 255.0)

    // Fonts — Reflection lives in the body/content tier, so all three helpers
    // resolve to Inter. Use `CodepetTheme.display()` for true display text.
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return CodepetTheme.inter(size, weight: weight)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return CodepetTheme.inter(size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return CodepetTheme.inter(size, weight: weight)
    }
}

// MARK: - PetAvatar

struct PetAvatar: View {
    @EnvironmentObject var appState: AppState

    let mood: PetMood
    let size: CGFloat

    private var character: PetCharacter {
        PetCharacter.all[appState.activeChar] ?? PetCharacter.all["byte"]!
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Radial halo — pet feels more present
            Circle()
                .fill(
                    RadialGradient(
                        colors: [character.color.opacity(0.28), character.color.opacity(0.0)],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.65
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .fill(character.color.opacity(0.16))
                .frame(width: size, height: size)
                .overlay(
                    CharacterImage(character.id, size: size * 0.88)
                        .charIdle(character.id)
                        .petBreathing()
                )

            Circle()
                .fill(ReflectionTheme.color(for: mood))
                .overlay(Circle().stroke(Color.white, lineWidth: max(size * 0.04, 1.5)))
                .frame(width: size * 0.28, height: size * 0.28)
                .offset(x: size * 0.02, y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - TriggerPill

struct TriggerPill: View {
    let trigger: TriggerTag

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ReflectionTheme.accent)
                .frame(width: 5, height: 5)
            Text("\(trigger.code) · \(trigger.label)")
                .font(ReflectionTheme.sans(11, weight: .medium))
                .foregroundColor(ReflectionTheme.accent)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(ReflectionTheme.accent.opacity(0.10))
        )
    }
}

// MARK: - Eyebrow

struct Eyebrow: View {
    let text: String
    var color: Color = ReflectionTheme.mutedText

    var body: some View {
        Text(text.uppercased())
            .font(ReflectionTheme.sans(10, weight: .semibold))
            .tracking(1.4)
            .foregroundColor(color)
    }
}

// MARK: - Source label pill

struct SourceEyebrow: View {
    let source: EventSource

    var body: some View {
        Text(source.rawValue.uppercased())
            .font(ReflectionTheme.sans(9, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(ReflectionTheme.sourceTintFg(for: source))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(ReflectionTheme.sourceTintBg(for: source))
            )
    }
}
