import SwiftUI

struct DictionaryCard: View {

    @Environment(\.uiLanguage) private var uiLanguage

    let term: DictionaryTerm
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(term.title(uiLanguage))
                    .font(CodepetTheme.display(18, weight: .bold))
                    .foregroundColor(CodepetTheme.primaryText)

                Text(markdown: term.shortDefinition(uiLanguage))
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
                            Text(isExpanded
                                 ? (uiLanguage == .vi ? "Thu gọn" : "Show less")
                                 : (uiLanguage == .vi ? "Tìm hiểu thêm" : "Learn more"))
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
            section(title: uiLanguage == .vi ? "Ví dụ ẩn dụ" : "Analogy", body: term.analogy(uiLanguage))

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
                section(title: uiLanguage == .vi ? "Khi nào dùng" : "When to use", body: when(uiLanguage))
            }
        }
        .padding(.top, 4)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            Text(markdown: body)
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
