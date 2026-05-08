import SwiftUI

// MARK: - CodepetTheme
//
// Tokens + view modifiers that align in-app chrome with the marketing site
// (code-pet.com). The aesthetic is soft and modern: cream background,
// generously rounded corners, blurred drop shadows, system sans-serif type,
// and bright accent colors. Pet sprites themselves stay pixel art via
// `.interpolation(.none)` — only the chrome around them matches the site.

enum CodepetTheme {

    // MARK: Surfaces

    /// Page background — warm cream that the marketing site uses across hero,
    /// product, and footer sections.
    static let pageBackground = Color(red: 0xF8 / 255.0, green: 0xF7 / 255.0, blue: 0xF3 / 255.0)

    /// Card / panel surface. Solid white sits cleanly on top of the cream
    /// background.
    static let surface = Color.white

    /// Subtle hairline used inside cards for dividers when a stronger
    /// boundary is needed than whitespace alone.
    static let hairline = Color(red: 0xEC / 255.0, green: 0xE9 / 255.0, blue: 0xE2 / 255.0)

    // MARK: Text

    /// Headline / primary text — near-black with a touch of warmth.
    static let primaryText = Color(red: 0x1F / 255.0, green: 0x1B / 255.0, blue: 0x15 / 255.0)

    /// Body copy — slightly softer than headlines.
    static let bodyText = Color(red: 0x33 / 255.0, green: 0x2E / 255.0, blue: 0x27 / 255.0)

    /// Muted text — labels, captions, helper copy.
    static let mutedText = Color(red: 0x77 / 255.0, green: 0x70 / 255.0, blue: 0x65 / 255.0)

    // MARK: Brand accents (mirrors the marketing site)

    static let accentPurple = Color(red: 0x7C / 255.0, green: 0x3A / 255.0, blue: 0xED / 255.0)
    static let accentPink   = Color(red: 0xFF / 255.0, green: 0x6B / 255.0, blue: 0x9D / 255.0)
    static let accentGold   = Color(red: 0xFD / 255.0, green: 0xB0 / 255.0, blue: 0x22 / 255.0)
    static let accentTeal   = Color(red: 0x2D / 255.0, green: 0xD4 / 255.0, blue: 0xBF / 255.0)
    static let accentOrange = Color(red: 0xFF / 255.0, green: 0x8C / 255.0, blue: 0x42 / 255.0)

    // MARK: Geometry

    /// Default card corner radius — gentle ~14pt curve on stat cards and
    /// testimonial blocks.
    static let cardRadius: CGFloat = 14

    /// Pill-style buttons.
    static let pillRadius: CGFloat = 24

    /// Tighter radius for inline pills (input chrome, small chips).
    static let inputRadius: CGFloat = 12

    // MARK: Shadow tokens

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Soft elevation used on cards.
    static let cardShadow = Shadow(
        color: Color.black.opacity(0.08),
        radius: 12, x: 0, y: 4
    )

    /// Slightly stronger lift used on a floating panel (chat, modals).
    static let floatingShadow = Shadow(
        color: Color.black.opacity(0.12),
        radius: 24, x: 0, y: 12
    )

    // MARK: Typography

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Soft drop-shadow modifier

extension View {
    /// Apply a `CodepetTheme.Shadow` token.
    func codepetShadow(_ shadow: CodepetTheme.Shadow = CodepetTheme.cardShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Card container

/// Rounded white surface with a soft drop shadow.
struct CodepetCard<Content: View>: View {
    var fill: Color = CodepetTheme.surface
    var radius: CGFloat = CodepetTheme.cardRadius
    var shadow: CodepetTheme.Shadow = CodepetTheme.cardShadow
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .codepetShadow(shadow)
    }
}

// MARK: - Pill button style

/// Solid pill. Brand accent fill + white text by default. Matches the
/// site's primary CTA.
struct CodepetPillButtonStyle: ButtonStyle {
    var fill: Color = CodepetTheme.accentPurple
    var foreground: Color = .white
    var paddingH: CGFloat = 18
    var paddingV: CGFloat = 10
    var font: Font = CodepetTheme.body(13, weight: .semibold)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(foreground)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(
                RoundedRectangle(cornerRadius: CodepetTheme.pillRadius, style: .continuous)
                    .fill(fill)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Compact icon button (close X, etc.)

struct CodepetIconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var fill: Color = .clear
    var foreground: Color = CodepetTheme.mutedText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed
                          ? Color.black.opacity(0.06)
                          : fill)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Soft input chrome

struct CodepetInputBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: CodepetTheme.inputRadius, style: .continuous)
                    .fill(Color(white: 0.97))
            )
    }
}

extension View {
    /// Wrap a TextField in soft input chrome.
    func codepetInput() -> some View {
        modifier(CodepetInputBackground())
    }
}
