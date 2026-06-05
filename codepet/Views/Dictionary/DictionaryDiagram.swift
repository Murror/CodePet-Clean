import SwiftUI

// MARK: - Diagram model
//
// A dictionary term's "Analogy" section is replaced by a small, labeled visual
// diagram. To keep ~150 terms maintainable we DON'T draw a bespoke picture per
// term — instead each term declares ONE of a handful of reusable templates and
// supplies a few bilingual label strings. The template view does the drawing,
// built entirely from the app's existing pixel primitives (`.pixelBox`,
// `CodepetTheme`, SF Symbols).

/// Which reusable diagram a term renders. Each case documents its label slots.
enum DiagramTemplate: String, Hashable {
    /// A named box with a value inside. labels: [0]=name, [1]=value.
    /// Used by: variable, constant, string, number, boolean.
    case labeledBox
    /// input ▸ machine ▸ output. labels: [0]=input, [1]=machine, [2]=output.
    /// Used by: function, parameter, return-value, pure-function, side-effect.
    case beforeAfter
    /// A condition that splits into two branches. labels: [0]=condition, [1]=true, [2]=false.
    /// Used by: if-else, conditional.
    case fork
    /// A repeating body with a stop condition. labels: [0]=body, [1]=stop-when.
    /// Used by: loop, iteration, break-continue.
    case cycle
    /// Two nodes exchanging a request and a response.
    /// labels: [0]=client, [1]=request, [2]=server, [3]=response.
    /// Used by: http, api.
    case requestResponse
    /// Ordered snapshots on a line. labels: each label = one snapshot (2–4).
    /// Used by: git, commit, branch, pull-request.
    case timeline
    // Phase 1 adds: nestedTree, twoSides, stack, studsContract, keyValue, layers.
}

/// Semantic accent so term data never imports SwiftUI `Color`.
enum DiagramAccent: Hashable {
    case purple, pink, gold, teal, orange, blue

    var color: Color {
        switch self {
        case .purple: return CodepetTheme.accentPurple
        case .pink:   return CodepetTheme.accentPink
        case .gold:   return CodepetTheme.accentGold
        case .teal:   return CodepetTheme.accentTeal
        case .orange: return CodepetTheme.accentOrange
        case .blue:   return CodepetTheme.accentBlue
        }
    }
}

/// A term's diagram declaration: template + positional bilingual labels.
struct DiagramSpec: Hashable {
    let template: DiagramTemplate
    let labels: [L10n]
    let accent: DiagramAccent
    let caption: L10n?

    init(_ template: DiagramTemplate,
         _ labels: [L10n],
         accent: DiagramAccent = .purple,
         caption: L10n? = nil) {
        self.template = template
        self.labels = labels
        self.accent = accent
        self.caption = caption
    }
}

// MARK: - Dispatch view

/// Renders a `DiagramSpec` by dispatching to its template view, with an
/// optional caption underneath. Fixed vertical band so cards don't jump.
struct DictionaryDiagramView: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            template
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
                .padding(.vertical, 6)

            if let caption = spec.caption {
                Text(markdown: caption(lang))
                    .font(CodepetTheme.body(11))
                    .foregroundColor(CodepetTheme.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var template: some View {
        switch spec.template {
        case .labeledBox:      LabeledBoxDiagram(spec: spec)
        case .beforeAfter:     BeforeAfterDiagram(spec: spec)
        case .fork:            ForkDiagram(spec: spec)
        case .cycle:           CycleDiagram(spec: spec)
        case .requestResponse: RequestResponseDiagram(spec: spec)
        case .timeline:        TimelineDiagram(spec: spec)
        }
    }
}

// MARK: - Shared diagram primitives

/// A chunky pixel box holding a short string — the workhorse of every template.
private struct DiagramBox: View {
    let text: String
    let accent: Color
    var mono: Bool = false
    var emphasized: Bool = false

    var body: some View {
        Text(text)
            .font(mono
                  ? .system(size: 13, weight: .semibold, design: .monospaced)
                  : .pixelSystem(size: 12, weight: .semibold))
            .foregroundColor(CodepetTheme.primaryText)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .pixelBox(
                fill: accent.opacity(emphasized ? 0.22 : 0.14),
                shadowOffset: 2, blockSize: 2, steps: 2, borderWidth: 2
            )
    }
}

/// A small rounded "sticker" / chip label.
private struct DiagramChip: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(.pixelSystem(size: 11, weight: .semibold))
            .foregroundColor(accent)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(accent.opacity(0.16))
            )
    }
}

private struct DiagramArrow: View {
    var systemName: String = "arrow.right"
    var color: Color = CodepetTheme.mutedText

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(color)
    }
}

/// Convenience: resolve positional label `i` for the current language.
private func label(_ spec: DiagramSpec, _ i: Int, _ lang: AppLanguage, default def: String = "") -> String {
    guard spec.labels.indices.contains(i) else { return def }
    return spec.labels[i](lang)
}

// MARK: - Templates

/// A named box with a value inside (variable, constant, string, number, boolean).
private struct LabeledBoxDiagram: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        let name = label(spec, 0, lang, default: "name")
        let value = label(spec, 1, lang)
        VStack(spacing: 6) {
            DiagramChip(text: name, accent: spec.accent.color)   // the "sticker"
            DiagramArrow(systemName: "arrow.down", color: spec.accent.color.opacity(0.6))
            DiagramBox(text: value.isEmpty ? "…" : value, accent: spec.accent.color, mono: true, emphasized: true)
        }
    }
}

/// input ▸ machine ▸ output (function, parameter, return-value, pure-function, side-effect).
private struct BeforeAfterDiagram: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        let input = label(spec, 0, lang, default: "input")
        let machine = label(spec, 1, lang, default: "f()")
        let output = label(spec, 2, lang, default: "output")
        HStack(spacing: 8) {
            DiagramBox(text: input, accent: CodepetTheme.mutedText)
            DiagramArrow()
            DiagramBox(text: machine, accent: spec.accent.color, mono: true, emphasized: true)
            DiagramArrow()
            DiagramBox(text: output, accent: spec.accent.color)
        }
    }
}

/// A condition splitting into a true branch and a false branch (if-else, conditional).
private struct ForkDiagram: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        let condition = label(spec, 0, lang, default: "condition?")
        let yes = label(spec, 1, lang, default: "true")
        let no = label(spec, 2, lang, default: "false")
        VStack(spacing: 8) {
            DiagramBox(text: condition, accent: spec.accent.color, mono: true, emphasized: true)
            DiagramArrow(systemName: "arrow.down", color: spec.accent.color.opacity(0.6))
            HStack(spacing: 16) {
                branch(symbol: "checkmark", text: yes, tint: CodepetTheme.accentTeal)
                branch(symbol: "xmark", text: no, tint: CodepetTheme.accentOrange)
            }
        }
    }

    private func branch(symbol: String, text: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
            DiagramBox(text: text, accent: tint)
        }
    }
}

/// A repeating body with a stop condition (loop, iteration, break-continue).
private struct CycleDiagram: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        let body = label(spec, 0, lang, default: "do this")
        let stop = label(spec, 1, lang)
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(spec.accent.color)
            VStack(alignment: .leading, spacing: 6) {
                DiagramBox(text: body, accent: spec.accent.color, emphasized: true)
                if !stop.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(CodepetTheme.accentOrange)
                        Text(stop)
                            .font(.pixelSystem(size: 11, weight: .semibold))
                            .foregroundColor(CodepetTheme.mutedText)
                    }
                }
            }
        }
    }
}

/// Two nodes exchanging a request and a response (http, api).
private struct RequestResponseDiagram: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        let client = label(spec, 0, lang, default: "client")
        let request = label(spec, 1, lang, default: "request")
        let server = label(spec, 2, lang, default: "server")
        let response = label(spec, 3, lang, default: "response")
        HStack(spacing: 10) {
            DiagramBox(text: client, accent: spec.accent.color)
            VStack(spacing: 6) {
                exchange(text: request, symbol: "arrow.right", tint: spec.accent.color)
                exchange(text: response, symbol: "arrow.left", tint: CodepetTheme.accentTeal)
            }
            DiagramBox(text: server, accent: spec.accent.color, emphasized: true)
        }
    }

    private func exchange(text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(CodepetTheme.mutedText)
                .lineLimit(1)
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
        }
    }
}

/// Ordered snapshots on a line (git, commit, branch, pull-request).
private struct TimelineDiagram: View {
    @Environment(\.uiLanguage) private var lang
    let spec: DiagramSpec

    var body: some View {
        let snapshots: [String] = spec.labels.isEmpty
            ? ["•", "•", "•"]
            : spec.labels.map { $0(lang) }
        HStack(spacing: 0) {
            ForEach(Array(snapshots.enumerated()), id: \.offset) { idx, snap in
                node(snap)
                if idx < snapshots.count - 1 {
                    Rectangle()
                        .fill(spec.accent.color.opacity(0.5))
                        .frame(height: 3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func node(_ text: String) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(spec.accent.color)
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color(hex: "#2D2B26"), lineWidth: 2))
            Text(text)
                .font(.pixelSystem(size: 10, weight: .semibold))
                .foregroundColor(CodepetTheme.bodyText)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
