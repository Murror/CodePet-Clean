import SwiftUI

struct ReflectionTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var reflectionStore: ReflectionEventStore
    @EnvironmentObject var narrativeStore: NarrativeStore
    @EnvironmentObject var summaryStore: SessionSummaryStore
    @EnvironmentObject var enricher: NarrativeEnricher
    @EnvironmentObject var endStore: SessionEndStore
    @EnvironmentObject var sessionEnricher: SessionSummaryEnricher
    @EnvironmentObject var chatStore: SessionChatStore
    @EnvironmentObject var chatController: SessionChatController

    @State private var selectedSessionId: String? = nil
    @State private var hoveredSessionId: String? = nil
    @State private var chatExpanded = false

    // MARK: - Pet name

    private var petName: String {
        PetCharacter.all[appState.activeChar]?.name ?? ReflectionPet.name
    }

    // MARK: - Turn + Session assembly

    private var allTurns: [Turn] {
        let inputs: [AssemblerInput] = reflectionStore.rawJSONLEvents.compactMap { entry in
            guard !entry.sessionId.isEmpty else { return nil }
            let kind: AssemblerInput.Kind
            switch entry.type {
            case "prompt":  kind = .prompt(text: entry.text)
            case "tool":    kind = .tool(text: entry.text)
            case "summary": kind = .summary(text: entry.text)
            default:        return nil
            }
            return AssemblerInput(kind: kind, isoTime: entry.isoTime, sessionId: entry.sessionId)
        }
        return TurnAssembler.assemble(
            inputs: inputs,
            now: Date(),
            narratives: narrativeStore.narratives
        )
    }

    private var allSessions: [Session] {
        let real = TurnAssembler.assembleSessions(
            turns: allTurns,
            summaries: summaryStore.summaries
        )
        return [Session.makeWelcome()] + real
    }

    private var selectedSession: Session? {
        if let id = selectedSessionId,
           let match = allSessions.first(where: { $0.id == id }) {
            return match
        }
        return allSessions.first  // first is welcome by construction
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sessionsSidebar
                .frame(width: 280)

            Divider()
                .background(ReflectionTheme.borderLight)

            Group {
                if let session = selectedSession {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 36) {
                            if session.isWelcome {
                                WelcomeSessionView()
                            } else {
                                petHeader(for: session)
                                sessionBody(for: session)
                                footer
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(ReflectionTheme.background)
        .overlay(alignment: .bottomTrailing) {
            if let session = selectedSession, !session.isWelcome {
                ZStack(alignment: .bottomTrailing) {
                    if chatExpanded {
                        SessionChatPanel(
                            session: session,
                            onClose: {
                                if chatController.inFlightSessionId == session.id {
                                    chatController.cancel()
                                }
                                chatExpanded = false
                            },
                            onSend: { text in
                                let request = makeChatRequest(for: session, userMessage: text)
                                Task {
                                    await chatController.send(
                                        userText: text,
                                        sessionId: session.id,
                                        request: request
                                    )
                                }
                            }
                        )
                        .padding(16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        SessionChatBubble(onTap: { chatExpanded = true })
                            .padding(16)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: chatExpanded)
            }
        }
        .onChange(of: allSessions) { sessions in
            let persona = currentPetPersona()
            for session in sessions {
                for turn in session.turns where turn.state == .summarizing && turn.narrative == nil {
                    Task { await enricher.enrich(turn: turn, petPersona: persona) }
                }
            }
            for session in sessions {
                if sessionEnricher.shouldAutoSummarize(session: session, endedSessionIds: endStore.endedSessionIds) {
                    Task { await sessionEnricher.enrich(session: session, petPersona: persona) }
                }
            }
        }
        .onChange(of: endStore.endedSessionIds) { _ in
            let sessions = allSessions
            let persona = currentPetPersona()
            for session in sessions {
                if sessionEnricher.shouldAutoSummarize(session: session, endedSessionIds: endStore.endedSessionIds) {
                    Task { await sessionEnricher.enrich(session: session, petPersona: persona) }
                }
            }
        }
    }

    private func currentPetPersona() -> SummarizeTurnRequest.PetPersonaDTO? {
        guard let pet = PetCharacter.all[appState.activeChar] else { return nil }
        return SummarizeTurnRequest.PetPersonaDTO(
            id: pet.id,
            name: pet.name,
            personality: pet.personality,
            domain: pet.domain
        )
    }

    private func makeChatRequest(for session: Session, userMessage: String) -> ChatSessionRequest {
        let history = chatStore.historySnapshot(for: session.id, lastN: 10)
            .map { ChatSessionRequest.ChatMessageDTO(role: $0.role.rawValue, text: $0.text) }
        let context = ReflectionComposition.makeChatContext(
            for: session,
            userBrief: nil  // TODO: wire userBrief once appState exposes it
        )
        let language = Locale.current.identifier.hasPrefix("vi") ? "vi" : "en"
        return ChatSessionRequest(
            sessionId: session.id,
            language: language,
            petPersona: currentPetPersona(),
            sessionContext: context,
            history: history,
            userMessage: userMessage
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer()
            Text("Nothing to reflect on yet.")
                .font(ReflectionTheme.serif(20, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
                .multilineTextAlignment(.center)
            Text("Open Claude Code and start coding — your story will appear here after each working session.")
                .font(ReflectionTheme.sans(13))
                .foregroundColor(ReflectionTheme.mutedText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }

    // MARK: - Sidebar

    private struct DayGroup: Identifiable {
        let label: String
        let sessions: [Session]
        var id: String { label }
    }

    /// Group sessions into day buckets. Sessions sorted newest-first within each bucket.
    /// The welcome session is excluded here — it's rendered separately in the sidebar.
    private func groupedSessions() -> [DayGroup] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let weekStart = cal.date(byAdding: .day, value: -6, to: today)!

        var bucketed: [String: [Session]] = [
            "TODAY": [], "YESTERDAY": [], "THIS WEEK": [], "EARLIER": []
        ]
        for session in allSessions where !session.isWelcome {
            let day = cal.startOfDay(for: session.startedAt)
            let key: String
            if day == today { key = "TODAY" }
            else if day == yesterday { key = "YESTERDAY" }
            else if day >= weekStart { key = "THIS WEEK" }
            else { key = "EARLIER" }
            bucketed[key, default: []].append(session)
        }

        let order = ["TODAY", "YESTERDAY", "THIS WEEK", "EARLIER"]
        return order.compactMap { label in
            let sessions = bucketed[label] ?? []
            guard !sessions.isEmpty else { return nil }
            return DayGroup(label: label, sessions: sessions)
        }
    }

    private func sessionRowTitle(for session: Session) -> String {
        // 1. First sentence of summary (≤60 chars)
        if let summaryText = session.summary?.summary {
            let firstSentence = summaryText.components(separatedBy: ".").first?.trimmingCharacters(in: .whitespaces) ?? summaryText
            let truncated = String(firstSentence.prefix(60))
            if !truncated.isEmpty { return truncated }
        }
        // 2. Newest turn narrative title
        let newestTurn = session.turns.last
        if let title = newestTurn?.narrative?.title { return title }
        // 3. Fallback: "Session HH:mm"
        return "Session \(timeDisplay(session.startedAt))"
    }

    private func sessionMetaLabel(for session: Session) -> String {
        let turnCount = session.turns.count
        let turnWord = turnCount == 1 ? "turn" : "turns"
        var parts = ["Session \(timeDisplay(session.startedAt))", "\(turnCount) \(turnWord)"]
        if let ended = session.endedAt {
            let mins = Int(ended.timeIntervalSince(session.startedAt) / 60)
            if mins > 0 { parts.append("\(mins) min") }
        }
        return parts.joined(separator: " · ")
    }

    private var sessionsSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(ReflectionTheme.serif(16, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Welcome group — always pinned at top
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WELCOME")
                            .font(CodepetTheme.pixel(12))
                            .tracking(1.0)
                            .foregroundColor(ReflectionTheme.mutedText)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                        welcomeSidebarRow(Session.makeWelcome())
                    }

                    // Day-bucket groups
                    let groups = groupedSessions()
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.label)
                                .font(CodepetTheme.pixel(12))
                                .tracking(1.0)
                                .foregroundColor(ReflectionTheme.mutedText)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 2)

                            ForEach(group.sessions) { session in
                                sidebarSessionRow(session)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0xFD / 255.0, green: 0xFC / 255.0, blue: 0xF8 / 255.0))
    }

    private func welcomeSidebarRow(_ session: Session) -> some View {
        let isSelected = session.id == selectedSessionId
        return Button {
            selectedSessionId = session.id
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.pixelSystem(size: 13, weight: .semibold))
                    .foregroundColor(ReflectionTheme.accent)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(ReflectionTheme.accent.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get started")
                        .font(ReflectionTheme.sans(12.5, weight: .semibold))
                        .foregroundColor(ReflectionTheme.primaryText)
                    Text("Connect Claude Code to begin")
                        .font(ReflectionTheme.sans(10.5))
                        .foregroundColor(ReflectionTheme.mutedText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? LinearGradient(colors: [ReflectionTheme.accent.opacity(0.18), ReflectionTheme.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private func sidebarSessionRow(_ session: Session) -> some View {
        let isSelected = session.id == selectedSessionId
        let isHovered = session.id == hoveredSessionId
        return Button {
            selectedSessionId = session.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(sessionStateColor(session))
                    .frame(width: 6, height: 6)
                    .padding(.top, 7)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sessionRowTitle(for: session))
                        .font(ReflectionTheme.sans(12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(ReflectionTheme.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(sessionMetaLabel(for: session))
                        .font(ReflectionTheme.sans(10.5))
                        .foregroundColor(ReflectionTheme.mutedText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ReflectionTheme.accent.opacity(0.10)
                          : (isHovered ? Color.black.opacity(0.03) : Color.clear))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(ReflectionTheme.accent)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .onHover { hoveredSessionId = $0 ? session.id : nil }
    }

    /// Color represents the "worst" state among the session's turns.
    private func sessionStateColor(_ session: Session) -> Color {
        let hasFailed = session.turns.contains {
            if case .failed = $0.state { return true }
            return false
        }
        if hasFailed { return ReflectionTheme.moodAlert }
        let hasSummarizing = session.turns.contains { $0.state == .summarizing || $0.state == .pending }
        if hasSummarizing { return ReflectionTheme.accent }
        return ReflectionTheme.moodCalm
    }

    // MARK: - Pet header (session level)

    @ViewBuilder
    private func petHeader(for session: Session) -> some View {
        HStack(alignment: .center, spacing: 12) {
            PetAvatar(mood: .calm, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(petName)
                    .font(ReflectionTheme.serif(18, weight: .medium))
                    .foregroundColor(ReflectionTheme.primaryText)
                Text(dateDisplay(session.startedAt))
                    .font(ReflectionTheme.sans(11))
                    .foregroundColor(ReflectionTheme.mutedText)
            }
            Spacer()
        }
    }

    // MARK: - Session body

    @ViewBuilder
    private func sessionBody(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            // Session header strip
            sessionHeaderStrip(for: session)

            // Pet recap up top — high-level voice before the turn-by-turn detail
            SessionSummaryView(summary: session.summary) {
                let persona = currentPetPersona()
                Task { await sessionEnricher.enrich(session: session, petPersona: persona) }
            }

            // Per-turn rendering (chronological, oldest first).
            // Avatar appears only on the newest turn — older turns share the
            // pet-color thread so the page doesn't feel like the avatar
            // repeats on every entry.
            ForEach(Array(session.turns.enumerated()), id: \.element.id) { index, turn in
                turnSection(for: turn, isLast: index == session.turns.count - 1)
            }
        }
    }

    private func sessionHeaderStrip(for session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sessionMetaLabel(for: session))
                .font(ReflectionTheme.sans(13, weight: .medium))
                .foregroundColor(ReflectionTheme.primaryText)
            Rectangle()
                .fill(ReflectionTheme.borderLight)
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func turnSection(for turn: Turn, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Turn title + time metadata
            VStack(alignment: .leading, spacing: 6) {
                if let title = turn.narrative?.title {
                    Text(title)
                        .font(ReflectionTheme.serif(18, weight: .medium))
                        .foregroundColor(ReflectionTheme.primaryText)
                }
                HStack(spacing: 6) {
                    Text(timeDisplay(turn.startedAt))
                        .font(ReflectionTheme.sans(12))
                        .foregroundColor(ReflectionTheme.mutedText)
                    if let ended = turn.endedAt {
                        Text("·")
                            .foregroundColor(ReflectionTheme.mutedText)
                        Text("\(Int(ended.timeIntervalSince(turn.startedAt) / 60)) min")
                            .font(ReflectionTheme.sans(12))
                            .foregroundColor(ReflectionTheme.mutedText)
                    }
                }
            }

            // Narrative chat view or loading state
            if let narrative = turn.narrative {
                NarrativeChatTurnView(narrative: narrative, showAvatar: isLast)
            } else {
                TurnLoadingStates(state: turn.state, onRetry: {
                    let persona = currentPetPersona()
                    Task { await enricher.enrich(turn: turn, petPersona: persona) }
                })
            }

            // Collapsed technical details
            if !turn.rawEvents.isEmpty {
                TechnicalDetailsView(prompt: turn.prompt, events: turn.rawEvents)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Eyebrow(text: "CodePet v1.0 · reflection · captured quietly. shown on request.")
            Spacer()
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func timeDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateDisplay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · MMMM d"
        return f.string(from: date)
    }
}

#Preview {
    let summaryStore = SessionSummaryStore()
    let api = ReflectionAPIClient()
    let chatStore = SessionChatStore(
        fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-chat.json")
    )
    let chatController = SessionChatController(api: api, store: chatStore)
    return ReflectionTab()
        .environmentObject(AppState())
        .environmentObject(ReflectionEventStore())
        .environmentObject(NarrativeStore())
        .environmentObject(summaryStore)
        .environmentObject(NarrativeEnricher(
            api: api,
            store: NarrativeStore(),
            language: "vi"
        ))
        .environmentObject(SessionEndStore())
        .environmentObject(SessionSummaryEnricher(
            api: api,
            store: summaryStore,
            language: "vi"
        ))
        .environmentObject(chatStore)
        .environmentObject(chatController)
        .frame(width: 900, height: 800)
}
