import SwiftUI

struct DictionaryCard: View {

    @Environment(\.uiLanguage) private var uiLanguage

    let term: DictionaryTerm
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    /// The active/most-recent project's inferred stack + name, computed once by
    /// `DictionaryView` and passed down so cards don't re-infer per render.
    var projectTags: Set<ProjectTag> = []
    var projectName: String? = nil

    private var usedInProject: String? {
        guard let projectName else { return nil }
        return DictionaryMatcher.projectUsing(term, projectTags: projectTags, projectName: projectName)
    }

    /// The card's color — its topic's brand color, so every card in a topic
    /// shares one consistent, category-coded hue (Functions = pink, Control
    /// Flow = blue, …). Drives the icon chip, section labels, and the button.
    /// The multicolor diagram still lives inside the expanded card.
    private var accentColor: Color {
        DictionaryContent.accent(forTopicId: term.topicId).color
    }

    /// The card's icon — its topic's icon, matching the sidebar and hero badge
    /// so a card reads unmistakably as part of its category.
    private var glyph: String {
        DictionaryContent.topic(forId: term.topicId)?.icon ?? "book.fill"
    }

    var body: some View {
        PixelCard(fill: accentColor.opacity(0.07)) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Text(markdown: term.cardDefinition(uiLanguage))
                    .font(CodepetTheme.body(15))
                    .foregroundColor(CodepetTheme.bodyText)
                    .fixedSize(horizontal: false, vertical: true)

                if isExpanded {
                    deepDive
                        .transition(.opacity)
                }

                HStack {
                    Spacer()
                    Button(action: onToggleExpand) {
                        HStack(spacing: 6) {
                            Text(isExpanded
                                 ? (uiLanguage == .vi ? "Thu gọn" : "Show less")
                                 : (uiLanguage == .vi ? "Tìm hiểu thêm" : "Learn more"))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(PixelButtonStyle(
                        fill: accentColor,
                        paddingH: 18,
                        paddingV: 10,
                        font: .pixelSystem(size: 13, weight: .semibold)
                    ))
                }
            }
            .padding(18)
        }
        .animation(.easeInOut(duration: 0.22), value: isExpanded)
    }

    // MARK: - Header (title + optional "used in project" badge)

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: glyph)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .pixelBox(fill: accentColor, shadowOffset: 2, blockSize: 2, steps: 2, borderWidth: 2)

            Text(term.title(uiLanguage))
                .font(CodepetTheme.display(18, weight: .bold))
                .foregroundColor(CodepetTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let project = usedInProject {
                usedInBadge(project)
            }
        }
    }

    private func usedInBadge(_ project: String) -> some View {
        let tint = techTagColor(projectTagLabels(Set(term.tags)).first ?? "")
        return HStack(spacing: 4) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 8, weight: .bold))
            Text(uiLanguage == .vi ? "Dùng trong \(project)" : "Used in \(project)")
                .font(.pixelSystem(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.14)))
    }

    // MARK: - Deep dive

    @ViewBuilder
    private var deepDive: some View {
        VStack(alignment: .leading, spacing: 16) {
            section(title: uiLanguage == .vi ? "Hiểu sâu hơn" : "What it really means",
                    body: term.whatItReallyMeans(uiLanguage))

            if let diagram = term.diagram {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel(uiLanguage == .vi ? "Hình dung" : "Picture it")
                    DictionaryDiagramView(spec: diagram)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }

            if let code = term.codeExample {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("Code")
                    Text(code)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
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
                .font(CodepetTheme.body(15))
                .foregroundColor(CodepetTheme.bodyText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(accentColor)
                .frame(width: 14, height: 4)
            Text(text.uppercased())
                .font(CodepetTheme.body(11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(CodepetTheme.bodyText)
        }
    }
}
