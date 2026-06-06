import SwiftUI

struct DictionaryView: View {

    @Environment(\.uiLanguage) private var uiLanguage
    @EnvironmentObject private var projectStore: ProjectStore

    @State private var selectedTopicId: String = DictionaryContent.topics.first!.id
    @State private var searchQuery: String = ""
    @State private var expandedTermIds: Set<String> = []
    @State private var showProjectPanel: Bool = true

    /// When true the dictionary is shown as a plain, universal reference: the
    /// project panel (Surface B) and the per-card "Used in …" badges (Surface
    /// A) are hidden. Lets a user read definitions detached from whatever
    /// project they happen to be working on. Persisted so the choice sticks.
    @AppStorage("cp_dictionaryDetached") private var detached: Bool = false

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

    /// The project group actually applied to the UI — `nil` while detached, so
    /// the panel and every card badge drop out together. (`projectGroup` stays
    /// live underneath so the re-link bar still knows which project to offer.)
    private var effectiveGroup: DictionaryMatcher.ProjectTermGroup? {
        detached ? nil : projectGroup
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
                VStack(spacing: 6) {
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
        let accent = topic.accent.color
        let count = DictionaryContent.terms(in: topic.id).count
        return Button {
            selectedTopicId = topic.id
            searchQuery = ""
        } label: {
            HStack(spacing: 10) {
                sidebarIcon(topic.icon, accent: accent, selected: isSelected)
                Text(topic.title(uiLanguage))
                    .font(CodepetTheme.pixel(13))
                    .foregroundColor(isSelected ? .white : CodepetTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                countBadge(count, accent: accent, selected: isSelected)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? accent : Color.clear)
            )
            // Make the WHOLE row clickable — without this, `.buttonStyle(.plain)`
            // only hit-tests the opaque icon/title/badge, so clicks landing on
            // the transparent Spacer gap in the middle of the row do nothing
            // (felt like "I have to click 2-3 times to switch tabs").
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarIcon(_ name: String, accent: Color, selected: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(selected ? .white : accent)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.22) : accent.opacity(0.16))
            )
    }

    private func countBadge(_ count: Int, accent: Color, selected: Bool) -> some View {
        Text("\(count)")
            .font(.pixelSystem(size: 10, weight: .semibold))
            .foregroundColor(selected ? .white : accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(selected ? Color.white.opacity(0.22) : accent.opacity(0.12))
            )
    }

    // MARK: - Content pane

    private var contentPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(CodepetTheme.hairline)
            cardList
        }
    }

    /// Topic currently driving the header theme (nil while searching).
    private var currentTopic: DictionaryTopic? {
        isSearching ? nil : DictionaryContent.topic(forId: selectedTopicId)
    }

    /// Accent for the hero banner: the selected topic's color, or purple in
    /// search mode.
    private var headerAccent: Color {
        currentTopic?.accent.color ?? CodepetTheme.accentPurple
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroBanner
            searchField
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    /// Always-visible toggle for project tailoring, living in the hero banner.
    /// On → the project panel + "Used in …" badges appear (when a project is
    /// detected); off → the dictionary reads as a plain universal reference.
    /// Stateful label so its effect is legible even before a project exists.
    private var tailorToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { detached.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: detached ? "pin.slash.fill" : "pin.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(detached
                     ? (uiLanguage == .vi ? "Đã tách" : "Detached")
                     : (uiLanguage == .vi ? "Theo dự án" : "Tailored"))
                    .font(.pixelSystem(size: 10, weight: .semibold))
            }
            .foregroundColor(detached ? CodepetTheme.mutedText : CodepetTheme.accentPurple)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(detached
                               ? Color.white.opacity(0.7)
                               : CodepetTheme.accentPurple.opacity(0.16))
            )
        }
        .buttonStyle(.plain)
        .help(detached
              ? (uiLanguage == .vi ? "Bật lại gợi ý theo dự án của bạn" : "Tailor the dictionary to your project")
              : (uiLanguage == .vi ? "Xem từ điển không gắn với dự án" : "Show the dictionary without your project"))
    }

    private var heroBanner: some View {
        let accent = headerAccent
        let icon = currentTopic?.icon ?? "magnifyingglass"
        let title = isSearching
            ? (uiLanguage == .vi ? "Kết quả tìm kiếm" : "Search results")
            : currentTopicTitle
        let subtitle: String = {
            if isSearching {
                let n = visibleTerms.count
                return uiLanguage == .vi ? "\(n) kết quả" : "\(n) result\(n == 1 ? "" : "s")"
            }
            return currentTopic?.blurb(uiLanguage) ?? ""
        }()
        return PixelCard(fill: accent.opacity(0.16), shadowOffset: 3, blockSize: 3, steps: 2, borderWidth: 3) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .pixelBox(fill: accent, shadowOffset: 2, blockSize: 2, steps: 2, borderWidth: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CodepetTheme.display(22, weight: .bold))
                        .foregroundColor(CodepetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(CodepetTheme.body(12))
                            .foregroundColor(CodepetTheme.bodyText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)

                tailorToggle

                if !isSearching {
                    let count = DictionaryContent.terms(in: selectedTopicId).count
                    VStack(spacing: 1) {
                        Text("\(count)")
                            .font(CodepetTheme.display(20, weight: .bold))
                            .foregroundColor(accent)
                        Text(uiLanguage == .vi ? "từ" : "terms")
                            .font(.pixelSystem(size: 9, weight: .semibold))
                            .tracking(1.0)
                            .foregroundColor(CodepetTheme.mutedText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isSearching ? headerAccent : CodepetTheme.mutedText)
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
                        if !isSearching, let group = effectiveGroup {
                            projectPanel(group, proxy: proxy)
                        }
                        ForEach(visibleTerms) { term in
                            DictionaryCard(
                                term: term,
                                isExpanded: expandedTermIds.contains(term.id),
                                onToggleExpand: { toggleExpand(term.id) },
                                projectTags: effectiveGroup?.tags ?? [],
                                projectName: effectiveGroup?.projectName
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
                    .contentShape(Rectangle())
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
