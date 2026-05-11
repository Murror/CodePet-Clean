import SwiftUI

struct DictionaryCard: View {

    let term: DictionaryTerm
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(term.title)
                    .font(CodepetTheme.display(18, weight: .bold))
                    .foregroundColor(CodepetTheme.primaryText)

                Text(term.shortDefinition)
                    .font(CodepetTheme.body(13))
                    .foregroundColor(CodepetTheme.bodyText)
                    .fixedSize(horizontal: false, vertical: true)

                if isExpanded {
                    deepDive
                        .transition(.opacity)
                }

                HStack {
                    Spacer()
                    Button(action: onToggleExpand) {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show less" : "Learn more")
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .buttonStyle(PixelButtonStyle(
                        fill: CodepetTheme.accentPurple,
                        paddingH: 12,
                        paddingV: 6,
                        font: .pixelSystem(size: 11, weight: .semibold)
                    ))
                }
            }
            .padding(18)
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    @ViewBuilder
    private var deepDive: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(title: "Analogy", body: term.analogy)

            if let code = term.codeExample {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Code")
                    Text(code)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(CodepetTheme.primaryText)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .pixelBox(
                            fill: Color(white: 0.96),
                            shadowOffset: 3,
                            blockSize: 3,
                            steps: 2,
                            borderWidth: 3
                        )
                }
            }

            if let when = term.whenToUse {
                section(title: "When to use", body: when)
            }
        }
        .padding(.top, 4)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            Text(body)
                .font(CodepetTheme.body(13))
                .foregroundColor(CodepetTheme.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(CodepetTheme.body(10, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(CodepetTheme.mutedText)
    }
}
