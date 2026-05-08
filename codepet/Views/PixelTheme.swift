import SwiftUI

// MARK: - PixelTheme
//
// Reusable building blocks for the pixel-chrome look: hard 2px borders, no
// rounded corners, solid color fills, hard offset drop shadows. Apply these
// with view modifiers (.pixelBorder, .pixelShadow) or by wrapping content in
// PixelPanel / PixelBubble. Buttons get .buttonStyle(PixelButtonStyle()).
//
// Existing pet sprites already use .interpolation(.none); this theme aligns
// the surrounding chrome (panels, bubbles, buttons, inputs) with that
// aesthetic without changing any pet/kingdom artwork.

enum PixelTheme {

    // MARK: Tokens

    /// Default border thickness — exactly 2 SwiftUI points wide so the line
    /// stays crisp at @1x and @2x without sub-pixel softening.
    static let borderWidth: CGFloat = 2

    /// Default drop-shadow offset.
    static let shadowOffset: CGFloat = 4

    /// Hard outline color used for borders and shadows by default.
    static let outline = Color(red: 0x2D / 255.0, green: 0x2B / 255.0, blue: 0x26 / 255.0)

    /// Slightly lighter than outline — used inside a panel as a divider.
    static let divider = Color(red: 0x55 / 255.0, green: 0x52 / 255.0, blue: 0x4B / 255.0)

    /// Default panel background — the Reflection background reads warm.
    static let panelFill = Color.white

    /// Soft hilight overlay for pressed/hover states.
    static let press = Color.black.opacity(0.06)
}

// MARK: - Pixel border modifier

struct PixelBorderModifier: ViewModifier {
    let color: Color
    let width: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            Rectangle()
                .strokeBorder(color, lineWidth: width)
        )
    }
}

extension View {
    /// Hard pixel-style border. No corner rounding.
    func pixelBorder(_ color: Color = PixelTheme.outline, width: CGFloat = PixelTheme.borderWidth) -> some View {
        modifier(PixelBorderModifier(color: color, width: width))
    }
}

// MARK: - Pixel hard-shadow modifier

struct PixelShadowModifier: ViewModifier {
    let color: Color
    let offset: CGFloat

    func body(content: Content) -> some View {
        content.background(
            Rectangle()
                .fill(color)
                .offset(x: offset, y: offset)
        )
    }
}

extension View {
    /// Hard offset drop shadow — a single colored rectangle behind the view,
    /// shifted by `offset` in both axes. No gaussian blur.
    func pixelShadow(_ color: Color = PixelTheme.outline, offset: CGFloat = PixelTheme.shadowOffset) -> some View {
        modifier(PixelShadowModifier(color: color, offset: offset))
    }
}

// MARK: - Pixel panel container

/// Solid fill + hard border + optional hard drop shadow. Use as a background
/// for cards, dialogs, and chat panels.
struct PixelPanel<Content: View>: View {
    var fill: Color = PixelTheme.panelFill
    var borderColor: Color = PixelTheme.outline
    var shadow: Color? = PixelTheme.outline
    var shadowOffset: CGFloat = PixelTheme.shadowOffset
    @ViewBuilder var content: Content

    var body: some View {
        let body = content
            .background(Rectangle().fill(fill))
            .pixelBorder(borderColor)
        if let shadow {
            body.pixelShadow(shadow, offset: shadowOffset)
        } else {
            body
        }
    }
}

// MARK: - Pixel button style

/// Solid colored block with hard outline. On press, the button shifts down-
/// right by `shadowOffset` to "press in" — the drop shadow disappears at the
/// same time, mimicking the pet/kingdom aesthetic.
struct PixelButtonStyle: ButtonStyle {
    var fill: Color = PixelTheme.panelFill
    var foreground: Color = PixelTheme.outline
    var border: Color = PixelTheme.outline
    var shadow: Color = PixelTheme.outline
    var paddingH: CGFloat = 12
    var paddingV: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(Rectangle().fill(pressed ? PixelTheme.press : Color.clear))
            .background(Rectangle().fill(fill))
            .pixelBorder(border)
            .offset(
                x: pressed ? PixelTheme.shadowOffset / 2 : 0,
                y: pressed ? PixelTheme.shadowOffset / 2 : 0
            )
            .pixelShadow(shadow, offset: pressed ? 0 : PixelTheme.shadowOffset / 2)
            .animation(nil, value: pressed) // crisp snap, no easing on the press
    }
}

// MARK: - Pixel icon button (compact, square, no shadow — for close X etc.)

struct PixelIconButtonStyle: ButtonStyle {
    var size: CGFloat = 22
    var fill: Color = PixelTheme.panelFill
    var foreground: Color = PixelTheme.outline
    var border: Color = PixelTheme.outline

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(Rectangle().fill(configuration.isPressed ? PixelTheme.press : fill))
            .pixelBorder(border)
            .animation(nil, value: configuration.isPressed)
    }
}

// MARK: - Pixel text field background

struct PixelTextFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Rectangle().fill(Color.white))
            .pixelBorder()
    }
}

extension View {
    /// Wrap a TextField (or any input control) in pixel chrome.
    func pixelTextField() -> some View {
        modifier(PixelTextFieldBackground())
    }
}
