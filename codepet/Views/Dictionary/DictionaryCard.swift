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

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: 12) {
                header

                Text(markdown: term.cardDefinition(uiLanguage))
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

    // MARK: - Header (title + optional "used in project" badge)

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(term.title(uiLanguage))
                .font(CodepetTheme.display(18, weight: .bold))
                .foregroundColor(CodepetTheme.primaryText)
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
