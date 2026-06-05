import SwiftUI

struct DictionaryView: View {

    @Environment(\.uiLanguage) private var uiLanguage
    @EnvironmentObject private var projectStore: ProjectStore

    @State private var selectedTopicId: String = DictionaryContent.topics.first!.id
    @State private var searchQuery: String = ""
    @State private var expandedTermIds: Set<String> = []
    @State private var showProjectPanel: Bool = true

    private var visibleTerms: [DictionaryTerm] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DictionaryContent.terms(in: selectedTopicId)
        }
        return DictionaryContent.search(trimmed)
    }

    private var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The most-recent project's matched terms + inferred stack. Computed once
    /// per render and reused for the panel AND every card's "Used in…" badge.
    private var projectGroup: DictionaryMatcher.ProjectTermGroup? {
        DictionaryMatcher.match(projects: projectStore.projects)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
                .frame(width: 220)

            Rectangle()
                .fill(CodepetTheme.hairline)
                .frame(width: 1)

            contentPane
                .frame(maxWidth: .infinity)
        }
        .background(CodepetTheme.pageBackground)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(uiLanguage == .vi ? "TỪ ĐIỂN" : "DICTIONARY")
                .font(CodepetTheme.pixel(11))
                .tracking(1.2)
                .foregroundColor(CodepetTheme.mutedText)
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 14)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(DictionaryContent.topics) { topic in
                        topicRow(topic)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
        }
    }

    private func topicRow(_ topic: DictionaryTopic) -> some View {
        let isSelected = topic.id == selectedTopicId && !isSearching
        return Button {
            selectedTopicId = topic.id
            searchQuery = ""
        } label: {
            HStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .frame(width: 18)
                    .foregroundColor(isSelected ? .white : CodepetTheme.bodyText)
                Text(topic.title(uiLanguage))
                    .font(CodepetTheme.pixel(13))
                    .foregroundColor(isSelected ? .white : CodepetTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? CodepetTheme.accentPurple : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content pane

    private var contentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(CodepetTheme.hairline)
            cardList
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSearching
                 ? (uiLanguage == .vi ? "Kết quả tìm kiếm" : "Search results")
                 : currentTopicTitle)
                .font(CodepetTheme.display(22, weight: .bold))
                .foregroundColor(CodepetTheme.primaryText)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CodepetTheme.mutedText)
                TextField(uiLanguage == .vi ? "Tìm kiếm trong từ điển…" : "Search all terms…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(CodepetTheme.body(13))
                    .foregroundColor(CodepetTheme.primaryText)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CodepetTheme.mutedText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .codepetInput()
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 18)
    }

    private var currentTopicTitle: String {
        DictionaryContent.topics.first { $0.id == selectedTopicId }?.title(uiLanguage)
            ?? (uiLanguage == .vi ? "Từ điển" : "Dictionary")
    }

    @ViewBuilder
    private var cardList: some View {
        if visibleTerms.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if !isSearching, let group = projectGroup {
                            projectPanel(group, proxy: proxy)
                        }
                        ForEach(visibleTerms) { term in
                            DictionaryCard(
                                term: term,
                                isExpanded: expandedTermIds.contains(term.id),
                                onToggleExpand: { toggleExpand(term.id) },
                                projectTags: projectGroup?.tags ?? [],
                                projectName: projectGroup?.projectName
                            )
                            .id(term.id)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                }
            }
        }
    }

    // MARK: - Surface B: project-aware panel

    private func projectPanel(_ group: DictionaryMatcher.ProjectTermGroup, proxy: ScrollViewProxy) -> some View {
        PixelCard(fill: Color(hex: "#EEEDFE")) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showProjectPanel.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(CodepetTheme.accentPurple)
                        Text(uiLanguage == .vi
                             ? "Trong \(group.projectName), bạn đang dùng:"
                             : "In \(group.projectName), you're using:")
                            .font(CodepetTheme.display(14, weight: .bold))
                            .foregroundColor(CodepetTheme.primaryText)
                        Spacer()
                        Image(systemName: showProjectPanel ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(CodepetTheme.mutedText)
                    }
                }
                .buttonStyle(.plain)

                if showProjectPanel {
                    stackPills(group.tags)
                    termGrid(group, proxy: proxy)
                }
            }
            .padding(16)
        }
        .padding(.bottom, 4)
    }

    private func stackPills(_ tags: Set<ProjectTag>) -> some View {
        let labels = projectTagLabels(tags)
        return HStack(spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.pixelSystem(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(techTagColor(label)))
            }
            Spacer(minLength: 0)
        }
    }

    private func termGrid(_ group: DictionaryMatcher.ProjectTermGroup, proxy: ScrollViewProxy) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(group.terms) { matched in
                Button {
                    jumpTo(matched.term, proxy: proxy)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(CodepetTheme.accentPurple)
                        Text(matched.term.title(uiLanguage))
                            .font(CodepetTheme.body(12, weight: .semibold))
                            .foregroundColor(CodepetTheme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func jumpTo(_ term: DictionaryTerm, proxy: ScrollViewProxy) {
        searchQuery = ""
        selectedTopicId = term.topicId
        expandedTermIds.insert(term.id)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(term.id, anchor: .top)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(CodepetTheme.mutedText)
            Text(uiLanguage == .vi
                 ? "Không có kết quả cho \u{201C}\(searchQuery)\u{201D}."
                 : "No matches for \u{201C}\(searchQuery)\u{201D}.")
                .font(CodepetTheme.body(13))
                .foregroundColor(CodepetTheme.mutedText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleExpand(_ id: String) {
        if expandedTermIds.contains(id) {
            expandedTermIds.remove(id)
        } else {
            expandedTermIds.insert(id)
        }
    }
}
